# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

suppress_ess_warning <- function(.f, pattern = NULL) {
  if (is.null(pattern)) {
    pattern <- "The ESS has been capped to avoid unstable"
  }
  force(.f) # ensure .f is evaluated once
  function(...) {
    withCallingHandlers(
      .f(...),
      warning = function(w) {
        if (grepl(pattern, conditionMessage(w))) {
          invokeRestart("muffleWarning")
        }
      }
    )
  }
}

orch_pipeline_clean <- suppress_ess_warning(orchestrate_pipeline)
fit_model_clean     <- suppress_ess_warning(fit_model)

library(testthat)
library(CFAEpiNow2Pipeline)

test_check("CFAEpiNow2Pipeline")
