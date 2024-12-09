import sys
import os

from azure.identity import DefaultAzureCredential
from msrest.authentication import BasicTokenAuthentication
from azure.batch import BatchServiceClient
import azure.batch.models as batchmodels

if __name__ == "__main__":
    # Authenticate with workaround because Batch is the one remaining
    # service that doesn't yet support Azure auth flow v2 :) :)
    # https://github.com/Azure/azure-sdk-for-python/issues/30468
    credential_v2 = DefaultAzureCredential()
    token = {"access_token": credential_v2.get_token("https://batch.core.windows.net/.default").token}
    credential_v1 = BasicTokenAuthentication(token)

    batch_client = BatchServiceClient(
        credentials=credential_v1,
        batch_url=os.environ["az_batch_url"]
     )

    # Add job to pool
    pool_id = sys.argv[1]
    job_id = sys.argv[2]

    #############
    # Set up job
    job = batchmodels.JobAddParameter(
        id=job_id,
        pool_info=batchmodels.PoolInformation(pool_id=pool_id)
    )

    try:
        batch_client.job.add(job)
    except batchmodels.BatchErrorException as err:
        if err.error.code != "JobExists":
            raise
        else:
            print("Job already exists. Using job object")

   ###########
    # Set up task on job
    task_id = 'sampletask'
    registry = os.environ["AZURE_CONTAINER_REGISTRY"]
    task_container_settings = batchmodels.TaskContainerSettings(
        image_name=registry + '/cfa-epinow2-pipeline:test-edit-azure-flow',
        container_run_options='--rm --workdir /'
    )
    task_env_settings = [
        batchmodels.EnvironmentSetting(name="az_tenant_id", value=os.environ["AZURE_TENANT_ID"]),
        batchmodels.EnvironmentSetting(name="az_client_id", value=os.environ["AZURE_CLIENT_ID"]),
        batchmodels.EnvironmentSetting(name="az_service_principal", value=os.environ["AZURE_CLIENT_SECRET"])
    ]
    command = "Rscript -e \"CFAEpiNow2Pipeline::orchestrate_pipeline('test-batch.json', config_container = 'zs-test-pipeline-update', input_dir = '/cfa-epinow2-pipeline/input', output_dir = '/cfa-epinow2-pipeline', output_container = 'zs-test-pipeline-update')\""

    # Run task at the admin level to be able to read/write to mounted drives
    user_identity=batchmodels.UserIdentity(
        auto_user=batchmodels.AutoUserSpecification(
           scope=batchmodels.AutoUserScope.pool,
           elevation_level=batchmodels.ElevationLevel.admin,
        )
    )

    task = batchmodels.TaskAddParameter(
        id=task_id,
        command_line=command,
        container_settings=task_container_settings,
        environment_settings=task_env_settings,
        user_identity=user_identity
    )

    batch_client.task.add(job_id, task)
