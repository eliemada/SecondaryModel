# Triple-barrier target experiment: slides and evidence

The current decks use Pablo's GPU8 Test window, **2026-01-08–2026-07-18**.
The independently reproduced M1 spread-equity baseline has UP Sharpe **−2.5744**
and DOWN Sharpe **+1.7423**. All **24 AutoGluon/Kumo fits and the report completed**;
641 artifact files were downloaded on 2026-10-28 at 17:05 UTC. The results and
slides were reviewed on **2026-10-29**. Pablo's saved M2 scores remain labeled as
reference results; the new TP fits are separate models and differ numerically.
The comparison now includes **TabPFN and Random Forest: all 48 fits are complete
and reviewed**. The added run `gpu8-targets-20261029-030611` completed successfully;
617 artifact files were downloaded on 2026-10-29 at 04:20 UTC. Its 144 M1/M2
metrics passed replay, and all 24 fits' tuning files and production logs match
the frozen GPU8 parameters. Both runs share identical realized M1 trades and features.

- [Short presentation](prendinger_brief.pdf): 15 slides.
- [Full presentation](main.pdf): 31 slides.
- [Historical target trial](earlier_target_trial.pdf): 4 slides, with the completed
  earlier experiment on **2025-10-09–2026-01-18**. Its positive UP scores belong to
  that earlier period.

Pages 3 and 5 of the current decks highlight the negative UP Sharpes. The final
three slides show the four-backend grid, changes versus TP, and changes versus the
matched TB reference. Every cell now contains a reviewed result; the original
AutoGluon/Kumo scores are unchanged. The cash comparison distinguishes
positions held at entry cost from positions marked to current closing prices;
neither is the spread-equity calculation.

## What TP means

**TP means true-positive meta-labeling, not take profit.** On a Kronos proposal
(`pred=1`), the original dataset has `meta_label=lab`: label 1 if the signed
seven-day close return exceeds the 0.2% fee, otherwise label 0. The sign is
reversed for DOWN trades. This equivalence was checked on all 18,230 proposals
with a complete future horizon across the 40 daily CSVs (5,269 UP / 12,961 DOWN),
with zero mismatches. These counts cover the full source files, not only Test.

The **TP column** reports M2 trained on that original target. **TB ref** keeps
the same label but applies TB's eligibility filter. **TB-k** changes the label
to the profit/stop/time-barrier outcome after fees. The execution policy in this
comparison remains day 7 for every target. M2 predicts an unknown future outcome;
the TP baseline does not select known future winners. The definition is on page
12 of the short deck and page 28 of the full deck.

## Four-backend comparison

| Fresh M2 fit | TP | TB ref | TB k=0.5 | TB k=1 | TB k=1.5 | TB k=2 |
|---|---:|---:|---:|---:|---:|---:|
| AutoGluon UP | −2.1989 | −2.3745* | −2.2462 | −2.3764* | −2.3053 | −2.2801 |
| AutoGluon DOWN | 0.3385 | 1.4521 | 1.8216 | 1.3574 | 1.3829 | 1.0802 |
| Kumo UP | −1.9834 | −2.2551 | −2.4632 | −2.7139 | −2.0380 | −2.2250 |
| Kumo DOWN | 1.8839 | 2.0008 | −0.2777 | 1.7312 | 1.8492 | 1.7296 |
| TabPFN UP | −2.5266 | −2.5698 | −2.3531* | −2.5939 | −2.4448 | −2.5187 |
| TabPFN DOWN | 0.8822 | 0.9883 | 1.5687 | 1.0459 | 0.8287 | 0.7971 |
| Random Forest UP | −1.8000 | −1.5173 | −2.2215 | −1.7786 | −1.3877 | −1.8103 |
| Random Forest DOWN | 1.2014 | 1.2459 | −0.4732 | −0.2561 | 1.2215 | 0.8245 |

