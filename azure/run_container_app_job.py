# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "azure-identity==1.21.0",
#     "azure-storage-blob==12.25.1",
#     "azure-mgmt-appcontainers==3.2.0",
#     "azure-mgmt-resource==23.4.0",
# ]
# ///

"""
There is an Azure Container App Job (CAJ) named cfa-epinow2-pipeline that can be used to execute jobs. The CAJ has been preconfigured with the necessary service principal environment variables to simplify execution.
This script is intended to be a drop-in replacement for the existing azure/job.py script, but using CAJ for compute instead of Azure Batch and not requiring a pool_id.

View logs and metrics here: https://portal.azure.com/#@ext.cdc.gov/resource/subscriptions/ef340bd6-2809-4635-b18b-7e6583a8803b/resourceGroups/EXT-EDAV-CFA-PRD/providers/Microsoft.App/jobs/cfa-epinow2-pipeline/containers

Here is a KQL query for monitoring invocations for a job by replacing 'Rt-estimation-2025-04-29T19-07-39.001200+00-00' with your job_id:
ContainerAppSystemLogs_CL
| where JobName_s == 'cfa-epinow2-pipeline' and EnvironmentName_s == 'thankfuldune-b4ce103c'
| sort by TimeGenerated desc
| summarize arg_max(TimeGenerated, *) by ExecutionName_s
| join kind=inner (
    ContainerAppConsoleLogs_CL
    | where ContainerJobName_s == 'cfa-epinow2-pipeline' and Log_s startswith "✔ Blob 'Rt-estimation-2025-04-29T19-07-39.001200+00-00" and TimeGenerated >= datetime(2025-05-23T15:20:00)
) on $left.ReplicaName_s == $right.ContainerGroupName_s
| project TimeGenerated, Sys_Logs = Log_s, ExecutionName_s, Type_s, Console_Logs = Log_s1, Duration = TimeGenerated - TimeGenerated1
"""

from azure.identity import DefaultAzureCredential
from azure.mgmt.appcontainers import ContainerAppsAPIClient
from azure.mgmt.resource.subscriptions import SubscriptionClient
from azure.storage.blob import BlobServiceClient


def main(image_name: str, config_container: str, job_id: str):
    """
    Submit a job

    Arguments
    ----------
    image_name: str
        The name of the container image (and tag) to use for the Rt pipeline run
    config_container: str
        The name of the storage container where config files are located
    job_id: str
        The name of the job to use for the Rt pipeline run.
    """

    job_name = "cfa-epinow2-pipeline"
    resource_group = "ext-edav-cfa-prd"
    blob_account = "cfaazurebatchprd"
    blob_url = f"https://{blob_account}.blob.core.windows.net"
    credential_v2 = DefaultAzureCredential()

    blob_service_client = BlobServiceClient(blob_url, credential_v2)
    container_client = blob_service_client.get_container_client(
        container=config_container
    )

    task_configs: list[str] = [
        b.name for b in container_client.list_blobs() if job_id in b.name
    ]
    if len(task_configs) > 0:
        print(f"Creating {len(task_configs)} tasks in job {job_id}")
    elif len(task_configs) == 0:
        raise ValueError("No tasks found")

    # Get first subscription for logged-in credential
    first_subscription_id = (
        SubscriptionClient(credential_v2).subscriptions.list().next().subscription_id
    )

    client = ContainerAppsAPIClient(
        credential=credential_v2, subscription_id=first_subscription_id
    )

    # Download existing job template
    job_template = client.jobs.get(
        resource_group_name=resource_group, job_name=job_name
    ).template
    container = job_template.containers[0]

    container.image = image_name

    for i, config_path in enumerate(task_configs):
        # Update the command for this config
        container.command = [
            "Rscript",
            "-e",
            f"CFAEpiNow2Pipeline::orchestrate_pipeline('{config_path}', config_container = '{config_container}')",
        ]

        # Start job
        job_execution = client.jobs.begin_start(
            resource_group_name=resource_group, job_name=job_name, template=job_template
        ).result()

        state_config = config_path.split("/").pop()
        job_execution_id = job_execution.id.split("/").pop()
        print(
            f"Started Container App Job #{i + 1}/{len(task_configs)} for {state_config} with execution ID: {job_execution_id}"
        )


if __name__ == "__main__":
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="Run a job on Azure Container Apps Jobs with the specified image and config container"
    )
    parser.add_argument(
        "--image_name",
        type=str,
        help="The name of the container image (and tag) to use for the Rt pipeline run",
        required=True,
    )
    parser.add_argument(
        "--config_container",
        type=str,
        help="The name of the storage container where config files are located",
        default="rt-epinow2-config",
    )
    parser.add_argument(
        "--job_id",
        type=str,
        help="The name of the job to use for the Rt pipeline run",
        default=None,
    )

    # Parse the args
    args = parser.parse_args()
    image_name: str = args.image_name
    config_container: str = args.config_container
    job_id: str = args.job_id

    main(
        image_name=image_name,
        config_container=config_container,
        job_id=job_id,
    )
