"""Build presentation data from the audited paper-MTM replay, retaining fitted thresholds."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "report/triple_barrier"
OUT = REPORT / "pilot_results/paper_mtm_20261029"


def main() -> None:
    original = json.loads((REPORT / "pilot_results/gpu8_four_backends/slide_data.json").read_text())
    verified = json.loads((REPORT / "pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/local_daily_baselines.json").read_text())
    audit = json.loads((OUT / "reconciliation.json").read_text())
    assert audit["all_our_m1_events_and_net_returns_equal_paper"] and audit["all_extended_positions_closed"]
    for path, digest in audit["input_trade_csv_sha256"].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
    replay = pd.read_csv(OUT / "our_48_cells_extended_mtm.csv")
    replay["direction"] = replay["direction"].str.lower()
    lookup = replay.set_index(["model", "direction", "mode"], verify_integrity=True)
    expected = {(r["model"], r["direction"], r["mode"]) for r in original["rows"]}
    assert set(lookup.index) == expected and len(expected) == 48
    rows = []
    for fit in original["rows"]:
        r = lookup.loc[(fit["model"], fit["direction"], fit["mode"])]
        assert r.source_run == fit["source_run"]
        assert int(r.n_m1) == fit["n_total_trades"] and int(r.n_m2) == fit["n_m2_trades"]
        row = {k: fit[k] for k in ["mode", "model", "direction", "source_run", "threshold", "constraint_satisfied", "n_samples_train", "fee"]}
        row.update({
            "entry_start": r.entry_start, "entry_end": r.entry_end,
            "equity_start": r.m1_equity_start, "equity_end": r.m1_equity_end,
            "n_total_trades": int(r.n_m1), "n_m2_trades": int(r.n_m2),
            "coverage_pct": float(r.coverage_pct),
            "n_bars": int(r.m1_n_bars), "n_horizon_returns": int(r.m1_n_weekly_returns),
        })
        for model in ["m1", "m2"]:
            row.update({
                f"{model}_sharpe": float(r[f"{model}_sharpe"]),
                f"{model}_total_return_pct": float(r[f"{model}_return_pct"]),
                f"{model}_max_drawdown_pct": float(r[f"{model}_max_drawdown_pct"]),
            })
        rows.append(row)
    by_cell = {(r["model"], r["direction"], r["mode"]): r for r in rows}
    for r in rows:
        for mode in ["tp", "tb_ref"]:
            ref = by_cell[r["model"], r["direction"], mode]
            for metric, stem in [("m2_sharpe", "delta_sharpe"), ("m2_total_return_pct", "delta_return_pp"), ("m2_max_drawdown_pct", "delta_max_drawdown_pp")]:
                r[f"{stem}_vs_{mode}"] = r[metric] - ref[metric]
    assert sum(not r["constraint_satisfied"] for r in rows) == 3
    baseline = {}
    for direction in ["up", "down"]:
        cohort = [r for r in rows if r["direction"] == direction]
        first = cohort[0]
        for key in ["m1_sharpe", "m1_total_return_pct", "m1_max_drawdown_pct", "n_total_trades", "n_bars", "n_horizon_returns"]:
            np.testing.assert_allclose([r[key] for r in cohort], first[key], rtol=0, atol=1e-9)
        baseline[direction] = {
            "sharpe": first["m1_sharpe"], "return_pct": first["m1_total_return_pct"],
            "max_drawdown_pct": first["m1_max_drawdown_pct"], "n_trades": first["n_total_trades"],
            **{k: first[k] for k in ["entry_start", "entry_end", "equity_start", "equity_end", "n_bars", "n_horizon_returns"]},
        }
        assert first["n_bars"] == 199 and first["n_horizon_returns"] == 28
    paper = pd.read_csv(OUT / "Output/Analysis/Backtest_ExtendedTail/MTM/mtm_before_after_all.csv")
    paper = paper[(paper.m1 == "Kronos") & (paper.gran == "1d")]
    reference = []
    for _, r in paper.iterrows():
        reference.append({
            "model": r.m2, "direction": r["dir"].lower(),
            "m1_total_return": float(r.m1_ret_mtm), "m1_max_drawdown": float(r.m1_mdd_mtm), "m1_sharpe": float(r.m1_sr_mtm),
            "m2_total_return": float(r.m2_ret_mtm), "m2_max_drawdown": float(r.m2_mdd_mtm), "m2_sharpe": float(r.m2_sr_mtm),
            "n_m1": int(r.n_m1), "n_m2": int(r.n_m2), "bh_total_return": float(r.bh_ret),
        })
    assert len(reference) == 10
    assert all(r["m2_sharpe"] < 0 for r in rows if r["direction"] == "up")
    result = {
        "engine": "cash_mtm_extended_tail", "completed": 48, "expected": 48, "status": "complete",
        "models": original["models"], "modes": original["modes"], "directions": original["directions"],
        "baseline": baseline, "rows": rows, "paper_reference": reference,
        "actual_splits": verified["checks"]["tp"]["up"]["splits"],
        "configured_splits": original["splits"], "fee": original["fee"],
        "threshold_policy": "Original fitted thresholds and approvals; the separate validation-cohort correction is not applied.",
        "tp_definition": original["tp_definition"],
        "engine_bridge": json.loads(pd.read_csv(OUT / "m1_engine_bridge.csv").to_json(orient="records")),
        "source_sha256": {name: hashlib.sha256((OUT / name).read_bytes()).hexdigest() for name in ["reconciliation.json", "our_48_cells_extended_mtm.csv", "m1_engine_bridge.csv", "Output/Analysis/Backtest_ExtendedTail/MTM/mtm_before_after_all.csv"]},
    }
    (OUT / "slide_data.json").write_text(json.dumps(result, indent=2, allow_nan=False) + "\n")
    pd.DataFrame(rows).to_csv(OUT / "reviewed_results.csv", index=False, float_format="%.10f")
    print(json.dumps({"cells": len(rows), "baselines": baseline, "fallback_cells": 3, "highest_down": max((r for r in rows if r["direction"] == "down"), key=lambda r: r["m2_sharpe"])}))


if __name__ == "__main__":
    main()
