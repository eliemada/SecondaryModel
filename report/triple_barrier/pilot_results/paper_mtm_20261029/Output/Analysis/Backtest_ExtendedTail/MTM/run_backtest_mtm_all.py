"""Before/after of the cash engine's mark-to-market fix, for every M1 x M2 x direction x granularity.

Same logic as Output/Analysis/Backtest_ExtendedTail/run_extended_tail_all.py (extended
timeline: the last entry + horizon bars; equal-weight Buy & Hold over the same bars;
Sharpe of non-overlapping horizon returns, annualised sqrt(bars/year / horizon)).
'book' = current engine without close (positions held at entry cost);
'mtm'  = the same engine with close=bar closes (open positions marked each bar).
Run from SecondaryModel/src:  python <this file>   -> mtm_before_after_all.csv
"""
import sys, copy, warnings; warnings.filterwarnings("ignore")
SRC = "/home/pablo/M2_DS/SecondaryModel/src"; sys.path.insert(0, SRC)
from pathlib import Path
from multiprocessing import Pool
import numpy as np, pandas as pd, yaml
from Utils.backtest.engine import (_build_cash_equity, _calc_sharpe, _calc_drawdown,
                                   _annualization_factor, _equity_horizon_returns, _load_raw_close_prices)
OUT = Path(__file__).with_name("mtm_before_after_all.csv")
G = ["1d", "12h", "8h", "6h", "4h", "2h", "1h"]; H = 7
M1S = ["Kronos", "Fincast", "Chronos2", "Tirex"]; M2S = ["rf", "tabpfn", "autogluon", "tabicl", "ctts"]
BASE = yaml.safe_load(open(f"{SRC}/config.yaml"))

def _cfg(m1):
    c = copy.deepcopy(BASE); c["experiment"]["m1"] = c["data"]["load"]["m1"] = m1.lower()
    c["paths"]["csv_dir"] = f"{SRC}/Data_MLA/{m1}/Crypto/TP/horizon_7"; return c

def _stats(eq, ann_h):
    h = _equity_horizon_returns(eq, H) if len(eq) > H else np.array([])
    return (eq.iloc[-1] - 1) * 100, _calc_drawdown(eq.values) * 100, _calc_sharpe(h, ann_h)

def run(job):
    m1, m2n = job; cfg = _cfg(m1); rows = []
    for d in ("DOWN", "UP"):
        for g in G:
            tr = pd.read_csv(f"{SRC}/Output/{m1}/{m2n}/{d}/Utility_Score_NoCal/{g}_tp/10_backtest_cash_trades.csv",
                             parse_dates=["date"]).sort_values("date")
            m2 = tr[tr["m2_approved"].astype(bool)]
            raw = _load_raw_close_prices(cfg, g, direction=d.lower())
            bars = pd.DatetimeIndex(sorted(raw["date"].unique()))
            t0, t1 = tr["date"].min(), tr["date"].max()
            t1x = bars[min(bars.searchsorted(t1, side="left") + H, len(bars) - 1)]
            piv = raw[(raw["date"] >= t0) & (raw["date"] <= t1x)].pivot_table(index="date", columns="asset", values="close")
            first = piv.apply(lambda c: c.dropna().iloc[0] if c.notna().any() else np.nan)
            bh = (piv / first).mean(axis=1)
            ann_h = np.sqrt(_annualization_factor(g) ** 2 / H)
            r = {"m1": m1, "m2": m2n, "dir": d, "gran": g, "n_m1": len(tr), "n_m2": len(m2)}
            for tag, kw in (("book", {}), ("mtm", {"close": piv})):
                e2 = _build_cash_equity(m2, bh.index, H, **kw)[0]
                e1 = _build_cash_equity(tr, bh.index, H, flat_size=True, **kw)[0]
                for k, eq in (("m2", e2), ("m1", e1)):
                    r[f"{k}_ret_{tag}"], r[f"{k}_mdd_{tag}"], r[f"{k}_sr_{tag}"] = _stats(eq, ann_h)
            r["bh_ret"], r["bh_mdd"], r["bh_sr"] = _stats(bh, ann_h)
            rows.append(r)
    return rows

if __name__ == "__main__":
    out = []
    with Pool(8) as p:
        for rows in p.imap_unordered(run, [(a, b) for a in M1S for b in M2S]):
            out += rows; print(rows[0]["m1"], rows[0]["m2"], "done", flush=True)
    df = pd.DataFrame(out).sort_values(["m1", "m2", "dir", "gran"])
    assert np.allclose(df.m2_ret_book, df.m2_ret_mtm) and np.allclose(df.m1_ret_book, df.m1_ret_mtm), "final returns differ"
    df.to_csv(OUT, index=False); print("saved", OUT, len(df))
