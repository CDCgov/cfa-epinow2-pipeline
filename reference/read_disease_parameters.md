# Read in disease process parameters from an external file or files

Read in disease process parameters from an external file or files

## Usage

``` r
read_disease_parameters(
  generation_interval_path,
  delay_interval_path,
  right_truncation_path,
  disease,
  as_of_date,
  geo_value,
  report_date
)
```

## Arguments

- generation_interval_path, delay_interval_path, right_truncation_path:

  Path to a local file with the parameter PMF. See
  [`read_interval_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_interval_pmf.md)
  for details on the file schema. The parameters can be in the same file
  or a different file.

- disease:

  A string specifying the disease being modeled. One of `"COVID-19"` or
  `"Influenza"` or `"RSV"`.

- as_of_date:

  Use the parameters that were used in production on this date. Set for
  the current date for the most up-to-to date version of the parameters
  and set to an earlier date to use parameters from an earlier time
  period.

- geo_value:

  An uppercase, two-character string specifying the geographic value,
  usually a state or `"US"` for national data.

- report_date:

  An optional parameter to subset the query to a parameter on or before
  a particular `report_date`. Right now, the only parameter with report
  date-specific estimates is `right_truncation`. Note that this is
  similar to, but different from `as_of_date`. The `report_date` is used
  to select the particular value of a time-varying estimate. This
  estimate may itself be regenerated over time (e.g., as new data
  becomes available or with a methodological update). We can pull the
  estimate for date `report_date` as generated on date `as_of_date`.

## Value

A named list with three PMFs. The list elements are named
`generation_interval`, `delay_interval`, and `right_truncation`. If a
path to a local file is not provided (NA or NULL), the corresponding
parameter estimate will be NA in the returned list.

## Details

`generation_interval_path` is required because the generation interval
is a required parameter for \$R_t\$ estimation. `delay_interval_path`
and `right_truncation_path` are optional

## See also

Other parameters:
[`check_returned_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/check_returned_pmf.md),
[`opts_formatter`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/opts_formatter.md),
[`read_interval_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_interval_pmf.md)
