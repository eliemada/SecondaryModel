// Thesis discussion with training diagnostics and paper-aligned cash-MTM Test results for SecondaryModel's
// own 20-asset Kronos-forecast universe (not the Synthetic-Generation `fit20` cohort --
// that's an unrelated regime-model calibration set; only 13/20 overlap).
// rtk proxy typst compile --root report report/triple_barrier/prendinger_brief.typ report/triple_barrier/prendinger_brief.pdf
#import "../intro/theme.typ": *
#import "slides.typ": *
#import "experiment_dates.typ": experiment-dates-slide, gpu8-baseline-slide, gpu8-cash-slide, gpu8-reference-slide, gpu8-target-matrix-slide, current-up, metric, comparison-status, diagnostic-dates

#show: setup
#set document(title: "M2 targets across 20 assets — Prendinger discussion", author: "Elie Bruno")
#let evidence = json("analysis/out/brief_fit20_summary.json")
#let pct(x) = str(calc.round(100 * x, digits: 1)) + "%"

#title-slide(
  kicker: "THESIS DISCUSSION · PROF. PRENDINGER",
  title: [M2 Target Comparison],
  subtitle: [Triple-barrier labels · four backends · 20 crypto assets],
  meta: (
    ("Author", [Elie Bruno · NII Tokyo]),
    ("Setup", [Daily candles · frozen Kronos · cash-MTM · day-7 exits]),
    ("Baseline", [M1 UP Sharpe: #metric(current-up.sharpe, digits: 4)]),
    ("Updated", [29 October 2026 · #comparison-status]),
  ),
)

#experiment-dates-slide()
#gpu8-baseline-slide()
#gpu8-cash-slide()
#gpu8-reference-slide()

#slide(kicker: "1 · Ground truth", title: [From Prices to Labels])[
  #v(13pt)
  #grid(columns: (1fr, auto, 1fr, auto, 1fr), gutter: 12pt, align: horizon,
    flow-node([Past prices], [Frozen M1 proposes UP or DOWN.]),
    arrow,
    flow-node([Future prices], [Apply exits and fees.], tone: accent, fill: soft),
    arrow,
    flow-node([Meta-label z], [1 if profitable; 0 otherwise.], tone: accent, fill: soft),
  )
  #v(23pt)
  #grid(columns: (1fr, 1fr), gutter: 20pt,
    card([Inspect labels], [
      Compare exits and label changes on historical M1 calls. No retraining needed.
    ], tone: blue, fill: blue-soft),
    card([Test performance], [
      Retrain M2 on each target, then compare. Keep M1 frozen.
    ]),
  )
  #src[AFML §§3.4–3.7. #diagnostic-dates 7,593 proposals; 19/20 assets (TON unavailable).]
]

#slide(kicker: "2 · Trade direction", title: [Long and Short Barriers])[
  #text(size: 17pt)[BTC · #evidence.candle_example.date · entry at day-0 close · symmetric k = 1 barriers.]
  #v(6pt)
  #align(center, image("figures/brief_fit20_candles.svg", width: 100%, height: 7.8cm, fit: "contain"))
  #v(8pt)
  #note[#text(size: 16pt)[*Long*: profit above entry. *Short*: profit below entry. Stops are on the opposite side.]]
  #src[Training example selected for a stop; SHORT is counterfactual. Same volatility for both sides; 0.2% cost; assumed barrier fills.]
]

#slide(kicker: "3 · Volatility", title: [Barrier Width by Asset])[
  #align(center)[$ w_(a,t) = k sigma_(a,t) sqrt(7) $]
  #align(center, image("figures/brief_fit20_volatility.svg", width: 96%, height: 7.6cm, fit: "contain"))
  #v(4pt)
  #note[#text(size: 16pt)[Same k, different widths: *BTC 6.7% · ETH 9.6% · SUI 16.3%* at k = 1.]]
  #src[#diagnostic-dates EWMA(100) at entry; width stays fixed per trade. Dots: median; lines: 10th–90th percentiles.]
]

#slide(kicker: "4 · Label diagnostics", title: [UP and DOWN Outcomes])[
  #text(size: 17pt)[1,921 UP proposals · 5,672 DOWN proposals · positive/negative after 0.2% fees.]
  #v(9pt)
  #align(center, image("figures/brief_fit20_direction.svg", width: 100%, height: 7.5cm, fit: "contain"))
  #v(9pt)
  #note[#text(size: 16pt)[Labels change for *5.9% of UP* and *4.4% of DOWN* proposals.]]
  #src[#diagnostic-dates Each bar = 100% of that side's proposals. Expiry +/−: positive/negative net return. High/low touches; same-candle ties = stop.]
]

#slide(kicker: "5 · Barrier distance", title: [Sensitivity to k])[
  #text(size: 17pt)[Small k: closer exits. Large k: more trades remain open until day 7.]
  #v(9pt)
  #align(center, image("figures/brief_fit20_k.svg", width: 100%, height: 7.4cm, fit: "contain"))
  #v(10pt)
  #note[#text(size: 16pt)[At k = 1: *55.8% profit/stop exits*, yet only *4.8% of labels change*.]]
  #src[#diagnostic-dates Equal asset weights; shading: 10th–90th percentiles. Training diagnostics do not select an optimal k.]
]

#slide(kicker: "6 · Research protocol", title: [Choosing k])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([One shared k], [
      - All assets and both directions.
      - Test 0.5, 1, 1.5, 2.
      - Fix features, horizon and fees.
    ], tone: blue, fill: blue-soft),
    card([Validate the choice], [
      - Define exits and the objective first.
      - Check return, drawdown and stability.
      - Confirm on fresh data.
    ]),
  )
  #v(18pt)
  #note[#text(size: 16pt)[*Volatility already adapts the width.* Add more parameters only with a stable validation gain.]]
  #src[Proposed protocol: AFML ch. 7 and 11. The 2026 Test has already been inspected; label balance alone is not an objective.]
]

#gpu8-target-matrix-slide()
