ifndef TAG
	TAG = local
endif

IMAGE_NAME=cfa-epinow2-pipeline

deps:
	docker build -t $(REGISTRY)$(IMAGE_NAME)-dependencies:$(TAG) -f Dockerfile-dependencies

pull:
	docker pull $(REGISTRY)$(IMAGE_NAME)-dependencies:$(TAG)

build:
	docker build -t $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		--build-arg TAG=$(TAG) -f Dockerfile .

tag:
	docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)$(IMAGE_NAME):$(TAG)

up:
	docker run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) /bin/bash

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
