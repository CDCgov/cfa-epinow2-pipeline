write_sample_parameters_file <- function(value,
                                         path,
                                         state,
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
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  duckdb::duckdb_register(con, "test_table", df)
  sql <- "COPY (SELECT * FROM test_table) TO ?path"
  query <- DBI::sqlInterpolate(
    DBI::ANSI(),
    sql,
    path = DBI::dbQuoteIdentifier(DBI::ANSI(), path)
  )

  # Retry a few times because DuckDB throws std::exception intermittently.
  # This seems like a bug in DuckDB coming from on.exit not always closing the
  # connection in case of error and/or the many layers of filesystem runner
  # involved in writing this temp file. Rather than think too hard about it,
  # this is the sledgehammer approach.
  attempt <- 0
  success <- NULL
  while (attempt < 5 && is.null(success)) {
    attempt <- attempt + 1
    try(success <- DBI::dbExecute(con, query))
  }

  invisible(path)
}
