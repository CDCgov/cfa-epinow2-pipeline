#' Synthetic dataset of stochastic SIR system with known Rt
#'
#' A dataset from Gostic, Katelyn M., et al. "Practical considerations for
#' measuring the effective reproductive number, Rt." PLoS Computational Biology
#' 16.12 (2020): e1008409. The data are simulated from a stochastic SEIR
#' compartmental model.
#'
#' This synthetic dataset has a number of desirable properties:
#'
#' 1. The force of infection changes depending on the Rt, allowing for sudden
#' changes in the Rt. This allows for modeling of sudden changes in infection
#' dynamics, which might otherwise be difficult to capture. Rt estimation
#' framework
#'
#' 2. The realized Rt is known at each timepoint
#'
#' 3. The dataset incorporates a simple generation interval and a reporting
#' delay.
#'
#' Gostic et al. benchmark the performance of a number of Rt estimation
#' frameworks, providing practical guidance on how to use this dataset to
#' evaluate Rt estimates.
#'
#' In practice, we've found that the amount of observation noise in the
#' incidence and/or observed cases is often undesirably low for testing. Many
#' empirical datasets are much noisier. As a result, models built with these
#' settings in mind can perform poorly on this dataset or fail to converge. To
#' the original dataset, we add a new column with the original incidence counts
#' with additional observation noise: `obs_incidence`. We manually add
#' observation noise with `rnbinom(299, mu = gostic_toy_rt[["obs_cases"]], size
#' = 10)` and the random seed 123456 and store it in the `obs_incidence` column.
#'
#' @name gostic_toy_rt
#' @format `gostic_toy_rt` A data frame with 301 rows and 12 columns:
#' \describe{
#'    \item{time}{Timestep of the discrete-time stochastic SEIR simulation}
#'    \item{date}{Added from the original Gostic, 2020 dataset. A date
#'    corresponding to the assigned `time`. Arbitrarily starts on January 1st,
#'    2023.}
#'    \item{S, E, I, R}{The realized state of the stochastic SEIR system}
#'    \item{dS, dEI, DIR}{The stochastic transition between compartments}
#'    \item{incidence}{The true incidence in the `I` compartment at time t}
#'    \item{obs_cases}{The observed number of cases at time t from
#'    forward-convolved incidence.}
#'    \item{obs_incidence}{Added from the original Gostic, 2020 dataset. The
#'     `incidence` column with added negative-binomial observation noise.
#'     Created with `set.seed(123456)` and the call
#'      `rnbinom(299, mu = gostic_toy_rt[["incidence"]], size = 10)` Useful for
#'       testing.}
#'    \item{true_r0}{The initial R0 of the system (i.e., 2)}
#'    \item{true_rt}{The known, true Rt of the epidemic system}
#' }
#' @source
#' <https://github.com/cobeylab/Rt_estimation/tree/d9d8977ba8492ac1a3b8287d2f470b313bfb9f1d> # nolint
#' @family data
"gostic_toy_rt"

#' Generation interval corresponding to the sample `gostic_toy_rt` dataset
#'
#' Gostic et al., 2020 simulates data from a stochastic SEIR model. Residence
#' time in both the E and the I compartments is exponentially distributed, with
#' a mean of 4 days (or a rate/inverse-scale of 1/4). These residence times
#' imply a gamma-distributed generation time distribution with a shape of 2 and
#' a rate of 1/4. We convert the continuous gamma distribution into a PMF to use
#' with `{RtGam}`.
#'
#' From this parametric specification, we produce a double-censored,
#' left-truncated probability mass function of the generation interval
#' distribution. We produce the PMF using `{epinowcast}`'s
#' `simulate_double_censored_pmf()` with version 0.3.0. See
#' https://doi.org/10.1101/2024.01.12.24301247 for more information on
#' double-censoring biases and corrections.
#'
#' We correct the output from `simulate_double_censored_pmf()` to make it
#' appropriate to use with `{EpiNow2}`. The function returns a numeric vector,
#' with the position of the element corresponding to one day more than the
#' length of the delay and value corresponding to the amount of discretized
#' probability density in the bin. The vector does not necessarily sum to one.
#' We drop the first element of the vector, which corresponds to a zero-day
#' delay. The renewal framework, which underpins our model does not account for
#' zero-day delays. We renormalize the left-truncated vector to sum to one so
#' that it's a proper PMF.
#'
#' @name sir_gt_pmf
#' @format `sir_gt_pmf` A numeric vector of length 26 that sums to one within
#'   numerical tolerance
#' @family data
"sir_gt_pmf"
