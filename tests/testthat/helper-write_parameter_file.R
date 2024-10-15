write_sample_parameters_file <- function(value,
                                         path,
                                         param,
                                         disease,
                                         parameter,
                                         start_date,
                                         end_date,
                                         geo_value,
                                         reference_date) {
  Sys.sleep(0.05)
  df <- data.frame(
    start_date = as.Date(start_date),
    disease = disease,
    parameter = parameter,
    end_date = end_date,
    geo_value = geo_value,
    value = I(list(value)),
    reference_date = reference_date
  )

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con))

  duckdb::duckdb_register(con, "test_table", df)
  # This is bad practice but `dbBind()` doesn't allow us to parameterize COPY
  # ... TO.  The danger of doing it this way seems quite low risk because it's
  # an ephemeral from a temporary in-memory DB. There's no actual database to
  # guard against a SQL injection attack.
  query <- paste0("COPY (SELECT * FROM test_table) TO '", path, "'")
  DBI::dbExecute(con, query)

  invisible(path)
}
