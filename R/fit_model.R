#' Fit an EpiNow2 model
#'
#' @param data As returned from [CFAEpiNow2Pipeline::read_data()]
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
    list(
      mean = priors[["rt"]][["mean"]],
      sd = priors[["rt"]][["sd"]]
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

  # Stan sampler ------------------------------------------------------------
  stan <- EpiNow2::stan_opts(
    cores = sampler_opts[["cores"]],
    chains = sampler_opts[["chains"]],
    # NOTE: seed gets used twice -- as the seed passed here to the Stan sampler
    # and below as the R PRNG seed for EpiNow2 initialization
    seed = seed,
    warmup = sampler_opts[["iter_warmup"]],
    samples = sampler_opts[["iter_samples"]],
    control = list(
      adapt_delta = sampler_opts[["adapt_delta"]],
      max_treedepth = sampler_opts[["max_treedepth"]]
    )
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
        verbose = interactive()
      )
    }),
    # Downgrade model erroring out to a warning so we can catch and return
    error = function(cnd) {
      cli::cli_warn(
        "Model fitting failed. Returning NA.",
        parent = cnd,
        class = "failing_fit"
      )
      NA
    }
  )
}

#' Format PMFs for EpiNow2
#'
#' Format PMFs for use by EpiNow2. Delays or right truncation are optional and
#' can be skipped by passing an NA.
#'
#' @param pmf As returned from [CFAEpiNow2Pipeline::read_disease_parameters()].
#'   A PMF vector or an NA, if not applying the PMF to the model fit.
#'
#' @return An EpiNow2::*_opts() formatted object or NA with a message
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
  if (rlang::is_na(pmf) || rlang::is_null(pmf)) {
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

    cli::cli_abort(
      c(
        "Right truncation PMF longer than the data",
        "PMF length: {.val {length(pmf)}}",
        "Data length: {.val {nrow(data)}}",
        "PMF can only be up to length as the data"
      ),
      class = "right_trunc_too_long"
    )
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
