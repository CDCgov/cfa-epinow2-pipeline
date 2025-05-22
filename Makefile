REGISTRY=cfaprdbatchcr.azurecr.io/
IMAGE_NAME=cfa-epinow2-pipeline
BRANCH=$(shell git branch --show-current)
CONFIG_CONTAINER=rt-epinow2-config
CNTR_MGR=docker
ifeq ($(BRANCH), main)
TAG=latest
else
TAG=$(BRANCH)
endif

CONFIG=test.json
POOL="cfa-epinow2-$(TAG)"
TIMESTAMP:=$(shell  date -u +"%Y%m%d_%H%M%S")
JOB:=Rt-estimation-$(TIMESTAMP)

# The report date to use, in ISO format (YYYY-MM-DD). Default is today
REPORT_DATE?=$(shell date -u +%F)

.DEFAULT_GOAL := help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

pull: ## Login to Azure Container Registry and pull the latest container image
	az acr login --name 'cfaprdbatchcr'
	$(CNTR_MGR) pull $(REGISTRY)$(IMAGE_NAME):$(TAG)

build: ## Build the Docker image with given tag
	$(CNTR_MGR) build -t $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		--build-arg TAG=$(TAG) -f Dockerfile .

tag: ## Tags the local image for pushing to the container registry
	$(CNTR_MGR) tag $(IMAGE_NAME):$(TAG) $(REGISTRY)$(IMAGE_NAME):$(TAG)

config: ## Generates a configuration file for running the model
	uv run azure/generate_configs.py \
		--disease="COVID-19,Influenza" \
		--state=all \
		--output-container=nssp-rt-v2 \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

rerun-config: ## Generate a configuration file to rerun a previous model
	uv run azure/generate_rerun_configs.py \
		--output-container=nssp-rt-v2 \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

backfill-config-and-run: ## Generate backfill configs, and run in batch
	# More and other options are available, see the script for details if these
	# basic arguments are not sufficient. It is expected that backfill configs
	# will be relatively different from one another, so it is likely these arguments
	# will be different for each backfill.
	# To see those options, run `uv run azure/backfill_generate_and_run.py --help`
	uv run --env-file .env azure/backfill_generate_and_run.py \
		--state=all \
		--disease="COVID-19,Influenza" \
		--str-report-dates="2025-04-30,2025-05-07,2025-05-14" \
		--reference-date-time-span="8w" \
		--data-paths-template="gold/{}.parquet" \
		--data-container="nssp-etl" \
		--backfill-name="your-backfill-name" \
		--output-container="nssp-rt-testing" \
		--image-name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--pool-id="$(POOL)"

run-batch: ## Runs job.py on Azure Batch
	uv run --env-file .env \
	azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

run-prod: config run-batch ## Calls config and run-batch

rerun-prod: rerun-config run-batch ## Calls rerun-config and run-batch

run: ## Run pipeline from R interactively in the container
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/mnt -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
	Rscript -e "CFAEpiNow2Pipeline::orchestrate_pipeline('$(CONFIG)', config_container = 'rt-epinow2-config', input_dir = '/mnt/input', output_dir = '/mnt')"

up: ## Start an interactive bash shell in the container with project directory mounted
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) /bin/bash

push: ## Push the tagged image to the container registry
	$(CNTR_MGR) push $(REGISTRY)$(IMAGE_NAME):$(TAG)

test-batch: ## Run GitHub Actions workflow and then job.py for testing on Azure Batch
	gh workflow run \
	  -R cdcgov/cfa-config-generator run-workload.yaml  \
	  -f disease=all \
	  -f state=NY \
	  -f output_container="nssp-rt-testing" \
	  -f job_id=$(JOB)
	uv run --env-file .env \
		azure/job.py \
			--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
			--config_container="$(CONFIG_CONTAINER)" \
			--pool_id="$(POOL)" \
			--job_id="$(JOB)"

test: ## Run unit tests for the CFAEpiNow2Pipeline R package
	Rscript -e "testthat::test_local()"

document: ## Generate roxygen2 documentation for the CFAEpiNow2Pipeline R package
	Rscript -e "roxygen2::roxygenize()"

check: ## Perform R CMD check for the CFAEpiNow2Pipeline R package
	Rscript -e "rcmdcheck::rcmdcheck()"
