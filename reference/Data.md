# Data Class

Represents the data-related configurations.

## Usage

``` r
Data(
  path = class_missing,
  blob_storage_container = class_missing,
  report_date = class_missing,
  reference_date = class_missing
)
```

## Arguments

- path:

  A string specifying the path to the data Parquet file.

- blob_storage_container:

  Optional. The name of the blob storage container to which the data
  file will be uploaded. If NULL, no upload will occur.

- report_date:

  A list of strings representing report dates.

- reference_date:

  A list of strings representing reference dates.

## See also

Other config:
[`Config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Config.md),
[`Interval`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Interval.md),
[`Parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Parameters.md),
[`read_json_into_config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_json_into_config.md)
