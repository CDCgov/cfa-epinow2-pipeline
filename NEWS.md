# CFAEpiNow2Pipeline v0.2.0

## Features
* Add output container as a new field in the config file.
* Building with ubuntu-latest and using Container App runner for all else, remove azure-cli action
* Adding exclusions documentation and Makefile support
* Add the blob storage container, if provided
* Adding make command to test Azure batch
* Updating subnet ID and pool VM to 22.04 from 20.04
* Write model diagnostics to an output file, correcting an oversight
* Refactored GH Actions container build to cfa-actions 2-step build
* Creating SOP.md to document weekly run procedures
* Allows unique job_ids for runs.
* Makefile supports either docker or podman as arguments to setup & manage containers
* Streamlined configurable container execution provided by included start.sh script
* Container App Job execution tools added including job-template.yaml file for single task and Python script for bulk tasks
* GitHub Actions workflow added to start Azure Container App Job
* Minor changes in removing unused container tags from Azure CR.

# CFAEpiNow2Pipeline v0.1.0

This initial release establishes minimal feature parity with the internal EpiNow2 Rt modeling pipeline. It adds wrappers to integrate with internal data schemas and ingest pre-estimated model parameters (i.e., generation intervals, right-truncation). It defines an output schema and adds comprehensive logging. The repository also has functionality to set up and deploy to Azure Batch.

## Features

* GitHub Actions to build Docker images on PR and merge to main, deploy Azure Batch environments off the built images, and tear down the environment (including images) on PR close.
* Comprehensive documentation of pipeline code and validation of input data, parameters, and model run configs
* Set up comprehensive logging of model runs and handle pipeline failures to preserve logs where possible
* Automatically download and upload inputs and outputs from Azure Blob Storage
* Read parameters on the same day correctly
* Re-add missing dependency in python venv
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
