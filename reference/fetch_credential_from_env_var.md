# Fetch Azure credential from environment variable

And throw an informative error if credential is not found

## Usage

``` r
fetch_credential_from_env_var(env_var)
```

## Arguments

- env_var:

  A character, the credential to fetch

## Value

The associated value

## See also

Other azure:
[`download_file_from_container()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/download_file_from_container.md),
[`download_if_specified()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/download_if_specified.md),
[`fetch_blob_container()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fetch_blob_container.md)
