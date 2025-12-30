"""
This script processes an exclusions review Excel file and extracts point and state
exclusions based on specified criteria. The extracted data is then uploaded to Azure
Blob Storage in CSV format.
"""

# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "azure-identity",
#     "azure-storage-blob",
#     "fastexcel",
#     "polars",
# ]
# ///
import io
from datetime import date
from pathlib import Path

import polars as pl
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContainerClient

# The spreadsheet has some header rows that are nice for humans but not for parsing
SKIP_ROWS = 3

# These are the expected columns in the sheets
COLUMN_NAMES = [
    "state",
    "dates_affected",
    "observed_volume",
    "expected_volume",
    "initial_thoughts",
    "state_abb",
    "review_1_decision",
    "reviewer_2_decision",
    "final_decision",
    "drop_dates",
    "additional_reasoning",
]


# Mapping of sheet names to pathogens
SHEETS_TO_PATHOGENS = {
    "Rt_Review_COVID": "covid",
    "Rt_Review_Influenza": "influenza",
    "Rt_Review_RSV": "rsv",
}

# combined output schema and columns
COMBINED_SCHEMA = {
    "report_date": pl.Date,
    "state": pl.String,
    "state_abb": pl.String,
    "pathogen": pl.String,
    "review_1_decision": pl.String,
    "reviewer_2_decision": pl.String,
    "final_decision": pl.String,
    "reference_date": pl.Date,
    "geo_value": pl.String,
}
COMBINED_COLUMNS = list(COMBINED_SCHEMA.keys())

POINT_EXCLUSIONS_SCHEMA = {
    "reference_date": pl.Date,
    "report_date": pl.Date,
    "state": pl.String,
    "disease": pl.String,
}

STATE_EXCLUSIONS_SCHEMA = {
    "state_abb": pl.String,
    "pathogen": pl.String,
    "type": pl.String,
}


def empty_final_frame() -> pl.DataFrame:
    return pl.DataFrame(
        {
            col: pl.Series(name=col, dtype=dtype, values=[])
            for col, dtype in COMBINED_SCHEMA.items()
        }
    )


def prep_single_sheet(
    sheet_name: str,
    sheet_df: pl.DataFrame,
    pathogen: str,
    report_date: date,
) -> pl.DataFrame:
    # If the sheet is empty or has no data rows, return an empty frame with the correct
    # schema
    if sheet_df.height <= SKIP_ROWS:
        return empty_final_frame()

    # Trim off unnecessary header rows
    trimmed = sheet_df.slice(offset=SKIP_ROWS)
    base_columns = trimmed.columns[: len(COLUMN_NAMES)]

    # Check we have the expected number of columns
    if len(base_columns) < len(COLUMN_NAMES):
        msg = f"Sheet {sheet_name} is missing expected columns"
        raise ValueError(msg)

    rename_map = dict(zip(base_columns, COLUMN_NAMES))

    cleaned = (
        trimmed.select(base_columns)
        .rename(rename_map)
        # Explode the drop_dates column into multiple rows, split by "|"
        .with_columns(pl.col("drop_dates").cast(pl.String, strict=False).str.split("|"))
        .explode("drop_dates")
        # Clean up drop_dates values: strip whitespace, leaving any nulls as nulls
        .with_columns(
            drop_dates=pl.when(pl.col("drop_dates").is_not_null()).then(
                pl.col("drop_dates").str.strip_chars()
            )
        )
        # Convert empty drop_dates to nulls
        .with_columns(
            drop_dates=pl.when(
                pl.col("drop_dates").is_not_null() & (pl.col("drop_dates") == "")
            )
            .then(pl.lit(None))
            .otherwise(pl.col("drop_dates"))
        )
        # Filter out any rows with null state abbreviations
        .filter(pl.col("state").is_not_null())
        # Add in report_date and pathogen columns
        .with_columns(
            report_date=pl.lit(report_date),
            pathogen=pl.lit(pathogen),
        )
        .with_columns(
            # Parse drop_dates into reference_date
            reference_date=pl.col("drop_dates").str.strptime(
                pl.Date, format="%Y%m%d", strict=False
            ),
            # Rename state_abb to geo_value
            geo_value=pl.col("state_abb"),
            # Standardize pathogen names
            pathogen=pl.when(pl.col("pathogen").eq("covid"))
            .then(pl.lit("COVID-19"))
            .when(
                pl.col("pathogen").eq("influenza"),
            )
            .then(pl.lit("Influenza"))
            .when(pl.col("pathogen").eq("rsv"))
            .then(pl.lit("RSV"))
            .otherwise(pl.col("pathogen")),
        )
        # Select and order the final columns
        .select(COMBINED_COLUMNS)
    )

    return cleaned


