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
    state: Annotated[
        str,
        typer.Option(
            help=(
                "State(s). Can be '*', 'all', a single state, or"
                " multiple states, separated by commas."
            ),
            show_default=False,
        ),
    ],
    disease: Annotated[
        str,
        typer.Option(
            help=(
                "Disease(s). Can be '*', 'all', a single disease, or"
                " multiple diseases, separated by commas."
            ),
            show_default=False,
        ),
    ],
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
    data_container: Annotated[
        str,
        typer.Option(
            help=(
                "The name of the blob storage container for input data. "
                "Usually 'nssp-etl'"
            ),
            show_default=False,
        ),
    ],
    backfill_name: Annotated[
        str,
        typer.Option(
            help=(
                "Name of the backfill run. This will be used to generate the job IDs for each"
                "report date in the format `<backfill_name>_<report_date>`."
            ),
            show_default=False,
        ),
    ],
    output_container: Annotated[
        str,
        typer.Option(
            help=("Blob storage container to store model output."),
            show_default=False,
        ),
    ],
    str_as_of_dates: Annotated[
        str,
        typer.Option(
            help=(
                "The parameter as-of dates. Default is to match the report dates. "
                "Otherwise, a comma separated list of dates in ISO format. "
            )
        ),
    ] = "match_report_dates",
    data_paths_template: Annotated[
        str | None,
        typer.Option(
            help=(
                "Use this option over --str-data-paths most of the time. "
                "A string representing the f-string template for data paths. "
                "The '{}' section will be replaced with the report date "
                "for each report date. This is most useful when pulling from the NSSP gold "
                "data. For example, 'gold/{}.parquet' would become 'gold/2025-01-01.parquet' "
                "for the report date 2025-01-01. "
                "Cannot be used in conjunction with the --data-paths option."
            ),
        ),
    ] = None,
    str_data_paths: Annotated[
        str | None,
        typer.Option(
            help=(
                "Comma separated paths to the data. One path for each report date. "
                "If the data is in blob, these should be the names of the blobs. "
                "Cannot be used in conjunction with the --report-date-fstring option."
            ),
        ),
    ] = None,
    task_exclusions: Annotated[
        str | None,
        typer.Option(
            help=(
                "Comma separated state:disease pairs."
                " Will be applied to all report dates."
            )
        ),
    ] = None,
) -> None:
    """
    Generate and upload config files for the EpiNow2 pipeline.
    """
    # Split on commas and spaces, and remove empty strings
    # This will handle cases like "2025-01-01, 2025-01-02 2025-01-03,2025-01-04".
    # Then parse each date string into a date object.
    report_dates: list[date] = [
        date.fromisoformat(s.strip()) for s in str_report_dates.split(",")
    ]

    # Check if both data_paths and data_paths_template are provided, and error out if so
    if str_data_paths and data_paths_template:
        raise ValueError(
            "Cannot use both --data-paths and --report-date-fstring options at the same time."
        )
    # Check that at least one of data_paths or data_paths_template is provided
    if (not str_data_paths) and (not data_paths_template):
        raise ValueError(
            "Must provide either --data-paths or --report-date-fstring option."
        )

    # If data_paths is provided, split on commas and remove empty strings
    data_paths: list[str] = (
        [s.strip() for s in str_data_paths.split(",")]
        if str_data_paths and (not data_paths_template)
        else [
            data_paths_template.format(report_date.isoformat())  # type: ignore
            for report_date in report_dates
        ]
    )

    as_of_dates: list[date] = (
        [date.fromisoformat(s.strip()) for s in str_as_of_dates.split(",")]
        if str_as_of_dates != "match_report_dates"
        else report_dates
    )

    job_ids: list[str] = generate_backfill_config(
        state=state,
        disease=disease,
        report_dates=report_dates,
        reference_date_time_span=reference_date_time_span,
        data_paths=data_paths,
        data_container=data_container,
        backfill_name=backfill_name,
        as_of_dates=as_of_dates,
        output_container=output_container,
        task_exclusions=task_exclusions,
    )


if __name__ == "__main__":
    typer.run(main)
