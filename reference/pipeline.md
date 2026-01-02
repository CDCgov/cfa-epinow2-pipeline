# Run an Rt Estimation Model Pipeline

This function runs a complete pipeline for fitting an Rt estimation
model, using the `EpiNow2` model, based on a configuration file. The
pipeline processes the model, logs its progress, and handles errors by
logging warnings and setting the pipeline status. Output and logs are
written to the specified directories. Additionally, support for
uploading logs and outputs to a blob storage container is planned.

## Usage

``` r
orchestrate_pipeline(
  config_path,
  config_container = NULL,
  input_dir = "/input",
  output_dir = "/output"
)

execute_model_logic(config, input_dir, output_dir)
```

## Arguments

- config_path:

  A string specifying the file path to the JSON configuration file.

- config_container:

  Optional. The name of the blob storage container from which the config
  file will be downloaded.

- input_dir:

  A string specifying the directory to read inputs from. If passing
  storage containers, this is where the files will be downloaded to.

- output_dir:

  A string specifying the directory where output, logs, and other
  pipeline artifacts will be saved. Defaults to the root directory
  ("/").

- config:

  A Config object containing configuration settings for the pipeline,
  including paths to data, exclusions, disease parameters, model
  settings, and other necessary inputs.

## Value

The function returns a boolean, TRUE For pipeline success and FALSE
otherwise. It writes the files: directory will contain the following
files:

- Model RDS file (`model.rds`)

- Sample output in Parquet format (`<task_id>.parquet` in the `samples/`
  directory)

- Summary output in Parquet format (`<task_id>.parquet` in the
  `summaries/` directory)

- Log file (`logs.txt`) in the task directory

Returns `TRUE` on success. Errors are caught by the outer pipeline logic
and logged accordingly.

## Details

The function reads the configuration from a JSON file and uses this to
set up the job and task identifiers. It creates an output directory
structure based on these IDs and starts logging the process in a file.
The main pipeline process is handled by `execute_model_logic()`, with
errors caught and logged as warnings. The function will log the success
or failure of the run.

Logs are written to a file in the output directory, and console output
is also mirrored in this log file. Error handling is in place to capture
any issues during the pipeline execution and ensure they are logged
appropriately.

During the execution of the pipeline, the following output files are
expected to be generated:

- **Model Output**: An RDS file of the fitted model is saved in the
  task-specific directory (`model.rds`).

- **Samples**: Parquet files containing the model's sample outputs are
  saved in a `samples` subdirectory, named using the `task_id` (e.g.,
  `task_id.parquet`).

- **Summaries**: Parquet files summarizing the model's results are saved
  in a `summaries` subdirectory, also named using the `task_id` (e.g.,
  `task_id.parquet`).

- **Logs**: A `logs.txt` file is generated in the task directory,
  capturing both console and error messages.

The output directory structure will follow this format:

    <output_dir>/
    └── <job_id>/
        ├── samples/
        │   └── <task_id>.parquet
        ├── summaries/
        │   └── <task_id>.parquet
        └── tasks/
            └── <task_id>/
                ├── model.rds
                └── logs.txt

This function performs the core model fitting process within the Rt
estimation pipeline, including reading data, applying exclusions,
fitting the model, and writing outputs such as model samples, summaries,
and logs.

## See also

Other pipeline:
[`fit_model()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fit_model.md),
[`format_stan_opts()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/format_stan_opts.md)

Other pipeline:
[`fit_model()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fit_model.md),
[`format_stan_opts()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/format_stan_opts.md)
