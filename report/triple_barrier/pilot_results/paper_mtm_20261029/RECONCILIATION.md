# Paper MTM reconciliation

**The M1 predictions and trades match. The reported equity calculation did not.**
Replaying all 48 pilot cells with the paper's cash-MTM engine and extended exit
calendar reproduces its M1 return, drawdown and Sharpe within `1e-9`.

The paper's [roi_ext_mtm.csv](Output/Analysis/Backtest_ExtendedTail/MTM/roi_ext_mtm.csv)
was copied read-only from:
`gpu8-pablo:/home/pablo/M2_DS/SecondaryModel/src/Output/Analysis/Backtest_ExtendedTail/MTM/`.
The original CSVs, rerun script, engine and configuration are retained here with
SHA-256 hashes in [provenance.json](provenance.json).

## Where TB is applied

Kronos is frozen. Its UP/DOWN proposals are labelled by their future triple-barrier
outcome; M2 learns those labels and decides which proposals to approve.
`src/Data_MLA/meta_label_tb.py:125–192` changes `lab` and `meta_label`, preserving
the source predictions and prices. The `lab` change also affects the validation
precision floor used in threshold selection.

This is a **target comparison**: executed returns for both M1 and M2 still use the
signed day-7 close return minus 0.2% fees (`src/Utils/backtest/engine.py:614–628`).
The pilot does not execute early profit/stop exits. TB label accuracy and original
day-7 label accuracy are different quantities; financial M1 results use the same
trades and returns in every arm.

## Why M1 appeared different

The slides take the standard pipeline's spread-equity results. The paper instead
uses [run_backtest_mtm_all.py](Output/Analysis/Backtest_ExtendedTail/MTM/run_backtest_mtm_all.py):

- Lines 34–41 reuse the saved trades and extend the calendar **seven bars past the
  last entry**. For Kronos 1d, entries run from **2026-01-08 to 2026-07-18**;
  valuation and liquidation continue through **2026-07-25**.
- Lines 46–50 use `_build_cash_equity`, with closing prices for MTM and
  `flat_size=True` for M1. The slides use `_build_spread_equity` instead.
- Both calculate annualized Sharpe from non-overlapping seven-day equity returns.
  Extending the calendar changes **192 bars / 27 returns** to **199 bars / 28 returns**.

| Calculation on the same M1 trades | UP return | UP Sharpe | DOWN return | DOWN Sharpe |
|---|---:|---:|---:|---:|
| Spread, original calendar (slides) | −54.2478% | −2.5744 | +30.4409% | +1.7423 |
| Cash at entry cost, original calendar | −43.6045% | −2.7945 | +12.5711% | +0.7878 |
| Cash MTM, original calendar | −43.6609% | −2.1420 | +12.3460% | +0.8076 |
| Cash at entry cost, extended calendar | −43.3134% | −2.7208 | +12.8333% | +0.7669 |
| **Cash MTM, extended calendar (paper and our replay)** | **−43.3134%** | **−2.0372** | **+12.8333%** | **+0.7622** |

Spread equity normalizes overlapping trade returns by average concentration and
compounds them. Cash equity allocates available capital: M1 requests 10% of free
cash per proposal, with pro-rata filling when necessary. M2 additionally sizes
positions from its probabilities. These are different portfolio constructions.

MTM changes the equity path, hence drawdown and Sharpe. **It does not change final
return once all positions have closed.** On the original calendar the cash engine
clamps earlier exits to the last bar and leaves that last bar's new entries open
(5 UP / 14 DOWN). Extending through their actual day-7 exits removes this boundary
problem. See the copied [engine](Utils/backtest/engine.py), lines 198–236.

The spread row above preserves the original full-precision slide values. The
[bridge CSV](m1_engine_bridge.csv) replays six-decimal trade CSVs; its spread returns
differ only by the resulting CSV-rounding error (less than 0.00004 percentage points).

## What was verified

- All **40** daily forecast/price CSVs are byte-identical locally and on GPU8.
- All **48** pilot cells have exactly the paper's M1 `(date, asset, signed net return)`
  rows: **1,045 UP** and **2,580 DOWN**. Their extended-MTM M1 results match the paper.
- All **280** rows of the rounded paper ROI table agree with its full-precision
  before/after CSV. Book/MTM final returns agree for all 280 stored rows.
- The **10 Kronos × 1d paper cells** were rerun for both M1 and M2, book and MTM,
  plus buy-and-hold: **150 metric checks** reproduce the full-precision reference.
- All 48 pilot M2 cells were also replayed under that same paper policy, retaining
  their original probabilities, thresholds and approvals. All positions close;
  book and MTM final returns agree. No model was retrained and no threshold reselected.
- The production source hashes still match both original experiment manifests.

Reproduce with [reconcile_paper_mtm.py](../../analysis/reconcile_paper_mtm.py).
The assertions and full numerical results are in [reconciliation.json](reconciliation.json).

## Why M2 can still differ

The pilot M2 models were refitted. Their saved probabilities and approvals differ
from the paper's fitted M2 models, even for the original TP target. For example,
AutoGluon DOWN approves 1,003 proposals versus 922 in the paper; the two models
disagree on 499 approval decisions. Under the same MTM engine its TP return/Sharpe
is −5.6542% / −0.1261 versus the paper's +9.8980% / +1.0615. TB arms additionally
change the training target. Kumo has no counterpart in this paper table.

This audit proves the prediction differences; it does not attribute them to a
particular random seed, numerical library or fitted ensemble. The paper's M2
results are references, not exact reproductions by our newly fitted TP models.

## Outputs and slide status

- [our_48_cells_extended_mtm.csv](our_48_cells_extended_mtm.csv): all 48 pilot cells
  recalculated with the paper's engine and calendar, including the matching M1.
- [m1_engine_bridge.csv](m1_engine_bridge.csv): separates the engine, valuation and
  calendar effects.
- [slide_data.json](slide_data.json) and [reviewed_results.csv](reviewed_results.csv):
  original fit metadata joined to the MTM replay, with both sets of deltas recalculated.
  Built by [prepare_mtm_slides.py](../../analysis/prepare_mtm_slides.py).
- Both current PDFs now use the MTM M1 **and** M2 results, including the paper
  reference and the 48-cell matrix. They distinguish entry dates from the final
  exit date. The separate historical PDF and LightGBM appendix retain their own
  explicitly labelled methods. Original threshold-fallback markers remain.
