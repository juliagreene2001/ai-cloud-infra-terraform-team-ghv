"""Validate and test copied configuration with mocked Google resources and no cloud state."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="ghv-terraform-policy-") as temporary:
        folder = Path(temporary)
        for source in (ROOT / "infra").glob("*.tf"):
            if source.name != "backend.tf":
                shutil.copy2(source, folder / source.name)
        shutil.copy2(ROOT / "infra/.terraform.lock.hcl", folder / ".terraform.lock.hcl")
        shutil.copytree(ROOT / "infra/tests", folder / "tests")
        commands = [
            ["terraform", "init", "-backend=false", "-input=false", "-no-color"],
            ["terraform", "validate", "-no-color"],
            ["terraform", "test", "-no-color"],
        ]
        installed = ROOT / "infra/.terraform/providers"
        if installed.exists():
            commands[0].append(f"-plugin-dir={installed}")
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with args.output.open("w") as output:
                for command in commands:
                    subprocess.run(command, cwd=folder, stdout=output, check=True)
        else:
            for command in commands:
                subprocess.run(command, cwd=folder, check=True)


if __name__ == "__main__":
    main()
