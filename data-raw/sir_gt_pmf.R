# E and I compartments both with exponentially distributed residence times
# with a mean of 4 days.
shape <- 2
rate <- 1 / 4

sir_gt_pmf <- dpcens(0:26,
  pgamma,
  shape = shape,
  rate = rate,
  D = 27
) # v0.4.0

# Drop first element because GI can't have same-day transmission
# and replace with a zero
sir_gt_pmf <- c(0, sir_gt_pmf[2:27])

# Renormalize to a proper PMF
while (abs(sum(sir_gt_pmf) - 1) > 1e-10) {
  sir_gt_pmf <- sir_gt_pmf / sum(sir_gt_pmf)
}

dpcens <- function(
    x,
    pdist,
    pwindow = 1,
    swindow = 1,
    D = Inf,
    dprimary = stats::dunif,
    dprimary_args = list(),
    log = FALSE,
    pdist_name = lifecycle::deprecated(),
    dprimary_name = lifecycle::deprecated(),
    ...) {
  nms <- .name_deprecation(pdist_name, dprimary_name)
  if (!is.null(nms$pdist)) {
    pdist <- add_name_attribute(pdist, nms$pdist)
  }
  if (!is.null(nms$dprimary)) {
    dprimary <- add_name_attribute(dprimary, nms$dprimary)
  }

  check_pdist(pdist, D, ...)
  check_dprimary(dprimary, pwindow, dprimary_args)

  if (max(x + swindow) > D) {
    stop(
      "Upper truncation point is greater than D. It is ",
      max(x + swindow),
      " and D is ",
      D,
      ". Resolve this by increasing D to be the maximum",
      " of x + swindow.",
      call. = FALSE
    )
  }

  # Compute CDFs for all unique points
  unique_points <- sort(unique(c(x, x + swindow)))
  unique_points <- unique_points[unique_points > 0]
  if (length(unique_points) == 0) {
    return(rep(0, length(x)))
  }

  cdfs <- pprimarycensored(
    unique_points,
    pdist,
    pwindow,
    Inf,
    dprimary,
    dprimary_args,
    ...
  )

  # Create a lookup table for CDFs
  cdf_lookup <- stats::setNames(cdfs, as.character(unique_points))

  result <- vapply(
    x,
    function(d) {
      if (d < 0) {
        return(0) # Return 0 for negative delays
      } else if (d == 0) {
        # Special case for d = 0
        cdf_upper <- cdf_lookup[as.character(swindow)]
        return(cdf_upper)
      } else {
        cdf_upper <- cdf_lookup[as.character(d + swindow)]
        cdf_lower <- cdf_lookup[as.character(d)]
        return(cdf_upper - cdf_lower)
      }
    },
    numeric(1)
  )

  if (is.finite(D)) {
    if (max(unique_points) == D) {
      cdf_d <- max(cdfs)
    } else {
      cdf_d <- pprimarycensored(
        D,
        pdist,
        pwindow,
        Inf,
        dprimary,
        dprimary_args,
        ...
      )
    }
    result <- result / cdf_d
  }

  if (log) {
    return(log(result))
  } else {
    return(result)
  }
}

usethis::use_data(sir_gt_pmf, overwrite = TRUE)
