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
#    "pyyaml>=6.0.2",
#     "cfa-config-generator @ git+https://github.com/cdcgov/cfa-config-generator.git@gio-return-config",
# ]
# ///
from datetime import date, datetime, timedelta, timezone
import os
import subprocess

import dagster as dg

from cfa_dagster.azure_adls2 import ADLS2PickleIOManager
from cfa_dagster.utils import (
    bootstrap_dev,
    collect_definitions,
    get_latest_metadata_for_partition,
    launch_asset_backfill,
)
from cfa_dagster.azure_batch.executor import azure_batch_executor
from cfa_dagster.azure_container_app_job.executor import (
    azure_container_app_job_executor as azure_caj_executor,
)
from cfa_dagster.docker.executor import docker_executor

from cfa_config_generator.utils.epinow2.driver_functions import (
    generate_local_config
)
from cfa_config_generator.utils.epinow2.constants import (
    nssp_valid_states,
    all_diseases
)

# start the Dagster dev server
bootstrap_dev()

# get the user from the environment, throw an error if variable is not set
user = os.environ["DAGSTER_USER"]

# check Dagster-set env var if we're in dev mode
is_production = not os.getenv("DAGSTER_IS_DEV_CLI")

STORAGE_ACCOUNT = "cfaazurebatchprd"
STORAGE_ACCOUNT_PATH = f"https://{STORAGE_ACCOUNT}.blob.core.windows.net"
CONFIG_CONTAINER = "rt-epinow2-config"
# OUTPUT_CONTAINER = "nssp-rt-v2" if is_production else "nssp-rt-testing"
OUTPUT_CONTAINER = "nssp-rt-testing"


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
    # BackfillPolicy.single_run() will allow all partitions to be materialized
    # in a single run aka a single container app job execution.
    # Since this is a multi-dimension partition, it ends up being 3 runs
    backfill_policy=dg.BackfillPolicy.single_run()
)
def single_run_rt_config(
    context: dg.AssetExecutionContext,
    config: RtConfig
) -> None:
    """
    The Rt pipeline config
    """
    context.log.debug(f"config: '{config}'")
    report_date: date = date.fromisoformat(config.report_date_str)
    production_date: date = date.fromisoformat(config.production_date_str)
    now: datetime = datetime.now(timezone.utc)

    # Make sure facility_active_proportion is between 0 and 1.
    if not (0 <= config.facility_active_proportion <= 1):
        raise ValueError(
            "facility_active_proportion must be between 0 and 1, inclusive."
        )

    # split list of disease|state pairs into comma-separated strings
    # e.g. ["RSV|AK", "COVID-19|AR"] -> "RSV,COVID-19", "AK,AR"
    diseases, states = map(
        lambda x: ",".join(sorted(set(x))),
        zip(*[key.split("|") for key in context.partition_keys])
    )

    rt_configs = generate_local_config(
        state=states,
        disease=diseases,
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
    )
    for rt_config in rt_configs:
        disease = rt_config["disease"]
        state = rt_config["geo_value"]
        task_id = rt_config["task_id"]
        partition_key = f"{disease}|{state}"
        # Materialize asset metadata per partition
        yield dg.AssetMaterialization(
            asset_key=context.asset_key,
            partition=partition_key,
            metadata={
                "storage_account": STORAGE_ACCOUNT,
                "storage_container": CONFIG_CONTAINER,
                "job_id": config.job_id,
                "blob": f"{config.job_id}/{task_id}.json",
                "config": rt_config
            }
        )
    context.log.debug(f"partition_key_range: '{context.partition_key_range}'")
    # materialize empty result since Dagster
    # can't output values per-partition for BackfillPolicy.single_run()
    yield dg.MaterializeResult()


@dg.asset(
    description="The Rt pipeline",
    partitions_def=rt_partitions,
    deps=[single_run_rt_config],
)
def single_config_rt_pipeline(
    context: dg.AssetExecutionContext,
    config: RtConfig,
) -> str:

    metadata = get_latest_metadata_for_partition(
        context.instance,
        "single_run_rt_config",
        context.partition_key
    )
    context.log.debug(f"metadata: '{metadata}'")
    config = metadata.get("config")

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


workdir = "/app"
image = "cfaprdbatchcr.azurecr.io/cfa-epinow2-pipeline:dagster"

# configuring an executor to run workflow steps on Docker
# add this to a job or the Definitions class to use it
docker_executor_configured = docker_executor.configured(
    {
        # specify a default image
        "image": image,
        # "env_vars": [f"DAGSTER_USER={user}"],
        "container_kwargs": {
            "volumes": [
                # bind the ~/.azure folder for optional cli login
                f"/home/{user}/.azure:/root/.azure",
                # bind current file so we don't have to rebuild
                # the container image for workflow changes
                f"{__file__}:{workdir}/{os.path.basename(__file__)}",
            ]
        },
    }
)

# configuring an executor to run workflow steps on Azure Container App Jobs
# add this to a job or the Definitions class to use it
azure_caj_executor_configured = azure_caj_executor.configured(
    {
        "container_app_job_name": "cfa-dagster",
        "cpu": 2,
        "memory": 4,
        "image": image,
        # "env_vars": [f"DAGSTER_USER={user}"],
    }
)

# configuring an executor to run workflow steps on Azure Batch 4CPU 16GB pool
# add this to a job or the Definitions class to use it
azure_batch_executor_configured = azure_batch_executor.configured(
    {
        "pool_name": "cfa-dagster",
        "image": image,
        # "env_vars": [f"DAGSTER_USER={user}"],
        "container_kwargs": {
            "working_dir": workdir,
        },
    }
)


@dg.op
def launch_pipeline(context: dg.OpExecutionContext):
    partition_keys = rt_partitions.get_partition_keys()[:3]
    asset_selection = ["single_run_rt_config", "single_config_rt_pipeline"]
    backfill_id = launch_asset_backfill(
        asset_selection,
        partition_keys,
    )
    context.log.info(f"Launched backfill with id: '{backfill_id}'")


@dg.job(
    # run this job directly on the code location server
    executor_def=dg.in_process_executor
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
    # setting Docker as the default executor. comment this out to use
    # the default executor that runs directly on your computer
    # executor=dg.in_process_executor
    # executor=docker_executor_configured,
    executor=azure_caj_executor_configured,
    # executor=azure_batch_executor_configured,
)
