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
from pathlib import Path
import dagster as dg
from dagster_azure.blob import (
    AzureBlobStorageDefaultCredential,
    AzureBlobStorageResource,
)
from cfa_dagster import (
    ADLS2PickleIOManager,
    GraphDimension,
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
# ============================================================================
# Dagster Initialization
# ============================================================================
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

# Instead of hardcoding the repo name, this will always find the containing directory of this defs file
local_workdir = Path(__file__).parent.resolve()  # absolute path to the workdir
container_workdir = Path(
    f"/{local_workdir.name}"
)  # in the container, workdir is mounted at /


# ============================================================================
# Dagster configs - defines executors
# Executors control how steps in a job run are executed
# ============================================================================

# Most basic execution - in dev, launches and runs locally
# In prod, launches on the code location but runs in Azure Container App Jobs
# Used for lightweight assets and jobs, etc. where volume mounts are not needed
basic_execution_config = ExecutionConfig(
    executor=SelectorConfig(
        class_name=azure_container_app_job_executor.__name__
        if is_production
        else dg.multiprocess_executor.__name__
    ),
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
                    f"{__file__}:{container_workdir}/{os.path.basename(__file__)}",
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
                "working_dir": "/cfa-epinow2-pipeline",
                # mount config if your existing Batch pool already has Blob mounts
                # "volumes": [
                #     "nssp-etl:nssp-etl",
                # ]
            },
        },
    ),
)

# ============================================================================
# Assets - operations that produce tracked artifacts
# ============================================================================

class RtConfig(dg.ConfigurableResource):
    # Define a unique job identifier by combining a fixed string with the current UTC timestamp
    job_id: str = (
        "Rt-estimation-" +
        datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")  # Format: YYYYMMDD_HHMMSS
    )
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
    # disease: list[str] = list(all_diseases)
    # disease: GraphDimension[str] = GraphDimension(["COVID", "FLU", "RSV"])
    disease: GraphDimension[str] = GraphDimension(["FLU"])

    # List of states to process. The full list is commented out, currently only AZ is used for testing
    # states: list[str] = sorted(nssp_valid_states)
    # states: list[str] = ['AZ']  # Subset of states used for testing purposes
    states: GraphDimension[str] = GraphDimension(["AZ"])

@dynamic_graph_asset(
    description = "Rt pipeline config generation",
)
def cfa_config_generator(
    context: dg.OpExecutionContext,
    rt_config: RtConfig,
) -> dict:
    """
    The Rt pipeline config
    """
    context.log.debug(f"config: '{rt_config}'")
    state = rt_config.state.current_value
    context.log.info(f"Running for state: {state}")
    disease = rt_config.disease.current_value
    context.log.info(f"Running for disease: {disease}")
    report_date: date = date.fromisoformat(rt_config.report_date_str)
    production_date: date = date.fromisoformat(rt_config.production_date_str)
    now: datetime = datetime.now(timezone.utc)

    # Make sure facility_active_proportion is between 0 and 1.
    if not (0 <= config.facility_active_proportion <= 1):
        raise ValueError(
            "facility_active_proportion must be between 0 and 1, inclusive."
        )

    rt_config_dict = generate_config(
        state=state,
        disease=disease,
        report_date=report_date,
        reference_dates=[
            report_date - timedelta(days=1),
            report_date - timedelta(weeks=8),
        ],
        data_path=f"gold/{report_date.isoformat()}.parquet",
        data_container=rt_config.input_container,
        production_date=production_date,
        job_id=config.job_id,
        as_of_date=now.isoformat(),
        output_container=rt_config.output_container,
        facility_active_proportion=rt_config.facility_active_proportion,
    )[0]  # only exepecting one
    task_id = rt_config_dict["task_id"]
    yield dg.Output(
        value=rt_config_dict,
        metadata={
            "storage_account": STORAGE_ACCOUNT,
            "storage_container": CONFIG_CONTAINER,
            "job_id": rt_config.job_id,
            "blob": f"{rt_config.job_id}/{task_id}.json",
        }
    )
    return rt_config_dict


