library(cmdstanr)
library(rstan)
library(bayesplot)
library(ggplot2)
library(dplyr)
library(pak)
library(data.table)

# finds DESCRIPTION at path = "." and installs from there
pak::local_install_dev_deps()

schools_dat <- list(
  J = 8, 
  y = c(28,  8, -3,  7, -1,  1, 18, 12),
  sigma = c(15, 10, 16, 11,  9, 11, 10, 18)
)

## RSTAN
schools_mod_cp <- stan_model("schools_mod_cp.stan")
fit_cp <- rstan::sampling(schools_mod_cp, data = schools_dat, seed = 803214055, control = list(adapt_delta = 0.9))

## CMDSTANR
mod <- cmdstan_model("schools_mod_cp.stan")

np_cp <- bayesplots::nuts_params(fit_cp)
# assign to an object so we can reuse later
scatter_theta_cp <- mcmc_scatter(
  posterior_cp, 
  pars = c("theta[1]", "tau"), 
  transform = list(tau = "log"), # can abbrev. 'transformations'
  np = np_cp, 
  size = 1
)

# this morphology is similar "Neal's Funnel"
scatter_theta_cp

scatter_eta_ncp <- mcmc_scatter(
  posterior_ncp, 
  pars = c("eta[1]", "tau"), 
  transform = list(tau = "log"), 
  np = np_ncp, 
  size = 1
)
scatter_eta_ncp

# mcmc pairs plot
mcmc_pairs(posterior_cp, np = np_cp, pars = c("mu","tau","theta[1]"),
           off_diag_args = list(size = 0.75))

# A function we'll use several times to plot comparisons of the centered 
# parameterization (cp) and the non-centered parameterization (ncp). See
# help("bayesplot_grid") for details on the bayesplot_grid function used here.
compare_cp_ncp <- function(cp_plot, ncp_plot, ncol = 2, ...) {
  bayesplot_grid(
    cp_plot, ncp_plot, 
    grid_args = list(ncol = ncol),
    subtitles = c("Centered parameterization", 
                  "Non-centered parameterization"),
    ...
  )
}


scatter_theta_ncp <- mcmc_scatter(
  posterior_ncp, 
  pars = c("theta[1]", "tau"), 
  transform = list(tau = "log"), 
  np = np_ncp, 
  size = 1
)

compare_cp_ncp(scatter_theta_cp, scatter_theta_ncp, ylim = c(-8, 4))

# time plot to show evolution of chains over time
color_scheme_set("mix-brightblue-gray")

# tau parameter is variance
mcmc_trace(posterior_cp, pars = "tau", np = np_cp) + 
  xlab("Post-warmup iteration")

mcmc_trace(posterior_cp, pars = "tau", np = np_cp, window = c(300, 500)) + 
  xlab("Post-warmup iteration")

color_scheme_set("red")
mcmc_nuts_divergence(np_cp, lp_cp)

# manually get the divergences in np_cp
divergence_nums <- np_cp %>% 
  filter(Parameter == "divergent__" & Value == 1) %>% 
  pull(Iteration)

divergent_accept_stats <- 
  np_cp %>% 
  filter(Iteration %in% divergence_nums & Parameter == "accept_stat__") 

# higher delta means smaller step-size and more 'nuanced' exploration
fit_cp_2 <- sampling(schools_mod_cp, data = schools_dat,
                     control = list(adapt_delta = 0.999), seed = 978245244)

fit_cp_bad_rhat <- sampling(schools_mod_cp, data = schools_dat, 
                            iter = 50, init_r = 10, seed = 671254821)

rhats <- bayesplot::rhat(fit_cp_bad_rhat)
print(rhats)

color_scheme_set("brightblue") # see help("color_scheme_set")
mcmc_rhat(rhats)

ratios_cp <- bayesplot::neff_ratio(fit_cp)
print(ratios_cp)

# EpiNow2/R/extract.R
CrIs = c(0.2, 0.5, 0.9)
CrIs <- sort(CrIs)
sym_CrIs <- c(0.5, 0.5 - CrIs / 2, 0.5 + CrIs / 2)

args <- list(object = fit_cp, probs = sym_CrIs)
summary <- do.call(rstan::summary, args)

cmdstanr::set_cmdstan_path()
# what does inherits(fit_cp) return?!
inherits(fit_cp, "stanfit")
inherits(fit_cp, "CmdStanMCMC")

var_names <- TRUE
summary <- data.table::as.data.table(summary$summary,
                                     keep.rownames = ifelse(var_names,
                                                            "variable",
                                                            FALSE))

summary <- summary[, c("n_eff", "Rhat") := NULL]
