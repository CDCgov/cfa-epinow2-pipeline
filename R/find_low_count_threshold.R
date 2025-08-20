#' Determine Low Case Count Threshold Based on Pathogen
#'
#' @inheritParams Config
#'
#' @return An integer that reflects the value X where number ED visits < X
#' in the past week and week prior results in an n_low_case_count flag for
#' that pathogen-state pair
#' @family diagnostics
#' @export
low_case_count_threshold <- function(low_case_count_thresholds, disease) {
  if (disease == "test") {
    low_count_threshold <- 10
  } else {
    low_count_threshold <- low_case_count_threshold[["disease"]]
  }
  return(low_count_threshold)
}
