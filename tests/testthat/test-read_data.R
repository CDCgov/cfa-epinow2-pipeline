test_that("Data read for one state works on happy path", {
  data_path <- test_path("data/test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  expected <- DBI::dbGetQuery(con, "
                         SELECT
                           report_date,
                           reference_date,
                           geo_value AS state_abb,
                           value AS confirm
                         FROM read_parquet(?)
                         WHERE reference_date <= '2023-01-22'",
    params = list(data_path)
  )
  DBI::dbDisconnect(con)

  actual <- read_data(data_path,
    disease = "test",
    state_abb = "test",
    report_date = "2023-10-28",
    min_reference_date = as.Date("2023-01-02"),
    max_reference_date = "2023-01-22"
  )

  expect_equal(actual, expected)
})

test_that("Data read for US overall works on happy path", {
  data_path <- test_path("data/us_overall_test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  expected <- DBI::dbGetQuery(con, "
                         SELECT
                           report_date,
                           reference_date,
                           geo_value AS state_abb,
                           value AS confirm
                         FROM read_parquet(?)
                         WHERE reference_date <= '2023-01-22'",
    params = list(data_path)
  )
  DBI::dbDisconnect(con)

  actual <- read_data(data_path,
    disease = "test",
    state_abb = "US",
    report_date = "2023-10-28",
    min_reference_date = "2023-01-02",
    max_reference_date = "2023-01-22"
  )

  expect_equal(actual, expected)
})

test_that("Reading a file that doesn't exist fails", {
  data_path <- "not_a_real_file"
  expect_error(
    read_data(data_path,
      disease = "test",
      state_abb = "not_a_real_state",
      report_date = "2023-10-28",
      min_reference_date = "2023-01-02",
      max_reference_date = "2023-01-22"
    ),
    class = "file_not_found"
  )
})

test_that("A query with no matching return fails", {
  data_path <- test_path("data/us_overall_test_data.parquet")
  expect_error(
    read_data(data_path,
      disease = "test",
      state_abb = "not_a_real_state",
      report_date = "2023-10-28",
      min_reference_date = "2023-01-02",
      max_reference_date = "2023-01-22"
    ),
    class = "empty_return"
  )
})

test_that("An invalid query throws a wrapped error", {
  # point the query at a non-parquet file
  data_path <- test_path("test-read_data.R")
  expect_error(
    read_data(data_path,
      disease = "test",
      state_abb = "not_a_real_state",
      report_date = "2023-10-28",
      min_reference_date = "2023-01-02",
      max_reference_date = "2023-01-22"
    ),
    class = "wrapped_invalid_query"
  )
})


test_that("Incomplete return throws warning", {
  data_path <- test_path("data/test_data.parquet")

  expect_warning(
    read_data(data_path,
      disease = "test",
      state_abb = "test",
      report_date = "2023-10-28",
      min_reference_date = "2022-12-01",
      max_reference_date = "2023-01-22"
    ),
    class = "incomplete_return"
  )
})
