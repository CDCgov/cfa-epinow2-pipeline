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

# info from cfa-nnh-pipelines forthcoming