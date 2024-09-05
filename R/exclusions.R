#' Convert case counts in matching rows to NA
#'
#' NAs are skipped in model fitting by EpiNow2, so matched rows are excluded
#' from the model likelihood.
#'
#' @param cases A dataframe returned by [read_data()]
#' @param exclusions A dataframe returned by [read_exclusions()]
#'
#' @return A dataframe with the same rows and schema as `cases` and the value in
#'   the column `confirm` converted to NA in any rows that match a row in
#'   `exclusions`
#' @export
apply_exclusions <- function(cases, exclusions) {
  cli::cli_alert_info("Applying exclusions to case data")

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con))

  duckdb::duckdb_register(con, "cases", cases)
  duckdb::duckdb_register(con, "exclusions", exclusions)

  df <- DBI::dbGetQuery(con, "
    SELECT
      cases.report_date,
      cases.reference_date,
      cases.disease,
      cases.state_abb,
      CASE
        WHEN exclusions.reference_date IS NOT NULL THEN NULL
        ELSE cases.confirm
      END AS confirm
      FROM cases
      LEFT JOIN exclusions
        ON cases.reference_date = exclusions.reference_date
        AND cases.report_date = exclusions.report_date
        AND cases.state_abb = exclusions.state_abb
        AND cases.disease = exclusions.disease
      ORDER BY cases.reference_date
    ")

  cli::cli_alert_info("{.val {sum(is.na(df[['confirm']]))}} exclusions applied")

  return(df)
}

#' Read exclusions from an external file
#'
#' Expects to read a CSV with required columns:
#' * `reference_date`
#' * `report_date`
#' * `state_abb`
#' * `disease`
#'
#' These columns have the same meaning as in [read_data]. Additional columns are
#' allowed and will be ignored by the reader.
#'
#' @param path The path to the local file in `.csv` format with points to
#'   exclude
#'
#' @return A dataframe with columns `reference_date`, `report_date`,
#'   `state_abb`, `disease`
#' @export
read_exclusions <- function(path) {
  check_file_exists(path)

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con))
  df <- rlang::try_fetch(
    DBI::dbGetQuery(con, "
      SELECT
        reference_date,
        report_date,
        state_abb,
        disease
      FROM read_csv(?)
        ",
      params = list(path)
    ),
    error = function(con) {
      cli::cli_abort(
        c(
          "Error fetching exclusions from {.path {path}}",
          "Original error: {con}"
        ),
        class = "wrapped_invalid_query"
      )
    }
  )

  if (nrow(df) == 0) {
    cli::cli_abort("No data matching returned from {.path {path}}",
      class = "empty_return"
    )
  }

  cli::cli_alert_success("Exclusions file read")

  return(df)
}
