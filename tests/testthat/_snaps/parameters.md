# NULL `reference_date` prints in output

    Code
      pmf <- CFAEpiNow2Pipeline:::check_returned_pmf(pmf_df = pmf_df, parameter = parameter,
        disease = disease, as_of_date = as_of_date, geo_value = geo_value,
        report_date = report_date, path = path)
    Message
      Using right-truncation estimate for date "NA"
      Queried last available estimate from "2023-01-15" or earlier
      Subject to parameters available as of "2023-01-01"

# GI with nonzero first element throws warning

    Code
      fixed <- format_generation_interval(pmf)
    Condition
      Warning:
      First element of GI PMF is not 0
      x Renewal equation assumes no same-day transmission
      ! Auto-fixing by prepending a 0. Consider left-truncating instead?
      > New PMF: 0, 0.0478174439101374, 0.0760979101401105, 0.0895274782138445, 0.0932924246386663, 0.0910112663029942, 0.0851745750679048, 0.0774669281292755, 0.0690016173717581, 0.0604909602604732, 0.0523692179334625, 0.0448807538374044, 0.0381427961649933, 0.0321897258102522, 0.0270039920145235, 0.0225374046222701, 0.0187255476449921, 0.0154973154449738, ..., 0.00308673656614286, and 0.00250027133286461

