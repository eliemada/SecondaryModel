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

## Added TabPFN / Random Forest comparison

Run `gpu8-targets-20261029-030611` adds 24 fits (TabPFN / RF × six targets × UP/DOWN),
bringing the comparison to 48. It preserves the completed AutoGluon/Kumo run and
uses the unchanged GPU8 production code, input CSVs, dates, features, fees and
threshold method. CLI overrides select these backends; the base YAML remains the
observed GPU8 configuration.

The four `slurm/gpu8_hpo_reference/*/*/1d/best_params.json` files were fetched
read-only from GPU8 revision `5b61d08` on 2026-10-29. Their hashes and source paths
are recorded in `provenance.json`. These TP-tuned settings are fixed across all
targets, rather than re-optimized separately for each TB target.

| Backend | UP | DOWN |
|---|---|---|
| Random Forest | 100 trees, depth 3, minimum leaf 48 | 900 trees, depth 12, minimum leaf 34 |
| TabPFN | 4 estimators, temperature 0.9 | 32 estimators, temperature 0.75 |

Other saved settings are retained. The original TabPFN factory does not forward
flat HPO preprocessing keys such as `preprocess_transform`; that original mapping
is preserved. Preparation records the effective parameters and unused reference
keys in `backend_reference_checks.json`, after real fit/predict checks.

To reproduce the submission, first create a fresh manifest:

```sh
.venv/bin/python slurm/gpu8_trial.py submit --models tabpfn rf --dry-run
.venv/bin/python slurm/gpu8_model_reference.py attach --manifest <printed-manifest-path> --reference-dir slurm/gpu8_hpo_reference --submit
```

The attachment freezes the reference files, installs identical backend/direction
parameters in each target's own HPO folder, checks that the production loader
reads them, and rejects changed parameters before training. It extends the
generated run scripts without modifying the launcher used by the completed run.
Five focused tests cover production baseline parity and frozen parameter wiring.

Completed jobs: preparation **3234260**, training **3234261**, report **3234262**;
every task exited successfully. The downloader received all 24 new fit summaries
and 617 artifact files at 2026-10-29 04:20 UTC. All four learner smoke checks passed.
Preparation requests 16 GiB / 30 minutes; each two-direction training task requests
32 GiB / one hour. All tasks use the same original training/Test pipeline. The
downloader excludes TabPFN fitted weights and RF serialized models as well as
the existing model/cache exclusions. All 48 scores now appear in the slides.

The review replays the added run's 144 M1/M2 metrics within 0.0001 (maximum
absolute discrepancy 0.0000493). It verifies all 24 mode/backend/direction HPO
copies against GPU8 hashes and confirms the parameter values in every production
fit log. Completion, effective parameters, baseline checks and the parameter audit
are stored in `slurm/runs/gpu8-targets-20261029-030611/`. Across both runs, all 48
fits have identical realized M1 trades/returns and feature lists within direction.

TabPFN DOWN k=0.5 scores 1.5687: +0.6865 versus TP, +0.5804 versus TB ref. Random
Forest UP k=1.5 scores −1.3877: +0.4123 versus TP, +0.1296 versus TB ref, while
still losing money. All UP cells remain negative. TabPFN UP k=0.5 adds a third
fallback-threshold cell alongside AutoGluon UP TB ref and k=1. This is an
exploratory comparison with fixed day-7 execution and one fit per cell.

Here **TP means true-positive meta-labeling**, not take profit: for a Kronos
proposal, its original label is 1 iff the signed day-7 return exceeds the 0.002
fee. TB ref keeps that label with matched eligibility; TB-k changes the label,
while execution stays fixed at day 7.