Added run: preparation **3234260**, training array **3234261**, report **3234262**;
all completed with exit code 0.
It calls the same production `m2_pipeline.py`, retains Pablo's configured dates,
features, fees and threshold method, and freezes his direction-specific
`HPO_NoCal` settings across all six targets. No new hyperparameter search runs.
Random Forest uses 100 trees / depth 3 for UP and 900 / depth 12 for DOWN.
TabPFN uses 4 ensemble estimators / temperature 0.9 for UP and 32 / 0.75 for DOWN,
with the other saved parameters retained by the original factory. The exact
parameter files and their provenance accompany the experiment code.

Values are annualized spread-equity Sharpe, using 27 seven-day return observations.
\* The utility constraint was not satisfied; the original pipeline used its 0.5
fallback threshold. These cells remain in the comparison and are flagged in the PDF.

AutoGluon DOWN k=0.5 improves by **+1.4831 versus fresh TP**, **+0.3695 versus
matched TB ref**, and **+0.0793 versus M1**. Its return is +61.5904%, with worse
drawdown (−26.5509%) than TB ref (−13.9467%) and M1 (−17.0362%). For AutoGluon and
Kumo, all volatility-barrier UP scores are below TP. Kumo's volatility-barrier
variants also have lower DOWN Sharpe than its TP fit. There is no uniform TB gain.

TabPFN DOWN k=0.5 improves by **+0.6865 versus TP** and **+0.5804 versus TB ref**,
reaching Sharpe 1.5687, return +34.7808% and drawdown −17.5132%. It remains below
M1's DOWN Sharpe 1.7423. Random Forest UP k=1.5 improves by **+0.4123 versus TP**
and **+0.1296 versus TB ref**, but still has Sharpe −1.3877 and return −34.6094%.
RF DOWN k=1.5 has only +0.0201 versus TP and −0.0244 versus TB ref. All UP cells
remain negative; the highest observed DOWN Sharpe is Kumo TB ref at 2.0008.

There are three fallback-threshold cells: AutoGluon UP TB ref, AutoGluon UP k=1,
and TabPFN UP k=0.5. Their 0.5 threshold was used because the utility constraint
was not satisfied; the asterisks make those cases explicit.

The TB eligibility rule removes 13 UP and 64 DOWN early TON training proposals.
It also excludes 32 UP / 90 DOWN tail rows whose returns are unavailable; the
production TP backtest drops those same rows. Realized Test trades, fees and
features match across all targets and backends; Val-Cal/Val-Opt counts and date
boundaries match. TB-k versus TB-ref is the comparison with matched eligibility.
This is one fit per cell on an already inspected Test period, with fixed day-7
execution: no significance or optimal-k claim, and no early barrier-exit execution.

[Reviewed metrics and both deltas](pilot_results/gpu8_four_backends/reviewed_results.csv),
[four-backend slide evidence](pilot_results/gpu8_four_backends/slide_data.json),
the [AutoGluon/Kumo verification](pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/verification.json),
the [TabPFN/RF verification](pilot_results/gpu8_target_trial/gpu8-targets-20261029-030611/verification.json),
and the [cross-run comparison](pilot_results/gpu8_four_backends/cross_run_verification.json)
record the results. The two verifications replay all 288 M1/M2 metrics from saved trades
within 0.0001, check the frozen source and daily input hashes, verify generated
label hashes, and match the cluster comparison reports. The replay uses `return_pct / 100`
for the CSV's extra precision, after cross-checking the fractional return column.
The combined evidence includes 48 reviewed scores. Downloading and reviewing are
separate steps; the downloader alone does not publish scores.

## Rebuild the PDFs

From the repository root, with Typst installed:

```sh
typst compile --root report report/triple_barrier/prendinger_brief.typ report/triple_barrier/prendinger_brief.pdf
typst compile --root report report/triple_barrier/main.typ report/triple_barrier/main.pdf
typst compile --root report report/triple_barrier/earlier_target_trial.typ report/triple_barrier/earlier_target_trial.pdf
```

The required figures, JSON/YAML inputs, shared theme and logos accompany the
sources. Inter and New Computer Modern are the intended fonts; font availability
can affect layout on another machine.

The GitHub copy is a presentation build snapshot. Dataset caches, model weights,
private administrative files and temporary previews are excluded. Python analysis
and download helpers in the original thesis workspace are separate from this
standalone Typst build. Speaker notes retain their original research provenance
and workspace references.