@dynamic_graph_asset(
    description = "A parallel asset that runs the Rt pipeline for different diseases and states",
)
def cfa_epinow2_pipeline(
    context: dg.OpExecutionContext,
    rt_config: RtConfig,
    cfa_config_generator: dict, #this is the output from the config asset 
) -> str:
    config_results = cfa_config_generator

    job_id = config_results["job_id"]
    task_id = config_results["task_id"]
    blob_name = f"{job_id}/{task_id}.json"
    
    # debug logs printed in 
    context.log.debug(f"job_id: '{job_id}'")
    context.log.debug(f"blob_name: '{blob_name}'")
    context.log.debug(f"config: '{rt_config}'")
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

# ============================================================================
# Jobs and Ops
# These can create images.
# ============================================================================

# These are only used in dev - they should not appear on the production webserver
if not is_production():
    # Build and Push Image ---------------------------

    @dg.op
    def build_image_op(
        context: dg.OpExecutionContext,
        should_push: bool,
        should_deploy_to_prod: bool,
        dockerfile_path: str,
        build_context: str,
        image: str,
    ):
        """
        Builds the image used by dagster. Requires that your VM be registered with an Azure managed identity.

        should_push: bool - should the image be pushed to the Container Registry?
        should_deploy_to_prod: bool - should the prod server be updated with the newest image? (usually you do not want to do this)
        dockerfile_path: str - where is the Dockerfile located locally? (has a default)
        build_context: str - where should we build from? (has a default)
        image: str - the full name (including registry and tag) of the image
        """

        build_command = [
            "docker",
            "buildx",
            "build",
            "-t",
            image,
            "-f",
            dockerfile_path,
            build_context,
        ]

        if should_push:
            subprocess.run(
                ["az", "login", "--identity"],
                check=True,
            )
            subprocess.run(["az", "acr", "login", "-n", registry], check=True)
            build_command.append("--push")
        context.log.info(f"Running {' '.join(build_command)}")
        subprocess.run(build_command, check=True)

        update_script_url = (
            # repo
            "https://raw.githubusercontent.com/CDCgov/cfa-dagster/"
            # ref
            "refs/heads/main/"
            # file
            "scripts/update_code_location.py"
        )

        if should_deploy_to_prod:
            context.log.info(f"Deploying {image} to the dagster prod server.")
            subprocess.run(
                ["uv", "run", update_script_url, "--registry_image", image], check=True
            )

    @dg.job(
        description=(
            "Build the container image used by dagster to run this project's asset pipelines."
            "Run after making any change and before running the pipelines."
        ),
        config=dg.RunConfig(
            ops={
                "build_image_op": {
                    "inputs": {
                        "should_push": True,
                        "should_deploy_to_prod": False,
                        "dockerfile_path": f"{local_workdir}/Dockerfile",
                        # the build context should be the top level of the repo
                        "build_context": str(local_workdir),
                        "image": image,
                    }
                }
            },
            # configure this job to run on your computer
            execution=basic_execution_config.to_run_config(),
        ),
        executor_def=dynamic_executor(),
    )
    def build_image():
        build_image_op()

    # Explore the image you built as it will be run with dagster ---------------------------

    @dg.op
    def explore_image_op(
        context: dg.OpExecutionContext,
    ):
        """
        Allows you to run the container you previously built and explore the filesystem that will be used by dagster.
        """
        context.log.info(
            "Check the terminal from which you ran the webserver to interact; stdout from your terminal will appear below."
        )
        explore_cmd = (
            ["docker", "run", "-it"]
            + [
                item
                for mount in blob_mounts
                for item in ("-v", local_mounting_dir + mount)
            ]
            + ["--rm", image, "bash"]
        )
        subprocess.run(explore_cmd, check=True)

    @dg.job(
        description=(
            "Interactively navigate the filesystem of your last-built container, "
            "as it would be used in Docker or Azure Batch execution."
        ),
        executor_def=dg.in_process_executor,
    )
    def explore_image():
        explore_image_op()

# ============================================================================
# Dagster Definitions object 
# ============================================================================
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
        "rt_config": RtConfig(),
    },
    executor=dynamic_executor(
        # try switching to Azure compute after pushing your image
        default_config=basic_execution_config,
        #default_config=docker_config,
        #default_config=azure_caj_config,
        # default_config=azure_batch_config,
        # alternate configs show you default values in the Launchpad on hover
        alternate_configs=[
            basic_execution_config,
            docker_config,
            azure_caj_config,
            azure_batch_config,
        ],
    ),
)