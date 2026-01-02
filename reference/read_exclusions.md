# Read exclusions from an external file

Expects to read a CSV with required columns:

- `reference_date`

- `report_date`

- `state`

- `disease`

## Usage

``` r
read_exclusions(path)
```

## Arguments

- path:

  The path to the exclusions file in `.csv` format

## Value

A dataframe with columns `reference_date`, `report_date`, `geo_value`,
`disease`

## Details

These columns have the same meaning as in
[`read_data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_data.md).
Additional columns are allowed and will be ignored by the reader.

## See also

Other exclusions:
[`apply_exclusions()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/apply_exclusions.md)
