#' Extract and reformat samples from a model fit object
#'
#' This function extracts the desired parameters from a model fit object,
#' processes the Stan draws, and joins them with a date-time-parameter map for
#' further analysis. The function transforms the data into long format and
#' standardizes parameter names for easier quantile summarization and analysis.
#'
#' @param fit A list representing the model fit object, which includes estimates
#' and Stan samples. The `fit` object must contain an `estimates$samples`
#' data.table with columns `date`, `time`, `parameter`, and `type`, as well as a
#' Stan fit object in `estimates$fit`.
#'
#' @return A `data.table` in long format with the following columns:
#' \describe{
#'   \item{\code{time}}{The timepoint at which the draw was made.}
#'   \item{\code{_draw}}{The draw number from the Stan fit.}
#'   \item{\code{_chain}}{The chain number from the Stan fit.}
#'   \item{\code{parameter}}{The standardized parameter name (e.g.,
#'   latent_cases, obs_cases, Rt, growth_rate).}
#'   \item{\code{value}}{The value of the parameter for the corresponding draw
#'   and time.}
#'   \item{\code{reference_date}}{The date associated with the timepoint.}
#'   \item{\code{type}}{The type of the parameter (e.g., estimate or
#'   observation).}
#' }
#'
#' @details
#' The function performs the following steps:
#' \enumerate{
#'   \item Extracts unique combinations of date, time, parameter, and type from
#'   the model fit.
#'   \item Extracts relevant parameters from the Stan model, such as imputed and
#'   observed reports, the reproduction number (\code{Rt}), and the growth rate
#'   (\code{r}).
#'   \item Converts the extracted data from wide to long format for further
#'   analysis.
#'   \item Performs a left join of the date-time-parameter map onto the Stan
#'   draws to associate the proper dates and types with the parameters.
#'   \item Standardizes the parameter names for consistency.
#' }
#'
#' @export
extract_samples_from_fit <- function(fit) {
  # Step 1: Extract unique date-time-parameter combinations
  # This step extracts combinations from the "samples" part of the fit
  fact_table <- fit[["estimates"]][["samples"]][,
    c("date", "time", "parameter"),
    with = FALSE
  ]
  fact_table <- na.omit(unique(fact_table))

  # Step 1.1: Add corresponding 'obs_cases' rows for 'latent_cases' dates
  # `samples` table produced by EpiNow2 doesn't have `obs_reports` so the join
  # produces an NA. We want the date-time combinations to match for
  # both `imputed_` and `obs_` reports.
  obs_fact_table <- fact_table[fact_table[["parameter"]] == "imputed_reports", ]
  data.table::set(obs_fact_table, j = "parameter", value = factor(
    obs_fact_table[["parameter"]],
    levels = c("imputed_reports"),
    labels = c("obs_reports")
  ))


  # Combine original fact_table with new 'obs_reports' rows
  fact_table <- rbind(fact_table, obs_fact_table, fill = TRUE)

  # Step 2: Extract desired parameters from the Stan object as posterior draws
  stanfit <- fit[["estimates"]][["fit"]]
  stan_draws <- tidybayes::spread_draws(
    stanfit,
    imputed_reports[time],
    obs_reports[time],
    R[time],
    r[time]
  ) |>
    data.table::as.data.table()

  # Step 3: Pivot data from wide to long format for further processing
  pivoted_dt <- data.table::melt(
    stan_draws,
    id.vars = c("time", ".draw", ".chain"),
    measure.vars = c("obs_reports", "imputed_reports", "R", "r"),
    # Changed variable name to match fact_table for join
    variable.name = "parameter",
    value.name = "value"
  )

  # Step 4: Left join the date-time-parameter map onto the Stan draws
  merged_dt <- merge(
    pivoted_dt,
    fact_table,
    by = c("time", "parameter"),
    all.x = TRUE,
    all.y = FALSE
  )

  # Step 5: Standardize parameter names
  data.table::set(merged_dt, j = "parameter", value = factor(
    merged_dt[["parameter"]],
    levels = c("imputed_reports", "obs_reports", "R", "r"),
    labels = c("latent_cases", "obs_cases", "Rt", "growth_rate")
  ))

  data.table::setnames(
    merged_dt,
    old = c(".draw", ".chain", "date"),
    new = c("_draw", "_chain", "reference_date")
  )

  return(merged_dt)
}
