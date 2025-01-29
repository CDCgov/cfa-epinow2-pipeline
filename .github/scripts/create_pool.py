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
CONTAINER_REGISTRY_SERVER="<container registry server>"
CONTAINER_REGISTRY_USERNAME="<container registry username>"
CONTAINER_REGISTRY_PASSWORD="<container registry password>"
CONTAINER_IMAGE_NAME="<container image name>"

If running in CI, all of the above environment variables should be set in the repo
secrets.
"""

import os
from azure.identity import DefaultAzureCredential
from msrest.authentication import BasicTokenAuthentication
from azure.batch import BatchServiceClient
from azure.batch.models import (
    PoolAddParameter,
    VirtualMachineConfiguration,
    ImageReference,
    ContainerConfiguration,
    ContainerRegistry,
)
from azuretools.autoscale import remaining_task_autoscale_formula

batch_account = os.environ["BATCH_ACCOUNT"]
batch_url = f"https://{batch_account}.eastus.batch.azure.com"


def main() -> None:
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

    # Create the BatchServiceClient
    batch_client = BatchServiceClient(credentials=credential_v1, batch_url=batch_url)

    # Create the pool using direct Class construction as much as possible for IDE
    # assissitance
    batch_client.pool.add(
        PoolAddParameter(
            id=os.environ["POOL_ID"],
            display_name="Rt Epinow2 Pool",
            # 4 cores, 16GB RAM, 150GB disk
            vm_size="STANDARD_d4d_v5",
            virtual_machine_configuration=VirtualMachineConfiguration(
                image_reference=ImageReference(
                    publisher="microsoft-dsvm",
                    offer="ubuntu-hpc",
                    sku="2204",
                    version="latest",
                ),
                node_agent_sku_id="batch.node.ubuntu 22.04",
                container_configuration=ContainerConfiguration(
                    type="dockercompatible",
                    container_registries=[
                        ContainerRegistry(
                            registry_server=os.environ["CONTAINER_REGISTRY_SERVER"],
                            user_name=os.environ["CONTAINER_REGISTRY_USERNAME"],
                            password=os.environ["CONTAINER_REGISTRY_PASSWORD"],
                        )
                    ],
                    container_image_names=[os.environ["CONTAINER_IMAGE_NAME"]],
                ),
            ),
            enable_auto_scale=True,
            # Use STF's autoscale formula function
            auto_scale_formula=remaining_task_autoscale_formula(
                # Evaluate every 5 minutes
                evaluation_interval="PT5M",
                task_sample_interval_minutes=5,
                max_number_vms=100,
            ),
        )
    )


if __name__ == "__main__":
    main()
