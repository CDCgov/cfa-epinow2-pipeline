# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "azure-identity==1.21.0",
#     "azure-mgmt-appcontainers==3.2.0",
#     "azure-mgmt-resource==23.4.0",
#     "azure-storage-blob==12.25.1",
#     "cfa-config-generator",
#     "tqdm",
#     "typer",
# ]
#
# [tool.uv.sources]
# cfa-config-generator = { git = "https://github.com/CDCgov/cfa-config-generator" }
# ///


from datetime import date, datetime, timedelta, timezone
import subprocess

import typer
from azure.identity import DefaultAzureCredential
from azure.mgmt.appcontainers import ContainerAppsAPIClient
from azure.mgmt.resource.subscriptions import SubscriptionClient
from azure.storage.blob import BlobServiceClient
from cfa_config_generator.utils.epinow2.driver_functions import generate_config
from tqdm import tqdm


def iter_wednesdays(start_date: date, end_date: date) -> list[date]:
    if start_date > end_date:
        raise ValueError("start_date must be on or before end_date")
    if start_date.weekday() != 2:
        raise ValueError("start_date must be a Wednesday")
    current = start_date
    dates: list[date] = []
    while current <= end_date:
        dates.append(current)
        current += timedelta(days=7)
    return dates


def latest_wednesday(today: date) -> date:
    return today - timedelta(days=(today.weekday() - 2) % 7)


def build_job_id(prefix: str, report_date: date) -> str:
    return f"{prefix}-{report_date.isoformat()}"


