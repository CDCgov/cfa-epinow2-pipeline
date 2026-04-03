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
  facility_active_proportion = 0.94
) {
  rlang::arg_match(disease)
  check_file_exists(data_path)

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # any_visits_this_day is calculated for API v2
  # True if a given facility, on a given reference_date had a DDI count > 0
  # Same across all diseases and metrics for (facility, reference_date)
  is_api_v2 <- rlang::try_fetch(
    {
      cols <- DBI::dbGetQuery(
        con,
        "SELECT * FROM read_parquet(?) LIMIT 0;",
        params = list(data_path)
      ) |>
        names()

      "any_visits_this_day" %in% cols
    },
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

  is_us <- identical(geo_value, "US")

  cli::cli_inform(
    c(
      "Using {if (is_api_v2) 'API v2 (facility filtered)' else 'API v1'}",
      "query for {.val {geo_value}}"
    )
  )

  disease_param <- if (disease == "COVID-19") paste0(disease, "%") else disease

  base_params <- list(
    data_path = data_path,
    disease = disease_param,
    min_ref_date = stringify_date(min_reference_date),
    max_ref_date = stringify_date(max_reference_date),
    report_date = stringify_date(report_date)
  )

  geo_select <- if (is_us) {
    "'US' AS geo_value"
  } else {
    "geo_value"
  }

  geo_filter <- if (is_us) {
    ""
  } else {
    "AND geo_value = ?"
  }

  group_by <- if (is_us) {
    "GROUP BY reference_date, report_date, disease"
  } else {
    "GROUP BY geo_value, reference_date, report_date, disease"
  }

  if (!is_api_v2) {
    query <- glue::glue(
      "
      SELECT
        report_date,
        reference_date,
        CASE
          WHEN disease = 'COVID-19/Omicron' THEN 'COVID-19'
          ELSE disease
        END AS disease,
        {geo_select},
        SUM(value) AS confirm
      FROM read_parquet(?)
      WHERE disease LIKE ?
        AND metric = 'count_ed_visits'
        AND reference_date >= ?::DATE
        AND reference_date <= ?::DATE
        AND report_date = ?::DATE
        {geo_filter}
      {group_by}
      ORDER BY reference_date
    "
    )

    params <- base_params
    if (!is_us) {
      params <- c(params, list(geo_value = geo_value))
    }
  } else {
    query <- glue::glue(
      "
      WITH facility_checks AS (
        SELECT
          *,
          AVG(IF(any_visits_this_day, 1, 0)) OVER (
            PARTITION BY facility
          ) AS proportion_true
        FROM read_parquet(?)
        WHERE disease LIKE ?
          AND metric = 'count_ed_visits'
          AND reference_date >= ?::DATE
          AND reference_date <= ?::DATE
          AND report_date = ?::DATE
          {geo_filter}
      )
      SELECT
        report_date,
        reference_date,
        CASE
          WHEN disease = 'COVID-19/Omicron' THEN 'COVID-19'
          ELSE disease
        END AS disease,
        {geo_select},
        SUM(value) AS confirm
      FROM facility_checks
      WHERE proportion_true >= ?
      -- `WHERE` filters before the GROUP BY, so this filter excludes
      -- from the agg all facilities with insufficient reporting
      {group_by}
      ORDER BY reference_date
    "
    )

    params <- base_params
    if (!is_us) {
      params <- c(params, list(geo_value = geo_value))
    }
    params <- c(
      params,
      list(facility_active_proportion = facility_active_proportion)
    )
  }

  df <- rlang::try_fetch(
    DBI::dbGetQuery(
      con,
      statement = query,
      params = unname(params)
    ),
    error = function(con) {
      cli::cli_abort(
        c(
          "Error fetching data from {.path {data_path}}",
          "Using parameters:",
          "*" = "data_path: {.path {base_params[['data_path']]}}",
          "*" = "disease: {.val {base_params[['disease']]}}",
          "*" = "min_reference_date: {.val {base_params[['min_ref_date']]}}",
          "*" = "max_reference_date: {.val {base_params[['max_ref_date']]}}",
          "*" = "report_date: {.val {base_params[['report_date']]}}",
          "*" = "geo_value: {.val {geo_value}}",
          "*" = paste0(
            "facility_active_proportion: ",
            "{.val {facility_active_proportion}}"
          ),
          "Original error: {con}"
        ),
        class = "wrapped_invalid_query"
      )
    }
  )

  if (nrow(df) == 0) {
    cli::cli_abort(
      c(
        "No data matching returned from {.path {data_path}}",
        "Using parameters {base_params}"
      ),
      class = "empty_return"
    )
  }

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
      as.Date(setdiff(expected_dates, df[["reference_date"]]))
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
  df
}
