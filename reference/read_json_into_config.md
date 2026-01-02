# Read JSON Configuration into Config Object

Reads a JSON file from the specified path and converts it into a
`Config` object.

## Usage

``` r
read_json_into_config(config_path, optional_fields)
```

## Arguments

- config_path:

  A string specifying the path to the JSON configuration file.

- optional_fields:

  A list of strings specifying the optional fields in the JSON file. If
  a field is not present in the JSON file, and is marked as optional, it
  will be set to either the empty type (e.g. `chr(0)`), or NULL. If a
  field is not present in the JSON file, and is not marked as optional,
  an error will be thrown.

## Value

An instance of the `Config` class populated with the data from the JSON
file.

## See also

Other config:
[`Config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Config.md),
[`Data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Data.md),
[`Interval`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Interval.md),
[`Parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Parameters.md)
