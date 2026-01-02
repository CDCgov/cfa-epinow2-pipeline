# Calculate low case count diagnostic flag

The diagnostic flag is TRUE if either of the *last* two weeks of the
dataset have fewer than an aggregate X cases per week. See the
low_case_count_threshold parameter for what the value of X is. This
aggregation excludes the count from confirmed outliers, which have been
set to NA in the data.

## Usage

``` r
low_case_count_diagnostic(df, low_count_threshold)
```

## Arguments

- df:

  A dataframe as returned by
  [`read_data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_data.md).
  The dataframe must include columns such as `reference_date` (a date
  vector) and `confirm` (the number of confirmed cases per day).

- low_count_threshold:

  an integer that determines cutoff for determining low_case_count flag.
  If the jurisdiction has less than X ED visist for the respective
  pathogen, it will be considered as having too few cases and later on
  in post-processing the Rt estimate and growth category will be edited
  to NA and "Not Estimated", respectively

## Value

A logical value (TRUE or FALSE) indicating whether either of the last
two weeks in the dataset had fewer than 10 cases per week.

## Details

This function assumes that the `df` input dataset has been "completed":
that any implicit missingness has been made explicit.

## See also

Other diagnostics:
[`extract_diagnostics()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/extract_diagnostics.md),
[`low_case_count_threshold()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/low_case_count_threshold.md)
