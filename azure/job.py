# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "azure-batch==14.2.0",
#     "azure-identity==1.21.0",
#     "azure-storage-blob==12.25.1",
#     "msrest==0.7.1",
# ]
# ///
import datetime
import os
import time
import uuid

from msrest.authentication import BasicTokenAuthentication

import azure.batch.models as batchmodels
from azure.batch import BatchServiceClient
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


def main(image_name: str, config_container: str, pool_id: str, job_id: str):
    """
    Submit a job

    Arguments
    ----------
    image_name: str
        The name of the container image (and tag) to use for the job
    config_container: str
        The name of the storage container for the job to output to
    pool_id: str
        The name of the pool to use for the job
    job_id: str
        The name of the job to use for the job.
    """
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
        b.name for b in container_client.list_blobs() if job_id in b.name
    ]
    if len(task_configs) > 0:
        print(f"Creating {len(task_configs)} tasks in job {job_id} on pool {pool_id}")
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
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="Submit a job to Azure Batch with the specified image and config container"
    )
    parser.add_argument(
        "--image_name",
        type=str,
        help="The name of the container image (and tag) to use for the job",
        required=True,
    )
    parser.add_argument(
        "--config_container",
        type=str,
        help="The name of the storage container for the job to output to",
        required=True,
    )
    parser.add_argument(
        "--pool_id",
        type=str,
        help="The name of the pool to use for the job",
        required=True,
    )
    parser.add_argument(
        "--job_id",
        type=str,
        help="The name of the job to use for the job. Defaults to pool_id",
        default=None,
    )

    # Parse the args
    args = parser.parse_args()
    image_name: str = args.image_name
    config_container: str = args.config_container
    pool_id: str = args.pool_id
    # Use pool_id as job_id if not specified
    job_id: str = args.job_id or pool_id

    main(
        image_name=image_name,
        config_container=config_container,
        pool_id=pool_id,
        job_id=job_id,
    )
