#!/bin/bash
# If the development mode is true, then install the extra packages
if [ "$DEVELOPMENT" = "true" ]; then
    echo "Development mode is enabled";

    # Setting up dependencies
    apt-get update && apt-get install \
        libharfbuzz-dev libfribidi-dev libfontconfig1-dev \
        libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
        --no-install-recommends -y && \
    install2.r --error devtools roxygen2 testthat languageserver && \

    # Installing the httpgd package (requires libcairo)
    apt-get install -y --no-install-recommends libcairo2-dev && \
    installGithub.r nx10/httpgd;

    # Installing pre-commit and uv
    apt-get install pipx -y --no-install-recommends
    echo 'PATH=/root/.local/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
    pipx install uv
    pipx install pre-commit
    pipx inject pre-commit pre-commit-uv
else
    echo "Development mode is disabled";
fi
