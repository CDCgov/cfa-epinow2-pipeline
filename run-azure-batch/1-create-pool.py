import datetime
import os
import sys
import toml

from azure.identity import (
    ChainedTokenCredential,
    EnvironmentCredential,
    AzureCliCredential,
    ClientSecretCredential,
)
from azure.keyvault.secrets import SecretClient
from azure.storage.blob import BlobServiceClient
from azure.mgmt.batch import BatchManagementClient
from azure.core.exceptions import HttpResponseError


def create_container(blob_service_client: BlobServiceClient, container_name: str):
    container_client = blob_service_client.get_container_client(
        container=container_name
    )
    if not container_client.exists():
        container_client.create_container()
        print("Container [{}] created.".format(container_name))
    else:
        print("Container [{}] already exists.".format(container_name))


def get_autoscale_formula():
    autoscale_file = os.path.join(sys.path[0], "autoscale_formula.txt")
    with open(autoscale_file, "r") as autoscale_text:
        return autoscale_text.read()

if __name__ == "__main__":
    start_time = datetime.datetime.now()

    # Load configuration
    config = toml.load("run_azure_batch/configuration.toml")

    # Get credential
    # First use user credential to access the key vault
    credential_order = (EnvironmentCredential(), AzureCliCredential())
    user_credential = ChainedTokenCredential(*credential_order)
    secret_client = SecretClient(
        vault_url=config["Authentication"]["vault_url"],
        credential=user_credential,
    )
    sp_secret = secret_client.get_secret(
        config["Authentication"]["vault_sp_secret_id"]
    ).value
    
    # Get Service Principal credential from key vault
    sp_credential = ClientSecretCredential(
        tenant_id=config["Authentication"]["tenant_id"],
        client_id=config["Authentication"]["application_id"],
        client_secret=sp_secret,
    )

    # Create the Azure Storage Blob Service Client
    blob_service_client = BlobServiceClient(
        account_url=config["Storage"]["storage_account_url"],
        credential=sp_credential,
    )

    # Create the blob storage container for this batch job
    input_container_name = "nnh-rt-input"
    create_container(blob_service_client, input_container_name)
    output_container_name = "nnh-rt-output"
    create_container(blob_service_client, output_container_name)

    # Create the Azure Batch Management client
    batch_mgmt_client = BatchManagementClient(
        credential=sp_credential,
        subscription_id=config["Authentication"]["subscription_id"],
    )

    # Define the JSON for the batch pool creation request

    # User-assigned identity for the pool
    user_identity = {
        "type": "UserAssigned",
        "userAssignedIdentities": {
            config["Authentication"]["user_assigned_identity"]: {
                "clientId": config["Authentication"]["client_id"],
                "principalId": config["Authentication"]["principal_id"],
            }
        },
    }

    # Network configuration with no public IP and virtual network
    network_config = {
        "subnetId": config["Authentication"]["subnet_id"],
        "publicIPAddressConfiguration": {"provision": "NoPublicIPAddresses"},
        "dynamicVnetAssignmentScope": "None",
    }

    # Virtual machine configuration
    deployment_config = {
        "virtualMachineConfiguration": {
            "imageReference": {
                "publisher": "microsoft-azure-batch",
                "offer": "ubuntu-server-container",
                "sku": "20-04-lts",
                "version": "latest",
            },
            "nodeAgentSkuId": "batch.node.ubuntu 20.04",
            "containerConfiguration": {
                "type": "dockercompatible",
                "containerImageNames": [config["Container"]["container_image_name"]],
                "containerRegistries": [
                    {
                        "registryServer": config["Container"]["container_registry_url"],
                        "userName": config["Container"]["container_registry_username"],
                        "password": config["Container"]["container_registry_password"],
                        "registryServer": config["Container"][
                            "container_registry_server"
                        ],
                        # "registryServer": config["Container"]["container_registry_url"],
                        # "identityReference": {
                        #     "resourceId": config["Authentication"][
                        #         "user_assigned_identity"
                        #     ]
                        # },
                    }
                ],
            },
        }
    }

    # Mount configuration
    mount_config = [
        {
            "azureBlobFileSystemConfiguration": {
                "accountName": config["Storage"]["storage_account_name"],
                "identityReference": {
                    "resourceId": config["Authentication"]["user_assigned_identity"]
                },
                "containerName": "nnh-rt-input",
                "blobfuseOptions": "-o direct_io",
                "relativeMountPath": "input",
            }
        },
        {
            "azureBlobFileSystemConfiguration": {
                "accountName": config["Storage"]["storage_account_name"],
                "identityReference": {
                    "resourceId": config["Authentication"]["user_assigned_identity"]
                },
                "containerName": "nnh-rt-output",
                "blobfuseOptions": "-o direct_io",
                "relativeMountPath": "output",
            }
        },
    ]

    # Assemble the pool parameters JSON
    pool_parameters = {
        "identity": user_identity,
        "properties": {
            "vmSize": config["Batch"]["pool_vm_size"],
            "interNodeCommunication": "Disabled",
            "taskSlotsPerNode": 1,
            "taskSchedulingPolicy": {"nodeFillType": "Spread"},
            "deploymentConfiguration": deployment_config,
            "networkConfiguration": network_config,
            "scaleSettings": {
                # "fixedScale": {
                #     "targetDedicatedNodes": 1,
                #     "targetLowPriorityNodes": 0,
                #     "resizeTimeout": "PT15M"
                # }
                "autoScale": {
                    "evaluationInterval": "PT5M",
                    "formula": get_autoscale_formula(),
                }
            },
            "resizeOperationStatus": {
                "targetDedicatedNodes": 1,
                "nodeDeallocationOption": "Requeue",
                "resizeTimeout": "PT15M",
                "startTime": "2023-07-05T13:18:25.7572321Z",
            },
            "currentDedicatedNodes": 1,
            "currentLowPriorityNodes": 0,
            "targetNodeCommunicationMode": "Simplified",
            "currentNodeCommunicationMode": "Simplified",
            "mountConfiguration": mount_config,
        },
    }

    pool_id = config["Batch"]["pool_id"]
    account_name = config["Batch"]["batch_account_name"]
    resource_group_name = config["Authentication"]["resource_group"]

    try:
        batch_mgmt_client.pool.create(
            resource_group_name=resource_group_name,
            account_name=account_name,
            pool_name=pool_id,
            parameters=pool_parameters,
        )
        print(f"Pool {pool_id!r} created")
    except HttpResponseError as error:
        if "PropertyCannotBeUpdated" in error.message:
            print(f"Pool {pool_id!r} already exists")
        else:
            raise error
