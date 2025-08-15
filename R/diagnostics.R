#' Extract diagnostic metrics from model fit and data
#'
#' This function extracts various diagnostic metrics from a fitted `EpiNow2`
#' model and provided data. It checks for low case counts and computes
#' diagnostics from the fitted model, including the mean acceptance
#' statistic, divergent transitions, maximum tree depth, and Rhat values.
#' Additionally, a combined flag is computed indicating if any diagnostics
#' are outside an acceptable range. The results are returned as a data frame.
#'
#' @param fit The model fit object from `EpiNow2`
#' @param data A data frame containing the input data used in the model fit.
#' @inheritParams Config
#'
#' @return A \code{data.frame} containing the extracted diagnostic metrics. The
#' data frame includes the following columns:
#' \itemize{
#'   \item \code{diagnostic}: The name of the diagnostic metric.
#'   \item \code{value}: The value of the diagnostic metric.
#'   \item \code{job_id}: The unique identifier for the job.
#'   \item \code{task_id}: The unique identifier for the task.
#'   \item \code{disease,geo_value,model,low_case_count_thresholds}: Metadata
#' for downstream processing.

#' }
#'
#' @details
#' The following diagnostics are calculated:
#' \itemize{
#'   \item \code{mean_accept_stat}: The average acceptance statistic across
#'         all chains.
#'   \item \code{p_divergent}: The *proportion* of divergent transitions across
#'         all samples.
#'   \item \code{n_divergent}: The *number* of divergent transitions across
#'         all samples.
#'   \item \code{p_max_treedepth}: The proportion of samples that hit the
#'         maximum tree depth.
#'   \item \code{p_high_rhat}: The *proportion* of parameters with Rhat values
#'         greater than 1.05, indicating potential convergence issues.
#'   \item \code{n_high_rhat}: The *number* of parameters with Rhat values
#'         greater than 1.05, indicating potential convergence issues.
#'   \item \code{low_case_count_flag}: A flag indicating if there are low case
#'         counts in the data. See \code{low_case_count_diagnostic()} for more
#'         information on this diagnostic.
#'   \item \code{epinow2_diagnostic_flag}: A combined flag that indicates if
#'         any diagnostic metrics are outside an accepted range, as determined
#'         by the thresholds: (1) mean_accept_stat < 0.1, (2) p_divergent >
#'         0.0075, (3) p_max_treedepth > 0.05, and (4) p_high_rhat > 0.0075.
#' }
#' @family diagnostics
#' @export
extract_diagnostics <- function(
  fit,
  data,
  job_id,
  task_id,
  disease,
  geo_value,
  model,
  low_case_count_thresholds
) {
  if (disease == "COVID-19") {
    low_case_count_threshold <- low_case_count_thresholds[["COVID-19"]]
  }
  if (disease == "RSV") {
    low_case_count_threshold <- low_case_count_thresholds[["RSV"]]
  }
  if (disease == "Influenza") {
    low_case_count_threshold <- low_case_count_thresholds[["Influenza"]]
  }
  if (disease == "test") {
    low_case_count_threshold <- 10
  }

  low_case_count <- low_case_count_diagnostic(data, low_case_count_threshold)

  epinow2_diagnostics <- rstan::get_sampler_params(
    fit$estimates$fit,
    inc_warmup = FALSE
  )
  mean_accept_stat <- mean(
    sapply(epinow2_diagnostics, function(x) mean(x[, "accept_stat__"]))
  )
  p_divergent <- mean(
    rstan::get_divergent_iterations(fit$estimates$fit),
    na.rm = TRUE
  )
  n_divergent <- sum(
    rstan::get_divergent_iterations(fit$estimates$fit),
    na.rm = TRUE
  )
  p_max_treedepth <- mean(
    rstan::get_max_treedepth_iterations(fit$estimates$fit),
    na.rm = TRUE
  )
  p_high_rhat <- mean(
    rstan::summary(fit$estimates$fit)$summary[, "Rhat"] > 1.05,
    na.rm = TRUE
  )
  n_high_rhat <- sum(
    rstan::summary(fit$estimates$fit)$summary[, "Rhat"] > 1.05,
    na.rm = TRUE
  )

  # Combine all diagnostic flags into one flag
  diagnostic_flag <- any(
    mean_accept_stat < 0.1,
    p_divergent > 0.0075, # 0.0075 = 15 in 2000 samples are divergent
    p_max_treedepth > 0.05,
    p_high_rhat > 0.0075
  )
  # Create individual vectors for the columns of the diagnostics data frame
  diagnostic_names <- c(
    "mean_accept_stat",
    "p_divergent",
    "n_divergent",
    "p_max_treedepth",
    "p_high_rhat",
    "n_high_rhat",
    "diagnostic_flag",
    "low_case_count_flag"
  )
  diagnostic_values <- c(
    mean_accept_stat,
    p_divergent,
    n_divergent,
    p_max_treedepth,
    p_high_rhat,
    n_high_rhat,
    diagnostic_flag,
    low_case_count
  )

  data.frame(
    diagnostic = diagnostic_names,
    value = diagnostic_values,
    job_id = job_id,
    task_id = task_id,
    disease = disease,
    geo_value = geo_value,
    model = model
  )
}

