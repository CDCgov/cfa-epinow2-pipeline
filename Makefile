REGISTRY=cfaprdbatchcr.azurecr.io/
IMAGE_NAME=cfa-epinow2-pipeline
BRANCH=$(shell git branch --show-current)
ifeq ($(BRANCH), 'main')
TAG=latest
else
TAG=$(BRANCH)
endif

CONFIG=test.json


deps:
	docker build -t $(REGISTRY)$(IMAGE_NAME)-dependencies:$(TAG) -f Dockerfile-dependencies

pull:
	az acr login --name 'cfaprdbatchcr'
	docker pull $(REGISTRY)$(IMAGE_NAME)-dependencies:$(TAG)
	docker pull $(REGISTRY)$(IMAGE_NAME):test-$(TAG)

build:
	docker build -t $(REGISTRY)$(IMAGE_NAME):test-$(TAG) \
		--build-arg TAG=$(TAG) -f Dockerfile .

tag:
	docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)$(IMAGE_NAME):$(TAG)

run:
	docker run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):test-$(TAG) \
	Rscript -e "CFAEpiNow2Pipeline::orchestrate_pipeline('$(CONFIG)', config_container = 'zs-test-pipeline-update', input_dir = '/cfa-epinow2-pipeline/input', output_dir = '/cfa-epinow2-pipeline', output_container = 'zs-test-pipeline-update')"


up:
	docker run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--env-file .env \
	--rm $(REGISTRY)$(IMAGE_NAME):test-$(TAG) /bin/bash

run-function:
	docker run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) \
	Rscript -e "CFAEpiNow2Pipeline::run_pipeline('/cfa-epinow2-pipeline/configs/baa631b0a39111efbec600155d6da693_MS_Influenza_1731703176.json')"

push:
	docker push $(REGISTRY)$(IMAGE_NAME):$(TAG)


test:
	Rscript -e "testthat::test_local()"

document:
	Rscript -e "roxygen2::roxygenize()"

check:
	Rscript -e "rcmdcheck::rcmdcheck()"
