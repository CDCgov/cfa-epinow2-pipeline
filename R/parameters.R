#' Read in disease process parameters from an external file or files
#'
#' @param generation_interval_path,delay_interval_path,right_truncation_path
#'   Path to a local file with the parameter PMF. See [read_interval_pmf] for
#'   details on the file schema. The parameters can be in the same file or a
#'   different file.
#' @param disease One of `COVID-19` or `Influenza`
#' @param as_of_date Use the parameters that were used in production on this
#'   date. Set for the current date for the most up-to-to date version of the
#'   parameters and set to an earlier date to use parameters from an earlier
#'   time period.
#' @param group Used only for parameters with a state-level estimate (i.e., only
#'   right-truncation). The two-letter uppercase state abbreviation.
#'
#' @return A named list with three PMFs. The list elements are named
#'   `generation_interval`, `delay_interval`, and `right_truncation`. If a path
#'   to a local file is not provided (NA or NULL), the corresponding parameter
#'   estimate will be NA in the returned list.
#' @details `generation_interval_path` is required because the generation
#'   interval is a required parameter for $R_t$ estimation.
#'   `delay_interval_path` and `right_truncation_path` are optional (but
#'   strongly suggested).
#' @export
read_disease_parameters <- function(
    generation_interval_path,
    delay_interval_path,
    right_truncation_path,
    disease,
    as_of_date,
    group) {
  generation_interval <- read_interval_pmf(
    path = generation_interval_path,
    disease = disease,
    as_of_date = as_of_date,
    parameter = "generation_interval"
  )

  if (path_is_specified(delay_interval_path)) {
    delay_interval <- read_interval_pmf(
      path = delay_interval_path,
      disease = disease,
      as_of_date = as_of_date,
      parameter = "delay"
    )
  } else {
    cli::cli_alert_warning(
      "No delay interval path specified. Using a delay of 0 days."
    )
    delay_interval <- NA
  }

  if (path_is_specified(right_truncation_path)) {
    right_truncation <- read_interval_pmf(
      path = right_truncation_path,
      disease = disease,
      as_of_date = as_of_date,
      parameter = "right_truncation",
      group = group
    )
  } else {
    cli::cli_alert_warning(
      "No right truncation path specified. Not adjusting for right truncation."
    )
    right_truncation <- NA
  }

  parameters <- list(
    generation_interval = generation_interval,
    delay_interval = delay_interval,
    right_truncation = right_truncation
  )
  return(parameters)
}

path_is_specified <- function(path) {
  !rlang::is_null(path) &&
    !rlang::is_na(path)
}

#' Read parameter PMF into memory
#'
#' Using DuckDB from a parquet file. The function expects the file to be in SCD2
#' format with column names:
#' * parameter
#' * geo_value
#' * disease
#' * start_date
#' * end_date
#' * value
#'
#' start_date and end_date specify the date range for which the value was used.
#' end_date may be NULL (e.g. for the current value used in production). value
#' must contain a pmf vector whose values are all positive and sum to 1. all
#' other fields must be consistent with the specifications of the function
#' arguments describe below, which are used to query from the .parquet file.
#'
#' SCD2 format is shorthand for slowly changing dimension type 2. This format is
#' normalized to track change over time:
#' https://en.wikipedia.org/wiki/Slowly_changing_dimension#Type_2:_add_new_row
#'
#' @param path A path to a local file
#' @param disease One of "COVID-19" or "Influenza"
#' @param as_of_date The parameters "as of" the date of the model run
#' @param parameter One of "generation interval", "delay", or "right-truncation
#' @param group An optional parameter to subset the query to a parameter with a
#'   particular two-letter state abbrevation. Right now, the only parameter with
#'   state-specific estimates is `right-truncation`.
#'
#' @return A PMF vector
#' @export
read_interval_pmf <- function(path,
                              disease = c("COVID-19", "Influenza", "test"),
                              as_of_date,
                              parameter = c(
                                "generation_interval",
                                "delay",
                                "right_truncation"
                              ),
                              group = NA) {
  ###################
  # Validate input
  rlang::arg_match(parameter)
  rlang::arg_match(disease)

  as_of_date <- stringify_date(as_of_date)
  cli::cli_alert_info("Reading {.arg right_truncation} from {.path {path}}")
  if (!file.exists(path)) {
    cli::cli_abort("File {.path {path}} does not exist",
      class = "file_not_found"
    )
  }


  ################
  # Prepare query

  query <- "
    SELECT value
    FROM read_parquet(?)
    WHERE 1=1
      AND parameter = ?
      AND disease = ?
      AND start_date < ? :: DATE
      AND (end_date > ? OR end_date IS NULL)
    "
  parameters <- list(
    path,
    parameter,
    disease,
    as_of_date,
    as_of_date
  )

  # Handle state separately because can't use `=` for NULL comparison and
  # DBI::dbBind() can't parameterize a query after IS
  if (rlang::is_na(group) || rlang::is_null(group)) {
    query <- paste(query, "AND geo_value IS NULL;")
  } else {
    query <- paste(query, "AND geo_value = ?")
    parameters <- c(parameters, list(group))
  }

  ################
  # Execute query

  con <- DBI::dbConnect(duckdb::duckdb())
  pmf_df <- rlang::try_fetch(
    DBI::dbGetQuery(
      conn = con,
      statement = query,
      params = parameters
    ),
    error = function(cnd) {
      cli::cli_abort(
        c(
          "Failure loading {.arg {parameter}} from {.path {path}}",
          "Using {.val {disease}}, {.val {as_of_date}}, and {.val {group}}",
          "Original error: {cnd}"
        ),
        class = "wrapped_error"
      )
    }
  )
  DBI::dbDisconnect(con)


  ################
  # Validate loaded PMF
  if (nrow(pmf_df) != 1) {
    cli::cli_abort(
      c(
        "Failure loading {.arg {parameter}} from {.path {path}} ",
        "Query did not return exactly one row",
        "Using {.val {disease}}, {.val {as_of_date}}, and {.val {group}}",
        "Query matched {.val {nrow(pmf_df)}} rows"
      ),
      class = "not_one_row_returned"
    )
  }

  pmf <- pmf_df[["value"]][[1]]

  if ((length(pmf) < 1) || !rlang::is_bare_numeric(pmf)) {
    cli::cli_abort(
      c(
        "Invalid {.arg {parameter}} returned.",
        "x" = "Expected a PMF",
        "i" = "Loaded object: {pmf_df}"
      ),
      class = "not_a_pmf"
    )
  }

  if (any(pmf < 0) || any(pmf > 1) || abs(sum(pmf) - 1) > 1e-10) {
    cli::cli_abort(
      c(
        "Returned numeric vector is not a valid PMF",
        "Any below 0: {any(pmf < 0)}",
        "Any above 1: {any(pmf > 1)}",
        "Sum is within 1 with tol of 1e-10: {abs(sum(pmf) - 1) < 1e-10}",
        "pmf: {.val {pmf}}"
      ),
      class = "invalid_pmf"
    )
  }

  cli::cli_alert_success("{.arg {parameter}} loaded")

  return(pmf)
}

#' DuckDB date comparison fails if the dates are not in string format
#' @noRd
stringify_date <- function(date) {
  if (inherits(date, "Date")) {
    format(date, "%Y-%m-%d")
  }
}
