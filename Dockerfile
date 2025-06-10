FROM docker.io/rocker/geospatial:4.4.3

# Will copy the package to the container preserving the directory structure
RUN mkdir -p pkg

COPY ./DESCRIPTION pkg/

# Installing missing dependencies
RUN apt-get update && apt-get install -y --no-install-recommends pandoc-citeproc
RUN install2.r pak
# dependencies = TRUE means we install `suggests` too
RUN Rscript -e 'pak::local_install_deps("pkg", upgrade = FALSE, dependencies = TRUE)'
# The cmdstan version will need to be incrementally updated
# Must also manually bump cmdstan version `.github/workflows` when updating
RUN Rscript -e 'cmdstanr::install_cmdstan(version="2.36.0")'
# This requires access to the Azure Container Registry
# FROM ghcr.io/cdcgov/cfa-epinow2-pipeline:${TAG}

# Will copy the package to the container preserving the directory structure
COPY . pkg/

# Install the full package while leaving the tar.gz file in the
# container for later use.
RUN R CMD build --no-build-vignettes --no-manual pkg && \
    R CMD INSTALL CFAEpiNow2Pipeline_*.tar.gz

# Ensure the package is working properly
RUN R CMD check --no-build-vignettes --no-manual CFAEpiNow2Pipeline_*.tar.gz

CMD ["bash"]
