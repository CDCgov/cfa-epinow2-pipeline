# Helper to create minimal valid S7 objects for config
make_gen_interval <- function() {
  GenerationInterval(path = "g.csv", blob_storage_container = NULL)
}
make_delay_interval <- function() {
  DelayInterval(path = "d.csv", blob_storage_container = NULL)
}
make_right_trunc <- function() {
  RightTruncation(path = "r.csv", blob_storage_container = NULL)
}
make_params <- function() {
  Parameters(
    as_of_date = "2024-01-01",
    generation_interval = make_gen_interval(),
    delay_interval = make_delay_interval(),
    right_truncation = make_right_trunc()
  )
}
make_data <- function() {
  Data(
    path = "foo.parquet",
    blob_storage_container = NULL,
    report_date = "2024-01-01",
    reference_date = "2024-01-01"
  )
}
make_exclusions <- function() {
  Exclusions(path = "ex.csv", blob_storage_container = NULL)
}
make_config <- function() {
  Config(
    job_id = "job1",
    task_id = "task1",
    min_reference_date = "2024-01-01",
    max_reference_date = "2024-01-31",
    report_date = "2024-01-31",
    production_date = "2024-01-31",
    disease = "COVID-19",
    geo_value = "US",
    geo_type = "state",
    seed = 42L,
    horizon = 2L,
    model = "EpiNow2",
    config_version = "1.0",
    quantile_width = c(0.5, 0.95),
    data = make_data(),
    priors = list(rt = list(mean = 1, sd = 0.5), gp = list(alpha_sd = 1)),
    parameters = make_params(),
    sampler_opts = list(
      cores = 1,
      chains = 2,
      iter_warmup = 100,
      iter_sampling = 100,
      max_treedepth = 10,
      adapt_delta = 0.8
    ),
    exclusions = make_exclusions(),
    output_container = NULL
  )
}

test_that("Exclusions class can be constructed and properties set", {
  excl <- make_exclusions()
  expect_s3_class(excl, "CFAEpiNow2Pipeline::Exclusions")
  expect_equal(S7::prop(excl, "path"), "ex.csv")
  expect_null(S7::prop(excl, "blob_storage_container"))
})

test_that("Interval and subclasses can be constructed", {
  expect_s3_class(make_gen_interval(), "CFAEpiNow2Pipeline::GenerationInterval")
  expect_s3_class(make_delay_interval(), "CFAEpiNow2Pipeline::DelayInterval")
  expect_s3_class(make_right_trunc(), "CFAEpiNow2Pipeline::RightTruncation")
  intv <- Interval(path = "int.csv", blob_storage_container = NULL)
  expect_s3_class(intv, "CFAEpiNow2Pipeline::Interval")
})

test_that("Parameters class can be constructed", {
  params <- make_params()
  expect_s3_class(params, "CFAEpiNow2Pipeline::Parameters")
  expect_equal(S7::prop(params, "as_of_date"), "2024-01-01")
  expect_s3_class(
    S7::prop(params, "generation_interval"),
    "CFAEpiNow2Pipeline::GenerationInterval"
  )
})

test_that("Data class can be constructed", {
  d <- make_data()
  expect_s3_class(d, "CFAEpiNow2Pipeline::Data")
  expect_equal(S7::prop(d, "path"), "foo.parquet")
})

test_that("Config class can be constructed with nested objects", {
  cfg <- make_config()
  expect_s3_class(cfg, "CFAEpiNow2Pipeline::Config")
  expect_equal(S7::prop(cfg, "job_id"), "job1")
  expect_s3_class(S7::prop(cfg, "data"), "CFAEpiNow2Pipeline::Data")
})

test_that("read_json_into_config reads and constructs Config object", {
  # Create a minimal config as a list, matching make_config()
  gen <- list(path = "g.csv", blob_storage_container = NULL)
  del <- list(path = "d.csv", blob_storage_container = NULL)
  rt <- list(path = "r.csv", blob_storage_container = NULL)
  params <- list(
    as_of_date = "2024-01-01",
    generation_interval = gen,
    delay_interval = del,
    right_truncation = rt
  )
  excl <- list(path = "ex.csv", blob_storage_container = NULL)
  d <- list(
    path = "foo.parquet",
    blob_storage_container = NULL,
    report_date = "2024-01-01",
    reference_date = "2024-01-01"
  )
  cfg_list <- list(
    job_id = "job1",
    task_id = "task1",
    min_reference_date = "2024-01-01",
    max_reference_date = "2024-01-31",
    report_date = "2024-01-31",
    production_date = "2024-01-31",
    disease = "COVID-19",
    geo_value = "US",
    geo_type = "state",
    seed = 42L,
    horizon = 2L,
    model = "EpiNow2",
    config_version = "1.0",
    quantile_width = c(0.5, 0.95),
    data = d,
    priors = list(rt = list(mean = 1, sd = 0.5), gp = list(alpha_sd = 1)),
    parameters = params,
    sampler_opts = list(
      cores = 1,
      chains = 2,
      iter_warmup = 100,
      iter_sampling = 100,
      max_treedepth = 10,
      adapt_delta = 0.8
    ),
    exclusions = excl,
    output_container = NULL
  )
  tf <- tempfile(fileext = ".json")
  jsonlite::write_json(cfg_list, tf, auto_unbox = TRUE)
  cfg <- read_json_into_config(tf, optional_fields = c("output_container"))
  expect_s3_class(cfg, "CFAEpiNow2Pipeline::Config")
  expect_equal(S7::prop(cfg, "job_id"), "job1")
  expect_s3_class(S7::prop(cfg, "data"), "CFAEpiNow2Pipeline::Data")
  expect_s3_class(S7::prop(cfg, "parameters"), "CFAEpiNow2Pipeline::Parameters")
  expect_s3_class(S7::prop(cfg, "exclusions"), "CFAEpiNow2Pipeline::Exclusions")
  unlink(tf)
})
