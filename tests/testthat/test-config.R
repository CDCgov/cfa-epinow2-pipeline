# Unit tests for config classes and read_json_into_config

test_that("Config S7 classes can be constructed and validate fields", {
  data <- Data(
    path = "data/test_data.parquet",
    blob_storage_container = NULL,
    report_date = "2023-01-01",
    reference_date = "2022-12-01"
  )
  exclusions <- Exclusions(path = "data/test_exclusions.csv", blob_storage_container = NULL)
  gi <- GenerationInterval(path = "data/gi.csv", blob_storage_container = NULL)
  di <- DelayInterval(path = "data/di.csv", blob_storage_container = NULL)
  rt <- RightTruncation(path = "data/rt.csv", blob_storage_container = NULL)
  params <- Parameters(
    as_of_date = "2023-01-01",
    generation_interval = gi,
    delay_interval = di,
    right_truncation = rt
  )
  config <- Config(
    job_id = "job1",
    task_id = "task1",
    min_reference_date = "2022-12-01",
    max_reference_date = "2023-01-01",
    report_date = "2023-01-01",
    production_date = "2023-01-01",
    disease = "COVID-19",
    geo_value = "CA",
    geo_type = "state",
    seed = 42L,
    horizon = 7L,
    model = "EpiNow2",
    config_version = "1.0",
    quantile_width = c(0.5, 0.95),
    data = data,
    priors = list(rt = list(mean = 1, sd = 0.2), gp = list(alpha_sd = 0.05)),
    parameters = params,
    sampler_opts = list(cores = 1, chains = 1, iter_warmup = 10, iter_sampling = 10, max_treedepth = 10, adapt_delta = 0.8),
    exclusions = exclusions,
    output_container = NULL
  )
  expect_s3_class(config, "Config")
  expect_equal(config@job_id, "job1")
  expect_equal(config@data@path, "data/test_data.parquet")
  expect_equal(config@parameters@generation_interval@path, "data/gi.csv")
})

test_that("read_json_into_config returns Config object for valid input", {
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config <- read_json_into_config(config_path, c("exclusions", "output_container"))
  expect_s3_class(config, "Config")
  expect_true(!is.null(config@job_id))
  expect_true(!is.null(config@parameters@generation_interval))
})

test_that("read_json_into_config errors on missing required fields", {
  # Create a minimal invalid config file
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(list(job_id = "job1"), tmp)
  expect_error(
    read_json_into_config(tmp, c("exclusions", "output_container")),
    class = "cli_error"
  )
})

test_that("read_json_into_config warns for missing optional fields", {
  # Remove an optional field from a valid config
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config_list <- jsonlite::read_json(config_path)
  config_list$output_container <- NULL
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(config_list, tmp, auto_unbox = TRUE)
  expect_message(
    read_json_into_config(tmp, c("exclusions", "output_container")),
    regexp = "Optional field"
  )
})
