// Thesis discussion with training diagnostics and original-pipeline Test results for SecondaryModel's
// own 20-asset Kronos-forecast universe (not the Synthetic-Generation `fit20` cohort --
// that's an unrelated regime-model calibration set; only 13/20 overlap).
// rtk proxy typst compile --root report report/triple_barrier/prendinger_brief.typ report/triple_barrier/prendinger_brief.pdf
#import "../intro/theme.typ": *
#import "slides.typ": *
#import "experiment_dates.typ": experiment-dates-slide, gpu8-baseline-slide, gpu8-cash-slide, gpu8-reference-slide, gpu8-target-matrix-slide, current-up, metric, diagnostic-dates

#show: setup
#set document(title: "M2 targets across 20 assets — Prendinger discussion", author: "Elie Bruno")
#let evidence = json("analysis/out/brief_fit20_summary.json")
#let pct(x) = str(calc.round(100 * x, digits: 1)) + "%"

#title-slide(
  kicker: "THESIS DISCUSSION · PROF. PRENDINGER",
  title: [What should M2 learn\ to call a good trade?],
  subtitle: [Triple-barrier labels across 20 assets:\ volatility, direction, and a controlled target experiment.],
  meta: (
    ("Scope", [SecondaryModel's own 20 assets · daily candles · 7-day maximum holding period]),
    ("Evidence", [Training diagnostics · verified M1 baseline · Pablo's saved M2 reference]),
    ("Prepared", [22 October 2026 · short discussion for next week]),
    ("Update", [29 October 2026 · UP M1 Sharpe #metric(current-up.stats.m1_sharpe, digits: 4) · 24 / 24 M2 fits complete]),
  ),
)

#experiment-dates-slide()
#gpu8-baseline-slide()
#gpu8-cash-slide()
#gpu8-reference-slide()

#slide(kicker: "1 · M2 and ground truth", title: [Inspecting the labels does not require retraining M2])[
  #v(13pt)
  #grid(columns: (1fr, auto, 1fr, auto, 1fr), gutter: 12pt, align: horizon,
    flow-node([Past candles], [Market features + frozen M1\ M1 proposes UP or DOWN.]),
    arrow,
    flow-node([Observed future candles], [Apply the chosen exit rule.\ Compute the net outcome.], tone: accent, fill: soft),
    arrow,
    flow-node([Meta-label z], [1 if the proposal paid;\ 0 otherwise.], tone: accent, fill: soft),
  )
  #v(23pt)
  #grid(columns: (1fr, 1fr), gutter: 20pt,
    card([No retraining], [
      Compare volatility, barrier touches and label changes using the same historical M1 calls.
    ], kicker: "What we can show now", tone: blue, fill: blue-soft),
    card([Retrain the secondary model], [
      To test whether M2 learns the new target better, fit it on the new labels. Reuse M1's forecasts.
    ], kicker: "What a performance claim needs"),
  )
  #src[AFML §§3.4–3.7. #diagnostic-dates 7,593 eligible UP/DOWN proposals from 19 of SecondaryModel's 20 assets; TON unavailable in this parquet.]
]

#slide(kicker: "2 · Candles and direction", title: [The same price move can stop a long and profit a short])[
  #text(size: 17pt)[BTC · #evidence.candle_example.date · entry at day-0 close · symmetric k = 1 barriers.]
  #v(6pt)
  #align(center, image("figures/brief_fit20_candles.svg", width: 100%, height: 7.8cm, fit: "contain"))
  #v(8pt)
  #note[#text(size: 16pt)[UP / long: profit above entry, stop below. DOWN / short: profit below, stop above.\
  The same entry-time volatility is used for both directions.]]
  #src[Actual training-period candles; explanatory episode selected for a stop. SHORT is a counterfactual, not a second Kronos call. Cost 0.2%; assumed barrier fills.]
]

#slide(kicker: "3 · Volatility across the 20 assets", title: [One common k still gives a different width at each entry])[
  #align(center)[$ w_(a,t) = k sigma_(a,t) sqrt(7) $]
  #align(center, image("figures/brief_fit20_volatility.svg", width: 96%, height: 7.6cm, fit: "contain"))
  #v(4pt)
  #note[#text(size: 16pt)[At k = 1, median widths are *6.7% for BTC*, *9.6% for ETH*, and *16.3% for SUI*.\
  σ changes with the asset and date; the chosen barrier is then fixed for that event.]]
  #src[#diagnostic-dates EWMA(100), known at entry; dots = median, lines = entry-date 10th–90th percentiles; √7 scaling.]
]

#slide(kicker: "4 · UP and DOWN proposals", title: [Apply TBM to both sides; report the outcomes separately])[
  #text(size: 17pt)[1,921 UP proposals · 5,672 DOWN proposals · same k = 1 and same volatility estimator.]
  #v(9pt)
  #align(center, image("figures/brief_fit20_direction.svg", width: 100%, height: 7.5cm, fit: "contain"))
  #v(9pt)
  #note[#text(size: 16pt)[Meta-labels change for *5.9% of UP calls* and *4.4% of DOWN calls*.\
  These groups contain different dates and market conditions; this is a descriptive comparison.]]
  #src[#diagnostic-dates 19 of 20 assets; high/low touches, same-bar double touch = stop; cost 0.2%. Positive-label share is not M2's predictive accuracy.]
]

#slide(kicker: "5 · Sensitivity to k", title: [A similar binary label can hide a different trade])[
  #text(size: 17pt)[Small k: closer exits. Large k: more trades remain open until day 7.]
  #v(9pt)
  #align(center, image("figures/brief_fit20_k.svg", width: 100%, height: 7.4cm, fit: "contain"))
  #v(10pt)
  #note[#text(size: 16pt)[At k = 1: *55.8% horizontal exits*, but only *4.8% changed labels*, averaged across assets.\
  The exit, return and holding time can change while “profitable / unprofitable” stays the same.]]
  #src[#diagnostic-dates Equal asset weights. Shading: 10th–90th percentiles across assets. Training diagnostics; these charts do not select an optimal k.]
]

#slide(kicker: "6 · Choosing k", title: [Start with a global k; select it for the intended trade])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Start with one shared parameter], [
      - Same k for all 20 assets and both sides.
      - Volatility already adapts the width.
      - Small grid: 0.5, 1, 1.5, 2.
      - Keep the horizon, features and cost model fixed.
    ], tone: blue, fill: blue-soft),
    card([Choose on validation data], [
      - Specify the intended exit policy first.
      - Rank candidates by a predefined net portfolio objective.
      - Check drawdown, coverage and stability across assets and time.
      - Confirm the choice on fresh data.
    ]),
  )
  #v(18pt)
  #note[#text(size: 16pt)[There is no universal “ideal k”. Add separate direction or asset parameters only if they bring a stable validation benefit. A 50/50 label balance is not an optimization objective.]]
  #src[Proposed research protocol. AFML ch. 7 and ch. 11; López de Prado's backtest-overfitting work. Existing 2026 test results have already been inspected.]
]

#gpu8-target-matrix-slide()
