#' Read in the dataset of incident case counts
#'
#' Each row of the table corresponds to a single facilities' cases for a
#' reference-date/report-date/disease tuple. We want to aggregate these counts
#' to the level of geographic aggregate/report-date/reference-date/disease.
#'
#' We handle two distinct cases for geographic aggregates:
#'
#' 1. A single state: Subset to facilities **in that state only** and aggregate
#' up to the state level 2. The US overall: Aggregate over all facilities
#' without any subsetting
#'
#' Note that we do _not_ apply exclusions here. The exclusions are applied
#' later, after the aggregations. That means that for the US overall, we
#' aggregate over points that might potentially be excluded at the state level.
#' Our recourse in this case is to exclude the US overall aggregate point.
#'
#' @param data_path The path to the local file. This could contain a glob and
#'   must be in parquet format.
#' @inheritParams Config
#'
#' @return A dataframe with one or more rows and columns `report_date`,
#'   `reference_date`, `geo_value`, `confirm`
#' @family read_data
#' @export
read_data <- function(
  data_path,
  disease = c("COVID-19", "Influenza", "RSV", "test"),
  geo_value,
  report_date,
  max_reference_date,
  min_reference_date,
  facility_active_proportion
) {
  rlang::arg_match(disease)

  check_file_exists(data_path)

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(expr = DBI::dbDisconnect(con))

  # Get the schema of the data file, and check if `any_visits_this_day` is
  # present. If it is, then it is an API v2 file, otherwise it is an API v1
  # file. We use this to determine the query we need to run.
  is_api_v2 <- rlang::try_fetch(
    DBI::dbGetQuery(
      con,
      "SELECT * FROM read_parquet(?) LIMIT 0;",
      params = list(data_path)
    ) |>
      names() |>
      # Does it contain `any_visits_this_day`?
      stringr::str_detect("any_visits_this_day") |>
      any(),
    error = function(con) {
      cli::cli_abort(
        c(
          "Error reading schema from {.path {data_path}}",
          "Original error: {con}"
        ),
        class = "wrapped_schema_read_error"
      )
    }
  )

  parameters <- list(
    data_path = data_path,
    # If disease is COVID-19, we want to match both COVID-19 and
    # COVID-19/Omicron when filtering, so we add the % wildcard here
    disease = ifelse(disease == "COVID-19", paste0(disease, "%"), disease),
    min_ref_date = stringify_date(min_reference_date),
    max_ref_date = stringify_date(max_reference_date),
    report_date = stringify_date(report_date)
  )

  # We need different queries for the states and the US overall. For US overall
  # we need to aggregate over all the facilities in all the states. For the
  # states, we need to aggregate over all the facilities in that one state
  if (geo_value == "US" && !is_api_v2) {
    query <- "
   SELECT
     report_date,
     reference_date,
     CASE
       WHEN disease = 'COVID-19/Omicron' THEN 'COVID-19'
       ELSE disease
     END AS disease,
     -- We want to inject the 'US' as our abbrevation here bc data is not agg'd
     'US' AS geo_value,
      sum(value) AS confirm
    FROM read_parquet(?)
    WHERE 1=1
      AND disease LIKE ?
      AND metric = 'count_ed_visits'
      AND reference_date >= ? :: DATE
      AND reference_date <= ? :: DATE
      AND report_date = ? :: DATE
    GROUP BY reference_date, report_date, disease
    ORDER BY reference_date
   "
  } else if (geo_value != "US" && !is_api_v2) {
    # We want just one state so aggregate over facilites in that one state only
    query <- "
  SELECT
    report_date,
    reference_date,
    CASE
     WHEN disease = 'COVID-19/Omicron' THEN 'COVID-19'
     ELSE disease
    END AS disease,
    geo_value AS geo_value,
    sum(value) AS confirm,
  FROM read_parquet(?)
  WHERE 1=1
    AND disease LIKE ?
    AND metric = 'count_ed_visits'
    AND reference_date >= ? :: DATE
    AND reference_date <= ? :: DATE
    AND report_date = ? :: DATE
    AND geo_value = ?
  GROUP BY geo_value, reference_date, report_date, disease
  ORDER BY reference_date
  "
    # Append `geo_value` to the query
    parameters <- c(parameters, list(geo_value = geo_value))
  } else if (geo_value == "US" && is_api_v2) {
    # Add a column that is the proportion true over
    # the whole 8 week modeling period.
    query <- "
      WITH facility_checks AS (
        SELECT *,
        -- This is the same as `all(any_visits_this_day)`
        -- when grouped by facility
        AVG(IF(any_visits_this_day, 1, 0)) OVER
            (PARTITION BY facility) AS proportion_true
        FROM read_parquet(?)
        -- Filter here during the CTE, otherwise the PARTITION BY
        -- statement will be computationally expensive
        WHERE 1=1
          AND disease LIKE ?
          AND metric = 'count_ed_visits'
          AND reference_date >= ? :: DATE
          AND reference_date <= ? :: DATE
          AND report_date = ? :: DATE
      ) SELECT
        report_date,
        reference_date,
        CASE
          WHEN disease = 'COVID-19/Omicron' THEN 'COVID-19'
          ELSE disease
        END AS disease,
        -- We want to inject the 'US' as our abbrevation here bc data
        -- is not agg'd
        'US' AS geo_value,
        sum(value) AS confirm
      FROM facility_checks
      WHERE proportion_true = ?
      GROUP BY reference_date, report_date, disease
      ORDER BY reference_date
     "
    # Append `facility_active_proportion` to the query
    parameters <- c(parameters, list(
      facility_active_proportion = facility_active_proportion
    ))
  } else {
    # Add a column that is the proportion true over
    # the whole 8 week modeling period.
    query <- "
      WITH facility_checks AS (
        SELECT *,
        -- This is the same as `all(any_visits_this_day)`
        -- when grouped by facility
        AVG(IF(any_visits_this_day, 1, 0)) OVER
            (PARTITION BY facility) AS proportion_true
        FROM read_parquet(?)
        -- Filter here during the CTE, otherwise the PARTITION BY
        -- statement will be computationally expensive
        WHERE 1=1
          AND disease LIKE ?
          AND metric = 'count_ed_visits'
          AND reference_date >= ? :: DATE
          AND reference_date <= ? :: DATE
          AND report_date = ? :: DATE
          AND geo_value = ?
      ) SELECT
        report_date,
        reference_date,
        CASE
          WHEN disease = 'COVID-19/Omicron' THEN 'COVID-19'
          ELSE disease
        END AS disease,
        geo_value AS geo_value,
        sum(value) AS confirm
      FROM facility_checks
      WHERE proportion_true = ?
      GROUP BY geo_value, reference_date, report_date, disease
      ORDER BY reference_date
     "
    # Append `geo_value` to the query
    parameters <- c(parameters, list(
      geo_value = geo_value,
      facility_active_proportion = facility_active_proportion
    ))
  }

  df <- rlang::try_fetch(
    DBI::dbGetQuery(
      con,
      statement = query,
      params = unname(parameters)
    ),
    error = function(con) {
      cli::cli_abort(
        c(
          "Error fetching data from {.path {data_path}}",
          "Using parameters:",
          "*" = "data_path: {.path {parameters[['data_path']]}}",
          "*" = "disease: {.val {parameters[['disease']]}}",
          "*" = "min_reference_date: {.val {parameters[['min_ref_date']]}}",
          "*" = "max_reference_date: {.val {parameters[['max_ref_date']]}}",
          "*" = "report_date: {.val {parameters[['report_date']]}}",
          "*" = "geo_value: {.val {parameters[['geo_value']]}}",
          "*" = paste0(
            "facility_active_proportion:",
            " {.val {parameters[['facility_active_proportion']]}}"
          ),
          "Original error: {con}"
        ),
        class = "wrapped_invalid_query"
      )
    }
  )

  # Guard against empty return
  if (nrow(df) == 0) {
    cli::cli_abort(
      c(
        "No data matching returned from {.path {data_path}}",
        "Using parameters {parameters}"
      ),
      class = "empty_return"
    )
  }
  # Warn for incomplete return
  n_rows_expected <- as.Date(max_reference_date) -
    as.Date(min_reference_date) +
    1
  if (nrow(df) != n_rows_expected) {
    expected_dates <- seq.Date(
      from = as.Date(min_reference_date),
      to = as.Date(max_reference_date),
      by = "day"
    )
    missing_dates <- stringify_date(
      # Setdiff strips the date attribute from the objects; re-add it so that we
      # can pretty-format the date for printing
      as.Date(
        setdiff(expected_dates, df[["reference_date"]])
      )
    )
    cli::cli_warn(
      c(
        "Incomplete number of rows returned",
        "Expected {.val {n_rows_expected}} rows",
        "Observed {.val {nrow(df)}} rows",
        "Missing reference date(s): {missing_dates}"
      ),
      class = "incomplete_return"
    )
  }

  cli::cli_alert_success("Read {nrow(df)} rows from {.path {data_path}}")
  return(df)
}