def current_branch_tag() -> str:
    branch = subprocess.run(
        ["git", "branch", "--show-current"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    return "latest" if branch == "main" else branch


def default_image_name() -> str:
    return f"cfaprdbatchcr.azurecr.io/cfa-epinow2-pipeline:{current_branch_tag()}"


def generate_configs_for_date(
    *,
    state: str,
    disease: str,
    job_id: str,
    report_date: date,
    output_container: str,
    input_container: str,
    production_date: date,
    facility_active_proportion: float,
) -> None:
    now = datetime.now(timezone.utc)
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


def list_task_configs(
    *,
    blob_account: str,
    config_container: str,
    job_id: str,
    credential: DefaultAzureCredential,
) -> list[str]:
    blob_url = f"https://{blob_account}.blob.core.windows.net"
    blob_service_client = BlobServiceClient(blob_url, credential)
    container_client = blob_service_client.get_container_client(
        container=config_container
    )
    task_configs = [
        b.name for b in container_client.list_blobs(name_starts_with=f"{job_id}/")
    ]
    if not task_configs:
        raise ValueError(f"No config blobs found for job_id {job_id}")
    return task_configs


def submit_caj_job(
    *,
    image_name: str,
    config_container: str,
    job_id: str,
    blob_account: str,
    resource_group: str,
    job_name: str,
) -> None:
    credential = DefaultAzureCredential()
    task_configs = list_task_configs(
        blob_account=blob_account,
        config_container=config_container,
        job_id=job_id,
        credential=credential,
    )
    print(f"Creating {len(task_configs)} CAJ executions for job {job_id}")

    subscription_id = (
        SubscriptionClient(credential).subscriptions.list().next().subscription_id
    )
    client = ContainerAppsAPIClient(
        credential=credential,
        subscription_id=subscription_id,
    )

    job_template = client.jobs.get(
        resource_group_name=resource_group,
        job_name=job_name,
    ).template
    container = job_template.containers[0]
    container.image = image_name

    for i, config_path in enumerate(task_configs, start=1):
        container.command = [
            "Rscript",
            "-e",
            (
                "CFAEpiNow2Pipeline::orchestrate_pipeline("
                f"'{config_path}', config_container = '{config_container}')"
            ),
        ]
        job_execution = client.jobs.begin_start(
            resource_group_name=resource_group,
            job_name=job_name,
            template=job_template,
        ).result()
        config_name = config_path.split("/").pop()
        execution_id = job_execution.id.split("/").pop()
        print(
            f"Started CAJ execution {i}/{len(task_configs)} "
            f"for {config_name}: {execution_id}"
        )


def main(
    start_date_str: str = typer.Option(
        "2024-03-06",
        "--start-date",
        help="First Wednesday to backfill, in ISO format.",
    ),
    end_date_str: str | None = typer.Option(
        None,
        "--end-date",
        help="Last Wednesday to backfill, in ISO format. Defaults to the latest Wednesday on or before today.",
    ),
    prefix: str = typer.Option(
        "2026-04-api-v2-backfill",
        "--prefix",
        help="Job ID prefix. Each job ID becomes <prefix>-YYYY-MM-DD.",
    ),
    state: str = typer.Option(
        "all",
        "--state",
        help="State selection passed to the config generator.",
    ),
    disease: str = typer.Option(
        "COVID-19,Influenza,RSV",
        "--disease",
        help="Disease selection passed to the config generator.",
    ),
    output_container: str = typer.Option(
        "nssp-rt-testing",
        "--output-container",
        help="Blob container for pipeline outputs.",
    ),
    input_container: str = typer.Option(
        "nssp-etl-api-v2",
        "--input-container",
        help="Blob container holding API v2 input parquet files.",
    ),
    config_container: str = typer.Option(
        "rt-epinow2-config",
        "--config-container",
        help="Blob container holding generated config files.",
    ),
    image_name: str | None = typer.Option(
        None,
        "--image-name",
        help="Container image to run for each task. Defaults to the current branch tag, or latest on main.",
    ),
    production_date_str: str = typer.Option(
        date.today().isoformat(),
        "--production-date",
        help="Production date to encode in generated configs.",
    ),
    facility_active_proportion: float = typer.Option(
        0.94,
        "--facility-active-proportion",
        min=0.0,
        max=1.0,
        help="Minimum active-reporting proportion for API v2 facility filtering.",
    ),
    dry_run: bool = typer.Option(
        False,
        "--dry-run",
        help="Print planned jobs without generating configs or submitting them.",
    ),
    blob_account: str = typer.Option(
        "cfaazurebatchprd",
        "--blob-account",
        help="Azure storage account for config blob discovery.",
    ),
    resource_group: str = typer.Option(
        "ext-edav-cfa-prd",
        "--resource-group",
        help="Azure resource group for the Container App Job.",
    ),
    container_app_job_name: str = typer.Option(
        "cfa-epinow2-pipeline",
        "--container-app-job-name",
        help="Azure Container App Job name.",
    ),
) -> None:
    start_date = date.fromisoformat(start_date_str)
    end_date = (
        date.fromisoformat(end_date_str)
        if end_date_str is not None
        else latest_wednesday(date.today())
    )
    production_date = date.fromisoformat(production_date_str)
    report_dates = iter_wednesdays(start_date, end_date)
    image_name = image_name or default_image_name()

    print(
        f"Preparing {len(report_dates)} weekly backfill runs "
        f"from {report_dates[0]} through {report_dates[-1]}"
    )
    print(f"Using image {image_name}")

    for report_date in tqdm(report_dates, desc="Submitting backfill jobs"):
        job_id = build_job_id(prefix, report_date)
        print(f"{'[dry-run] ' if dry_run else ''}{report_date.isoformat()} -> {job_id}")

        if dry_run:
            continue

        generate_configs_for_date(
            state=state,
            disease=disease,
            job_id=job_id,
            report_date=report_date,
            output_container=output_container,
            input_container=input_container,
            production_date=production_date,
            facility_active_proportion=facility_active_proportion,
        )

        submit_caj_job(
            image_name=image_name,
            config_container=config_container,
            job_id=job_id,
            blob_account=blob_account,
            resource_group=resource_group,
            job_name=container_app_job_name,
        )


if __name__ == "__main__":
    typer.run(main)
