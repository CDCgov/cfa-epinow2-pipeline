# If CNTR_PROG is undefined, then set it to be podman
ifndef CNTR_PROG
	CNTR_PROG = podman
endif

ifndef TAG
	TAG = local
endif

IMAGE_NAME=cfa-epinow2-pipeline

deps:
	$(CNTR_PROG) build -t $(REGISTRY)$(IMAGE_NAME)-dependencies:$(TAG) -f Dockerfile-dependencies

build:
	$(CNTR_PROG) build -t $(REGISTRY)$(IMAGE_NAME):$(TAG) \
		--build-arg TAG=$(TAG) -f Dockerfile

tag:
	$(CNTR_PROG) tag $(IMAGE_NAME):$(TAG) $(REGISTRY)$(IMAGE_NAME):$(TAG)

interactive:
	$(CNTR_PROG) run -v$(PWD):/cfa-epinow2-pipeline -it --rm $(REGISTRY)$(IMAGE_NAME):$(TAG)

push:
	$(CNTR_PROG) push $(REGISTRY)$(IMAGE_NAME):$(TAG)


test:
	Rscript -e "testthat::test_local()"

document:
	Rscript -e "roxygen2::roxygenize()"

check:
	Rscript -e "rcmdcheck::rcmdcheck()"
