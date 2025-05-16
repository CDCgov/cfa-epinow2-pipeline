# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "cfa-config-generator",
#     "typer",
# ]
#
# [tool.uv.sources]
# cfa-config-generator = { git = "https://github.com/cdcgov/cfa-config-generator" }
# ///

from datetime import date
from typing import Annotated

import typer
from cfa_config_generator.utils.epinow2.driver_functions import generate_backfill_config


def main(
    state: Annotated[str, typer.Option(help="State(s)", show_default=False)],
    disease: Annotated[str, typer.Option(help="Disease(s)", show_default=False)],
    str_report_dates: Annotated[
        list[str],
        typer.Option(help="List of ISO format report dates", show_default=False),
    ],
) -> None:
    """
    Generate and upload config files for the epinow2 pipeline.
    """
    # Convert report dates to date objects
    report_dates = [date.fromisoformat(date_str) for date_str in str_report_dates]

    print(report_dates)


if __name__ == "__main__":
    typer.run(main)
