# NULL `reference_date` prints in output

    Code
      pmf <- check_returned_pmf(pmf_df = pmf_df, parameter = parameter, disease = disease,
        as_of_date = as_of_date, group = group, report_date = report_date, path = path)
    Message
      Using right-truncation estimate for date "NA"
      Queried last available estimate from "2023-01-15" or earlier
      Subject to parameters available as of "2023-01-01"

