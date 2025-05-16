# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "cfa-config-generator",
#     "typer",
# ]
#
# [tool.uv.sources]
# cfa-config-generator = { git = "https://github.com/CDCgov/cfa-config-generator" }
# ///


from datetime import date, datetime, timedelta, timezone
from typing import Annotated

import typer
from cfa_config_generator.utils.epinow2.driver_functions import generate_config


def main(
    state: Annotated[
        str, typer.Option(help="State to generate config for", show_default=False)
    ],
    disease: Annotated[
        str, typer.Option(help="Disease to generate config for", show_default=False)
    ],
    job_id: Annotated[str, typer.Option(help="Job ID to use", show_default=False)],
    report_date_str: Annotated[
        str,
        typer.Option(
            help="Report date in ISO format to generate config for", show_default=False
        ),
    ],
    output_container: Annotated[
        str,
        typer.Option(help="Output container to upload config to", show_default=False),
    ],
    input_container: Annotated[
        str,
        typer.Option(help="Input container to download config from"),
    ] = "nssp-etl",
    production_date_str: Annotated[
        str,
        typer.Option(
            help="Production date in ISO format. Default is today", show_default=False
        ),
    ] = date.today().isoformat(),
):
    """
    Generate and upload config files for the epinow2 pipeline.
    """
    report_date: date = date.fromisoformat(report_date_str)
    production_date: date = date.fromisoformat(production_date_str)
    # Use the report date to generate the as_of_date string.
    as_of_date_str: str = report_date.isoformat()

    # Make sure the job ID is not empty.
    if not job_id:
        raise ValueError("Job ID cannot be empty")

    # Generate and upload to blob for all states and diseases.
    generate_config(
        state=state,
        disease=disease,
        report_date=report_date,
        reference_dates=[
            report_date - timedelta(days=1),
            report_date - timedelta(weeks=8),
        ],
        data_path=f"gold/{report_date.isoformat()}.parquet",
        data_container=input_container,
        production_date=production_date,
        job_id=job_id,
        as_of_date=as_of_date_str,
        output_container=output_container,
    )


if __name__ == "__main__":
    typer.run(main)
