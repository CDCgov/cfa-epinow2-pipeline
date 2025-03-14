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
empty_str_if_non_existent <- function(x) {
  ifelse(rlang::is_empty(x), "", x)
}

#' Check if the output container in the config file matches the one passed into
#' the function, or one or the other is NULL
#' @param arg_val The value of the output container argument passed in
#' @param config The config object
#' @return The config object with the output container set to the non-empty
#' value
#' @noRd
pick_non_empty <- function(arg_val, config) {
  # Check that the output container in the config file matches the one
  # passed in, or one or the other is NULL
  if (
    rlang::is_empty(config@output_container) &&
      rlang::is_empty(arg_val)
  ) {
    # Both are empty, so this is fine
    return(config)
  } else if (
    !rlang::is_empty(config@output_container) &&
      !rlang::is_empty(arg_val)
  ) {
    # Both are set, so check they match
    if (config@output_container != arg_val) {
      cli::cli_abort(c(
        "Output container in config file {.path {config@output_container}}",
        " does not match the one passed in {.path {arg_val}}",
        "i" = "Please pass in only one"
      ))
    }
    # They are the same, so return the config
    return(config)
  } else {
    # Get the non-empty one
    config@output_container <-
      if (rlang::is_empty(config@output_container)) {
        arg_val
      } else {
        config@output_container
      }
    return(config)
  }
}
