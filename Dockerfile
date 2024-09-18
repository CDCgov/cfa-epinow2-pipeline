# This requires access to the Azure Container Registry
FROM cfaprdbatchcr.azurecr.io/cfa-epinow2-pipeline-dependencies:latest

# Will copy the package to the container preserving the directory structure
COPY . pkg/

# Install the full package while leaving the tar.gz file in the
# container for later use.
RUN R CMD build --no-build-vignettes pkg && \
    R CMD INSTALL CFAEpiNow2Pipeline_*.tar.gz

# Ensure the package is working properly
RUN R CMD check CFAEpiNow2Pipeline_*.tar.gz

CMD ["bash"]
