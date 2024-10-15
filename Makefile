# If CNTR_PROG is undefined, then set it to be podman
ifndef CNTR_PROG
	CNTR_PROG = podman
endif

CNTR_USER=gvegayon
IMAGE_NAME=cfa-epinow2-pipeline-dependencies:latest

build:
	$(CNTR_PROG) build -t $(IMAGE_NAME) -f Dockerfile-dependencies . && \
	$(CNTR_PROG) tag $(IMAGE_NAME) $(CNTR_USER)/$(IMAGE_NAME)

push:
	$(CNTR_PROG) push $(CNTR_USER)/$(IMAGE_NAME)

run:
	$(CNTR_PROG) run -it --rm -v $(PWD):/mnt $(IMAGE_NAME)

test:
	Rscript -e "testthat::test_local()"

document:
	Rscript -e "roxygen2::roxygenize()"
	git add NAMESPACE
	git add man/

check:
	Rscript -e "rcmdcheck::rcmdcheck()"
