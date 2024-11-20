write_exclusions <- function() {
  exclusions <- data.frame(
    reference_date = as.Date("2023-01-07"),
    report_date = as.Date("2023-10-28"),
    state_abb = "test",
    disease = "test"
  )
  con <- DBI::dbConnect(duckdb::duckdb())
  duckdb::duckdb_register(con, "exclusions", exclusions)
  DBI::dbExecute(con, "COPY (SELECT * FROM exclusions)
                     TO 'data/test_exclusions.csv'")
}
