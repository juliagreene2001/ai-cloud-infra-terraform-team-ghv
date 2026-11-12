"""Execution guards for the GHV namespace and protected service."""

import importlib.util
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/terraform.py"
SPEC = importlib.util.spec_from_file_location("ghv_terraform", SCRIPT)
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


def cloud_change(name="team-ghv-fraud-api", actions=None):
    return {
        "mode": "managed",
        "type": "google_cloud_run_v2_service",
        "change": {
            "actions": actions or ["update"],
            "after": {"name": name, "project": "advanced-cloud-ai", "location": "europe-west1"},
        },
    }


def test_allows_reviewed_update_to_existing_ghv_service():
    RUNNER.check_plan({"resource_changes": [cloud_change()]})


def test_rejects_numeric_namespace():
    with pytest.raises(ValueError, match="outside team-ghv"):
        RUNNER.check_plan({"resource_changes": [cloud_change("team1-fraud-api")]})


@pytest.mark.parametrize("actions", [["delete"], ["delete", "create"], ["create"]])
def test_preexisting_service_cannot_be_deleted_replaced_or_recreated(actions):
    with pytest.raises(ValueError):
        RUNNER.check_plan({"resource_changes": [cloud_change(actions=actions)]})


def test_rejects_public_invoker_binding():
    binding = {
        "mode": "managed",
        "type": "google_cloud_run_v2_service_iam_binding",
        "change": {
            "actions": ["create"],
            "after": {
                "name": "team-ghv-fraud-api", "role": "roles/run.invoker", "members": ["allUsers"],
            },
        },
    }
    with pytest.raises(ValueError, match="Public invocation"):
        RUNNER.check_plan({"resource_changes": [binding]})


def test_rejects_mismatched_backend_prefix(tmp_path):
    (tmp_path / "terraform.tfvars").write_text('team = "team-ghv"\n')
    (tmp_path / "backend.tf").write_text('prefix = "team1"\n')
    with pytest.raises(ValueError, match="both use team-ghv"):
        RUNNER.check_configuration(tmp_path)


def test_local_cloud_fallback_is_disabled(monkeypatch, tmp_path, capsys):
    (tmp_path / "terraform.tfvars").write_text('team = "team-ghv"\n')
    (tmp_path / "backend.tf").write_text('prefix = "team-ghv"\n')
    monkeypatch.setattr(RUNNER, "INFRA", tmp_path)
    monkeypatch.setattr("sys.argv", ["terraform.py", "--local-state", "plan"])
    assert RUNNER.main() == 2
    assert "local cloud execution is disabled" in capsys.readouterr().err


def test_template_invoker_cannot_be_applied(tmp_path):
    (tmp_path / "terraform.tfvars").write_text(
        'team = "team-ghv"\ninvokers = ["user:firstname@albertschool.com"]\n'
    )
    (tmp_path / "backend.tf").write_text('prefix = "team-ghv"\n')
    with pytest.raises(ValueError, match="authorized school accounts"):
        RUNNER.check_configuration(tmp_path)
