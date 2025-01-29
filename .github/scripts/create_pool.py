# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "azure-batch",
#     "azure-identity",
#     "azure-mgmt-batch",
#     "msrest",
# ]
# ///
import os
from azure.identity import DefaultAzureCredential
from msrest.authentication import BasicTokenAuthentication
from azure.batch import BatchServiceClient
from azure.batch.models import (
    PoolAddParameter,
    VirtualMachineConfiguration,
    ImageReference,
)

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

    # Create a pool
    batch_client.pool.add(
        PoolAddParameter(
            id="rt-epinow2-pool",
            display_name="Rt Epinow2 Pool",
            # 4 coures, 16GB RAM, 150GB disk
            vm_size="STANDARD_d4d_v5",
            virtual_machine_configuration=VirtualMachineConfiguration(
                image_reference=ImageReference(
                    publisher="microsoft-dsvm",
                    offer="ubuntu-hpc",
                    sku="2204",
                    version="latest",
                ),
                node_agent_sku_id="batch.node.ubuntu 22.04",
            ),
        )
    )


if __name__ == "__main__":
    main()
