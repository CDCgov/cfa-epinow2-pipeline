# Determine Low Case Count Threshold Based on Pathogen

Determine Low Case Count Threshold Based on Pathogen

## Usage

``` r
low_case_count_threshold(low_case_count_thresholds, disease)
```

## Arguments

- low_case_count_thresholds:

  A named list of thresholds to use for determining n_low_case_count in
  diagnostic file Example: list(`COVID-19` = 10,
  ``` Influenza`` = 10,  ```RSV\` = 5)

- disease:

  A string specifying the disease being modeled. One of `"COVID-19"` or
  `"Influenza"` or `"RSV"`.

## Value

low_count_threshold An integer that reflects the value X where number ED
visits \< X in the past week and week prior results in an
n_low_case_count flag for that pathogen-state pair

## See also

Other diagnostics:
[`extract_diagnostics()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/extract_diagnostics.md),
[`low_case_count_diagnostic()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/low_case_count_diagnostic.md)
