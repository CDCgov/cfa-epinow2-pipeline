# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "cfa-config-generator",
#     "typer",
# ]
#
# [tool.uv.sources]
# cfa-config-generator = { git = "https://github.com/CDCgov/cfa-config-generator", branch = "dev-test_alt_priors_mpw"}
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
    facility_active_proportion: Annotated[
        float,
        typer.Option(
            help="""
            Minimum proportion of days of a facility must be actively reporting DDI
            counts during the modeling period. Must be a number between 0 and 1.
            Default is 0.94 (require active reporting for >=53 of 56 days in the training period).
            We do not recommend using 1.00, as this will filter out large fractions of the data in some states,
            because not all facilities report actively same-day (at lag 0). This default was chosen for correspondence
            with API v1, and it includes data from most facilities,
            even if they do not actively report at lag 0 or drop out for a few days incidentally.
            """,
            show_default=True,
        ),
    ] = 0.94,
):
    """
    Generate and upload config files for the epinow2 pipeline.
    """
    report_date: date = date.fromisoformat(report_date_str)
    production_date: date = date.fromisoformat(production_date_str)
    now: datetime = datetime.now(timezone.utc)

    # Make sure the job ID is not empty.
    if not job_id:
        raise ValueError("Job ID cannot be empty")

    # Make sure facility_active_proportion is between 0 and 1.
    if not (0 <= facility_active_proportion <= 1):
        raise ValueError(
            "facility_active_proportion must be between 0 and 1, inclusive."
        )

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
        as_of_date=now.isoformat(),
        output_container=output_container,
        facility_active_proportion=facility_active_proportion,
    )


if __name__ == "__main__":
    typer.run(main)
