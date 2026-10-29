# Triple-barrier target experiment: slides and evidence

The current decks use Pablo's GPU8 Test window, **2026-01-08–2026-07-18**.
The independently reproduced M1 spread-equity baseline has UP Sharpe **−2.5744**
and DOWN Sharpe **+1.7423**. All **24 AutoGluon/Kumo fits and the report completed**;
641 artifact files were downloaded on 2026-10-28 at 17:05 UTC. The results and
slides were reviewed on **2026-10-29**. Pablo's saved M2 scores remain labeled as
reference results; the new TP fits are separate models and differ numerically.

- [Short presentation](prendinger_brief.pdf): 14 slides.
- [Full presentation](main.pdf): 30 slides.
- [Historical target trial](earlier_target_trial.pdf): 4 slides, with the completed
  earlier experiment on **2025-10-09–2026-01-18**. Its positive UP scores belong to
  that earlier period.

Pages 3 and 5 of the current decks highlight the negative UP Sharpes. The final
three slides show all 24 scores, changes versus TP, and changes versus the matched
TB reference. The cash comparison distinguishes
positions held at entry cost from positions marked to current closing prices;
neither is the spread-equity calculation.

## Completed comparison

| Fresh M2 fit | TP | TB ref | TB k=0.5 | TB k=1 | TB k=1.5 | TB k=2 |
|---|---:|---:|---:|---:|---:|---:|
| AutoGluon UP | −2.1989 | −2.3745* | −2.2462 | −2.3764* | −2.3053 | −2.2801 |
| AutoGluon DOWN | 0.3385 | 1.4521 | 1.8216 | 1.3574 | 1.3829 | 1.0802 |
| Kumo UP | −1.9834 | −2.2551 | −2.4632 | −2.7139 | −2.0380 | −2.2250 |
| Kumo DOWN | 1.8839 | 2.0008 | −0.2777 | 1.7312 | 1.8492 | 1.7296 |

Values are annualized spread-equity Sharpe, using 27 seven-day return observations.
\* The utility constraint was not satisfied; the original pipeline used its 0.5
fallback threshold. These cells remain in the comparison and are flagged in the PDF.

AutoGluon DOWN k=0.5 improves by **+1.4831 versus fresh TP**, **+0.3695 versus
matched TB ref**, and **+0.0793 versus M1**. Its return is +61.5904%, with worse
drawdown (−26.5509%) than TB ref (−13.9467%) and M1 (−17.0362%). All volatility-barrier
variants have lower UP Sharpe than their TP fit; Kumo's volatility-barrier variants
also have lower DOWN Sharpe than its TP fit. There is no uniform TB gain.

The TB eligibility rule removes 13 UP and 64 DOWN early TON training proposals.
It also excludes 32 UP / 90 DOWN tail rows whose returns are unavailable; the
production TP backtest drops those same rows. Realized Test trades, fees and
features match across all targets and backends; Val-Cal/Val-Opt counts and date
boundaries match. TB-k versus TB-ref is the comparison with matched eligibility.
This is one fit per cell on an already inspected Test period, with fixed day-7
execution: no significance or optimal-k claim, and no early barrier-exit execution.

[Complete metrics and both deltas](pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/experiment_test.csv),
[slide evidence](pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/slide_data.json),
and [verification](pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/verification.json)
record the results. The verification replays all 144 M1/M2 metrics from saved trades
within 0.0001, checks the frozen source and daily input hashes, verifies generated
label hashes, and matches the cluster comparison report. It uses `return_pct / 100`
for the CSV's extra precision, after cross-checking the fractional return column.

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
