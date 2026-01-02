# Parameters Class

Holds all parameter-related configurations for the pipeline.

## Usage

``` r
Parameters(
  as_of_date = class_missing,
  generation_interval = class_missing,
  delay_interval = class_missing,
  right_truncation = class_missing
)
```

## Arguments

- as_of_date:

  A string representing the as-of date. Formatted as "YYYY-MM-DD".

- generation_interval:

  An instance of `GenerationInterval` class.

- delay_interval:

  An instance of `DelayInterval` class.

- right_truncation:

  An instance of `RightTruncation` class.

## See also

Other config:
[`Config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Config.md),
[`Data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Data.md),
[`Interval`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Interval.md),
[`read_json_into_config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_json_into_config.md)
