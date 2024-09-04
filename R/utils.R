#' DuckDB date comparison fails if the dates are not in string format
#' @noRd
stringify_date <- function(date) {
  if (inherits(date, "Date")) {
    format(date, "%Y-%m-%d")
  } else {
    date
  }
}
