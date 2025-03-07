# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "azure-batch",
#     "azure-identity",
#     "azure-mgmt-batch",
#     "azuretools",
#     "msrest",
# ]
#
# [tool.uv.sources]
# azuretools = { git = "https://github.com/cdcgov/cfa-azuretools" }
# ///
"""
If running locally, use:
uv run --env-file .env .github/scripts/create_pool.py
Requires a `.env` file with at least the following:
BATCH_ACCOUNT="<batch account name>"
AZURE_SUBSCRIPTION_ID="<azure subscription id>"
USER_ASSIGNED_IDENTITY="<user assigned identity>"
AZURE_CLIENT_ID="<azure client id>"
PRINCIPAL_ID="<principal id>"
CONTAINER_REGISTRY_SERVER="<container registry server>"
CONTAINER_REGISTRY_USERNAME="<container registry username>"
CONTAINER_REGISTRY_PASSWORD="<container registry password>"
CONTAINER_REGISTRY_URL="<container registry url>"
CONTAINER_IMAGE_NAME="https://full-cr-server/<container image name>:tag"
POOL_ID="<pool id>"
SUBNET_ID="<subnet id>"
AZURE_RESOURCE_GROUP_NAME="<resource group name>"

If running in CI, all of the above environment variables should be set in the repo
secrets.
"""

import os
from azure.identity import DefaultAzureCredential
from azure.mgmt.batch import BatchManagementClient

from azuretools.autoscale import remaining_task_autoscale_formula


def main() -> None:
    # Create the BatchManagementClient
    batch_mgmt_client = BatchManagementClient(
        credential=DefaultAzureCredential(),
        subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"],
    )

    # Assemble the pool parameters
    pool_parameters = {
        "identity": {
            "type": "UserAssigned",
            "userAssignedIdentities": {
                os.environ["USER_ASSIGNED_IDENTITY"]: {
                    "clientId": os.environ["AZURE_CLIENT_ID"],
                    "principalId": os.environ["PRINCIPAL_ID"],
                }
            },
        },
        "properties": {
            "vmSize": "STANDARD_d4d_v5",
            "interNodeCommunication": "Disabled",
            "taskSlotsPerNode": 1,
            "taskSchedulingPolicy": {"nodeFillType": "Spread"},
            "deploymentConfiguration": {
                "virtualMachineConfiguration": {
                    "imageReference": {
                        "publisher": "microsoft-dsvm",
                        "offer": "ubuntu-hpc",
                        "sku": "2204",
                        "version": "latest",
                    },
                    "nodeAgentSkuId": "batch.node.ubuntu 22.04",
                    "containerConfiguration": {
                        "type": "dockercompatible",
                        "containerImageNames": [os.environ["CONTAINER_IMAGE_NAME"]],
                        "containerRegistries": [
                            {
                                "registryServer": os.environ["CONTAINER_REGISTRY_URL"],
                                "userName": os.environ["CONTAINER_REGISTRY_USERNAME"],
                                "password": os.environ["CONTAINER_REGISTRY_PASSWORD"],
                                "registryServer": os.environ[
                                    "CONTAINER_REGISTRY_SERVER"
                                ],
                            }
                        ],
                    },
                }
            },
            "networkConfiguration": {
                "subnetId": os.environ["SUBNET_ID"],
                "publicIPAddressConfiguration": {"provision": "NoPublicIPAddresses"},
                "dynamicVnetAssignmentScope": "None",
            },
            "scaleSettings": {
                "autoScale": {
                    "evaluationInterval": "PT5M",
                    "formula": remaining_task_autoscale_formula(
                        # Evaluate every 5 minutes
                        evaluation_interval="PT5M",
                        task_sample_interval_minutes=5,
                        max_number_vms=100,
                    ),
                }
            },
            "resizeOperationStatus": {
                "targetDedicatedNodes": 1,
                "nodeDeallocationOption": "Requeue",
                "resizeTimeout": "PT15M",
                "startTime": "2023-07-05T13:18:25.7572321Z",
            },
            "currentDedicatedNodes": 0,
            "currentLowPriorityNodes": 0,
            "targetNodeCommunicationMode": "Simplified",
            "currentNodeCommunicationMode": "Simplified",
        },
    }

    batch_mgmt_client.pool.create(
        resource_group_name=os.environ["AZURE_RESOURCE_GROUP_NAME"],
        account_name=os.environ["BATCH_ACCOUNT"],
        pool_name=os.environ["POOL_ID"],
        parameters=pool_parameters,
    )


if __name__ == "__main__":
    main()
