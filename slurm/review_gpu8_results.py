"""Verify a downloaded GPU8 target run and export evidence for the presentation.

Uses the frozen production engine and saved approval flags. Does not fit models,
select k, change execution, or replace the reported metrics with replay values.
Run with the project's Python environment and the downloaded run/data available.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "src"))

from Data_MLA.meta_label_tb import eligibility_mask
from tb_pilot.compare import backtest_key, check_parity, economics_table, load_mode_run, mode_run_dir
from Utils.backtest.engine import (
    _annualization_factor, _build_spread_equity, _calc_drawdown,
    _calc_sharpe, _equity_horizon_returns, _load_raw_close_prices,
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(run_id: str, output: Path) -> None:
    output = output.resolve()
    os.chdir(REPO / "src")
    logs = REPO / "slurm/logs" / run_id
    plan = json.loads((logs / "manifest.json").read_text())
    cfg, root = plan["config"], plan["output_root_base"]
    horizon = cfg["data"]["load"]["forecast_horizon"]
    receipt = json.loads((Path(root) / "sync_receipt.json").read_text())
    expected = {(m, b, d) for m in plan["modes"] for b in plan["models"] for d in plan["directions"]}
    assert receipt["received_fit_summaries"] == receipt["expected_fits"] == len(expected)
    assert len(receipt["job_states"]) == len(plan["tasks"]) + 2
    assert all(s == {"state": "COMPLETED", "exit_code": "0:0"} for s in receipt["job_states"].values())
    assert not cfg["evaluation"].get("val_backtest", False)
    assert cfg["runtime"]["training"]["thres"] == "utility_nocal"
    for name, digest in plan["code_sha256"].items():
        assert sha(REPO / name) == digest, f"Source changed: {name}"

    # Validate the local daily inputs against the frozen cluster submission.
    daily_files = {name: digest for name, digest in plan["data_sha256"].items() if "/1d_tp/" in name}
    assert len(daily_files) == 40
    excluded = []
    for name, digest in daily_files.items():
        path = REPO / name
        assert sha(path) == digest, f"Input changed: {name}"
        frame = pd.read_csv(path)
        dates = pd.to_datetime(frame.date)
        mask = ((frame.pred == 1) & ~eligibility_mask(frame, horizon, 120)
                & dates.between(cfg["data"]["split"]["start_date"], cfg["data"]["split"]["train_end"]))
        if mask.any():
            excluded.append({"asset": path.stem.rsplit("_", 1)[0], "direction": path.stem.rsplit("_", 1)[1],
                             "n_removed_train": int(mask.sum()), "first": str(dates[mask].min().date()),
                             "last": str(dates[mask].max().date())})
    labels = json.loads((Path(root) / "labels/Kronos/horizon_7/manifest.json").read_text())
    for name, digest in labels["files"].items():
        assert sha(Path(name)) == digest, f"Generated labels changed: {name}"
    checks = json.loads((logs / "baseline_checks.json").read_text())
    runs, sources, replay, extra = [], {}, [], []
    for model in plan["models"]:
        for direction in plan["directions"]:
            for mode in plan["modes"]:
                directory = mode_run_dir(cfg, mode, model, direction, "1d", root)
                run = load_mode_run(cfg, mode, model, direction, "1d", "10_backtest_all", root)
                assert (run.summary["model"], run.summary["direction"], run.summary["meta_label_mode"]) == (model, direction, mode)
                for name in ("analysis_summary.json", "10_backtest_all_trades.csv"):
                    sources[str(directory / name)] = sha(directory / name)
                runs.append(run)
    assert {(r.mode, r.model, r.direction) for r in runs} == expected
    baseline = {}
    for direction in plan["directions"]:
        cohort = [r for r in runs if r.direction == direction]
        check_parity(cohort, "test", root)
        tp = next(r for r in cohort if r.mode == "tp")
        tp_stats = tp.summary[backtest_key(tp.model, "test")]
        original = checks["tp"][direction]
        start, end = tp.trades.date.min(), tp.trades.date.max()
        raw = _load_raw_close_prices(cfg, "1d", direction)
        timeline = pd.DatetimeIndex(sorted(raw.loc[raw.date.between(start, end), "date"].unique()))
        assert len(timeline) == original["n_calendar_bars"] == 192
        removed = sum(x["n_removed_train"] for x in excluded if x["direction"] == direction)
        for run in cohort:
            bt = run.summary[backtest_key(run.model, "test")]
            prep = checks[run.mode][direction]
            for split in ("idx_cal", "idx_opt"):
                assert prep["splits"][split] == original["splits"][split]
            assert prep["test_pairs_sha256"] == original["test_pairs_sha256"]
            assert run.summary["n_samples_train"] == prep["splits"]["idx_train"]["n"]
            assert run.summary["n_samples_train"] == tp.summary["n_samples_train"] - (0 if run.mode == "tp" else removed)
            tail_removed = original["dropped_nan_test_returns"] if run.mode != "tp" else 0
            assert run.summary["n_samples_total"] == tp.summary["n_samples_total"] - (removed if run.mode != "tp" else 0) - tail_removed
            for key in ("m1_sharpe", "m1_total_return", "m1_max_drawdown", "n_total_trades"):
                assert np.isclose(bt[key], original["stats"][key], atol=1e-4, rtol=0)
            trades = run.trades
            assert trades["m2_approved"].dtype == bool and trades["return"].notna().all()
            assert int(trades.m2_approved.sum()) == bt["n_m2_trades"]
            assert np.isclose(100 * trades.m2_approved.mean(), bt["execution_rate"], atol=.005, rtol=0)
            assert bt["fee"] == cfg["evaluation"]["fee_per_trade"] == .002
            assert np.allclose(trades.m2_prob, trades.m2_prob_raw, atol=0, rtol=0)
            # CSV probabilities are rounded to six decimals. Check decisions
            # outside that rounding interval against the full-precision threshold.
            margin = trades.m2_prob - bt["threshold"]
            unambiguous = margin.abs() > 5.1e-7
            assert np.array_equal(trades.loc[unambiguous, "m2_approved"], margin[unambiguous] >= 0)
            # Both CSV columns have six decimals, so return_pct retains two more
            # decimal places of the underlying fractional return. Cross-check
            # them and use that precision to avoid accumulated rounding noise.
            precise = trades.copy()
            precise["return"] = precise["return_pct"] / 100
            assert np.allclose(precise["return"], trades["return"], atol=5.1e-7, rtol=0)
            for strategy, frame in (("m1", precise), ("m2", precise[precise.m2_approved])):
                equity, _ = _build_spread_equity(frame, timeline, horizon)
                returns = _equity_horizon_returns(equity, horizon)
                assert len(returns) == 27
                metrics = {f"{strategy}_sharpe": _calc_sharpe(returns, _annualization_factor("1d") / np.sqrt(horizon)),
                           f"{strategy}_total_return": (equity.iloc[-1] - 1) * 100,
                           f"{strategy}_max_drawdown": _calc_drawdown(equity.to_numpy()) * 100}
                for key, value in metrics.items():
                    error = abs(value - bt[key])
                    assert error < .0001, (run.mode, run.model, direction, key, value, bt[key])
                    replay.append({"mode": run.mode, "model": run.model, "direction": direction,
                                   "metric": key, "reported": bt[key], "replayed": value, "abs_error": error})
            extra.append({"mode": run.mode, "model": run.model, "direction": direction,
                          "threshold": bt["threshold"], "constraint_satisfied": bt["constraint_satisfied"],
                          "n_samples_train": run.summary["n_samples_train"]})
        baseline[direction] = {"sharpe": tp_stats["m1_sharpe"], "return_pct": tp_stats["m1_total_return"],
                               "max_drawdown_pct": tp_stats["m1_max_drawdown"], "n_trades": len(tp.trades),
                               "period_start": str(start.date()), "period_end": str(end.date()),
                               "n_bars": len(timeline), "n_horizon_returns": 27}

    table = economics_table(runs, "test").merge(pd.DataFrame(extra), on=["mode", "model", "direction"], validate="one_to_one")
    for reference in ("tp", "tb_ref"):
        ref = table[table["mode"] == reference].set_index(["model", "direction"])
        for source, label in (("m2_sharpe", "sharpe"), ("m2_total_return_pct", "return_pp"), ("m2_max_drawdown_pct", "max_drawdown_pp")):
            table[f"delta_{label}_vs_{reference}"] = [r[source] - ref.loc[(r.model, r.direction), source] for _, r in table.iterrows()]
    cluster_table = pd.read_csv(Path(root) / "comparison/experiment_test.csv")
    assert len(cluster_table) == len(table)
    indexed = table.set_index(["mode", "model", "direction"])
    for _, row in cluster_table.iterrows():
        local = indexed.loc[(row["mode"], row.model, row.direction)]
        for key in ("m2_sharpe", "m1_sharpe", "m2_total_return_pct", "m2_max_drawdown_pct", "delta_sharpe_vs_tp"):
            assert np.isclose(row[key], local[key], atol=1e-8, rtol=0)

    output.mkdir(parents=True, exist_ok=True)
    data = {"run_id": run_id, "reviewed_at": datetime.now(UTC).isoformat(), "downloaded_at": receipt["synced_at"],
            "status": "complete", "completed": len(runs), "expected": len(expected), "models": plan["models"],
            "modes": plan["modes"], "directions": plan["directions"], "splits": cfg["data"]["split"],
            "fee": cfg["evaluation"]["fee_per_trade"], "threshold_method": "utility_nocal",
            "baseline": baseline, "rows": json.loads(table.to_json(orient="records")),
            "eligibility_exclusions": excluded, "metric_replay_count": len(replay),
            "max_replay_error": max(r["abs_error"] for r in replay), "job_states": receipt["job_states"],
            "interpretation": "Exploratory fixed-day-7 target comparison; deltas vs TP include eligibility differences. Use TB-ref for the matched label contrast. No significance or optimal-k claim."}
    (output / "slide_data.json").write_text(json.dumps(data, indent=2) + "\n")
    (output / "verification.json").write_text(json.dumps({"run_id": run_id, "code_files_verified": len(plan["code_sha256"]),
        "daily_input_files_verified": len(daily_files), "generated_label_files_verified": len(labels["files"]),
        "return_source": "return_pct / 100, checked against the six-decimal return column",
        "result_sha256": sources, "metric_replays": replay, "max_abs_error": data["max_replay_error"]}, indent=2) + "\n")
    table.to_csv(output / "experiment_test.csv", index=False)
    print(json.dumps({"completed": len(runs), "verified_metrics": len(replay), "max_abs_error": data["max_replay_error"],
                      "eligibility_exclusions": excluded, "output": str(output)}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", default="gpu8-targets-20261028-104504")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    verify(args.run_id, args.output)
