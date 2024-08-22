# CFA EpiNow2 Pipeline

## Overview

A lightweight wrapper around [{EpiNow2}](https://github.com/epiforecasts/EpiNow2) to add functionality for deployment in Azure Batch.
It holds some lightweight helper functions to interface with Azure services, convert input data to EpiNow2's expected input format, and save expected outputs. It also adds metadata and logging.

This package is meant to meet CFA's needs around model deployment in its computational environment.
The code is open source as part of CFA's goals around development, but it may not be possible to support extensions to additional environments.

## Structure

This repository holds an R package, `{CFAEpiNow2Pipeline}`.
The repository is structured as a standard R package.
All PRs pass R CMD check as part of the CI suite as a pre-condition for merge to main.

The package contains contains some adapters and wrappers to run `{EpiNow2}` at moderate computational scale, fitting hundreds or thousands of independent models in parallel with cloud resources.
The adapters read from datasets with standardized formats and produces outputs as flat files with standard names.

This package does _not_ manage pipeline deployment or kickoff, data extraction and transformation, or model output visualization.

## Components

1. **Config**: Model parameterization and input/output paths are specified by a config, with the path to this config passed at runtime.
    - The config is validated at runtime, but config generation is specified at pipeline runtime and not part of this package.
1. **Data**: Data load from the CFA data lake or from a local environment.
1. **Parameters**: Required parameters are read from the CFA data lake or from a local environment.
1. **Model run**: The R environment is managed such that the model runs from a fixed random seed, both for EpiNow2 initialization and Stan sampling.
1. **Outputs**: Model fits are saved as flat files with standardized formats and RDS objects.
1. **Logging**: Steps in the pipeline have comprehensive R-style logging, with the the [cli](https://github.com/r-lib/cli) package
1. **Metadata**: Model runs generate comprehensive metadata stored alongside outputs

## Project Admin

- @zsusswein
- @natemcintosh
- @kgostic

## General Disclaimer
This repository was created for use by CDC programs to collaborate on public health related projects in support of the [CDC mission](https://www.cdc.gov/about/organization/mission.htm).  GitHub is not hosted by the CDC, but is a third party website used by CDC and its partners to share information and collaborate on software. CDC use of GitHub does not imply an endorsement of any one particular service, product, or enterprise.

## Public Domain Standard Notice
This repository constitutes a work of the United States Government and is not
subject to domestic copyright protection under 17 USC § 105. This repository is in
the public domain within the United States, and copyright and related rights in
the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this repository will be released under the CC0 dedication. By
submitting a pull request you are agreeing to comply with this waiver of
copyright interest.

## License Standard Notice
The repository utilizes code licensed under the terms of the Apache Software
License and therefore is licensed under ASL v2 or later.

This source code in this repository is free: you can redistribute it and/or modify it under
the terms of the Apache Software License version 2, or (at your option) any
later version.

This source code in this repository is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the Apache Software License for more details.

You should have received a copy of the Apache Software License along with this
program. If not, see http://www.apache.org/licenses/LICENSE-2.0.html

The source code forked from other open source projects will inherit its license.

## Privacy Standard Notice
This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
[Disclaimer](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md)
and [Code of Conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

## Contributing Standard Notice
Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo)
and submitting a pull request. (If you are new to GitHub, you might start with a
[basic tutorial](https://help.github.com/articles/set-up-git).) By contributing
to this project, you grant a world-wide, royalty-free, perpetual, irrevocable,
non-exclusive, transferable license to all users under the terms of the
[Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or
later.

All comments, messages, pull requests, and other submissions received through
CDC including this GitHub page may be subject to applicable federal law, including but not limited to the Federal Records Act, and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

## Records Management Standard Notice
This repository is not a source of government records but is a copy to increase
collaboration and collaborative potential. All government records will be
published through the [CDC web site](http://www.cdc.gov).

## Additional Standard Notices
Please refer to [CDC's Template Repository](https://github.com/CDCgov/template) for more information about [contributing to this repository](https://github.com/CDCgov/template/blob/main/CONTRIBUTING.md), [public domain notices and disclaimers](https://github.com/CDCgov/template/blob/main/DISCLAIMER.md), and [code of conduct](https://github.com/CDCgov/template/blob/main/code-of-conduct.md).
