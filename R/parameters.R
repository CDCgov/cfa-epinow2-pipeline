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
#' @param group An optional parameter to subset the query to a parameter with a
#'   particular two-letter state abbrevation. Right now, the only parameter with
#'   state-specific estimates is `right_truncation`.
#' @param report_date An optional parameter to subset the query to a parameter
#'   on or before a particular `report_date`. Right now, the only parameter with
#'   report date-specific estimates is `right_truncation`. Note that this
#'   is similar to, but different from `as_of_date`. The `report_date` is used
#'   to select the particular value of a time-varying estimate. This estimate
#'   may itself be regenerated over time (e.g., as new data becomes available or
#'   with a methodological update). We can pull the estimate for date
#'   `report_date` as generated on date `as_of_date`.
#'
#' @return A named list with three PMFs. The list elements are named
#'   `generation_interval`, `delay_interval`, and `right_truncation`. If a path
#'   to a local file is not provided (NA or NULL), the corresponding parameter
#'   estimate will be NA in the returned list.
#' @details `generation_interval_path` is required because the generation
#'   interval is a required parameter for $R_t$ estimation.
#'   `delay_interval_path` and `right_truncation_path` are optional (but
#'   strongly suggested).
#' @family parameters
#' @export
read_disease_parameters <- function(
    generation_interval_path,
    delay_interval_path,
    right_truncation_path,
    disease,
    as_of_date,
    group,
    report_date) {
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
      group = group,
      report_date = report_date
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
#' @param parameter One of "generation interval", "delay", or "right-truncation
#' @inheritParams read_disease_parameters
#'
#' @return A PMF vector
#' @family parameters
#' @export
read_interval_pmf <- function(path,
                              disease = c("COVID-19", "Influenza", "test"),
                              as_of_date,
                              parameter = c(
                                "generation_interval",
                                "delay",
                                "right_truncation"
                              ),
                              group = NA,
                              report_date = NA) {
  ###################
  # Validate input
  rlang::arg_match(parameter)
  rlang::arg_match(disease)

  as_of_date <- stringify_date(as_of_date)
  cli::cli_alert_info("Reading {.arg {parameter}} from {.path {path}}")
  if (!file.exists(path)) {
    cli::cli_abort("File {.path {path}} does not exist",
      class = "file_not_found"
    )
  }


  ################
  # Prepare query

  query <- "
    SELECT value, reference_date
    FROM read_parquet(?)
    WHERE 1=1
      AND parameter = ?
      AND disease = ?
      AND start_date < ? :: DATE
      AND (CAST(end_date AS DATE) > ? :: DATE OR end_date IS NULL)
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
    query <- paste(query, "AND geo_value IS NULL")
  } else {
    query <- paste(query, "AND geo_value = ?")
    parameters <- c(parameters, list(group))
  }
  if (parameter == "right_truncation") {
    query <- paste(query, "AND (
                             reference_date <= ? :: DATE
                             OR reference_date IS NULL
                           )
                           ORDER BY reference_date DESC
                           LIMIT 1")
    parameters <- c(parameters, list(report_date))
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

  pmf <- check_returned_pmf(
    pmf_df,
    parameter,
    disease,
    as_of_date,
    group,
    report_date,
    path
  )

  cli::cli_alert_success("{.arg {parameter}} loaded")

  return(pmf)
}

#' Run validity checks on the PMF returned from the file
#'
#' We're treating this input as possibly invalid because it's from an
#' external file. We're still updating the schema and process ands has
#' been a frequent source of problems. We want to be alert to any
#' unexpexted changes in schema or format.
#'
#' @param pmf_df A dataframe with columns `value` and `reference_date`.
#' @inheritParams read_interval_pmf
#'
#' @return The unpacked `value` column, which is a valid PMF
#' @family parameters
#' @noRd
check_returned_pmf <- function(
    pmf_df,
    parameter,
    disease,
    as_of_date,
    group,
    report_date,
    path) {
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

  if (parameter == "right_truncation") {
    right_trunc_date <- stringify_date(pmf_df[["reference_date"]][[1]])
    if (rlang::is_null(right_trunc_date) || rlang::is_na(right_trunc_date)) {
      right_trunc_date <- "NA"
    }
    max_ref_date <- stringify_date(report_date)
    as_of_date <- stringify_date(as_of_date)
    cli::cli_inform(c(
      "Using right-truncation estimate for date {.val {right_trunc_date}}",
      "Queried last available estimate from {.val {max_ref_date}} or earlier",
      "Subject to parameters available as of {.val {as_of_date}}"
    ))
  }
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

  return(pmf)
}

#' Format PMFs for EpiNow2
#'
#' Opinionated wrappers around EpiNow2::generation_time_opts(),
#' EpiNow2::delay_opts(), or EpiNow2::dist_spec() that formats the generation
#' interval, delay, or right truncation parameters as an object ready for input
#' to EpiNow2.
#'
#' Delays or right truncation are optional and can be skipped by passing `pmf =
#' NA`.
#'
#' @param pmf As returned by [CFAEpiNow2Pipeline::read_disease_parameters()]. A
#'   PMF vector or an NA, if not applying the PMF to the model fit.
#'
#' @return An EpiNow2::*_opts() formatted object or NA with a message
#' @family parameters
#' @name opts_formatter
NULL

#' @rdname opts_formatter
#' @export
format_generation_interval <- function(pmf) {
  if (
    rlang::is_na(pmf) || rlang::is_null(pmf)
  ) {
    cli::cli_abort("No generation time PMF specified but is required",
                   class = "Missing_GI"
    )
  }
  
  suppressWarnings({
    EpiNow2::generation_time_opts(
      dist = EpiNow2::dist_spec(
        pmf = pmf
      )
    )
  })
}

#' @rdname opts_formatter
#' @export
format_delay_interval <- function(pmf) {
  if (
    rlang::is_na(pmf) || rlang::is_null(pmf)
  ) {
    cli::cli_alert("Not adjusting for infection to case delay")
    EpiNow2::delay_opts()
  } else {
    suppressWarnings({
      EpiNow2::delay_opts(
        dist = EpiNow2::dist_spec(
          pmf = pmf
        )
      )
    })
  }
}

#' @inheritParams fit_model
#' @rdname opts_formatter
#' @export
format_right_truncation <- function(pmf, data) {
  if (
    rlang::is_na(pmf) || rlang::is_null(pmf)
  ) {
    cli::cli_alert("Not adjusting for right truncation")
    EpiNow2::trunc_opts()
  } else if (length(pmf) > nrow(data)) {
    # Nasty bug we ran into where **left-hand** side of the PMF was being
    # silently removed if length of the PMF was longer than the data,
    # effectively eliminating the right-truncation correction
    
    trunc_len <- nrow(data)
    cli::cli_warn(
      c(
        "Removing right-truncation PMF elements after {.val {trunc_len}}",
        "Right truncation PMF longer than the data",
        "PMF length: {.val {length(pmf)}}",
        "Data length: {.val {nrow(data)}}",
        "PMF can only be up to the length of the data"
      ),
      class = "right_trunc_too_long"
    )
    suppressWarnings({
      EpiNow2::trunc_opts(
        dist = EpiNow2::dist_spec(
          pmf = pmf[seq_len(trunc_len)]
        )
      )
    })
  } else {
    suppressWarnings({
      EpiNow2::trunc_opts(
        dist = EpiNow2::dist_spec(
          pmf = pmf
        )
      )
    })
  }
}
