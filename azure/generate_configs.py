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


from datetime import datetime, timedelta
from typing import Annotated

import typer
from cfa_config_generator.utils.epinow2.driver_functions import generate_config


def main(
    job_id: Annotated[str, typer.Argument(help="Job ID to use.")],
    state: Annotated[str, typer.Option(help="State to generate config for")] = "all",
    disease: Annotated[
        str, typer.Option(help="Disease to generate config for")
    ] = "all",
    report_date: Annotated[
        datetime,
        typer.Option(
            help="Report date to generate config for. Default is today.",
            show_default=False,
            formats=["%Y-%m-%d"],
        ),
    ] = datetime.today(),
    input_container: Annotated[
        str,
        typer.Option(
            help="Input container to download config from",
        ),
    ] = "nssp-etl",
    output_container: Annotated[
        str,
        typer.Option(
            help="Output container to upload config to",
        ),
    ] = "nssp-rt-v2",
):
    """
    Generate and upload config files for the epinow2 pipeline.
    """
    report_date = report_date.date()
    now: datetime = datetime.now()
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
        production_date=None,
        job_id=job_id,
        as_of_date=now.isoformat(),
        output_container=output_container,
    )


if __name__ == "__main__":
    typer.run(main)
