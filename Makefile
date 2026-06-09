REGISTRY=cfaprdbatchcr.azurecr.io/
IMAGE_NAME=cfa-epinow2-pipeline
BRANCH=$(shell git branch --show-current)
CONFIG_CONTAINER=rt-epinow2-config
CNTR_MGR=docker
DATA_API=v1
ifeq ($(BRANCH), main)
TAG=latest
else
TAG=$(BRANCH)
endif

ifeq ($(DATA_API),v1)
API_CONTAINER := nssp-etl
else ifeq ($(DATA_API),v2)
API_CONTAINER := nssp-etl-api-v2
else
$(error Unknown DATA_API '$(DATA_API)'. Expected v1 or v2)
endif

# Temporary clean directory for builds/tests
TMP_BUILD_DIR=$(shell mktemp -d)
RSYNC_EXCLUDES=--exclude='.venv' --exclude='.env' --exclude='.git' --exclude='tmp_pkg'

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
		--disease="COVID-19,Influenza,RSV" \
		--state=all \
		--output-container=nssp-rt-v2 \
		--input-container=$(API_CONTAINER) \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

rerun-config: ## Generate a configuration file to rerun a previous model
	uv run azure/generate_rerun_configs.py \
		--output-container=nssp-rt-v2 \
		--input-container=$(API_CONTAINER) \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

run-caj: ## Runs run_container_app_job.py on Azure Container App Jobs
	uv run azure/run_container_app_job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--job_id="$(JOB)"


run-batch: ## Runs job.py on Azure Batch
	uv run --env-file .env \
		azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

run-prod: config run-caj ## Calls config and run-caj

rerun-prod: rerun-config run-caj ## Calls rerun-config and run-caj

run: ## Run pipeline from R interactively in the container
	@echo "Preparing clean run directory..."
	@rsync -av $(RSYNC_EXCLUDES) ./ $(TMP_BUILD_DIR)/ && \
	docker run --mount type=bind,source=$(TMP_BUILD_DIR),target=/mnt -it \
		--env-file .env \
		--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		Rscript -e "CFAEpiNow2Pipeline::orchestrate_pipeline('$(CONFIG)', config_container = 'rt-epinow2-config', input_dir = '/mnt/input', output_dir = '/mnt')" && \
	rm -rf $(TMP_BUILD_DIR)
	
#run: ## Run pipeline from R interactively in the container
#	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/mnt -it \
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
	uv run azure/generate_configs.py \
		--disease="COVID-19,Influenza,RSV" \
		--state=NY \
		--output-container=nssp-rt-testing \
		--input-container=$(API_CONTAINER) \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)
	uv run --env-file .env \
		azure/job.py \
			--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
			--config_container="$(CONFIG_CONTAINER)" \
			--pool_id="$(POOL)" \
			--job_id="$(JOB)"

test: ## Run unit tests for the CFAEpiNow2Pipeline R package
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
	Rscript -e "testthat::test_local('cfa-epinow2-pipeline')"

document: ## Generate roxygen2 documentation for the CFAEpiNow2Pipeline R package
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
	Rscript -e "roxygen2::roxygenize('cfa-epinow2-pipeline')"

check: ## Perform R CMD check for the CFAEpiNow2Pipeline R package
	@echo "Preparing clean build directory..."
	@TMPDIR=$$(mktemp -d) && \
	rsync -av --exclude='.venv' --exclude='.env' --exclude='.git' --exclude='tmp_pkg' ./ $$TMPDIR/ && \
	echo "Running R CMD check inside Docker..." && \
	docker run --mount type=bind,source=$$TMPDIR,target=/cfa-epinow2-pipeline -it \
		--env-file .env \
		--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		Rscript -e "rcmdcheck::rcmdcheck('cfa-epinow2-pipeline')" && \
	echo "Cleaning up temporary directory..." && \
	rm -rf $$TMPDIR

#check: ## Perform R CMD check for the CFAEpiNow2Pipeline R package
#	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
	Rscript -e "rcmdcheck::rcmdcheck('cfa-epinow2-pipeline')"
