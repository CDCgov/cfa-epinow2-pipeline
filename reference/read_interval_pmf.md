# Read parameter PMF into memory

Using DuckDB from a parquet file. The function expects the file to be in
SCD2 format with column names:

- parameter

- geo_value

- disease

- start_date

- end_date

- value

## Usage

``` r
read_interval_pmf(
  path,
  disease = c("COVID-19", "Influenza", "RSV", "test"),
  as_of_date,
  parameter = c("generation_interval", "delay", "right_truncation"),
  geo_value = NA,
  report_date = NA
)
```

## Arguments

- path:

  A path to a local file

- disease:

  A string specifying the disease being modeled. One of `"COVID-19"` or
  `"Influenza"` or `"RSV"`.

- as_of_date:

  Use the parameters that were used in production on this date. Set for
  the current date for the most up-to-to date version of the parameters
  and set to an earlier date to use parameters from an earlier time
  period.

- parameter:

  One of "generation interval", "delay", or "right-truncation"

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

A PMF vector

## Details

start_date and end_date specify the date range for which the value was
used. end_date may be NULL (e.g. for the current value used in
production). value must contain a pmf vector whose values are all
positive and sum to 1. all other fields must be consistent with the
specifications of the function arguments described below, which are used
to query from the .parquet file.

SCD2 format is shorthand for slowly changing dimension type 2. This
format is normalized to track change over time:
https://en.wikipedia.org/wiki/Slowly_changing_dimension#Type_2:\_add_new_row

## See also

Other parameters:
[`check_returned_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/check_returned_pmf.md),
[`opts_formatter`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/opts_formatter.md),
[`read_disease_parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_disease_parameters.md)
