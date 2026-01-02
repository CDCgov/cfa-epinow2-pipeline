# Load Azure Blob container using credentials in environment variables

This function depends on the following Azure credentials stored in
environment variables:

## Usage

``` r
fetch_blob_container(container_name)
```

## Arguments

- container_name:

  The Azure Blob Storage container associated with the credentials

## Value

A Blob endpoint

## Details

- `az_tenant_id`: an Azure Active Directory (AAD) tenant ID

- `az_subscription_id`: an Azure subscription ID

- `az_resource_group`: The name of the Azure resource group

- `az_storage_account`: The name of the Azure storage account

As a result it is an impure function, and should be used bearing that
warning in mind. Each variable is obtained using
[`fetch_credential_from_env_var()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fetch_credential_from_env_var.md)
(which will return an error if the credential is not specified or
empty).

## See also

Other azure:
[`download_file_from_container()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/download_file_from_container.md),
[`download_if_specified()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/download_if_specified.md),
[`fetch_credential_from_env_var()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fetch_credential_from_env_var.md)
