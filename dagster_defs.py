#!/usr/bin/env -S uv run --script
# PEP 723 dependency definition: https://peps.python.org/pep-0723/
# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#    "dagster-postgres>=0.27.4",
#    "dagster-webserver==1.12.2",
#    "dagster==1.12.2",
#    "dagster-graphql==1.12.2",
#    "cfa-dagster @ git+https://github.com/cdcgov/cfa-dagster.git",
#     "cfa-config-generator @ git+https://github.com/cdcgov/cfa-config-generator.git",
# ]
# ///

from datetime import date, datetime, timedelta, timezone
import os
import subprocess

import dagster as dg

from cfa_dagster import (
    AzureContainerAppJobRunLauncher,
    ADLS2PickleIOManager,
    start_dev_env,
    collect_definitions,
    launch_asset_backfill,
    azure_batch_executor,
    azure_container_app_job_executor as azure_caj_executor,
    docker_executor,
)
from dagster_docker import DockerRunLauncher
from cfa_config_generator.utils.epinow2.driver_functions import (
    generate_config
)
from cfa_config_generator.utils.epinow2.constants import (
    nssp_valid_states,
    all_diseases
)

# start the Dagster dev server
start_dev_env(__name__)

# get the user from the environment, throw an error if variable is not set
user = os.environ["DAGSTER_USER"]

# check Dagster-set env var if we're in dev mode
is_production = not os.getenv("DAGSTER_IS_DEV_CLI")


STORAGE_ACCOUNT = "cfaazurebatchprd"
STORAGE_ACCOUNT_PATH = f"https://{STORAGE_ACCOUNT}.blob.core.windows.net"
CONFIG_CONTAINER = "rt-epinow2-config"
# OUTPUT_CONTAINER = "nssp-rt-v2" if is_production else "nssp-rt-testing"
OUTPUT_CONTAINER = "nssp-rt-testing"  # hard-coding test during Dagster evaluation


state_partitions = dg.StaticPartitionsDefinition(sorted(nssp_valid_states))
disease_partitions = dg.StaticPartitionsDefinition(list(all_diseases))
rt_partitions = dg.MultiPartitionsDefinition({
    "state": state_partitions,
    "disease": disease_partitions,
})


class RtConfig(dg.Config):
    job_id: str = (
        "Rt-estimation-" +
        datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    )
    report_date_str: str = datetime.now(timezone.utc).strftime("%F")
    output_container: str = OUTPUT_CONTAINER
    input_container: str = "nssp-etl"
    production_date_str: str = date.today().isoformat()
    facility_active_proportion: float = 0.94


@dg.asset(
    description="The Rt pipeline config",
    partitions_def=rt_partitions,
)
def cfa_config_generator(
    context: dg.AssetExecutionContext,
    config: RtConfig
) -> dict:
    """
    The Rt pipeline config
    """
    context.log.debug(f"config: '{config}'")
    keys_by_dimension: dg.MultiPartitionKey = context.partition_key.keys_by_dimension
    state = keys_by_dimension["state"]
    disease = keys_by_dimension["disease"]
    report_date: date = date.fromisoformat(config.report_date_str)
    production_date: date = date.fromisoformat(config.production_date_str)
    now: datetime = datetime.now(timezone.utc)

    # Make sure facility_active_proportion is between 0 and 1.
    if not (0 <= config.facility_active_proportion <= 1):
        raise ValueError(
            "facility_active_proportion must be between 0 and 1, inclusive."
        )

    rt_config = generate_config(
        state=state,
        disease=disease,
        report_date=report_date,
        reference_dates=[
            report_date - timedelta(days=1),
            report_date - timedelta(weeks=8),
        ],
        data_path=f"gold/{report_date.isoformat()}.parquet",
        data_container=config.input_container,
        production_date=production_date,
        job_id=config.job_id,
        as_of_date=now.isoformat(),
        output_container=config.output_container,
        facility_active_proportion=config.facility_active_proportion,
    )[0]  # only exepecting one
    task_id = rt_config["task_id"]
    yield dg.MaterializeResult(
        value=rt_config,
        metadata={
            "storage_account": STORAGE_ACCOUNT,
            "storage_container": CONFIG_CONTAINER,
            "job_id": config.job_id,
            "blob": f"{config.job_id}/{task_id}.json",
            "config": rt_config
        }
    )


