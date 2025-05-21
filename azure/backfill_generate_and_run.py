# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "azure-batch==14.2.0",
#     "azure-identity==1.21.0",
#     "azure-storage-blob==12.25.1",
#     "cfa-config-generator",
#     "msrest==0.7.1",
#     "typer",
# ]
#
# [tool.uv.sources]
# cfa-config-generator = { git = "https://github.com/cdcgov/cfa-config-generator" }
# ///

import os
import uuid
from datetime import date
from typing import Annotated

import typer
from cfa_config_generator.utils.epinow2.driver_functions import generate_backfill_config
from msrest.authentication import BasicTokenAuthentication

import azure.batch.models as batchmodels
from azure.batch import BatchServiceClient
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


def main(
    state: Annotated[
        str,
        typer.Option(
            help=(
                "State(s). Can be '*', 'all', a single state, or"
                " multiple states, separated by commas."
            ),
            show_default=False,
        ),
    ],
    disease: Annotated[
        str,
        typer.Option(
            help=(
                "Disease(s). Can be '*', 'all', a single disease, or"
                " multiple diseases, separated by commas."
            ),
            show_default=False,
        ),
    ],
    str_report_dates: Annotated[
        str,
        typer.Option(
            help="List of comma separated ISO format report dates",
            show_default=False,
        ),
    ],
    reference_date_time_span: Annotated[
        str,
        typer.Option(
            help=(
                "A string representing the time span for the earliest reference date relative to"
                " the report date. This should be formatted following the conventions of polars"
                " `.dt.offset_by()`. Usually, this will be a string like '8w' or '1d' (for 8 weeks"
                " or 1 day)."
            ),
            show_default=False,
        ),
    ],
    data_container: Annotated[
        str,
        typer.Option(
            help=(
                "The name of the blob storage container for input data. "
                "Usually 'nssp-etl'"
            ),
            show_default=False,
        ),
    ],
    backfill_name: Annotated[
        str,
        typer.Option(
            help=(
                "Name of the backfill run. This will be used to generate the job IDs for each"
                "report date in the format `<backfill_name>_<report_date>`."
            ),
            show_default=False,
        ),
    ],
    output_container: Annotated[
        str,
        typer.Option(
            help=("Blob storage container to store model output."),
            show_default=False,
        ),
    ],
    str_as_of_dates: Annotated[
        str,
        typer.Option(
            help=(
                "The parameter as-of dates. Default is to match the report dates. "
                "Otherwise, a comma separated list of dates in ISO format. "
            )
        ),
    ] = "match_report_dates",
    data_paths_template: Annotated[
        str | None,
        typer.Option(
            help=(
                "Use this option over --str-data-paths most of the time. "
                "A string representing the f-string template for data paths. "
                "The '{}' section will be replaced with the report date "
                "for each report date. This is most useful when pulling from the NSSP gold "
                "data. For example, 'gold/{}.parquet' would become 'gold/2025-01-01.parquet' "
                "for the report date 2025-01-01. "
                "Cannot be used in conjunction with the --data-paths option."
            ),
        ),
    ] = None,
    str_data_paths: Annotated[
        str | None,
        typer.Option(
            help=(
                "Comma separated paths to the data. One path for each report date. "
                "If the data is in blob, these should be the names of the blobs. "
                "Cannot be used in conjunction with the --report-date-fstring option."
            ),
        ),
    ] = None,
    task_exclusions: Annotated[
        str | None,
        typer.Option(
            help=(
                "Comma separated state:disease pairs."
                " Will be applied to all report dates."
            )
        ),
    ] = None,
    config_only: Annotated[
        bool, typer.Option(help="Only generate config files.")
    ] = False,
    image_name: Annotated[
        str | None,
        typer.Option(
            help=(
                "The name of the container image (and tag) to use for the job. "
                "This should be in the format 'registry/image:tag'."
            ),
            show_default=False,
        ),
    ] = None,
    pool_id: Annotated[
        str | None,
        typer.Option(
            help="The name of the pool to use for the job.",
            show_default=False,
        ),
    ] = None,
    config_container: Annotated[
        str,
        typer.Option(help="The name of the config file storage container"),
    ] = "rt-epinow2-config",
) -> None:
    """
    Generate and upload config files for the EpiNow2 pipeline. Then, if asked for, kick
    off those tasks in Azure Batch.
    """
    # Split on commas and spaces, and remove empty strings
    # This will handle cases like "2025-01-01, 2025-01-02 2025-01-03,2025-01-04".
    # Then parse each date string into a date object.
    report_dates: list[date] = [
        date.fromisoformat(s.strip()) for s in str_report_dates.split(",")
    ]

    # Check if both data_paths and data_paths_template are provided, and error out if so
    if str_data_paths and data_paths_template:
        raise ValueError(
            "Cannot use both --data-paths and --report-date-fstring options at the same time."
        )
    # Check that at least one of data_paths or data_paths_template is provided
    if (not str_data_paths) and (not data_paths_template):
        raise ValueError(
            "Must provide either --data-paths or --report-date-fstring option."
        )

    # Make sure the image and pool id are provided if config_only is False
    if (config_only is False) and ((image_name is None) or (pool_id is None)):
        raise ValueError(
            "Must provide --image-name and --data-container options if not config_only."
        )

    # If data_paths is provided, split on commas and remove empty strings
    data_paths: list[str] = (
        [s.strip() for s in str_data_paths.split(",")]
        if str_data_paths and (not data_paths_template)
        else [
            data_paths_template.format(report_date.isoformat())  # type: ignore
            for report_date in report_dates
        ]
    )

    as_of_dates: list[date] = (
        [date.fromisoformat(s.strip()) for s in str_as_of_dates.split(",")]
        if str_as_of_dates != "match_report_dates"
        else report_dates
    )

    job_ids: list[str] = generate_backfill_config(
        state=state,
        disease=disease,
        report_dates=report_dates,
        reference_date_time_span=reference_date_time_span,
        data_paths=data_paths,
        data_container=data_container,
        backfill_name=backfill_name,
        as_of_dates=as_of_dates,
        output_container=output_container,
        task_exclusions=task_exclusions,
    )

    if config_only:
        print("Config files generated. Exiting.")
        return

    # Explicitly case pool_id and image_name to str to make the type checker happy
    pool_id = str(pool_id)
    image_name = str(image_name)

    # Kick off the tasks in Azure Batch
    blob_account = os.environ["BLOB_ACCOUNT"]
    blob_url = f"https://{blob_account}.blob.core.windows.net"
    batch_account = os.environ["BATCH_ACCOUNT"]
    batch_url = f"https://{batch_account}.eastus.batch.azure.com"

    # Authenticate with workaround because Batch is the one remaining
    # service that doesn't yet support Azure auth flow v2 :) :)
    # https://github.com/Azure/azure-sdk-for-python/issues/30468
    credential_v2 = DefaultAzureCredential()
    token = {
        "access_token": credential_v2.get_token(
            "https://batch.core.windows.net/.default"
        ).token
    }
    credential_v1 = BasicTokenAuthentication(token)

    batch_client = BatchServiceClient(credentials=credential_v1, batch_url=batch_url)

    #############
    # Set up job
    batch_job_id = pool_id
    job = batchmodels.JobAddParameter(
        id=batch_job_id, pool_info=batchmodels.PoolInformation(pool_id=pool_id)
    )

    try:
        batch_client.job.add(job)
    except batchmodels.BatchErrorException as err:
        if err.error.code != "JobExists":
            raise
        else:
            print("Job already exists. Using job object")

    ##########
    # Get tasks
    blob_service_client = BlobServiceClient(blob_url, credential_v2)
    container_client = blob_service_client.get_container_client(
        container=config_container
    )

    task_configs: list[str] = [
        b
        # We can pre-filter on the backfill name, as it makes up the first part of the
        # job id.
        for b in container_client.list_blob_names(name_starts_with=backfill_name)
        if any(job_id in b for job_id in job_ids)
    ]
    if len(task_configs) > 0:
        print(
            f"Creating {len(task_configs)} tasks in backfill job {backfill_name} on pool {pool_id}"
        )
    elif len(task_configs) == 0:
        raise ValueError("No tasks found")

    ###########
    # Set up tasks on job
    task_container_settings = batchmodels.TaskContainerSettings(
        image_name=image_name, container_run_options="--rm --workdir /"
    )
    task_env_settings = [
        batchmodels.EnvironmentSetting(
            name="az_tenant_id", value=os.environ["AZURE_TENANT_ID"]
        ),
        batchmodels.EnvironmentSetting(
            name="az_client_id", value=os.environ["AZURE_CLIENT_ID"]
        ),
        batchmodels.EnvironmentSetting(
            name="az_service_principal", value=os.environ["AZURE_CLIENT_SECRET"]
        ),
    ]

    # Run task at the admin level to be able to read/write to mounted drives
    user_identity = batchmodels.UserIdentity(
        auto_user=batchmodels.AutoUserSpecification(
            scope=batchmodels.AutoUserScope.pool,
            elevation_level=batchmodels.ElevationLevel.admin,
        )
    )

    for config_path in task_configs:
        command = f"Rscript -e \"CFAEpiNow2Pipeline::orchestrate_pipeline('{config_path}', config_container = '{config_container}', input_dir = '/mnt/input', output_dir = '/mnt/output')\""
        task = batchmodels.TaskAddParameter(
            id=str(uuid.uuid4()),
            command_line=command,
            container_settings=task_container_settings,
            environment_settings=task_env_settings,
            user_identity=user_identity,
        )

        batch_client.task.add(batch_job_id, task)


if __name__ == "__main__":
    typer.run(main)
