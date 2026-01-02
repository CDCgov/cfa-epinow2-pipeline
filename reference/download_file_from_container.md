# Download specified blobs from Blob Storage and save them in a local dir

Download specified blobs from Blob Storage and save them in a local dir

## Usage

``` r
download_file_from_container(
  blob_storage_path,
  local_file_path,
  storage_container
)
```

## Arguments

- blob_storage_path:

  A character of a blob in `storage_container`

- local_file_path:

  The local path to save the blob

- storage_container:

  The blob storage container with `blob_storage_path`

## Value

Invisibly, `local_file_path`

## See also

Other azure:
[`download_if_specified()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/download_if_specified.md),
[`fetch_blob_container()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fetch_blob_container.md),
[`fetch_credential_from_env_var()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fetch_credential_from_env_var.md)
