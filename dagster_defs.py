#!/usr/bin/env -S uv run --script
# PEP 723 dependency definition: https://peps.python.org/pep-0723/
# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#    "dagster-azure>=0.27.4",
#    "dagster-docker>=0.27.4",
#    "dagster-postgres>=0.27.4",
#    "dagster-webserver",
#    "dagster==1.11.4",
#  # pydantic 2.12.X contains breaking changes for Dagster
#    "pydantic==2.11.9",
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
from cfa_dagster.utils import bootstrap_dev, collect_definitions
from cfa_dagster.azure_batch.executor import azure_batch_executor
from cfa_dagster.azure_container_app_job.executor import (
    azure_container_app_job_executor as azure_caj_executor,
)
from cfa_dagster.docker.executor import docker_executor

from cfa_config_generator.utils.epinow2.driver_functions import generate_config
from cfa_config_generator.utils.epinow2.constants import nssp_valid_states, all_diseases

# start the Dagster dev server
bootstrap_dev()

# get the user from the environment, throw an error if variable is not set
user = os.environ["DAGSTER_USER"]

# check Dagster-set env var if we're in dev mode
is_production = not os.getenv("DAGSTER_IS_DEV_CLI")

STORAGE_ACCOUNT = "cfaazurebatchprd"
STORAGE_ACCOUNT_PATH = f"https://{STORAGE_ACCOUNT}.blob.core.windows.net"
CONFIG_CONTAINER = "rt-epinow2-config"
OUTPUT_CONTAINER = "nssp-rt-v2" if is_production else "nssp-rt-testing"


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
    partitions_def=rt_partitions
)
def rt_config(
    context: dg.AssetExecutionContext,
    job_id,
    config: RtConfig
) -> tuple[str, str, dict]:
    """
    The Rt pipeline config
    """
    keys_by_dimension: dg.MultiPartitionKey = context.partition_key.keys_by_dimension
    state = keys_by_dimension["state"]
    disease = keys_by_dimension["disease"]
    context.log.debug(f"state: '{state}'")
    context.log.debug(f"disease: '{disease}'")
    context.log.debug(f"report_date_str: '{config.report_date_str}'")
    context.log.debug(f"output_container: '{config.output_container}'")
    context.log.debug(f"input_container: '{config.input_container}'")
    context.log.debug(f"production_date_str: '{config.production_date_str}'")
    context.log.debug(f"facility_active_proportion: '{config.facility_active_proportion}'")
    report_date: date = date.fromisoformat(config.report_date_str)
    production_date: date = date.fromisoformat(config.production_date_str)
    now: datetime = datetime.now(timezone.utc)

    # Make sure facility_active_proportion is between 0 and 1.
    if not (0 <= config.facility_active_proportion <= 1):
        raise ValueError(
            "facility_active_proportion must be between 0 and 1, inclusive."
        )
    configs = generate_config(
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
        job_id=job_id,
        as_of_date=now.isoformat(),
        output_container=config.output_container,
        facility_active_proportion=config.facility_active_proportion,
    )
    config = configs[0]  # only running one partition at a time
    task_id = config.get("task_id")  # get task_id from config
    blob_name = f"{job_id}/{task_id}.json"
    config_path = f"{STORAGE_ACCOUNT_PATH}/{CONFIG_CONTAINER}/{blob_name}"
    return dg.MaterializeResult(
        value=(job_id, config_path, config),
        metadata={
            "job_id": job_id,
            "config_path": config_path,
            "config": dg.JsonMetadataValue(config)
        }
    )


@dg.asset(
    description="The Rt pipeline",
    partitions_def=rt_partitions
)
def rt_pipeline(context: dg.AssetExecutionContext, rt_config) -> str:
    job_id, config_path, config = rt_config
    context.log.debug(f"config_path: '{config_path}'")
    context.log.debug(f"config: '{config}'")
    subprocess.run([
            "Rscript",
            "-e",
            (f"CFAEpiNow2Pipeline::orchestrate_pipeline('{config_path}', "
             f"config_container = '{CONFIG_CONTAINER}')"),
    ], check=True)
    output_path = f"{STORAGE_ACCOUNT_PATH}/{OUTPUT_CONTAINER}/{job_id}"
    return dg.MaterializeResult(
        value=output_path,
        metadata={"output_path": output_path}
    )


workdir = "/opt/dagster/code_location/cfa-epinow2-pipeline"

# configuring an executor to run workflow steps on Docker
# add this to a job or the Definitions class to use it
docker_executor_configured = docker_executor.configured(
    {
        # specify a default image
        "image": "cfa-epinow2-pipeline:dagster",
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
        "container_app_job_name": "cfa-epinow2-pipeline",
        "image": f"cfaprdbatchcr.azurecr.io/cfa-dagster:{user}",
        # "env_vars": [f"DAGSTER_USER={user}"],
    }
)

# configuring an executor to run workflow steps on Azure Batch 4CPU 16GB RAM pool
# add this to a job or the Definitions class to use it
azure_batch_executor_configured = azure_batch_executor.configured(
    {
        "image": f"cfaprdbatchcr.azurecr.io/cfa-dagster:{user}",
        # "env_vars": [f"DAGSTER_USER={user}"],
        "container_kwargs": {
            "working_dir": workdir,
        },
    }
)

# jobs are used to materialize assets with a given configuration
rt_pipeline_job = dg.define_asset_job(
    name="rt_pipeline_job",
    # specify an executor including docker, Azure Container App Job, or
    # the future Azure Batch executor
    executor_def=docker_executor_configured,
    # uncomment the below to switch to run on Azure Container App Jobs.
    # remember to rebuild and push your image if you made any workflow changes
    # executor_def=azure_caj_executor_configured,
    selection=dg.AssetSelection.assets(job_id, rt_config, rt_pipeline),
    config=dg.RunConfig({
        "ops": {
            "job_id": JobIdConfig(),
            "rt_config": RtConfig(),
        }
    }),
    # tag the run with your user to allow for easy filtering in the Dagster UI
    tags={"user": user},
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
    executor=docker_executor_configured,
    # executor=azure_caj_executor_configured,
    # executor=azure_batch_executor_configured,
)
