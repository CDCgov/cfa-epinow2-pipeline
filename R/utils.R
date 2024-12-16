#' DuckDB date comparison fails if the dates are not in string format
#' @noRd
stringify_date <- function(date) {
  if (inherits(date, "Date")) {
    format(date, "%Y-%m-%d")
  } else {
    date
  }
}

check_file_exists <- function(data_path) {
  # Guard against file does not exist
  cli::cli_alert("Reading data from {.path {data_path}}")
  if (!file.exists(data_path)) {
    cli::cli_abort(
      "Cannot read data. File {.path {data_path}} doesn't exist",
      class = "file_not_found"
    )
  }
  invisible(data_path)
}

#' If `x` is null or empty, return an empty string, otherwise `x`
#' @noRd
empty_str_if_non_existant <- function(x) {
  ifelse(rlang::is_empty(x), "", x)
}
