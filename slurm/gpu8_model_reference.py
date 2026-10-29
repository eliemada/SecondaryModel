"""Attach frozen GPU8 RF/TabPFN tuning parameters to an isolated target run.

First create a dry-run manifest with gpu8_trial.py. This adds parameter checks and
real learner smoke checks to its scripts without changing the production pipeline
or the launcher used by the completed AutoGluon/Kumo run.
"""
from __future__ import annotations

import argparse
import json
import shlex
import shutil
from pathlib import Path

import numpy as np

import gpu8_trial as trial


def load_reference(plan: dict, directory: Path) -> dict:
    references = {}
    for model in plan["models"]:
        if model not in {"rf", "tabpfn"}:
            raise ValueError(f"This extension requires RF/TabPFN reference parameters: {model}")
        references[model] = {}
        for direction in plan["directions"]:
            path = directory / model / direction.upper() / "1d/best_params.json"
            payload = json.loads(path.read_text())
            if (payload.get("model"), payload.get("direction"), payload.get("granularity")) != (model, direction, "1d"):
                raise ValueError(f"Reference identity mismatch: {path}")
            if not payload.get("best_params"):
                raise ValueError(f"Missing tuned parameters: {path}")
            references[model][direction] = {"path": str(path.relative_to(trial.PROJECT)),
                                            "sha256": trial.sha(path), "best_params": payload["best_params"]}
    return references


def parameter_path(plan: dict, mode: str, model: str, direction: str) -> Path:
    return trial.SRC / plan["output_root_base"] / mode / "Kronos/HPO_NoCal" / model / direction.upper() / "1d/best_params.json"


def verify_parameters(plan: dict) -> None:
    trial.verify_code(plan)
    for mode in plan["modes"]:
        for model, directions in plan["reference_hpo"].items():
            for direction, reference in directions.items():
                path = parameter_path(plan, mode, model, direction)
                if trial.sha(path) != reference["sha256"]:
                    raise ValueError(f"Tuned parameters differ from GPU8: {path}")


def install_parameters(plan: dict) -> None:
    from Utils.utils import _load_best_params
    import yaml

    trial.verify_code(plan)
    for mode in plan["modes"]:
        cfg = yaml.safe_load((trial.SRC / plan["output_root_base"] / "configs" / f"{mode}.yaml").read_text())
        for model, directions in plan["reference_hpo"].items():
            for direction, reference in directions.items():
                target = parameter_path(plan, mode, model, direction)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(trial.PROJECT / reference["path"], target)
                if _load_best_params(cfg, model, direction, "1d") != reference["best_params"]:
                    raise ValueError("Production loader did not read the copied GPU8 parameters")
    verify_parameters(plan)


def prepare(plan: dict, folder: Path) -> None:
    from Utils.classifier.factory import _build_tree_model
    import torch

    install_parameters(plan)
    rng = np.random.default_rng(42)
    x = rng.normal(size=(160, 6)).astype(np.float32)
    y = (x[:, 0] + x[:, 1] > 0).astype(int)
    checks = []
    for model, directions in plan["reference_hpo"].items():
        for direction, reference in directions.items():
            learner = _build_tree_model(model, len(y), params=reference["best_params"])
            learner.fit(x, y)
            probabilities = learner.predict_proba(x[:8])
            if probabilities.shape != (8, 2) or not np.isfinite(probabilities).all() or not np.allclose(probabilities.sum(axis=1), 1, atol=1e-5):
                raise ValueError(f"Invalid smoke predictions: {model}/{direction}")
            effective = learner.get_params()
            checks.append({"model": model, "direction": direction, "status": "fit/predict passed",
                           "effective_parameters": effective,
                           "reference_keys_not_forwarded_by_original_factory": sorted(set(reference["best_params"]) - set(effective))})
            print("REFERENCE LEARNER VERIFIED", model, direction, flush=True)
            del learner
            torch.cuda.empty_cache()
    trial.save(folder / "backend_reference_checks.json", checks)


def attach(manifest: Path, directory: Path, submit: bool) -> None:
    plan = json.loads(manifest.read_text())
    folder = manifest.parent
    if (folder / "jobs.json").exists() or plan.get("reference_hpo"):
        raise ValueError("Only attach parameters to a fresh, unsubmitted dry run")
    plan["reference_hpo"] = load_reference(plan, directory)
    paths = [Path(__file__), directory / "provenance.json"]
    paths += [trial.PROJECT / r["path"] for ds in plan["reference_hpo"].values() for r in ds.values()]
    for path in paths:
        plan["code_sha256"][str(path.relative_to(trial.PROJECT))] = trial.sha(path)
    plan["extends_run"] = "gpu8-targets-20261028-104504"
    plan["parameter_policy"] = "GPU8 HPO_NoCal parameters, fixed by backend/direction across all six targets; no new HPO. Original factory mapping is unchanged."
    command = lambda stage: shlex.join([str(trial.PROJECT / ".venv/bin/python"), str(Path(__file__)), stage, "--manifest", str(manifest)])
    prep_path, train_path = folder / "prepare.sh", folder / "train.sh"
    prep = prep_path.read_text().replace("#SBATCH --mem=64G", "#SBATCH --mem=16G").replace("#SBATCH --time=00:45:00", "#SBATCH --time=00:30:00")
    prep += command("prepare") + "\n"
    train = train_path.read_text().replace("#SBATCH --time=03:00:00", "#SBATCH --time=01:00:00")
    lines = train.splitlines()
    matches = [i for i, line in enumerate(lines) if str(trial.PROJECT / "slurm/gpu8_trial.py") in line and " train " in line]
    if len(matches) != 1:
        raise ValueError("Unexpected generated training script")
    lines.insert(matches[0], command("verify"))
    trial.save(manifest, plan)
    prep_path.write_text(prep)
    train_path.write_text("\n".join(lines) + "\n")
    print("Attached frozen GPU8 parameters", manifest, flush=True)
    if not submit:
        return
    jobs = {}
    for stage in ("prepare", "train", "report"):
        args = ["sbatch", "--parsable"]
        dependency = "prepare" if stage == "train" else "train" if stage == "report" else None
        if dependency:
            args.append(f"--dependency=afterok:{jobs[dependency]}")
        args.append(str(folder / f"{stage}.sh"))
        jobs[stage] = trial.run(args, capture_output=True, text=True).stdout.strip()
        trial.save(folder / "jobs.json", jobs)
    print(json.dumps({"run_id": plan["run_id"], "new_fits": len(plan["tasks"]) * 2, "jobs": jobs}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["attach", "prepare", "verify"])
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--reference-dir", type=Path)
    parser.add_argument("--submit", action="store_true")
    args = parser.parse_args()
    manifest = args.manifest.resolve()
    if args.stage == "attach":
        if args.reference_dir is None:
            parser.error("attach requires --reference-dir")
        attach(manifest, args.reference_dir.resolve(), args.submit)
    else:
        import os
        os.chdir(trial.SRC)
        plan = json.loads(manifest.read_text())
        if args.stage == "prepare":
            prepare(plan, manifest.parent)
        else:
            verify_parameters(plan)
