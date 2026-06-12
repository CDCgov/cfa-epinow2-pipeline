#!/usr/bin/env -S uv run --script
# PEP 723 dependency definition: https://peps.python.org/pep-0723/
# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#    "cfa-dagster[dev] @ git+https://github.com/cdcgov/cfa-dagster.git",
#    "cfa-config-generator @ git+https://github.com/cdcgov/cfa-config-generator.git"
# ]
# ///

from datetime import date, datetime, timedelta, timezone
import os
import subprocess

import dagster as dg
from dagster_azure.blob import (
    AzureBlobStorageDefaultCredential,
    AzureBlobStorageResource,
)
from cfa_dagster import (
    ADLS2PickleIOManager,
    DynamicGraphAssetExecutionContext,
    ExecutionConfig,
    SelectorConfig,
    azure_batch_executor,
    azure_container_app_job_executor,
    collect_definitions,
    docker_executor,
    dynamic_executor,
    dynamic_graph_asset,
    is_production,
    start_dev_env,
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

STORAGE_ACCOUNT = IMAGE_REGISTRY = "cfaazurebatchprd"
STORAGE_ACCOUNT_PATH = f"https://{STORAGE_ACCOUNT}.blob.core.windows.net"
CONFIG_CONTAINER = "rt-epinow2-config"
# OUTPUT_CONTAINER = "nssp-rt-v2" if is_production else "nssp-rt-testing"
OUTPUT_CONTAINER = "nssp-rt-testing"  # hard-coding test during Dagster evaluation

# get the Git branch name 
def get_git_branch() -> str:
    try:
        branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        return branch.replace("/", "-")
    except Exception:
        return "latest"

# set the current Git branch as the image tag
branch = get_git_branch()
IMAGE_REGISTRY = "cfaprdbatchcr"
image_tag = "latest" if is_production() else branch
image = f"{IMAGE_REGISTRY}.azurecr.io/cfa-epinow2-pipeline:{image_tag}"

# Setting the working directory to match the working directory in the 
# Dockerfile 
workdir = "/app"

# ----------------
# Dagster configs - defines executors
# Executors control how steps in a job run are executed
# ---------------- 

# this is the default run config that launches the job in your local shell
# and executes each step in a separate system process
default_config = ExecutionConfig(
    launcher=SelectorConfig(class_name=dg.DefaultRunLauncher.__name__),
    executor=SelectorConfig(class_name=dg.multiprocess_executor.__name__),
)

# configuring an executor to run each workflow step in a new Docker container
# add this to a job or the Definitions class to use it
docker_config = ExecutionConfig(
    executor=SelectorConfig(
        class_name=docker_executor.__name__,
        config={
            # specify a default image
            "image": image,
            # set env vars here
            # "env_vars": [f"DAGSTER_USER"],
            "container_kwargs": {
                "volumes": [
                    # bind the ~/.azure folder for optional cli login
                    f"/home/{user}/.azure:/root/.azure",
                    # bind current file so we don't have to rebuild
                    # the container image for workflow changes
                    f"{__file__}:{workdir}/{os.path.basename(__file__)}",
                ]
            },
        },
    )
)

# configuring an executor to run each workflow step in a new Docker container
# add this to a job or the Definitions class to use it
docker_config = ExecutionConfig(
    executor=SelectorConfig(
        class_name=docker_executor.__name__,
        config={
            # specify a default image
            "image": image,
            # set env vars here
            # "env_vars": [f"DAGSTER_USER"],
            "container_kwargs": {
                "volumes": [
                    # bind the ~/.azure folder for optional cli login
                    f"/home/{user}/.azure:/root/.azure",
                    # bind current file so we don't have to rebuild
                    # the container image for workflow changes
                    f"{__file__}:{workdir}/{os.path.basename(__file__)}",
                ]
            },
        },
    )
)


# configuring an executor to run each workflow step in a new Azure Container
# App Job execution
# add this to a job or the Definitions class to use it
azure_caj_config = ExecutionConfig(
    executor=SelectorConfig(
        class_name=azure_container_app_job_executor.__name__,
        config={
            "container_app_job_name": "cfa-epinow2-pipeline",
            # specify a default image
            "image": image,
            # set env vars here
            # "env_vars": [f"DAGSTER_USER"],
        },
    )
)

# configuring a run launcher to launch each run in an Azure Container App Job
# and configuring an executor to run each workflow steps in a new Azure Batch
# task for maximum scale
# add this to a job or the Definitions class to use it
azure_batch_config = ExecutionConfig(
    executor=SelectorConfig(
        class_name=azure_batch_executor.__name__,
        config={
            # change the pool_name to your existing pool name
            "pool_name": "cfa-epinow2-pipeline",
            # specify a default image
            "image": image,
            # set env vars here
            "env_vars": ["CFA_DAGSTER_LOG_LEVEL=debug"],
            "container_kwargs": {
                # set the working directory to match your Dockerfile
                # required for Azure Batch
                "working_dir": workdir,
                # mount config if your existing Batch pool already has Blob mounts
                # "volumes": [
                #     "nssp-etl:nssp-etl",
                # ]
            },
        },
    ),
)

# ----------------
# Assets - operations that produce tracked artifacts
# ----------------

class RtConfig(dg.Config):
    # Define a unique job identifier by combining a fixed string with the current UTC timestamp
    job_id: str = (
        "Rt-estimation-" +
        datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")  # Format: YYYYMMDD_HHMMSS
    )
    # Set the report date as a string in the format YYYY-MM-DD using current UTC time
    report_date_str: str = datetime.now(timezone.utc).strftime("%F")  # Equivalent to "%Y-%m-%d"
    # Name of the storage container where outputs will be saved
    output_container: str = OUTPUT_CONTAINER
    # Name of the storage container from which input data will be read
    input_container: str = "nssp-etl"
    # The production date in ISO format (YYYY-MM-DD), using local date
    production_date_str: str = date.today().isoformat()
    # The proportion of active facilities to consider in the Rt estimation
    facility_active_proportion: float = 0.94
    # List of diseases to include in the Rt estimation
    disease: list[str] = list(all_diseases)
    # List of states to process. The full list is commented out, currently only AZ is used for testing
    # states: list[str] = sorted(nssp_valid_states)
    states: list[str] = ['AZ']  # Subset of states used for testing purposes

@dynamic_graph_asset(
    graph_dimensions = ["disease", "states"],
    description = "Rt pipeline config generation",
)
def cfa_config_generator(
    context: DynamicGraphAssetExecutionContext,
    config: RtConfig,
) -> dict:
    """
    The Rt pipeline config
    """
    context.log.debug(f"config: '{config}'")
    state = context.graph_dimension["states"]
    disease = context.graph_dimension["disease"]
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
    yield dg.Output(
        value=rt_config,
        metadata={
            "storage_account": STORAGE_ACCOUNT,
            "storage_container": CONFIG_CONTAINER,
            "job_id": config.job_id,
            "blob": f"{config.job_id}/{task_id}.json",
        }
    )
    return rt_config


@dynamic_graph_asset(
    graph_dimensions = ["disease", "states"],
    description = "A parallel asset that runs the Rt pipeline for different diseases and states",
)
def cfa_epinow2_pipeline(
    context: DynamicGraphAssetExecutionContext,
    config: RtConfig,
    cfa_config_generator: dict, #this is the output from the config asset 
) -> str:
    config_results = cfa_config_generator

    job_id = config_results["job_id"]
    task_id = config_results["task_id"]
    blob_name = f"{job_id}/{task_id}.json"
    
    # debug logs printed in 
    context.log.debug(f"job_id: '{job_id}'")
    context.log.debug(f"blob_name: '{blob_name}'")
    context.log.debug(f"config: '{config}'")
    context.log.debug(f"task_id: '{task_id}'")
    subprocess.run([
            "Rscript",
            "-e",
            (f"CFAEpiNow2Pipeline::orchestrate_pipeline('{blob_name}', "
             f"config_container = '{CONFIG_CONTAINER}')"),
    ], check=True)
    output_path = f"{STORAGE_ACCOUNT_PATH}/{OUTPUT_CONTAINER}/{job_id}"
    return dg.Output(
        value=output_path,
        metadata={
            "output_path": output_path,
            "storage_account": STORAGE_ACCOUNT,
            "storage_container": OUTPUT_CONTAINER,
            "blob_path": job_id,
        }
    )

# ------------------------------------------------
# Jobs - tasks that don't produce tracked artifacts
# ------------------------------------------------
# build and push the image to azure 
@dg.op
def build_image(context: dg.OpExecutionContext, should_push: bool):
    cmd = f"docker build -t {image} ."

    if should_push:
        subprocess.run(
            f"az login --identity && az acr login -n {IMAGE_REGISTRY}",
            check=True,
            shell=True,
        )
        cmd += " --push"

    context.log.debug(f"Running {cmd}")
    subprocess.run(cmd, check=True, shell=True)

# run the build_image() code 
@dg.job(
    config=dg.RunConfig(
        ops={"build_image": {"inputs": {"should_push": False}}},
        # configure this job to run on your computer
        execution=default_config.to_run_config(),
    ),
    executor_def=dynamic_executor(),
)
def build_image_job():
    build_image()

# change storage accounts between dev and prod
storage_account = "cfadagster" if is_production() else "cfadagsterdev"

# automatically collect Dagster definitions from the current file
collected_defs = collect_definitions(globals())

# Create Dagster definitions
defs = dg.Definitions(
    **collected_defs,
    resources={
        # This IOManager lets Dagster serialize asset outputs and store them
        # in Azure to pass between assets
        "io_manager": ADLS2PickleIOManager(),
        # an example storage account
        "azure_blob_storage": AzureBlobStorageResource(
            account_url=f"{storage_account}.blob.core.windows.net",
            credential=AzureBlobStorageDefaultCredential(),
        ),
    },
    executor=dynamic_executor(
        # try switching to Azure compute after pushing your image
        # default_config=default_config,
        #default_config=docker_config,
        default_config=azure_caj_config,
        # default_config=azure_batch_config,
        # alternate configs show you default values in the Launchpad on hover
        alternate_configs=[
            default_config,
            docker_config,
            azure_caj_config,
            azure_batch_config,
        ],
    ),
)