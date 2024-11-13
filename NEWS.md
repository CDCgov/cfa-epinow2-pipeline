# CFAEpiNow2Pipeline (development version)

* Adding a script to setup the Azure Batch Pool to link the container.
* Adding new action to post a comment on PRs with a link to the rendered pkgdown site.
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
