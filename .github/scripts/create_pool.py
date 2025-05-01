# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "azure-batch",
#     "azure-identity",
#     "azure-mgmt-batch",
#     "msrest",
# ]
# ///
"""
If running locally, use:
uv run --env-file .env .github/scripts/create_pool.py
Requires a `.env` file with at least the following:
BATCH_ACCOUNT="<batch account name>"
SUBSCRIPTION_ID="<azure subscription id>"
BATCH_USER_ASSIGNED_IDENTITY="<user assigned identity>"
AZURE_BATCH_ACCOUNT_CLIENT_ID="<azure client id>"
PRINCIPAL_ID="<principal id>"
CONTAINER_REGISTRY_SERVER="<container registry server>"
CONTAINER_IMAGE_NAME="https://full-cr-server/<container image name>:tag"
POOL_ID="<pool id>"
SUBNET_ID="<subnet id>"
RESOURCE_GROUP="<resource group name>"

If running in CI, all of the above environment variables should be set in the repo
secrets.
"""

import os

from azure.identity import DefaultAzureCredential
from azure.mgmt.batch import BatchManagementClient

AUTO_SCALE_FORMULA = """
// In this example, the pool size
// is adjusted based on the number of tasks in the queue.
// Note that both comments and line breaks are acceptable in formula strings.

// Get pending tasks for the past 5 minutes.
$samples = $ActiveTasks.GetSamplePercent(TimeInterval_Minute * 5);
// If we have fewer than 70 percent data points, we use the last sample point, otherwise we use the maximum of last sample point and the history average.
$tasks = $samples < 70 ? max(0, $ActiveTasks.GetSample(1)) :
max( $ActiveTasks.GetSample(1), avg($ActiveTasks.GetSample(TimeInterval_Minute * 5)));
// If number of pending tasks is not 0, set targetVM to pending tasks, otherwise half of current dedicated.
$targetVMs = $tasks > 0 ? $tasks : max(0, $TargetDedicatedNodes / 2);
// The pool size is capped at 100, if target VM value is more than that, set it to 100.
cappedPoolSize = 100;
$TargetDedicatedNodes = max(0, min($targetVMs, cappedPoolSize));
// Set node deallocation mode - keep nodes active only until tasks finish
$NodeDeallocationOption = taskcompletion;
"""


def main() -> None:
    # Create the BatchManagementClient
    batch_mgmt_client = BatchManagementClient(
        credential=DefaultAzureCredential(),
        subscription_id=os.environ["SUBSCRIPTION_ID"],
    )

    # Assemble the pool parameters
    pool_parameters = {
        "identity": {
            "type": "UserAssigned",
            "userAssignedIdentities": {
                os.environ["BATCH_USER_ASSIGNED_IDENTITY"]: {
                    "clientId": os.environ["AZURE_BATCH_ACCOUNT_CLIENT_ID"],
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
                                "identityReference": {
                                    "resourceId": os.environ[
                                        "BATCH_USER_ASSIGNED_IDENTITY"
                                    ]
                                },
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
                    "formula": AUTO_SCALE_FORMULA,
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
        resource_group_name=os.environ["RESOURCE_GROUP"],
        account_name=os.environ["BATCH_ACCOUNT"],
        pool_name=os.environ["POOL_ID"],
        parameters=pool_parameters,
    )


if __name__ == "__main__":
    main()
