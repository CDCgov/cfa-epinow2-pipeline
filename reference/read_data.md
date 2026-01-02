# Read in the dataset of incident case counts

Each row of the table corresponds to a single facilities' cases for a
reference-date/report-date/disease tuple. We want to aggregate these
counts to the level of geographic
aggregate/report-date/reference-date/disease.

## Usage

``` r
read_data(
  data_path,
  disease = c("COVID-19", "Influenza", "RSV", "test"),
  geo_value,
  report_date,
  max_reference_date,
  min_reference_date
)
```

## Arguments

- data_path:

  The path to the local file. This could contain a glob and must be in
  parquet format.

- disease:

  A string specifying the disease being modeled. One of `"COVID-19"` or
  `"Influenza"` or `"RSV"`.

- geo_value:

  An uppercase, two-character string specifying the geographic value,
  usually a state or `"US"` for national data.

- report_date:

  A string representing the report date. Formatted as "YYYY-MM-DD".

- max_reference_date:

  A string representing the maximum reference date. Formatted as
  "YYYY-MM-DD".

- min_reference_date:

  A string representing the minimum reference date. Formatted as
  "YYYY-MM-DD".

## Value

A dataframe with one or more rows and columns `report_date`,
`reference_date`, `geo_value`, `confirm`

## Details

We handle two distinct cases for geographic aggregates:

1.  A single state: Subset to facilities **in that state only** and
    aggregate up to the state level 2. The US overall: Aggregate over
    all facilities without any subsetting

Note that we do *not* apply exclusions here. The exclusions are applied
later, after the aggregations. That means that for the US overall, we
aggregate over points that might potentially be excluded at the state
level. Our recourse in this case is to exclude the US overall aggregate
point.