def read_review_excel_sheet(file_path: Path, report_date: date) -> pl.DataFrame:
    # Read all sheets at once
    all_sheets: dict[str, pl.DataFrame] = pl.read_excel(
        file_path,
        sheet_name=list(SHEETS_TO_PATHOGENS.keys()),
        has_header=False,
    )

    frames = []
    for sheet_name, pathogen in SHEETS_TO_PATHOGENS.items():
        sheet_df = all_sheets.get(sheet_name)

        if sheet_df is None:
            # Means the sheet is missing
            print(f"Warning: Sheet {sheet_name} not found in {file_path}")
            continue
        prepared = prep_single_sheet(
            sheet_name=sheet_name,
            sheet_df=sheet_df,
            pathogen=pathogen,
            report_date=report_date,
        )

        if prepared.height == 0:
            # Means the sheet was there, but had no data
            print(f"Info: Sheet {sheet_name} has no data after processing")
            continue

        frames.append(prepared)

    if len(frames) == 0:
        return empty_final_frame()

    return pl.concat(frames, how="vertical")


def main(file_path: Path, report_date: date, overwrite_blobs: bool):
    # === Read and process the exclusions Excel file ===================================
    combined_df = read_review_excel_sheet(file_path=file_path, report_date=report_date)

    if combined_df.height == 0:
        print(
            f"No data found in the exclusions file {file_path} after processing. Exiting."
        )
        return

    # === Create the point exclusions DataFrame ========================================
    # Get just the point exclusion rows: the ones with "Drop Point(s)" in final_decision
    point_exclusions_df = (
        combined_df.filter(
            pl.col("final_decision").str.contains("Drop Point", literal=True)
        )
        # Get into the desired schema
        .select(
            pl.col("reference_date"),
            pl.col("report_date"),
            pl.col("state_abb").alias("state"),
            pl.col("pathogen").alias("disease"),
        )
        # Double check the schema
        .cast(POINT_EXCLUSIONS_SCHEMA)  # type: ignore
        # Sort nicely
        .sort(by=["report_date", "state", "disease", "reference_date"])
    )
    print("Point Exclusions DataFrame:")
    print(point_exclusions_df)

    # === Create the state exclusions DataFrame ========================================
    # Get just the state exclusion rows: the ones with "Exclude State" in final_decision
    state_exclusion_df = (
        combined_df.filter(
            pl.col("final_decision").str.contains("Exclude State", literal=True)
        )
        # Create the "type" column based on "final_decision"
        .with_columns(
            pl.when(pl.col("final_decision").eq("Exclude State (Data)"))
            .then(pl.lit("Data"))
            .when(pl.col("final_decision").eq("Exclude State (Model)"))
            .then(pl.lit("Model"))
            .alias("type")
        )
        # Get into the desired schema
        .select(pl.col("state_abb"), pl.col("pathogen"), pl.col("type"))
        # Double check the schema
        .cast(STATE_EXCLUSIONS_SCHEMA)  # type: ignore
        # Sort nicely
        .sort(by=["state_abb", "pathogen", "type"])
    )
    print("State Exclusions DataFrame:")
    print(state_exclusion_df)

    # === Upload both to blob storage ==================================================
    # Create the blob storage client for the `nssp-etl` container
    ctr_client: ContainerClient = BlobServiceClient(
        account_url="https://cfaazurebatchprd.blob.core.windows.net/",
        credential=DefaultAzureCredential(),
    ).get_container_client("nssp-etl")

    # Upload the point exclusions CSV
    point_exclusion_buffer = io.BytesIO()
    point_exclusions_df.write_csv(point_exclusion_buffer)
    ctr_client.upload_blob(
        name=f"outliers-v2/{report_date.isoformat()}.csv",
        data=point_exclusion_buffer.getvalue(),
        overwrite=overwrite_blobs,
    )

    # Upload the state exclusions CSV
    state_exclusion_buffer = io.BytesIO()
    state_exclusion_df.write_csv(state_exclusion_buffer)
    ctr_client.upload_blob(
        name=f"state_exclusions/{report_date.isoformat()}_state_exclusions.csv",
        data=state_exclusion_buffer.getvalue(),
        overwrite=overwrite_blobs,
    )


if __name__ == "__main__":
    from argparse import ArgumentParser
    from datetime import date

    parser = ArgumentParser(description="Parse the outliers/exclusions exclusions file")
    parser.add_argument(
        "-d",
        "--date",
        type=str,
        default=date.today().strftime("%Y-%m-%d"),
        help=(
            "Date for which to parse the exclusions file (format: YYYY-MM-DD). "
            "Default is today's date."
        ),
    )

    parser.add_argument(
        "-f",
        "--file",
        type=str,
        help=(
            "Path to the exclusions Excel file. If none supplied,"
            " attempts to use the date to build `~/Downloads/Rt_Review_<date>.xlsx`"
        ),
        default="",
    )

    parser.add_argument(
        "--overwrite-blobs",
        action="store_true",
        help="Whether to overwrite existing blobs in storage (default: False)",
    )

    args = parser.parse_args()

    this_date = date.fromisoformat(args.date)
    if args.file:
        file_path = Path(args.file)
    else:
        file_path = (
            Path.home() / "Downloads" / f"Rt_Review_{this_date.strftime('%Y%m%d')}.xlsx"
        )

    assert file_path.is_file(), f"Exclusions file not found: {file_path}"

    main(
        file_path=file_path, report_date=this_date, overwrite_blobs=args.overwrite_blobs
    )
