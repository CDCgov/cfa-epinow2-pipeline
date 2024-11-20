# If CNTR_PROG is undefined, then set it to be podman
ifndef CNTR_PROG
	CNTR_PROG = docker
endif

ifndef TAG
	TAG = local
endif

IMAGE_NAME=cfa-epinow2-pipeline

deps:
	$(CNTR_PROG) build -t $(REGISTRY)$(IMAGE_NAME)-dependencies:$(TAG) -f Dockerfile-dependencies

pull:
	$(CNTR_PROG) pull $(REGISTRY)$(IMAGE_NAME)-dependencies:$(TAG)

build:
	$(CNTR_PROG) build -t $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		--build-arg TAG=$(TAG) -f Dockerfile

tag:
	$(CNTR_PROG) tag $(IMAGE_NAME):$(TAG) $(REGISTRY)$(IMAGE_NAME):$(TAG)

up:
	$(CNTR_PROG) run --mount type=bind,source=$(PWD),target=/cfa-epinow2-pipeline -it \
	--rm $(REGISTRY)$(IMAGE_NAME):$(TAG) /bin/bash

push:
	$(CNTR_PROG) push $(REGISTRY)$(IMAGE_NAME):$(TAG)


test:
	Rscript -e "testthat::test_local()"

document:
	Rscript -e "roxygen2::roxygenize()"

check:
	Rscript -e "rcmdcheck::rcmdcheck()"
