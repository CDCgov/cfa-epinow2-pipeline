# Interval Class

Represents a generic interval. Meant to be subclassed.

## Usage

``` r
Interval(path = class_missing, blob_storage_container = class_missing)
```

## Arguments

- path:

  A string specifying the path to the generation interval CSV file.

- blob_storage_container:

  Optional. The name of the blob storage container to get it from. If
  NULL, will look locally.

## See also

Other config:
[`Config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Config.md),
[`Data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Data.md),
[`Parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Parameters.md),
[`read_json_into_config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_json_into_config.md)
