"""Submit the daily target matrix using Pablo's pinned pipeline and date cutoffs.

Preparation verifies the environment and M1 Test baseline before any production fit.
Explicit --m2 overrides choose the experiment backends without altering the base YAML.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata as metadata
import json
import os
import shlex
import subprocess
import sys
import tempfile
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

PROJECT = Path(__file__).resolve().parents[1]
SRC = PROJECT / "src"
sys.path.insert(0, str(SRC))
REVISION = "5b61d0880a447dcc81b76169b6dbc59b2fd02276"
MODES = ["tp", "tb_ref", "tb_k050", "tb_k100", "tb_k150", "tb_k200"]


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def save(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, default=str))


def run(argv: list[str], **kwargs):
    print("RUN", shlex.join(map(str, argv)), flush=True)
    return subprocess.run(list(map(str, argv)), check=True, **kwargs)


def verify_code(plan: dict) -> None:
    for rel, expected in plan["code_sha256"].items():
        if sha(PROJECT / rel) != expected:
            raise ValueError(f"Code changed after submission: {rel}")


def environment(smoke: bool) -> dict:
    import torch

    reference = json.loads((PROJECT / "slurm/gpu8_environment_reference.json").read_text())
    normalize = lambda name: name.lower().replace("_", "-").replace(".", "-")
    observed = {normalize(d.metadata["Name"]): d.version for d in metadata.distributions() if d.metadata["Name"]}
    expected = {normalize(k): v for k, v in reference["packages"].items()}
    required = ["numpy", "pandas", "scipy", "scikit-learn", "torch", "pyarrow", "lightgbm", "catboost",
                "autogluon-tabular", "autogluon-core", "autogluon-common", "autogluon-features",
                "xgboost", "tabpfn", "tabicl"]
    for name in required:
        if observed.get(name, "").split("+")[0] != expected[name].split("+")[0]:
            raise ValueError(f"GPU8 package mismatch: {name}: {observed.get(name)} != {expected[name]}")
    for name in ("ray", "fastai"):
        if (name in observed) != (name in expected):
            raise ValueError(f"Optional learner availability differs for {name}")
    if not torch.cuda.is_available():
        raise RuntimeError("A GPU allocation is required")
    result = {"python": sys.version, "gpu8_python": reference["python"], "packages": observed,
              "cuda": torch.version.cuda, "gpu": torch.cuda.get_device_name(0),
              "notes": ["Python patch release and hardware may differ; exact package versions above are enforced.",
                        "NumPy/Arrow override AutoGluon metadata bounds to match the observed GPU8 environment."]}
    if smoke:
        from autogluon.tabular import TabularPredictor
        from Utils.classifier.kumo_tabular_classifier import KumoTabularClassifier

        rng = np.random.default_rng(42)
        x = rng.normal(size=(160, 6)).astype(np.float32)
        y = (x[:, 0] + x[:, 1] > 0).astype(int)
        data = pd.DataFrame(x, columns=[f"f{i}" for i in range(x.shape[1])])
        data["target"] = y
        with tempfile.TemporaryDirectory(prefix="gpu8-smoke-") as folder:
            predictor = TabularPredictor(label="target", path=folder, verbosity=0).fit(
                data, hyperparameters={"GBM": {"num_boost_round": 8}, "CAT": {"iterations": 8}},
                time_limit=60, num_cpus=4, num_gpus=0)
            names = predictor.model_names()
            if not any("LightGBM" in n for n in names) or not any("CatBoost" in n for n in names):
                raise RuntimeError(f"Required AutoGluon learners did not train: {names}")
            result["smoke_models"] = names
        kumo = KumoTabularClassifier()
        kumo.fit(x, y)
        probabilities = kumo.predict_proba(x[:8])
        assert probabilities.shape == (8, 2) and np.isfinite(probabilities).all()
        assert np.allclose(probabilities.sum(axis=1), 1, atol=1e-5)
        result["kumo_smoke"] = "fit/predict passed"
        del kumo
        torch.cuda.empty_cache()
    return result


def baseline(dataset, cfg: dict, direction: str, reference: dict) -> dict:
    from Utils.utils import _filter_dataset_by_granularity
    from Utils.edge import _compute_embargo_splits
    from Utils.backtest.engine import (_load_raw_close_prices, _build_spread_equity, _build_cash_equity,
                                       _calc_sharpe, _calc_drawdown, _equity_horizon_returns, _annualization_factor)

    ds = _filter_dataset_by_granularity(dataset, "1d")
    labels = ds["labels"].numpy()
    valid = np.flatnonzero(~np.isnan(labels))
    dates = pd.DatetimeIndex(ds["dates"])
    h = cfg["data"]["load"]["forecast_horizon"]
    splits = _compute_embargo_splits(dates[valid], cfg["data"]["split"]["train_end"],
                                     cfg["data"]["split"]["val_end"], h, "1d")
    index = valid[splits["idx_test"]]
    returns = ds["returns"].numpy()[index].copy()
    if direction == "down":
        returns = -returns
    trades = pd.DataFrame({"date": dates[index], "return": returns - cfg["evaluation"]["fee_per_trade"],
                           "asset": [ds["asset_map"].get(int(a), str(a)) for a in ds["asset_ids"].numpy()[index]]})
    # Match run_feature_backtest: drop unavailable realized returns BEFORE choosing
    # the equity calendar. In particular, the final horizon can have labels but
    # no realized return. Passing those rows to _build_spread_equity poisons it.
    n_nan_returns = int(trades["return"].isna().sum())
    trades = trades.dropna(subset=["return"]).reset_index(drop=True)
    if trades.empty:
        raise ValueError(f"No realized Test returns for {direction}")
    raw = _load_raw_close_prices(cfg, "1d", direction)
    close = raw[raw.date.between(trades.date.min(), trades.date.max())].pivot_table(index="date", columns="asset", values="close")
    equity, _ = _build_spread_equity(trades, close.index, h)
    stats = {"m1_total_return": (equity.iloc[-1] - 1) * 100,
             "m1_max_drawdown": _calc_drawdown(equity.values) * 100,
             "m1_sharpe": _calc_sharpe(_equity_horizon_returns(equity, h), _annualization_factor("1d") / np.sqrt(h)),
             "n_total_trades": len(trades)}
    for name, value in stats.items():
        if not np.isclose(value, reference[name], atol=0.0001, rtol=0):
            raise ValueError(f"M1 baseline mismatch ({direction}, {name}): {value} vs GPU8 {reference[name]}")
    result = {"stats": stats, "first_test_entry": str(trades.date.min()), "last_test_entry": str(trades.date.max()),
              "dropped_nan_test_returns": n_nan_returns, "n_calendar_bars": len(close.index),
              "n_horizon_returns": len(_equity_horizon_returns(equity, h)),
              "test_pairs_sha256": hashlib.sha256(trades.sort_values(["date", "asset"])[["date", "asset"]].to_csv(index=False).encode()).hexdigest(),
              "splits": {name: {"n": len(indices), "first": str(dates[valid[indices]].min()),
                                  "last": str(dates[valid[indices]].max())}
                         for name, indices in splits.items() if name.startswith("idx_")}}
    cash, _ = _build_cash_equity(trades, close.index, h, flat_size=True, close=close,
                                fee=cfg["evaluation"]["fee_per_trade"], direction=direction)
    result["cash_m1"] = {"return_pct": (cash.iloc[-1] - 1) * 100, "max_drawdown_pct": _calc_drawdown(cash.values) * 100}
    print("BASELINE VERIFIED", direction, json.dumps(result, default=str), flush=True)
    return result


def prepare(plan: dict, folder: Path) -> None:
    from Utils.utils import _build_cache_from_config
    from tb_pilot.make_configs import write_mode_configs

    verify_code(plan)
    for rel, expected in plan["data_sha256"].items():
        if sha(PROJECT / rel) != expected:
            raise ValueError(f"Input differs from GPU8: {rel}")
    save(folder / "environment.json", environment(smoke=True))
    root = Path(plan["output_root_base"])
    labels = root / "labels/Kronos/horizon_7"
    run([sys.executable, "-m", "Data_MLA.meta_label_tb", "--src",
         str(Path(plan["config"]["paths"]["csv_dir"]) / "1d_tp"), "--dst", str(labels), "--ref",
         "--ks", "0.5", "1", "1.5", "2", "--config", str(folder / "config.yaml"), "--h", "7", "--fee", "0.002"])
    configs = write_mode_configs(plan["config"], MODES, str(labels), root / "configs", output_root_base=str(root))
    reference = json.loads((PROJECT / "slurm/gpu8_reference.json").read_text())
    caches, checks = {}, {}
    for mode in MODES:
        cfg = yaml.safe_load(configs[mode].read_text())
        caches[mode], checks[mode] = {}, {}
        for direction in plan["directions"]:
            path, dataset = _build_cache_from_config(cfg, direction)
            saved = reference["outputs"][f"autogluon/{direction.upper()}"]["summary"]["autogluon_backtest_all_features"]
            checks[mode][direction] = baseline(dataset, cfg, direction, saved)
            caches[mode][direction] = {"path": str(path), "sha256": sha(path)}
            del dataset
    for direction in plan["directions"]:
        assert len({checks[mode][direction]["test_pairs_sha256"] for mode in MODES}) == 1
    save(folder / "cache_paths.json", caches)
    save(folder / "baseline_checks.json", checks)
    print("PREPARE PASSED: every mode reproduces the GPU8 M1 baseline; production fits may begin.", flush=True)


def train(plan: dict, folder: Path, task: int) -> None:
    verify_code(plan)
    environment(smoke=False)
    arm = plan["tasks"][task]
    caches = json.loads((folder / "cache_paths.json").read_text())
    for direction in plan["directions"]:
        cache = caches[arm["mode"]][direction]
        if sha(Path(cache["path"])) != cache["sha256"]:
            raise ValueError("Dataset cache changed after the verified baseline")
        argv = [sys.executable, "m2_pipeline.py", "--config", f"{plan['output_root_base']}/configs/{arm['mode']}.yaml",
                "--phase", "training", "--m2", arm["model"], "--direction", direction,
                "--granularity", "1d", "--cache_path", cache["path"]]
        run(argv)
    print("TASK COMPLETE", arm, flush=True)


def report(plan: dict, folder: Path) -> None:
    verify_code(plan)
    run([sys.executable, "-m", "tb_pilot.compare", "--phase", "experiment", "--config", str(folder / "config.yaml"),
         "--manifest", f"{plan['output_root_base']}/labels/Kronos/horizon_7/manifest.json",
         "--modes", *MODES, "--models", *plan["models"], "--directions", *plan["directions"],
         "--granularity", "1d", "--output-root-base", plan["output_root_base"],
         "--output-dir", f"{plan['output_root_base']}/comparison"])


def submit(models: list[str], dry_run: bool) -> None:
    from tb_pilot.schemas import SecondaryModelConfig

    cfg = yaml.safe_load((SRC / "config.yaml").read_text())
    reference_cfg = yaml.safe_load((PROJECT / "slurm/gpu8_config_reference.yaml").read_text())
    reference_cfg["paths"] = cfg["paths"]
    assert cfg == reference_cfg, "Config settings differ from GPU8"
    SecondaryModelConfig.model_validate(cfg)
    reference = json.loads((PROJECT / "slurm/gpu8_reference.json").read_text())
    # Source parity is checked against the observed GPU8 checkout, not just a branch label.
    for rel, expected in reference["source_sha256"].items():
        if rel not in ("src/config.yaml", "src/Utils/classifier/factory.py") and sha(PROJECT / rel) != expected:
            raise ValueError(f"Pablo source mismatch: {rel}")
    run_id = datetime.now(UTC).strftime("gpu8-targets-%Y%m%d-%H%M%S")
    folder = PROJECT / "slurm/logs" / run_id
    folder.mkdir(parents=True)
    (folder / "config.yaml").write_text((SRC / "config.yaml").read_text())
    paths = [*SRC.rglob("*.py"), Path(__file__), PROJECT / "pyproject.toml", PROJECT / "uv.lock",
             *[PROJECT / "slurm" / name for name in ("gpu8_config_reference.yaml", "gpu8_environment_reference.json", "gpu8_reference.json")]]
    tasks = [{"mode": mode, "model": model} for mode in MODES for model in models]
    plan = {"run_id": run_id, "gpu8_revision": REVISION, "config": cfg, "models": models,
            "modes": MODES, "directions": ["up", "down"], "granularity": "1d", "tasks": tasks,
            "output_root_base": f"Output_gpu8match/{run_id}", "data_sha256": reference["data_sha256"],
            "code_sha256": {str(p.relative_to(PROJECT)): sha(p) for p in paths},
            "scope": "Training and Test backtests only; 1d CLI override; explicit model grid. No HPO, edge or regime analysis jobs.",
            "extensions": ["Kumo factory registration and wrapper", "TB label generator/config/report helpers"],
            "purpose": "Exploratory target matrix on the GPU8 dates; this Test is already inspected."}
    manifest = folder / "manifest.json"
    save(manifest, plan)
    def script(stage: str, time_limit: str, memory: str, extra: list[str]) -> Path:
        path = folder / f"{stage}.sh"
        directives = ["#!/bin/bash", f"#SBATCH --job-name=gpu8-target-{stage}", "#SBATCH --partition=gpu",
                      "#SBATCH --qos=normal", "#SBATCH --gres=gpu:1", "#SBATCH --cpus-per-task=8",
                      f"#SBATCH --mem={memory}", f"#SBATCH --time={time_limit}",
                      f"#SBATCH --output={folder}/{stage}-%A_%a.out", f"#SBATCH --error={folder}/{stage}-%A_%a.err", *extra]
        command = shlex.join([str(PROJECT / ".venv/bin/python"), str(Path(__file__)), stage, "--manifest", str(manifest)])
        if stage == "train":
            command += ' --task "$SLURM_ARRAY_TASK_ID"'
        lines = [*directives, "set -euo pipefail", f"cd {shlex.quote(str(SRC))}",
                 'export HF_HOME="/scratch/izar/enbruno/.cache/huggingface"',
                 'export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-8}"', 'export KMP_DUPLICATE_LIB_OK=TRUE',
                 'export PYTHONUNBUFFERED=1', command]
        path.write_text("\n".join(lines) + "\n")
        return path
    prep = script("prepare", "00:45:00", "64G", [])
    sweep = script("train", "03:00:00", "32G", [f"#SBATCH --array=0-{len(tasks)-1}%8"])
    summary = script("report", "00:15:00", "8G", [])
    if dry_run:
        print("DRY RUN", manifest)
        return
    jobs = {}
    jobs["prepare"] = run(["sbatch", "--parsable", str(prep)], capture_output=True, text=True).stdout.strip()
    jobs["train"] = run(["sbatch", "--parsable", f"--dependency=afterok:{jobs['prepare']}", str(sweep)], capture_output=True, text=True).stdout.strip()
    jobs["report"] = run(["sbatch", "--parsable", f"--dependency=afterok:{jobs['train']}", str(summary)], capture_output=True, text=True).stdout.strip()
    save(folder / "jobs.json", jobs)
    print(json.dumps({"run_id": run_id, "fits": len(tasks) * 2, "jobs": jobs, "manifest": str(manifest)}, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["submit", "prepare", "train", "report"])
    parser.add_argument("--models", nargs="+", default=["autogluon", "kumo"])
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--task", type=int)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    os.chdir(SRC)
    if args.stage == "submit":
        submit(args.models, args.dry_run)
    else:
        plan = json.loads(args.manifest.read_text())
        folder = args.manifest.parent
        if args.stage == "prepare":
            prepare(plan, folder)
        elif args.stage == "train":
            train(plan, folder, args.task)
        else:
            report(plan, folder)


if __name__ == "__main__":
    main()
