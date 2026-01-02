# Format PMFs for EpiNow2

Opinionated wrappers around
[`EpiNow2::generation_time_opts()`](https://epiforecasts.io/EpiNow2/reference/generation_time_opts.html),
[`EpiNow2::delay_opts()`](https://epiforecasts.io/EpiNow2/reference/delay_opts.html),
or
[`EpiNow2::trunc_opts()`](https://epiforecasts.io/EpiNow2/reference/trunc_opts.html)
which format the generation interval, delay, or right truncation
parameters as an object ready for input to `EpiNow2`.

## Usage

``` r
format_generation_interval(pmf)

format_delay_interval(pmf)

format_right_truncation(pmf, data)
```

## Arguments

- pmf:

  As returned by
  [`read_disease_parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_disease_parameters.md).
  A PMF vector or an NA, if not applying the PMF to the model fit.

- data:

  in the format returned by
  [`read_data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_data.md)

## Value

An `EpiNow2::*_opts()` formatted object or NA with a message

## Details

Delays or right truncation are optional and can be skipped by passing
`pmf = NA`.

## See also

Other parameters:
[`check_returned_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/check_returned_pmf.md),
[`read_disease_parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_disease_parameters.md),
[`read_interval_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_interval_pmf.md)
