#' Fit an EpiNow2 model
#'
#' @param data, in the format returned by [CFAEpiNow2Pipeline::read_data()]
#' @param parameters As returned from
#'   [CFAEpiNow2Pipeline::read_disease_parameters()]
#' @param seed The random seed, used for both initialization by EpiNow2 in R and
#'   sampling in Stan
#' @param horizon The number of days, as an integer, to forecast
#' @param priors A list of lists. The first level should contain the key `rt`
#'   with elements `mean` and `sd` and the key `gp` with element `alpha_sd`.
#' @param sampler_opts A list. The Stan sampler options to be passed through
#'   EpiNow2. It has required keys: `cores`, `chains`, `iter_warmup`,
#'   `iter_sampling`, `max_treedepth`, and `adapt_delta`.
#'
#' @return A fitted model object of class `epinow` or, if model fitting fails,
#'   an NA is returned with a warning
#' @family pipeline
#' @export
fit_model <- function(
    data,
    parameters,
    seed,
    horizon,
    priors,
    sampler_opts) {
  # Priors ------------------------------------------------------------------
  rt <- EpiNow2::rt_opts(
    prior = EpiNow2::dist_spec(
      params_mean = priors[["rt"]][["mean"]],
      params_sd = priors[["rt"]][["sd"]]
    )
  )
  gp <- EpiNow2::gp_opts(
    alpha_sd = priors[["gp"]][["alpha_sd"]]
  )

  # Distributions -----------------------------------------------------------
  generation_time <- format_generation_interval(
    parameters[["generation_interval"]]
  )
  delays <- format_delay_interval(
    parameters[["delay_interval"]]
  )
  truncation <- format_right_truncation(
    parameters[["right_truncation"]],
    data
  )
  stan <- format_stan_opts(
    sampler_opts, seed
  )
  df <- data.frame(
    confirm = data[["confirm"]],
    date = as.Date(data[["reference_date"]])
  )
  rlang::try_fetch(
    withr::with_seed(seed, {
      EpiNow2::epinow(
        df,
        generation_time = generation_time,
        delays = delays,
        truncation = truncation,
        horizon = horizon,
        rt = rt,
        gp = gp,
        stan = stan,
        verbose = FALSE,
        # Dump logs to console to be caught by pipeline's logging instead of
        # EpiNow2's default through futile.logger
        logs = EpiNow2::setup_logging(
          threshold = "INFO",
          file = NULL,
          mirror_to_console = TRUE,
          name = "EpiNow2"
        ),
        filter_leading_zeros = FALSE,
      )
    }),
    error = function(cnd) {
      cli::cli_abort(
        "Call to EpiNow2::epinow() failed with an error",
        parent = cnd,
        class = "failing_fit"
      )
    }
  )
}

#' Format Stan options for input to EpiNow2
#'
#' Format configuration `sampler_opts` for input to EpiNow2 via a call to
#' [EpiNow2::stan_opts()].
#'
#' @inheritParams fit_model
#' @param seed A stochastic seed passed here to the Stan sampler and as the R
#' PRNG seed for EpiNow2 initialization
#'
#' @return A `stan_opts` object of arguments
#'
#' @family pipeline
#' @export
format_stan_opts <- function(sampler_opts, seed) {
  expected_stan_args <- c(
    "cores",
    "chains",
    "iter_warmup",
    "iter_sampling",
    "adapt_delta",
    "max_treedepth"
  )
  missing_keys <- !(expected_stan_args %in% names(sampler_opts))
  missing_elements <- rlang::is_null(sampler_opts[expected_stan_args])
  if (any(missing_keys) || any(missing_elements)) {
    cli::cli_abort(c(
      "Missing expected keys/values in {.val sampler_opts}",
      "Missing keys: {.val {expected_stan_args[missing_keys]}}",
      "Missing values: {.val {expected_stan_args[missing_elements]}}"
    ))
  }
  EpiNow2::stan_opts(
    backend = "cmdstanr",
    cores = sampler_opts[["cores"]],
    chains = sampler_opts[["chains"]],
    seed = seed,
    warmup = sampler_opts[["iter_warmup"]],
    samples = sampler_opts[["iter_sampling"]],
    control = list(
      adapt_delta = sampler_opts[["adapt_delta"]],
      max_treedepth = sampler_opts[["max_treedepth"]]
    )
  )
}
