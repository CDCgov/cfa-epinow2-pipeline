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

pull:
	az acr login --name 'cfaprdbatchcr'
	$(CNTR_MGR) pull $(REGISTRY)$(IMAGE_NAME):$(TAG)

build:
	$(CNTR_MGR) build -t $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		--build-arg TAG=$(TAG) -f Dockerfile .

tag:
	$(CNTR_MGR) tag $(IMAGE_NAME):$(TAG) $(REGISTRY)$(IMAGE_NAME):$(TAG)

config:
	uv run azure/generate_configs.py \
		--disease="COVID-19,Influenza" \
		--state=all \
		--output-container=nssp-rt-v2 \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

rerun-config:
	uv run azure/generate_rerun_configs.py \
		--output-container=nssp-rt-v2 \
		--job-id=$(JOB) \
		--report-date-str=$(REPORT_DATE)

run-batch:
	uv run --env-file .env \
	azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

run-prod: config
	uv run --env-file .env \
	azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

rerun-prod: rerun-config
	uv run --env-file .env \
	azure/job.py \
		--image_name="$(REGISTRY)$(IMAGE_NAME):$(TAG)" \
		--config_container="$(CONFIG_CONTAINER)" \
		--pool_id="$(POOL)" \
		--job_id="$(JOB)"

run:
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/mnt -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
	Rscript -e "CFAEpiNow2Pipeline::orchestrate_pipeline('$(CONFIG)', config_container = 'rt-epinow2-config', input_dir = '/mnt/input', output_dir = '/mnt')"


up:
	$(CNTR_MGR) run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) /bin/bash

push:
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

test:
	Rscript -e "testthat::test_local()"

document:
	Rscript -e "roxygen2::roxygenize()"

check:
	Rscript -e "rcmdcheck::rcmdcheck()"
