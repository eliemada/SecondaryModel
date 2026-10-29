# Daily target comparison using Pablo's GPU8 pipeline

This experiment starts from observed GPU8 revision
`5b61d0880a447dcc81b76169b6dbc59b2fd02276`. The production `m2_pipeline.py`,
backtest engine, feature preparation and threshold optimizer are unchanged.
Extensions add Kumo registration, TB target generation, isolated configurations,
comparison helpers and the submission/preparation checks.

The base configuration matches the observed GPU8 configuration except for local
paths. Explicit CLI arguments select the daily experiment backends. The grid is
AutoGluon and Kumo × TP, matched TB reference, k = 0.5/1/1.5/2 × UP/DOWN: **24 fits**.
TB changes M2's target labels; trade execution remains fixed at seven bars.
The fee is 0.002 and the threshold mode is `utility_nocal`.

## Dates and comparison

| Configured boundary | Date |
|---|---|
| Data start | 2024-07-01 |
| Training end | 2025-08-31 |
| Validation end | 2025-12-31 |
| Data end | 2026-08-01 |

The original loader's first eligible daily training entry is 2024-06-30 because
of its context-window convention. Val-Cal entries run 2025-09-08–2025-10-18;
Val-Opt entries run 2025-10-26–2025-12-31. Realized Test entries run
**2026-01-08–2026-07-18**, producing 192 calendar bars and 27 horizon returns.

| M1 spread baseline | Trades | Return | Maximum drawdown | Sharpe |
|---|---:|---:|---:|---:|
| UP | 1,045 | −54.2478% | −57.9912% | −2.5744 |
| DOWN | 2,580 | +30.4409% | −17.0362% | +1.7423 |

Independent local daily checks reproduce these metrics for all six targets and
both directions. The existing multigranularity UP cache was also checked. This
does not replace the scheduled preparation checks on every cluster cache.
The Test has already been inspected: comparisons are exploratory.

## Submission and checks

The launcher expects the Izar environment and the original input CSVs under
`src/Data_MLA/Kronos/Crypto/TP/horizon_7`. It contains Izar-specific scheduler and
Hugging Face cache settings. Adapt those settings before using another cluster.

```sh
uv sync --no-dev
.venv/bin/python slurm/gpu8_trial.py submit --dry-run
.venv/bin/python slurm/gpu8_trial.py submit
```

Each submission freezes its configuration and source/data hashes in a separate
run directory. Preparation verifies the 280 input CSV checksums, important
package versions, GPU availability, real LightGBM/CatBoost/Kumo fit/predict
smoke checks, and the saved M1 baseline for every mode/direction. Training waits
for preparation to pass, and the report waits for the training array.
Only the training/Test-backtest phase runs; there are no separate HPO, edge or
regime-analysis jobs in this grid.

The dependency lock reproduces the observed major GPU8 package versions,
including LightGBM. Explicit NumPy/Arrow overrides match the observed environment
despite AutoGluon's declared bounds. Python patch version, hardware and some
supporting packages differ; identical M2 predictions are not guaranteed.

## Recorded submission

The first submission, `gpu8-targets-20261027-153632`, failed in the custom M1
checker before production training: the checker omitted the production engine's
NaN-return filter. TP contains 32 UP and 90 DOWN Test rows without realized returns.
The checker now applies the same filter before choosing the equity calendar.
UP/DOWN regression tests compare it directly with `run_feature_backtest`.

The replacement is `gpu8-targets-20261028-104504`:

- Preparation: 3233490.
- Training array: 3233491.
- Report: 3233492.

The replacement's preparation, all 12 array tasks (two directions each), and report
completed successfully. All **24 fits** and 641 artifact files were downloaded on
2026-10-28 at 17:05 UTC. Results were reviewed on **2026-10-29**. The earlier-date
24-fit experiment is documented separately in the historical presentation.
Submission and completion records are under `slurm/runs/`; live logs, caches and
raw outputs are excluded from Git.

Validation before publication: **89 local tests passed**, Ruff passed for the
added experiment code, and the earlier preparation's GPU learner smoke checks
passed. A separate review of completed results replays all 144 M1/M2 return,
drawdown and Sharpe values within 0.0001; checks frozen source, daily input and
generated-label hashes; checks realized trade and feature parity; and verifies
the cluster comparison table. The saved CSV's `return_pct / 100` preserves more
precision than its six-decimal fractional-return column; both are cross-checked.

To reproduce that review with the local dataset and downloaded run present:

```sh
.venv/bin/python slurm/review_gpu8_results.py --output report/triple_barrier/pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504
```

AutoGluon DOWN k=0.5 scores 1.8216: +1.4831 versus its fresh TP fit, +0.3695 versus
the matched TB reference. All UP scores remain negative; Kumo's volatility-barrier
targets do not beat its TP in either direction. Full results, fallback-threshold
flags and both delta definitions accompany the slides. New TP fits differ from
Pablo's saved M2 models, although the baseline, data and configured settings match.

The current and historical presentation PDFs are linked from
[`report/triple_barrier/README.md`](../report/triple_barrier/README.md).
