"""Reconcile saved TB-pilot predictions with Pablo's extended-tail MTM paper table.

No fitting, threshold selection, or production-file edits. Run from the thesis root:
    code/SecondaryModel/.venv/bin/python report/triple_barrier/analysis/reconcile_paper_mtm.py
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[3]
REPO = ROOT / "code/SecondaryModel-gpu8"
SRC = REPO / "src"
EVIDENCE = ROOT / "report/triple_barrier/pilot_results/paper_mtm_20261029"
MTM = EVIDENCE / "Output/Analysis/Backtest_ExtendedTail/MTM"
RUNS = ["gpu8-targets-20261028-104504", "gpu8-targets-20261029-030611"]
H = 7


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_trades(path: Path) -> pd.DataFrame:
    tr = pd.read_csv(path, parse_dates=["date"]).sort_values("date")
    assert not tr.duplicated(["date", "asset"]).any(), path
    assert tr["return"].notna().all(), path
    assert tr["m2_approved"].dtype == bool, path
    return tr


def events(tr: pd.DataFrame) -> pd.Series:
    return tr.set_index(["date", "asset"])["return"].sort_index()


def main() -> None:
    # Bind this audit to the downloaded source and both completed experiments.
    provenance = json.loads((EVIDENCE / "provenance.json").read_text())
    for record in provenance["files"]:
        assert sha(EVIDENCE / record["local"]) == record["sha256"], record["local"]
    assert sha(SRC / "Utils/backtest/engine.py") == sha(EVIDENCE / "Utils/backtest/engine.py")
    manifests = []
    for run in RUNS:
        manifest = json.loads((REPO / "slurm/runs" / run / "manifest.json").read_text())
        for name, digest in manifest["code_sha256"].items():
            assert sha(REPO / name) == digest, name
        manifests.append(manifest)
    data_hashes = json.loads((EVIDENCE / "daily_data_sha256.json").read_text())
    data_root = SRC / "Data_MLA/Kronos/Crypto/TP/horizon_7/1d_tp"
    assert {p.name: sha(p) for p in data_root.glob("*.csv")} == data_hashes["sha256"]

    sys.path.insert(0, str(SRC))
    from Utils.backtest import engine

    ann = np.sqrt(engine._annualization_factor("1d") ** 2 / H)

    def stats(eq: pd.Series) -> dict:
        returns = engine._equity_horizon_returns(eq, H)
        return {
            "return_pct": float((eq.iloc[-1] - 1) * 100),
            "max_drawdown_pct": float(engine._calc_drawdown(eq.values) * 100),
            "sharpe": float(engine._calc_sharpe(returns, ann)),
            "n_bars": len(eq),
            "n_weekly_returns": len(returns),
            "equity_start": str(eq.index[0].date()),
            "equity_end": str(eq.index[-1].date()),
        }

    def cash(tr: pd.DataFrame, prices: pd.DataFrame, *, flat: bool, mtm: bool) -> dict:
        kwargs = {"close": prices} if mtm else {}
        eq, realized, ledger = engine._build_cash_equity(
            tr, prices.index, H, flat_size=flat, capital_log=True, **kwargs
        )
        return {
            **stats(eq),
            "n_open_final": int(ledger["n_open"].iloc[-1]),
            "n_realized": len(realized),
        }

    cfg = yaml.safe_load((EVIDENCE / "config.yaml").read_text())
    cfg["paths"]["csv_dir"] = str(data_root.parent)
    cfg["data"]["load"]["meta_label_mode"] = "tp"
    raw = {d: engine._load_raw_close_prices(cfg, "1d", direction=d.lower()) for d in ["UP", "DOWN"]}

    def prices_for(tr: pd.DataFrame, direction: str, extended: bool) -> pd.DataFrame:
        r = raw[direction]
        bars = pd.DatetimeIndex(sorted(r["date"].unique()))
        start, end = tr["date"].min(), tr["date"].max()
        if extended:
            end = bars[min(bars.searchsorted(end, side="left") + H, len(bars) - 1)]
        return r[(r["date"] >= start) & (r["date"] <= end)].pivot_table(
            index="date", columns="asset", values="close"
        )

    before = pd.read_csv(MTM / "mtm_before_after_all.csv")
    roi = pd.read_csv(MTM / "roi_ext_mtm.csv")
    assert len(before) == len(roi) == 280
    full = before.set_index(["m1", "m2", "dir", "gran"]).sort_index()
    table = roi.set_index(["b", "m", "d", "g"]).sort_index()
    assert full.index.to_list() == table.index.to_list()
    table_columns = {
        "r1": "m1_ret_mtm", "dd1": "m1_mdd_mtm", "s1": "m1_sr_mtm",
        "r2": "m2_ret_mtm", "dd2": "m2_mdd_mtm", "s2": "m2_sr_mtm", "bh": "bh_ret",
    }
    for a, b in table_columns.items():
        np.testing.assert_allclose(table[a], full[b], rtol=0, atol=0.00501)
    for model in ["m1", "m2"]:
        np.testing.assert_allclose(before[f"{model}_ret_book"], before[f"{model}_ret_mtm"], rtol=0, atol=1e-9)

    paper_replays = []
    references = {}
    for model in ["rf", "tabpfn", "autogluon", "tabicl", "ctts"]:
        for direction in ["UP", "DOWN"]:
            path = EVIDENCE / f"Output/Kronos/{model}/{direction}/Utility_Score_NoCal/1d_tp/10_backtest_cash_trades.csv"
            tr = read_trades(path)
            expected = full.loc[("Kronos", model, direction, "1d")]
            assert len(tr) == expected.n_m1
            assert int(tr.m2_approved.sum()) == expected.n_m2
            if direction in references:
                pd.testing.assert_series_equal(events(tr), events(references[direction]), check_exact=True)
            else:
                references[direction] = tr
            prices = prices_for(tr, direction, True)
            row = {"model": model, "direction": direction, "n_m1": len(tr), "n_m2": int(tr.m2_approved.sum())}
            for tag in ["book", "mtm"]:
                for name, subset in [("m1", tr), ("m2", tr[tr.m2_approved])]:
                    result = cash(subset, prices, flat=name == "m1", mtm=tag == "mtm")
                    assert result["n_open_final"] == 0
                    for metric, short in [("return_pct", "ret"), ("max_drawdown_pct", "mdd"), ("sharpe", "sr")]:
                        target = float(expected[f"{name}_{short}_{tag}"])
                        np.testing.assert_allclose(result[metric], target, rtol=0, atol=1e-9)
                    row[f"{name}_{tag}"] = result
            first = prices.apply(lambda c: c.dropna().iloc[0] if c.notna().any() else np.nan)
            bh = stats((prices / first).mean(axis=1))
            for metric, short in [("return_pct", "ret"), ("max_drawdown_pct", "mdd"), ("sharpe", "sr")]:
                np.testing.assert_allclose(bh[metric], expected[f"bh_{short}"], rtol=0, atol=1e-9)
            paper_replays.append(row)

    bridge = []
    for direction, tr in references.items():
        original = prices_for(tr, direction, False)
        extended = prices_for(tr, direction, True)
        spread, _ = engine._build_spread_equity(tr, original.index, H)
        bridge.append({"direction": direction, "engine": "spread_original", **stats(spread)})
        for tag, prices in [("original", original), ("extended", extended)]:
            for mtm in [False, True]:
                result = cash(tr, prices, flat=True, mtm=mtm)
                bridge.append({"direction": direction, "engine": f"cash_{'mtm' if mtm else 'book'}_{tag}", **result})

    rows = []
    input_hashes = {}
    for manifest in manifests:
        root = SRC / manifest["output_root_base"]
        for path in sorted(root.glob("*/Kronos/*/*/Utility_Score_NoCal/1d_*/10_backtest_cash_trades.csv")):
            mode, _, model, direction, _, _, _ = path.relative_to(root).parts
            tr = read_trades(path)
            input_hashes[str(path.relative_to(ROOT))] = sha(path)
            # Compare signed, fee-adjusted returns as well as dates and assets, independently of labels/probabilities.
            pd.testing.assert_series_equal(events(tr), events(references[direction]), check_exact=True)
            assert set(tr.direction.str.upper()) == {direction}
            prices = prices_for(tr, direction, True)
            m1 = cash(tr, prices, flat=True, mtm=True)
            m2 = cash(tr[tr.m2_approved], prices, flat=False, mtm=True)
            book2 = cash(tr[tr.m2_approved], prices, flat=False, mtm=False)
            assert m1["n_open_final"] == m2["n_open_final"] == book2["n_open_final"] == 0
            np.testing.assert_allclose(m2["return_pct"], book2["return_pct"], rtol=0, atol=1e-9)
            expected = full.loc[("Kronos", "autogluon", direction, "1d")]
            for metric, short in [("return_pct", "ret"), ("max_drawdown_pct", "mdd"), ("sharpe", "sr")]:
                np.testing.assert_allclose(m1[metric], expected[f"m1_{short}_mtm"], rtol=0, atol=1e-9)
            row = {
                "source_run": manifest["run_id"], "mode": mode, "model": model, "direction": direction,
                "n_m1": len(tr), "n_m2": int(tr.m2_approved.sum()),
                "coverage_pct": float(tr.m2_approved.mean() * 100),
                "entry_start": str(tr.date.min().date()), "entry_end": str(tr.date.max().date()),
                **{f"m1_{k}": v for k, v in m1.items()}, **{f"m2_{k}": v for k, v in m2.items()},
            }
            if mode == "tp" and model != "kumo":
                paper_path = EVIDENCE / f"Output/Kronos/{model}/{direction}/Utility_Score_NoCal/1d_tp/10_backtest_cash_trades.csv"
                theirs = read_trades(paper_path).set_index(["date", "asset"]).sort_index()
                ours = tr.set_index(["date", "asset"]).sort_index()
                row["tp_approval_disagreements_vs_paper"] = int((ours.m2_approved != theirs.m2_approved).sum())
                row["tp_max_probability_difference_vs_paper"] = float((ours.m2_prob - theirs.m2_prob).abs().max())
                row["paper_tp_n_m2"] = int(theirs.m2_approved.sum())
                paper = full.loc[("Kronos", model, direction, "1d")]
                row["paper_tp_m2_return_pct"] = float(paper.m2_ret_mtm)
                row["paper_tp_m2_sharpe"] = float(paper.m2_sr_mtm)
            rows.append(row)
    assert len(rows) == 48
    results = pd.DataFrame(rows).sort_values(["model", "direction", "mode"])
    results.to_csv(EVIDENCE / "our_48_cells_extended_mtm.csv", index=False, float_format="%.10f")
    pd.DataFrame(bridge).to_csv(EVIDENCE / "m1_engine_bridge.csv", index=False, float_format="%.10f")
    audit = {
        "scope": "Saved predictions only; no retraining, new threshold selection, or production engine changes.",
        "engine_sha256": sha(SRC / "Utils/backtest/engine.py"),
        "source_csvs_equal_gpu8": len(data_hashes["sha256"]),
        "paper_summary_rows_checked": len(roi),
        "paper_kronos_daily_cells_replayed": len(paper_replays),
        "paper_replayed_metric_checks": len(paper_replays) * 15,
        "our_cells_replayed": len(rows),
        "all_our_m1_events_and_net_returns_equal_paper": True,
        "all_our_m1_extended_mtm_metrics_equal_paper_atol": 1e-9,
        "all_extended_positions_closed": True,
        "all_extended_book_and_mtm_final_returns_equal": True,
        "annualization_multiplier": float(ann),
        "input_trade_csv_sha256": input_hashes,
        "paper_replays": paper_replays,
        "m1_bridge": bridge,
    }
    (EVIDENCE / "reconciliation.json").write_text(json.dumps(audit, indent=2) + "\n")
    print(pd.DataFrame(bridge)[["direction", "engine", "return_pct", "sharpe", "n_bars", "n_weekly_returns", "n_open_final"]].to_string(index=False))
    print("Verified: 280 summary rows; 10 paper cells (150 metrics); all 48 pilot M1 baselines match paper.")
    print(results[results["mode"] == "tp"][["model", "direction", "n_m2", "paper_tp_n_m2", "tp_approval_disagreements_vs_paper", "m2_return_pct", "paper_tp_m2_return_pct", "m2_sharpe", "paper_tp_m2_sharpe"]].to_string(index=False))


if __name__ == "__main__":
    main()
