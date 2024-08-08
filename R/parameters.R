#' Load the prod parameters subset to required parameters
#'
#' Assumes that the dataset is a single parquet file, either sitting locally on
#' disk or (optionally) sitting in Azure Blob. The flow here is (1) To check if
#' loading the file from Blob is required (if `blob_storage_container` was
#' specified in the config) (2) Fetch from Blob if needed (3) Load the required
#' parameters from the downloaded file (4) Validate that the parameters match
#' expectations (one each of `delay`, `right_truncation`, and
#' `generation_interval`), (5) Alert success and return the df
#'
#' The load from disk uses [DuckDB], to enable portability. We can use the same
#' simple SQL query across languages to get the necessary parameters, and this
#' can be refactored out into its repo as a future issue.
#'
#' @param path The path to the local file or in Blob storage
#' @param blob_storage_container Either a character with the Azure Blob storage
#'   container with the parameters or the path to the local file
#' @param local_dest Only required when `blob_storage_container` is specified, a
#'   local directory to save the downloaded file
#' @param as_of_date The date that the parameters were used
#' @param disease The disease parameters to use
#' @param geo_value If a `geo_value`-specific parameter, which `geo_value` to
#'   use
#'
#' @return A dataframe with columns: "geo_value", "value", "start_date",
#'   "end_date", "parameter", "disease", "format", "id". The "value" column is a
#'   list-column with the PMF of the parameters to be used with EpiNow2 as
#'   non-parametric distribution specification.
#' @export
fetch_parameters <- function(
    path,
    blob_storage_container,
    local_dest,
    as_of_date,
    disease,
    geo_value) {
  if (!rlang::is_null(blob_storage_container)) {
    cli::cli_alert_info(
      "Downloading blob {.path {path}} from {.path {blob_storage_container}}"
    )
    path <- download_from_azure_blob(
      path,
      local_dest,
      container_name = blob_storage_container
    )
  } else {
    cli::cli_alert(
      "No blob container provided. Reading from local path {.path {path}}"
    )
  }

  parameters <- load_parameters(
    path,
    disease,
    geo_value,
    as_of_date
  )
  validate_parameters(parameters)
  cli::cli_alert_info("Parameters loaded successfully")

  return(parameters)
}

#' Load the parameters from a local file
#'
#' @param path Location of the local file on disk
#' @param disease As specified in the prod parameter dataset
#' @param geo_value As specified in tbe prod parameter dataset
#' @param as_of_date The parameters used as of a particular date. Allows using
#'   an older version of the parameters, such as for backtesting.
#'
#' @return A dataframe with columns: "geo_value", "value", "start_date",
#'   "end_date", "parameter", "disease", "format", "id"
#' @export
load_parameters <- function(
    path,
    disease,
    geo_value,
    as_of_date) {
  cli::cli_alert_info("Reading parameters from {.path {path}}")

  con <- DBI::dbConnect(duckdb::duckdb())
  df <- rlang::try_fetch(
    dbGetQuery(con, "
    SELECT
       *
     FROM read_parquet(?)
     WHERE 1=1
       AND disease = ?
       -- for params with no geo value, like the GI
       AND (geo_value = ? OR geo_value IS NULL)
       --
       AND start_date <= ? :: DATE
       AND (end_date > ? :: DATE OR end_date IS NULL)
     ",
      params = list(
        path,
        disease,
        geo_value,
        as_of_date,
        as_of_date
      )
    ),
    error = function(con) {
      cli::cli_abort(
        c(
          "Failure reading parameters from local path {.path {path}}",
          "*" = "Disease: {.var {disease}}",
          "*" = "Geo value: {.var {geo_value}}",
          "*" = "As-of date: {.var {as_of_date}}"
        ),
        parent = con,
        class = "CFA_Rt"
      )
    }
  )
  dbDisconnect(con)

  return(df)
}

#' Check loaded parameters df matches expected
#'
#' We want one each of `right_truncation`, `delay`, and `generation_interval`
#'
#' @param df The parameters df returned by [load_parameters()]
#'
#' @return The argument df, invisibly
#' @export
validate_parameters <- function(df) {
  reqd <- c(
    "generation_interval",
    "delay",
    "right_truncation"
  )
  actual <- df[["parameter"]]
  setequal <- all(c(actual %in% reqd, reqd %in% actual))

  if (!setequal) {
    cli::cli_abort(
      c(
        "Returned parameters do not match required. Is `geo_value` correct?",
        "*" = "Supplied: {.val {actual}}",
        "*" = "Required: {.val {reqd}}",
        "!" = "Full df: {df}"
      )
    )
  }

  if (nrow(df) != length(reqd)) {
    cli::cli_abort(
      c(
        "Duplicate parameters supplied",
        "!" = "Supplied parameters: {.val {actual}}"
      )
    )
  }

  invisible(df)
}