@dg.asset(
    description="The Rt pipeline",
    partitions_def=rt_partitions,
)
def cfa_epinow2_pipeline(
    context: dg.AssetExecutionContext,
    cfa_config_generator
) -> str:
    config = cfa_config_generator

    job_id = config.get("job_id")
    blob_name = f"{job_id}/{config.get('task_id')}.json"

    context.log.debug(f"job_id: '{job_id}'")
    context.log.debug(f"blob_name: '{blob_name}'")
    context.log.debug(f"config: '{config}'")
    subprocess.run([
            "Rscript",
            "-e",
            (f"CFAEpiNow2Pipeline::orchestrate_pipeline('{blob_name}', "
             f"config_container = '{CONFIG_CONTAINER}')"),
    ], check=True)
    output_path = f"{STORAGE_ACCOUNT_PATH}/{OUTPUT_CONTAINER}/{job_id}"
    return dg.MaterializeResult(
        value=output_path,
        metadata={
            "config": config,
            "output_path": output_path,
            "storage_account": STORAGE_ACCOUNT,
            "storage_container": OUTPUT_CONTAINER,
            "blob_path": job_id,
        }
    )


# change from :dagster to :latest tag once merged to main
image = "cfaprdbatchcr.azurecr.io/cfa-epinow2-pipeline:dagster"


@dg.op
def launch_pipeline(context: dg.OpExecutionContext):
    partition_keys = rt_partitions.get_partition_keys()
    partition_keys = ["COVID-19|AL"]
    asset_selection = ["cfa_config_generator", "cfa_epinow2_pipeline"]
    backfill_id = launch_asset_backfill(
        asset_selection,
        partition_keys,
    )
    context.log.info(
        f"Launched backfill with id: '{backfill_id}'. "
        "Click the output metadata url to monitor"
    )
    return dg.Output(
        value=backfill_id,
        metadata={
            "url": dg.MetadataValue.url(f"/runs/b/{backfill_id}")
        }
    )


# This just calls the graphql api to launch the pipeline so it's
# small enough to run directly on the code location
@dg.job(
    executor_def=dg.in_process_executor,
    tags={
        "cfa_dagster/launcher": {
            "class": dg.DefaultRunLauncher.__name__
        }
    }
)
def weekly_rt_pipeline():
    launch_pipeline()


schedule_weekly_rt_pipeline = dg.ScheduleDefinition(
    default_status=(
        dg.DefaultScheduleStatus.RUNNING
        # don't run locally by default
        if is_production else dg.DefaultScheduleStatus.STOPPED
    ),
    job=weekly_rt_pipeline,
    cron_schedule="30 6 * * 3",
    execution_timezone="America/New_York",
)

collected_defs = collect_definitions(globals())

# Create Definitions object
defs = dg.Definitions(
    assets=collected_defs["assets"],
    asset_checks=collected_defs["asset_checks"],
    jobs=collected_defs["jobs"],
    sensors=collected_defs["sensors"],
    schedules=collected_defs["schedules"],
    resources={
        # This IOManager lets Dagster serialize asset outputs and store them
        # in Azure to pass between assets
        "io_manager": ADLS2PickleIOManager(),
    },
    # in_process_executor runs steps directly in the RunLauncher environment
    # When paired with the AzureContainerAppJobRunLauncher, this lets
    # cfa-config-generator and cfa-epinow2-pipeline run on the same CAJ
    executor=dg.in_process_executor,
    metadata={
        "cfa_dagster/launcher": {
            # uncomment the below to run locally using Docker
            # "class": DockerRunLauncher.__name__,
            # "config": {
            #     "image": image,
            # }
            "class": AzureContainerAppJobRunLauncher.__name__,
            "config": {
                "image": image,
                "container_app_job_name": "cfa-epinow2-pipeline"
            }
        }
    }
)
