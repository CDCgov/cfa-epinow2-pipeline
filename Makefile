# If CNTR_PROG is undefined, then set it to be podman
ifndef CNTR_PROG
	CNTR_PROG = podman
endif

CNTR_USER=gvegayon
IMAGE_NAME=cfa-epinow2-pipeline:latest

build:
	$(CNTR_PROG) build -t $(IMAGE_NAME) -f Dockerfile . && \
	$(CNTR_PROG) tag $(IMAGE_NAME) $(CNTR_USER)/$(IMAGE_NAME)

push:
	$(CNTR_PROG) push $(CNTR_USER)/$(IMAGE_NAME)

run:
	$(CNTR_PROG) run -it --rm -v $(PWD):/mnt $(IMAGE_NAME) 
