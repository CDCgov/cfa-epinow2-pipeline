# Package index

## Azure

Functions which manage interaction with Azure blob

- [`download_file_from_container()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/download_file_from_container.md)
  : Download specified blobs from Blob Storage and save them in a local
  dir
- [`download_if_specified()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/download_if_specified.md)
  : Download if specified
- [`fetch_blob_container()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fetch_blob_container.md)
  : Load Azure Blob container using credentials in environment variables
- [`fetch_credential_from_env_var()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fetch_credential_from_env_var.md)
  : Fetch Azure credential from environment variable

## Data

Example data included in the package

- [`gostic_toy_rt`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/gostic_toy_rt.md)
  : Synthetic dataset of stochastic SIR system with known Rt

- [`sir_gt_pmf`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sir_gt_pmf.md)
  :

  Generation interval corresponding to the sample `gostic_toy_rt`
  dataset

## Configuration

Manages the input of all configuration settings into the `EpiNow2` model

- [`Config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Config.md)
  : Config Class
- [`Data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Data.md)
  : Data Class
- [`Interval()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Interval.md)
  : Interval Class
- [`Parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Parameters.md)
  : Parameters Class
- [`read_json_into_config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_json_into_config.md)
  : Read JSON Configuration into Config Object

## Exclusions

Functions to handle exclusion of data from models

- [`apply_exclusions()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/apply_exclusions.md)
  : Convert case counts in matching rows to NA
- [`read_exclusions()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_exclusions.md)
  : Read exclusions from an external file

## Diagnostics

Functions to calculate diagnostics from fitted `EpiNow2` model

- [`extract_diagnostics()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/extract_diagnostics.md)
  : Extract diagnostic metrics from model fit and data
- [`low_case_count_diagnostic()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/low_case_count_diagnostic.md)
  : Calculate low case count diagnostic flag
- [`low_case_count_threshold()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/low_case_count_threshold.md)
  : Determine Low Case Count Threshold Based on Pathogen

## Parameter

Functions for parameter values that are input into the `EpiNow2` model

- [`check_returned_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/check_returned_pmf.md)
  : Run validity checks on the PMF returned from the file
- [`format_generation_interval()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/opts_formatter.md)
  [`format_delay_interval()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/opts_formatter.md)
  [`format_right_truncation()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/opts_formatter.md)
  : Format PMFs for EpiNow2
- [`read_disease_parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_disease_parameters.md)
  : Read in disease process parameters from an external file or files
- [`read_interval_pmf()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_interval_pmf.md)
  : Read parameter PMF into memory

## Pipeline

Functions to orchestrate running of the pipeline including fitting the
`EpiNow2` model

- [`fit_model()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fit_model.md)
  :

  Fit an `EpiNow2` model

- [`format_stan_opts()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/format_stan_opts.md)
  : Format Stan options for input to EpiNow2

- [`orchestrate_pipeline()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/pipeline.md)
  [`execute_model_logic()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/pipeline.md)
  : Run an Rt Estimation Model Pipeline

## Read data

Functions for data that are input into the `EpiNow2` model

- [`read_data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_data.md)
  : Read in the dataset of incident case counts

## Write output

Functions for post-processing and writing `EpiNow2` model output

- [`process_samples()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sample_processing_functions.md)
  [`process_quantiles()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sample_processing_functions.md)
  : Process posterior samples from a Stan fit object (raw draws).
- [`write_model_outputs()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/write_model_outputs.md)
  : Write model outputs to specified directories
- [`write_output_dir_structure()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/write_output_dir_structure.md)
  : Create output directory structure for a given job and task.
