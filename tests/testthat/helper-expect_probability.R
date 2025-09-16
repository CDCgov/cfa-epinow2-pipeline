#' Testthat helper to check `actual` is a probability
#'
#' @param actual A length one numeric vector between 0 and 1
#' @return NULL invisibly or a testthat failure as a side effect
expect_probability <- function(actual) {
  testthat::expect_length(actual, 1)
  testthat::expect_type(actual, "double")
  testthat::expect_lte(actual, 1)
  testthat::expect_gte(actual, 0)
  invisible(NULL)
}
