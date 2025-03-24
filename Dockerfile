# Adding arguments
ARG TAG=local

# This requires access to the Azure Container Registry
FROM ghcr.io/cdcgov/cfa-epinow2-pipeline:${TAG}

# Will copy the package to the container preserving the directory structure
COPY . pkg/
RUN chmod 755 pkg/start.sh

# Install the full package while leaving the tar.gz file in the
# container for later use.
RUN R CMD build --no-build-vignettes --no-manual pkg && \
    R CMD INSTALL CFAEpiNow2Pipeline_*.tar.gz

# Ensure the package is working properly
# Commenting out to complete build (will uncomment later)
# RUN R CMD check --no-build-vignettes --no-manual CFAEpiNow2Pipeline_*.tar.gz

ENTRYPOINT ["/bin/bash"]
