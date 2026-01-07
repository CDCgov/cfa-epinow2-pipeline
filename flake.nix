{
  description = "cfa-epinow2-pipeline dev env";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-25.11";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          nodejs = prev.nodejs_20;
        })
      ];
    };
    epinow2RDeps = with pkgs.rPackages; [
      checkmate
      cli
      data_table
      futile_logger
      ggplot2
      lifecycle
      lubridate
      # below is built into R, no install necessary
      # methods
      patchwork
      posterior
      primarycensored
      purrr
      R_utils
      Rcpp
      rlang
      rstan
      rstantools
      runner
      scales
      # below is built into R, no install necessary
      # stats
      truncnorm
      # below is built into R, no install necessary
      # utils
    ];
    # to update this package, run the following command and update the rev and hash props:
    # nix run nixpkgs#nix-prefetch-git -- --url https://github.com/epiforecasts/Epinow2
    EpiNow2 = (pkgs.rPackages.buildRPackage {
      name = "EpiNow2";
      # pname = "CFAEpinow2Pipeline";
      version = "0.1.0";
      src = pkgs.fetchFromGitHub {
        owner = "epiforecasts";
        repo = "Epinow2";
        rev = "9b8cd4fcceca41ac34545a38989f6f295ddeeaf7";
        hash = "sha256-wUrj4P80SlQ8CL2fy7pZxt8YTTphjB44ZEBfHmfZDiI=";
      };
      buildInputs = epinow2RDeps ++ [ pkgs.R ];
    });

    cmdstanrRDeps = with pkgs.rPackages; [
      checkmate
      data_table
      jsonlite
      posterior
      processx
      R6
      withr
      rlang
    ];

    # to update this package, run the following command and update the rev and hash props:
    # nix run nixpkgs#nix-prefetch-git -- --url https://github.com/stan-dev/cmdstanr
    cmdstanr = (pkgs.rPackages.buildRPackage {
      name = "cmdstanr";
      # pname = "CFAEpinow2Pipeline";
      version = "0.9.0";
      src = pkgs.fetchFromGitHub {
        owner = "stan-dev";
        repo = "cmdstanr";
        rev = "fc0d2cfbe2f0bdb744176f85d43717e6cd759969";
        hash = "sha256-7fTyzZ+aMdScPZ7Z5yQQQvUxVrK2xoCTABABC5YaiiQ=";
      };
      buildInputs = cmdstanrRDeps ++ [ pkgs.R ];
    });
    # R package dependencies (declare once)
    rDeps = with pkgs.rPackages; [
        AzureRMR
        AzureStor
        cmdstanr
        cli
        covr
        data_table
        DBI
        dplyr
        duckdb
        EpiNow2
        jsonlite
        rcmdcheck
        rlang
        roxygen2
        rstan
        S7
        lubridate
        readxl
        tidyr
        testthat
        tidybayes
        optparse
        httr
        Microsoft365R
    ];
  in
  {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Interactive R with all dependencies
        (rWrapper.override { packages = cmdstanrRDeps ++ epinow2RDeps ++ rDeps; })

        # Build the local CFAEpiNow2Pipeline package
        (pkgs.rPackages.buildRPackage {
          name = "CFAEpiNow2Pipeline";
          pname = "CFAEpiNow2Pipeline";
          version = "0.2.1.9000";
          src = ./.;
          buildInputs = rDeps ++ [ pkgs.R ];
        })
      ];

      shellHook = ''
        echo "R dev environment loaded."
        # uncomment to print all R library versions
        # Rscript -e 'ip <- installed.packages(); cat(sprintf("%-30s %s", ip[order(ip[, "Package"]), "Package"], ip[order(ip[, "Package"]), "Version"]), sep="\n")'

        # setting timezone to match Docker env
        export TZ=Etc/UTC
        Rscript -e "testthat::test_local('.')"
      '';
    };
  };
}
