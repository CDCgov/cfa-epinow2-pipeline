# Synthetic dataset of stochastic SIR system with known Rt

A dataset from Gostic, Katelyn M., et al. "Practical considerations for
measuring the effective reproductive number, Rt." PLoS Computational
Biology 16.12 (2020): e1008409. The data are simulated from a stochastic
SEIR compartmental model.

## Usage

``` r
gostic_toy_rt
```

## Format

`gostic_toy_rt` A data frame with 301 rows and 12 columns:

- time:

  Timestep of the discrete-time stochastic SEIR simulation

- date:

  Added from the original Gostic, 2020 dataset. A date corresponding to
  the assigned `time`. Arbitrarily starts on January 1st, 2023.

- S, E, I, R:

  The realized state of the stochastic SEIR system

- dS, dEI, DIR:

  The stochastic transition between compartments

- incidence:

  The true incidence in the `I` compartment at time t

- obs_cases:

  The observed number of cases at time t from forward-convolved
  incidence.

- obs_incidence:

  Added from the original Gostic, 2020 dataset. The `incidence` column
  with added negative-binomial observation noise. Created with
  `set.seed(123456)` and the call
  `rnbinom(299, mu = gostic_toy_rt[["incidence"]], size = 10)` Useful
  for testing.

- true_r0:

  The initial R0 of the system (i.e., 2)

- true_rt:

  The known, true Rt of the epidemic system

## Source

<https://github.com/cobeylab/Rt_estimation/tree/d9d8977ba8492ac1a3b8287d2f470b313bfb9f1d>
\# nolint

## Details

This synthetic dataset has a number of desirable properties:

1.  The force of infection changes depending on the Rt, allowing for
    sudden changes in the Rt. This allows for modeling of sudden changes
    in infection dynamics, which might otherwise be difficult to
    capture. Rt estimation framework

2.  The realized Rt is known at each timepoint

3.  The dataset incorporates a simple generation interval and a
    reporting delay.

Gostic et al. benchmark the performance of a number of Rt estimation
frameworks, providing practical guidance on how to use this dataset to
evaluate Rt estimates.

In practice, we've found that the amount of observation noise in the
incidence and/or observed cases is often undesirably low for testing.
Many empirical datasets are much noisier. As a result, models built with
these settings in mind can perform poorly on this dataset or fail to
converge. To the original dataset, we add a new column with the original
incidence counts with additional observation noise: `obs_incidence`. We
manually add observation noise with
`rnbinom(299, mu = gostic_toy_rt[["obs_cases"]], size = 10)` and the
random seed 123456 and store it in the `obs_incidence` column.

## See also

Other data:
[`sir_gt_pmf`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sir_gt_pmf.md)
