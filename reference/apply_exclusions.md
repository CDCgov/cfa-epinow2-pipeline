# Convert case counts in matching rows to NA

Mark selected points to be ignored in model fitting. This manual
selection occurs externally to the pipeline and is passed to the
pipeline in an exclusions file read with
[`read_exclusions()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_exclusions.md).
Mechanically, the exclusions are applied by converting specified points
to NAs in the dataset. NAs are skipped in model fitting by EpiNow2, so
matched rows are excluded from the model likelihood.

## Usage

``` r
apply_exclusions(cases, exclusions)
```

## Arguments

- cases:

  A dataframe returned by
  [`read_data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_data.md)

- exclusions:

  A dataframe returned by
  [`read_exclusions()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_exclusions.md)

## Value

A dataframe with the same rows and schema as `cases` where the value in
the column `confirm` converted to NA in any rows that match a row in
`exclusions`

## See also

Other exclusions:
[`read_exclusions()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_exclusions.md)
