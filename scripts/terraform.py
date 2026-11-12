"""Run only this GHV configuration, with isolated state and reviewed-plan safeguards."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

INFRA = Path(__file__).resolve().parents[1] / "infra"
TEAM = "team-ghv"
SERVICE = f"{TEAM}-fraud-api"
SERVICE_ID = f"projects/advanced-cloud-ai/locations/europe-west1/services/{SERVICE}"


def check_configuration(folder: Path) -> None:
    if not (folder / "terraform.tfvars").is_file():
        raise ValueError("Copy terraform.tfvars.example to terraform.tfvars and set your invokers")
    variables = (folder / "terraform.tfvars").read_text()
    team = re.search(r'^team\s*=\s*"([^"]+)"', variables, re.MULTILINE)
    prefix = re.search(r'prefix\s*=\s*"([^"]+)"', (folder / "backend.tf").read_text())
    if not team or team.group(1) != TEAM or not prefix or prefix.group(1) != TEAM:
        raise ValueError("The variables and backend must both use team-ghv")
    if "firstname@" in variables or "your.name@" in variables:
        raise ValueError("Replace template invokers with the authorized school accounts")


def check_plan(plan: dict) -> None:
    for resource in plan.get("resource_changes", []):
        if resource.get("mode") != "managed":
            continue
        change = resource["change"]
        values = change.get("after") or change.get("before") or {}
        kind = resource["type"]
        if kind == "google_cloud_run_v2_service":
            if values.get("name") != SERVICE:
                raise ValueError("Refusing a Cloud Run resource outside team-ghv")
            if "create" in change["actions"]:
                raise ValueError("Import the pre-existing GHV service before planning its update")
            if "delete" in change["actions"]:
                raise ValueError("The pre-existing GHV service must not be deleted or replaced")
            if (
                values.get("project") != "advanced-cloud-ai"
                or values.get("location") != "europe-west1"
            ):
                raise ValueError("Unexpected Cloud Run project or region")
        elif kind == "google_cloud_run_v2_service_iam_binding":
            if values.get("name") not in (SERVICE, SERVICE_ID):
                raise ValueError("Unexpected IAM target")
            if values.get("role") != "roles/run.invoker":
                raise ValueError("Unexpected service role")
            members = values.get("members", [])
            if any(member in ("allUsers", "allAuthenticatedUsers") for member in members):
                raise ValueError("Public invocation is forbidden")
        elif kind == "google_service_account":
            if values.get("account_id") != f"{TEAM}-run":
                raise ValueError("Unexpected exercise account")
        elif kind in ("google_project_iam_member", "google_storage_bucket_iam_member"):
            if values.get("role") not in ("roles/logging.logWriter", "roles/storage.objectViewer"):
                raise ValueError("Unexpected exercise grant")
            member = values.get("member")
            expected = f"serviceAccount:{TEAM}-run@advanced-cloud-ai.iam.gserviceaccount.com"
            if member and member != expected:
                raise ValueError("Unexpected exercise principal")
        else:
            raise ValueError(f"Unreviewed resource type: {kind}")


def main() -> int:
    arguments = sys.argv[1:]
    if not arguments:
        print("Usage: python3 scripts/terraform.py <command and arguments>")
        return 2
    try:
        check_configuration(INFRA)
        directory = INFRA
        if arguments[0] == "--local-state":
            raise ValueError("The GHV shared backend works; local cloud execution is disabled")
        command = arguments[0]
        if command == "destroy":
            raise ValueError("The existing GHV service is protected; destroy is disabled")
        if command == "apply":
            plans = [value for value in arguments[1:] if not value.startswith("-")]
            if len(plans) != 1 or not plans[0].endswith(".tfplan"):
                raise ValueError("Apply requires one saved .tfplan file; review a plan first")
            result = subprocess.run(
                ["terraform", "show", "-json", plans[0]], cwd=directory,
                capture_output=True, text=True, check=True,
            )
            check_plan(json.loads(result.stdout))
        if command == "import":
            targets = [value for value in arguments[1:] if not value.startswith("-")]
            if targets != ["google_cloud_run_v2_service.api", SERVICE_ID]:
                raise ValueError("Only the pre-existing team-ghv service may be imported here")
        state = directory / "terraform.tfstate"
        if state.exists():
            for resource in json.loads(state.read_text()).get("resources", []):
                if resource.get("type") == "google_cloud_run_v2_service":
                    names = [item["attributes"]["name"] for item in resource.get("instances", [])]
                    if any(name != SERVICE for name in names):
                        raise ValueError("The selected local state belongs to another namespace")
        credentials = subprocess.run(
            ["gcloud", "auth", "print-access-token"], capture_output=True, text=True
        )
        if credentials.returncode:
            print(credentials.stderr, file=sys.stderr)
            return credentials.returncode
        environment = os.environ.copy()
        environment["GOOGLE_OAUTH_ACCESS_TOKEN"] = credentials.stdout.strip()
        return subprocess.run(["terraform", *arguments], cwd=directory, env=environment).returncode
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Refused: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
