"""Protect the expanded comparison from missing, swapped or changed HPO settings."""
import json
import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parents[1] / "slurm"))
import gpu8_model_reference as reference


@pytest.fixture
def expansion(tmp_path, monkeypatch):
    monkeypatch.setattr(reference.trial, "PROJECT", tmp_path)
    monkeypatch.setattr(reference.trial, "SRC", tmp_path / "src")
    helper = tmp_path / "slurm/gpu8_model_reference.py"
    helper.parent.mkdir()
    helper.write_text("frozen helper\n")
    monkeypatch.setattr(reference, "__file__", str(helper))
    folder = tmp_path / "slurm/logs/new"
    folder.mkdir(parents=True)
    (folder / "prepare.sh").write_text("#!/bin/bash\n#SBATCH --mem=64G\n#SBATCH --time=00:45:00\nprepare-original\n")
    (folder / "train.sh").write_text(f"#!/bin/bash\n#SBATCH --time=03:00:00\npython {tmp_path}/slurm/gpu8_trial.py train --manifest {folder}/manifest.json\n")
    plan = {"models": ["tabpfn", "rf"], "directions": ["up", "down"],
            "modes": ["tp", "tb_ref", "tb_k050", "tb_k100", "tb_k150", "tb_k200"],
            "output_root_base": "Output_gpu8match/new", "code_sha256": {}}
    manifest = folder / "manifest.json"
    manifest.write_text(json.dumps(plan))
    directory = tmp_path / "slurm/references"
    directory.mkdir()
    (directory / "provenance.json").write_text("{}")
    for model in plan["models"]:
        for side, n in [("up", 4), ("down", 32)]:
            path = directory / model / side.upper() / "1d/best_params.json"
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps({"model": model, "direction": side, "granularity": "1d", "best_params": {"n_estimators": n}}))
    for mode in plan["modes"]:
        path = tmp_path / "src/Output_gpu8match/new/configs" / f"{mode}.yaml"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(yaml.safe_dump({"data": {"load": {"m1": "kronos"}},
            "runtime": {"training": {"thres": "utility_nocal"}},
            "paths": {"output_root": f"Output_gpu8match/new/{mode}"}}))
    monkeypatch.chdir(tmp_path / "src")
    return manifest, directory


def test_every_target_receives_same_frozen_direction_parameters(expansion):
    manifest, directory = expansion
    reference.attach(manifest, directory, submit=False)
    plan = json.loads(manifest.read_text())
    reference.install_parameters(plan)
    for mode in plan["modes"]:
        for model in plan["models"]:
            for direction, count in [("up", 4), ("down", 32)]:
                payload = json.loads(reference.parameter_path(plan, mode, model, direction).read_text())
                assert payload["best_params"]["n_estimators"] == count
    # A mode-specific change must be rejected before a production fit starts.
    path = reference.parameter_path(plan, "tb_k100", "tabpfn", "down")
    path.write_text("{}")
    with pytest.raises(ValueError, match="Tuned parameters differ"):
        reference.verify_parameters(plan)


def test_reference_changes_and_repeat_attachment_fail(expansion):
    manifest, directory = expansion
    reference.attach(manifest, directory, submit=False)
    plan = json.loads(manifest.read_text())
    with pytest.raises(ValueError, match="fresh, unsubmitted"):
        reference.attach(manifest, directory, submit=False)
    (directory / "tabpfn/UP/1d/best_params.json").write_text("{}")
    with pytest.raises(ValueError, match="Code changed"):
        reference.install_parameters(plan)


def test_swapped_directions_cannot_silently_use_defaults(expansion):
    manifest, directory = expansion
    plan = json.loads(manifest.read_text())
    path = directory / "rf/UP/1d/best_params.json"
    payload = json.loads(path.read_text())
    payload["direction"] = "down"
    path.write_text(json.dumps(payload))
    with pytest.raises(ValueError, match="Reference identity mismatch"):
        reference.attach(manifest, directory, submit=False)
