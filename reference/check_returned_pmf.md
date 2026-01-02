# Run validity checks on the PMF returned from the file

We're treating this input as possibly invalid because it's from an
external file. We're still updating the schema and this process has been
a frequent source of problems. We want to be alert to any unexpected
changes in schema or format.

## Usage

``` r
check_returned_pmf(
  pmf_df,
  parameter,
  disease,
  as_of_date,
  geo_value,
  report_date,
  path
)
```

## Arguments

- pmf_df:

  A dataframe with columns `value` and `reference_date`.

- parameter:

  One of "generation interval", "delay", or "right-truncation"

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

- path:

  A path to a local file

## Value

The unpacked `value` column, which is a valid PMF

## See also

Other parameters:
[`opts_formatter`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/opts_formatter.md),
[`read_disease_parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_disease_parameters.md),
[`read_interval_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_interval_pmf.md)
