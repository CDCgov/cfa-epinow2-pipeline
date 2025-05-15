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

pull: ## Pulls something
	az acr login --name 'cfaprdbatchcr'
	$(CNTR_MGR) pull $(REGISTRY)$(IMAGE_NAME):$(TAG)

build: ## Builds something
	$(CNTR_MGR) build -t $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		--build-arg TAG=$(TAG) -f Dockerfile .

tag: ## Tags something
	$(CNTR_MGR) tag $(IMAGE_NAME):$(TAG) $(REGISTRY)$(IMAGE_NAME):$(TAG)

config: ## Generates a configuration file
	uv run azure/generate_configs.py \
		--disease="COVID-19,Influenza" \
		--state=all \
		--output-container=nssp-rt-v2 \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

rerun-config: ## Reruns generating a configuration file (why?)
	uv run azure/generate_rerun_configs.py \
		--output-container=nssp-rt-v2 \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

run-batch: ## Runs job.py on Azure Batch
	uv run --env-file .env \
	azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

run-prod: config ## Runs job.py with config?
	uv run --env-file .env \
	azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

rerun-prod: rerun-config ## Reruns job.py with config (why?)
	uv run --env-file .env \
	azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

run: ## Runs something?
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/mnt -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
	Rscript -e "CFAEpiNow2Pipeline::orchestrate_pipeline('$(CONFIG)', config_container = 'rt-epinow2-config', input_dir = '/mnt/input', output_dir = '/mnt')"


up: ## Uploads something
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) /bin/bash

push: ## Push container to registry
	$(CNTR_MGR) push $(REGISTRY)$(IMAGE_NAME):$(TAG)

test-batch: 
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

test: ## Tests the CFAEpiNow2Pipeline R package
	Rscript -e "testthat::test_local()"

document: ## Document the CFAEpiNow2Pipeline R package
	Rscript -e "roxygen2::roxygenize()"

check: ## Checks the CFAEpiNow2Pipeline R package
	Rscript -e "rcmdcheck::rcmdcheck()"