#' Calculate low case count diagnostic flag
#'
#' The diagnostic flag is TRUE if either of the _last_ two weeks
#' of the dataset have fewer than an aggregate X cases per week.
#' See the low_case_count_threshold parameter for what the value
#' of X is. This aggregation excludes the count from confirmed
#' outliers, which have been set to NA in the data.
#'
#' This function assumes that the `df` input dataset has been
#' "completed": that any implicit missingness has been made explicit.
#'
#' @param df A dataframe as returned by [read_data()]. The dataframe must
#' include columns such as `reference_date` (a date vector) and `confirm`
#' (the number of confirmed cases per day).
#' @param low_case_count_threshold: an integer that determines cutoff for
#' determining low_case_count flag. If the jurisdiction has less than
#' X ED visist for the respective pathogen, it will be considered
#' as have to few cases and later on in post-processing the
#' Rt estimate and growth category will be edited to NA and
#' "Not Estimated", respectively
#'
#' @return A logical value (TRUE or FALSE) indicating whether either of the last
#' two weeks in the dataset had fewer than 10 cases per week.
#' @family diagnostics
#' @export
low_case_count_diagnostic <- function(df, low_case_count_threshold) {
  cli::cli_alert_info("Calculating low case count diagnostic")
  # Get the dates in the last and second-to-last weeks
  last_date <- as.Date(max(df[["reference_date"]], na.rm = TRUE))
  # Create week sequences explicitly in case of missingness
  ult_week_min <- last_date - 6
  ult_week_max <- last_date
  pen_week_min <- last_date - 13
  pen_week_max <- last_date - 7
  ultimate_week_dates <- seq.Date(
    from = ult_week_min,
    to = ult_week_max,
    by = "day"
  )
  penultimate_week_dates <- seq.Date(
    from = pen_week_min,
    to = pen_week_max,
    by = "day"
  )

  ultimate_week_count <- sum(
    df[
      df[["reference_date"]] %in% ultimate_week_dates,
      "confirm"
    ],
    na.rm = TRUE
  )
  penultimate_week_count <- sum(
    df[
      df[["reference_date"]] %in% penultimate_week_dates,
      "confirm"
    ],
    na.rm = TRUE
  )

  cli::cli_alert_info(c(
    "Ultimate week spans {format(ult_week_min, '%a, %Y-%m-%d')} ",
    "to {format(ult_week_max, '%a, %Y-%m-%d')} with ",
    "count {.val {ultimate_week_count}}"
  ))
  cli::cli_alert_info(c(
    "Penultimate week spans ",
    "{format(pen_week_min, '%a, %Y-%m-%d')} to ",
    "{format(pen_week_max, '%a, %Y-%m-%d')} with ",
    "count {.val {penultimate_week_count}}"
  ))

  any(
    ultimate_week_count < low_case_count_threshold,
    penultimate_week_count < low_case_count_threshold
  )
}
