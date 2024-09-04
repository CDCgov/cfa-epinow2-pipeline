load("data/gostic_toy_rt.rda")
gostic_toy_rt[["reference_date"]] <- as.Date("2023-01-01") +
  gostic_toy_rt[["time"]]
gostic_toy_rt[["report_date"]] <- max(gostic_toy_rt[["reference_date"]]) + 1

con <- DBI::dbConnect(duckdb::duckdb())

duckdb::duckdb_register(con, "gostic_toy_rt", gostic_toy_rt)
dbExecute(con, "
COPY (
  SELECT
    obs_incidence AS value,
    'test' AS geo_value,
    'test' AS disease,
    'count_ed_visits' AS metric,
    reference_date,
    report_date
  FROM gostic_toy_rt
  ORDER BY reference_date
  LIMIT 150
) TO
 'tests/testthat/data/test_data.parquet' (FORMAT PARQUET)
 ;
            ")

# Repeat for US overall
dbExecute(con, "
COPY (
  SELECT
    obs_incidence AS value,
    'US' AS geo_value,
    'test' AS disease,
    'count_ed_visits' AS metric,
    reference_date,
    report_date
  FROM gostic_toy_rt
  ORDER BY reference_date
  LIMIT 150
) TO
 'tests/testthat/data/us_overall_test_data.parquet' (FORMAT PARQUET)
 ;
            ")
dbDisconnect(con)
