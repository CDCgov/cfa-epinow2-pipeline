# CFAEpiNow2Pipeline (development version)

* Add functionality to pass `job_id` to config generation
* Build Batch pool on merge to main
* Install suggests into base first-step image
* Fixed issue with running `make pull` while on main.
* Improved documentation of `format_stan_opts`
* Drop old pre-commit action in favor of CI service
* Improve documentation of `fetch_blob_container`
* Add warning and autofix for improperly specified GI PMF
* Read parameters on the same day correctly
* Re-add missing dependency in python venv
* Don't emit DEBUG level logs from EpiNow2
* Clean up Azure Batch pools on PR close
* Added function families to documentation
* Renamed file containing diagnostic functions
* Change formatting of metadata values to be atomic.
* Add `blob_storage_container` as a field to the metadata.
* Use empty string for paths when non-existant.
* Add function families
* Populated the default values of the metadata to be saved.
* Working upload/download from ABS
* Working Azure upload/download
* Creating a Config class to make syncing configuration differences easier.
* Add a JSON reader for the Config class.
* Use the Config class throughout the pipeline.
* Adding a script to setup the Azure Batch Pool to link the container.
* Adding new action to post a comment on PRs with a link to the rendered pkgdown site.
* Add inner pipeline responsible for running the model fitting process
* Re-organizing GitHub workflows.
* Checks if batch pool exists. Pools are named after branches. Also allows for deletion via commit message.
* Merges workflows 1 and 2 into a single workflow.
* Now uses CFA Azure ACR and images in the workflows and Dockerfiles, etc.
* Added Docker image with all the requirements to build the package.
* Bump pre-commit hooks
* Fix bug in warning message for incomplete data read (h/t @damonbayer)
* Fit EpiNow2 model using params and fixed seed
* Removed `.vscode` folder from repo
* Read and apply exclusions to case data
* Data reader and processor
* Parameters read from local parquet file or files
* Additional CI bugs squashed
* Bug fixed in the updated, faster pre-commit checks
* Updated, faster pre-commit checks
* Azure Blob file download utilities
* CI running on Ubuntu only & working pkgdown deploy to Github Pages
* Initial R package with checks running in CI
* Updated DESCRIPTION and added guidelines for package authorship
* Set up README with explanation of purpose and scope
* Removed `add.R` placeholder
* Fix bugs in date casting caused by DuckDB v1.1.1 release
* Drop unused pre-commit hooks
* Write outputs to file
* Specify number of samples draws with `iter_sampling`
* Fix NOTE from missing variable name used with NSE
* Read from new parameters schema
* Fix bugs in parameter reading from local test run
* Fix bugs in parameter reading from local test run
* Add "US" as an option in `state_abb`
