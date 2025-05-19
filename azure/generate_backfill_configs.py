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
        str,
        typer.Option(
            help="List of comma separated ISO format report dates",
            show_default=False,
        ),
    ],
    reference_date_time_span: Annotated[
        str,
        typer.Option(
            help=(
                "A string representing the time span for the earliest reference date relative to"
                " the report date. This should be formatted following the conventions of polars"
                " `.dt.offset_by()`. Usually, this will be a string like '8w' or '1d' (for 8 weeks"
                " or 1 day)."
            ),
            show_default=False,
        ),
    ],
    data_paths: Annotated[
        str | None,
        typer.Option(
            help=(
                "A comma separated list of paths to the data. One path for each report date. "
                "If the data is in blob, these should be the names of the blobs. "
                "Cannot be used in conjunction with the --report-date-fstring option."
            ),
        ),
    ] = None,
    report_date_fstring: Annotated[
        str | None,
        typer.Option(
            help=(
                "A string representing the f-string format for data paths. "
                "The '{}' section will be replaced with the report date "
                "for each report date. This is most useful when pulling from the NSSP gold "
                "data. For example, 'gold/{}.parquet' would become 'gold/2025-01-01.parquet' "
                "for the report date 2025-01-01. "
                "Cannot be used in conjunction with the --data-paths option."
            ),
        ),
    ] = None,
) -> None:
    """
    Generate and upload config files for the epinow2 pipeline.
    """
    # Split on commas and spaces, and remove empty strings
    # This will handle cases like "2025-01-01, 2025-01-02 2025-01-03,2025-01-04".
    # Then parse each date string into a date object.
    report_dates: list[date] = [
        date.fromisoformat(s2)
        for s1 in str_report_dates.split(",")
        for s2 in s1.split(" ")
        if s2
    ]

    # Check if both data_paths and report_date_fstring are provided, and error out if so
    if data_paths and report_date_fstring:
        raise ValueError(
            "Cannot use both --data-paths and --report-date-fstring options at the same time."
        )
    # Check that at least one of data_paths or report_date_fstring is provided
    if not data_paths and not report_date_fstring:
        raise ValueError(
            "Must provide either --data-paths or --report-date-fstring option."
        )

    print(report_dates)


if __name__ == "__main__":
    typer.run(main)
