# Triple-barrier target experiment: slides and evidence

The current decks use **the paper's cash-MTM engine and extended exit calendar**.
All 48 pilot cells reproduce Pablo's M1: **UP −43.3134%, Sharpe −2.0372**;
**DOWN +12.8333%, Sharpe +0.7622**. Test entries are **2026-01-08–2026-07-18**;
all day-7 exits finish on **2026-07-25**. The equity calendar has 199 bars and
**28 weekly return observations**.

- [Short presentation](prendinger_brief.pdf): 15 slides.
- [Full presentation](main.pdf): 31 slides.
- [Historical trial](earlier_target_trial.pdf): 4 slides; the earlier
  2025-10-09–2026-01-18 experiment retains its original spread-equity method.

The baseline, paper reference, 48-cell matrix and both delta tables now use MTM.
The separate LightGBM study in the full deck retains its own explicitly labelled
method and dates. The new M2 fits differ from Pablo's saved fitted classifiers;
M1, input trades and the financial calculation are what have been reproduced exactly.

## TP and TB

**TP means true-positive meta-labeling, not take profit.** For a frozen Kronos
proposal, label 1 means its signed day-7 return exceeds the 0.2% fee; otherwise 0.
This was checked on 18,230 complete proposals in the 40 daily source CSVs.
**TB ref** retains TP labels on TB-eligible samples. **TB-k** uses the outcome at
profit, stop or expiry to label M1's proposals and train M2. Kronos stays frozen.
All actual backtests keep day-7 exits: this tests targets, not early barrier execution.

## Four-backend comparison

Cash-MTM Sharpe, annualized from 28 seven-day returns:

| Fresh M2 fit | TP | TB ref | k=0.5 | k=1 | k=1.5 | k=2 |
|---|---:|---:|---:|---:|---:|---:|
| AutoGluon UP | −1.3294 | −1.5814* | −1.1307 | −1.6379* | −1.4391 | −1.3788 |
| AutoGluon DOWN | −0.1261 | 0.6953 | −0.2169 | 0.3721 | 0.7348 | 0.4143 |
| Kumo UP | −1.4235 | −1.5327 | −1.6664 | −1.8809 | −1.4661 | −1.5579 |
| Kumo DOWN | 0.5165 | 0.4035 | −1.1224 | 0.5105 | 0.7100 | 0.3976 |
| TabPFN UP | −1.6506 | −1.6820 | −1.6470* | −1.8335 | −1.6046 | −1.7174 |
| TabPFN DOWN | 0.7892 | 0.7427 | 0.8247 | 1.1614 | 0.6787 | 0.6348 |
| Random Forest UP | −1.1054 | −0.9290 | −1.3210 | −0.9911 | −0.8393 | −0.9749 |
| Random Forest DOWN | 0.6241 | 0.7796 | 0.0263 | 0.2788 | 0.7886 | 0.5585 |

\* Original utility search used its fallback threshold of 0.5. All three cells
remain flagged; the MTM replay does not alter thresholds or approval decisions.

All UP scores remain negative. The highest observed DOWN Sharpe is **TabPFN k=1,
1.1614**: **+0.3722 versus TP**, **+0.4188 versus TB ref**; return **+14.0486%** and
drawdown **−13.0613%**. RF UP k=1.5 reaches **−0.8393**, gains **+0.2661 versus TP**
and **+0.0897 versus TB ref**, but still loses **18.1501%**. AutoGluon DOWN k=1.5
gains +0.8609 versus TP and only +0.0395 versus TB ref. Gains depend on the backend
and direction; these observations do not select an optimal k or establish significance.

The cash engine uses available capital and probability-based M2 sizing; spread
equity used average-concentration normalization. Consequently the earlier spread
rankings cannot be carried over. Both MTM and book valuation give identical final
returns after every position closes; MTM changes the equity path, drawdown and Sharpe.

## Controls and limits

Both completed runs use the frozen GPU8 production source and configuration:
`gpu8-targets-20261028-104504` (AutoGluon/Kumo) and
`gpu8-targets-20261029-030611` (TabPFN/RF). The latter's preparation 3234260, training
3234261 and report 3234262 completed successfully. RF/TabPFN use Pablo's saved
HPO_NoCal parameters, fixed by direction across targets. No new fitting, tuning or
threshold selection accompanied the MTM replay.

TB eligibility removes 13 UP / 64 DOWN early TON training proposals. It also
excludes 32 UP / 90 DOWN tail rows with unavailable returns; the production TP
backtest drops the same rows. Realized Test trades and features match across all
48 cells. TB-k versus TB ref controls eligibility; versus TP includes that change.

Three original fallback cases remain: AutoGluon UP TB ref and k=1, TabPFN UP k=0.5.
The [threshold audit](pilot_results/gpu8_four_backends/threshold_fallback_audit.json)
found that the validation precision reference included 722 proposals while the
search used 640 after embargo. Aligning those rows removes the three validation
fallbacks. The code correction is separate on `fix/threshold-validation-cohort`;
it has **not** been applied to this matrix. One fit per cell, 28 returns and an
already inspected Test period remain limitations.

## Evidence

The [paper reconciliation](pilot_results/paper_mtm_20261029/RECONCILIATION.md)
records the source files and checks. All 40 daily inputs are byte-identical to
GPU8. The audit checks all 280 paper summary rows, replays 150 metrics from its
10 Kronos daily cells, and matches M1 in all 48 pilot cells within 1e-9.
Every position closes; book and MTM final returns agree.

- [Current slide data](pilot_results/paper_mtm_20261029/slide_data.json).
- [Current metrics and both deltas](pilot_results/paper_mtm_20261029/reviewed_results.csv).
- [48 replayed cells](pilot_results/paper_mtm_20261029/our_48_cells_extended_mtm.csv).
- [Engine/calendar bridge](pilot_results/paper_mtm_20261029/m1_engine_bridge.csv).
- [Original spread results, archived](pilot_results/gpu8_four_backends/slide_data.json).

The original [AutoGluon/Kumo verification](pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/verification.json),
[TabPFN/RF verification](pilot_results/gpu8_target_trial/gpu8-targets-20261029-030611/verification.json)
and [cross-run checks](pilot_results/gpu8_four_backends/cross_run_verification.json)
retain source, parameter and input parity evidence. They describe the original
pipeline outputs, not the subsequent MTM valuation.

## Rebuild

Keep descriptive H1 titles short (2–5 words), one takeaway per slide, and methods
in the notes. From the thesis workspace:

```sh
code/SecondaryModel/.venv/bin/python report/triple_barrier/analysis/reconcile_paper_mtm.py
code/SecondaryModel/.venv/bin/python report/triple_barrier/analysis/prepare_mtm_slides.py
typst compile --root report report/triple_barrier/prendinger_brief.typ report/triple_barrier/prendinger_brief.pdf
typst compile --root report report/triple_barrier/main.typ report/triple_barrier/main.pdf
code/SecondaryModel/.venv/bin/python report/triple_barrier/analysis/verify_mtm_decks.py
```

The GitHub copy is a standalone Typst build snapshot with its figures, slide data,
shared theme and logos. Financial replay helpers require the original thesis
workspace's inputs and trained-run artifacts; PDF verification uses the supplied
slide data. Intended fonts: Inter and New Computer Modern.
