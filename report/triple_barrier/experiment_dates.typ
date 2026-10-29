// Keep result dates tied to saved evidence, independently of the working config.
#import "../intro/theme.typ": *
#import "slides.typ": *
#let completed = json("pilot_results/original_test/slide_data.json")
#let gpu8 = yaml("pilot_results/original_test/gpu8_config_observed.yaml")
#let diagnostics = json("analysis/out/brief_fit20_summary.json")
#let benchmark = json("analysis/out/benchmark_periods.json").periods
#let reference = json("pilot_results/gpu8_reference_5b61d08/verified_spread_results.json")
#let verified = json("pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/local_daily_baselines.json")
#let cash-replay = json("pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/cash_reference_diagnostics.json")
#let trial-results = json("pilot_results/gpu8_four_backends/slide_data.json")
#let comparison-status = str(trial-results.completed) + " / " + str(trial-results.expected) + " fits reviewed"
#let current-up = verified.checks.tp.up
#let current-down = verified.checks.tp.down
#let reference-period = reference.rows.first()
#let metric(x, digits: 2) = {
  let parts = str(calc.round(x, digits: digits)).split(".")
  let fraction = if parts.len() > 1 { parts.last() } else { "" }
  parts.first() + "." + fraction + range(digits - fraction.len()).map(n => "0").join("")
}
#let percentage(x) = metric(x) + "%"
#let day(x) = x.slice(0, 10)
#let diagnostic-dates = [Entry dates: #diagnostics.first_entry.slice(0, 10) – #diagnostics.last_entry.slice(0, 10).]
#let benchmark-dates = [Entry dates: train #benchmark.train.first_entry – #benchmark.train.last_entry; validation #benchmark.val.first_entry – #benchmark.val.last_entry; Test #benchmark.test.first_entry – #benchmark.test.last_entry.]
#let benchmark-test-dates = [Test entries: #benchmark.test.first_entry – #benchmark.test.last_entry.]

#let experiment-dates-slide() = {
  slide(kicker: "Dates and provenance", title: [Which dates belong to which results?])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 16pt)[Configured cutoffs · daily horizon = 7 bars · all dates below use YYYY-MM-DD.]
    #v(10pt)
    #set text(size: 14.5pt)
    #set table(inset: (x: 7pt, y: 7pt))
    #table(columns: (1.5fr, 1fr, 1fr, 1fr, 1fr), align: left,
      [Configuration], [Data start], [Train ends], [Validation ends], [Data ends],
      [Earlier trial · separate PDF],
      [#completed.splits.start_date], [#completed.splits.train_end], [#completed.splits.val_end], [#completed.splits.end_date],
      [Pablo GPU8 · now copied],
      [#gpu8.data.split.start_date], [#gpu8.data.split.train_end], [#gpu8.data.split.val_end], [#gpu8.data.split.end_date],
    )
    #v(12pt)
    #text(size: 15pt, weight: "bold")[Actual sample dates · after context and split rules]
    #v(6pt)
    #grid(columns: (1fr, 1.05fr), gutter: 18pt,
      text(size: 14pt)[
        *New daily inputs · Pablo's configuration*\
        Train: #day(current-up.splits.idx_train.first) – #day(current-up.splits.idx_train.last)\
        Val-Cal: #day(current-up.splits.idx_cal.first) – #day(current-up.splits.idx_cal.last)\
        Val-Opt: #day(current-up.splits.idx_opt.first) – #day(current-up.splits.idx_opt.last)\
        Test: #day(current-up.first_test_entry) – #day(current-up.last_test_entry)
      ],
      text(size: 14pt)[
        *Other evidence and historical context*\
        Label diagnostics: #diagnostics.first_entry.slice(0, 10) – #diagnostics.last_entry.slice(0, 10)\
        Historical AG / Kumo Test · separate PDF:\
        #completed.baseline.up.period_start – #completed.baseline.up.period_end\
        Separate LightGBM Test:\
        #benchmark.test.first_entry – #benchmark.test.last_entry
      ],
    )
    #v(12pt)
    #note[#text(size: 14pt)[The original loader creates a first training window on *2024-06-30*, one day before the configured start. Its context and embargo conventions are preserved. The realised Test dates match Pablo's saved reports.]]
    #src[GPU8 config observed 2026-10-27; daily input checks 2026-10-28; saved earlier trial, diagnostics and benchmark dates. Full LightGBM train/validation ranges accompany its result slides.]
  ]
}

#let gpu8-baseline-slide() = {
  slide(kicker: "Verified on 28 October 2026 · M1 baseline", title: [The reproduced UP baseline has Sharpe #metric(current-up.stats.m1_sharpe, digits: 4)])[
    #text(size: 15.5pt)[Test: #day(current-up.first_test_entry) – #day(current-up.last_test_entry) · spread equity · 7-day horizon · fee 0.2%.]
    #v(12pt)
    #set text(size: 17pt)
    #set table(inset: (x: 9pt, y: 8pt))
    #table(columns: (0.7fr, 1fr, 1fr, 1.2fr, 1fr), align: (left, right, right, right, right),
      [M1 side], [Return], [Sharpe], [Max drawdown], [Trades],
      [UP], percentage(current-up.stats.m1_total_return), text(fill: accent, weight: "bold", metric(current-up.stats.m1_sharpe, digits: 4)), percentage(current-up.stats.m1_max_drawdown), str(current-up.stats.n_total_trades),
      [DOWN], percentage(current-down.stats.m1_total_return), metric(current-down.stats.m1_sharpe, digits: 4), percentage(current-down.stats.m1_max_drawdown), str(current-down.stats.n_total_trades),
    )
    #v(10pt)
    #grid(columns: (1fr, 1fr, 1fr), gutter: 20pt,
      stat([12 / 12], [Target / direction baseline checks passed]),
      stat(str(current-up.n_horizon_returns), [Weekly return observations\ from #current-up.n_calendar_bars daily bars]),
      stat(percentage(reference-period.bh_total_return), [Buy-and-hold return\ on the same Test period]),
    )
    #v(8pt)
    #note[#text(size: 15pt)[Buy-and-hold also lost money in this period. All six targets share M1's Test trades. *Four-backend comparison: #comparison-status.* AutoGluon / Kumo are complete; TabPFN / Random Forest extend the same grid.]]
    #src[Independent daily data preparation reproduces saved GPU8 M1 metrics within 0.0001; existing UP multigranularity cache also checked. Spread equity smooths trade returns; Sharpe uses ×√(365.25/7). The inspected Test is exploratory.]
  ]
}

#let gpu8-cash-slide() = {
  let cost = cash-replay.rows.find(r => r.direction == "up" and r.exposure == 0.1 and not r.mark_to_market)
  let marked = cash-replay.rows.find(r => r.direction == "up" and r.exposure == 0.1 and r.mark_to_market)
  slide(kicker: "Interpreting the loss · same UP trade set", title: [Return and drawdown explain the “−45%” figure])[
    #text(size: 15.5pt)[Same #current-up.stats.n_total_trades UP trades · #day(current-up.first_test_entry) – #day(current-up.last_test_entry) · different equity calculations.]
    #v(15pt)
    #set text(size: 16pt)
    #set table(inset: (x: 9pt, y: 12pt))
    #table(columns: (2.15fr, 1fr, 1.2fr, 0.8fr), align: (left, right, right, right),
      [Equity calculation], [Total return], [Max drawdown], [Sharpe],
      [Spread · original baseline], percentage(current-up.stats.m1_total_return), percentage(current-up.stats.m1_max_drawdown), metric(current-up.stats.m1_sharpe),
      [Cash · open positions at cost], percentage(cost.return_pct), percentage(cost.mdd_pct), metric(cost.sharpe),
      [Cash · current market prices], percentage(marked.return_pct), percentage(marked.mdd_pct), metric(marked.sharpe),
    )
    #v(18pt)
    #grid(columns: (1fr, 1fr), gutter: 20pt,
      flow-node([Saved cash report], [*−43.60%* is the endpoint loss.\ *−45.35%* is the worst fall from a prior peak.\ Open positions remain at entry value.]),
      flow-node([Current cash code], [Open positions follow current closing prices.\ Interim losses become visible: *−48.75% drawdown*.\ Use the same valuation rule for comparisons.]),
    )
    #src[Replay of Pablo's saved UP trade CSV on 2026-10-28; cash exposure 0.10 in both rows. Saved cash metrics match positions held at cost. Final-day entries can remain open: cash figures are endpoint equity, including the current marking fee.]
  ]
}

#let gpu8-reference-slide() = {
  slide(kicker: "Pablo GPU8 · saved M2 reference", title: [Pablo's saved UP M2 Sharpes are also negative])[
    #text(size: 15.5pt)[Test entries: #reference-period.first_entry – #reference-period.last_entry · 1d · TP labels · spread-equity engine.]
    #v(10pt)
    #set text(size: 15pt)
    #set table(inset: (x: 8pt, y: 8pt))
    #let num = metric
    #let pct = percentage
    #let get(model, direction) = reference.rows.find(r => r.model == model and r.direction == direction)
    #let u = get("autogluon", "up")
    #let d = get("autogluon", "down")
    #let cells = ([M1 · all calls], pct(u.m1_total_return), text(fill: accent, weight: "bold", num(u.m1_sharpe)), pct(d.m1_total_return), num(d.m1_sharpe))
    #for (model, label) in (("autogluon", "AutoGluon"), ("ctts", "CTTS"), ("tabpfn", "TabPFN"), ("tabicl", "TabICL")) {
      let u = get(model, "up")
      let d = get(model, "down")
      cells += (label, pct(u.m2_total_return), text(fill: accent, weight: "bold", num(u.m2_sharpe)), pct(d.m2_total_return), num(d.m2_sharpe))
    }
    #table(columns: (1.45fr, 1fr, 1fr, 1fr, 1fr), align: (left, right, right, right, right),
      [Strategy], [UP return], [UP Sharpe], [DOWN return], [DOWN Sharpe], ..cells,
    )
    #v(12pt)
    #note[#text(size: 15pt)[These are *Pablo's saved TP results*. Fresh AutoGluon TP scores are *−2.1989 UP / +0.3385 DOWN*. The new matrix uses its own TP fits for deltas; the M1 baseline and dates match.]]
    #src[Saved GPU8 outputs fetched 2026-10-27; 48 replayed metrics agree within 0.0001. New models are separate fits on Izar, with pinned principal packages; hardware, Python patch release and fitted ensembles can differ. Exact M2 reproduction is not established.]
  ]
}

#let gpu8-target-matrix-slide() = {
  let fits = (("autogluon", "up", [AutoGluon · UP]), ("autogluon", "down", [AutoGluon · DOWN]),
              ("kumo", "up", [Kumo · UP]), ("kumo", "down", [Kumo · DOWN]),
              ("tabpfn", "up", [TabPFN · UP]), ("tabpfn", "down", [TabPFN · DOWN]),
              ("rf", "up", [RF · UP]), ("rf", "down", [RF · DOWN]))
  let get(model, direction, mode) = trial-results.rows.find(r => r.model == model and r.direction == direction and r.mode == mode)
  let signed(x) = (if x >= 0 { "+" } else { "" }) + metric(x, digits: 3)
  let delta-cell(x) = text(fill: if x < 0 { accent } else { blue }, weight: "bold", signed(x))
  let pending = text(fill: muted, "Pending")

  slide(kicker: "Reading the comparison", title: [TP means true-positive meta-labeling])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 16pt)[Original TP asks whether a Kronos proposal made money at day 7, *after the 0.2% fee*.]
    #v(8pt)
    #grid(columns: (1fr, 1fr), gutter: 20pt,
      flow-node([Label 1 · true positive], [The proposed UP or DOWN trade was profitable after the fee at day 7.]),
      flow-node([Label 0 · unsuccessful proposal], [Its signed day-7 return was zero or negative after the fee.]),
    )
    #v(8pt)
    #set text(size: 15pt)
    #set table(inset: (x: 8pt, y: 5pt))
    #table(columns: (0.7fr, 2.5fr, 2.2fr), align: left,
      [Column], [M2 training target], [Purpose],
      [*TP*], [Original seven-day true-positive label], [Original target baseline for each backend],
      [*TB ref*], [Same TP label; TB eligibility filter], [Control with matched training eligibility],
      [*TB k*], [Profit / stop / time-barrier outcome], [Test the effect of a different target],
    )
    #v(8pt)
    #note[#text(size: 15pt)[*TP is not a take-profit order.* M2 predicts success from the available features; it does not know the future label. All reported backtests still execute at day 7, including models trained on TB targets.]]
    #src[Original conversion: pred=1 and lab=1 → meta_label=1; pred=1 and lab=0 → 0. The signed day-7 rule agrees with all 18,230 complete-horizon proposals in the 40 daily CSVs. RF = Random Forest; TabPFN is the original GPU8 backend.]
  ]

  slide(kicker: "Four-backend target experiment · 29 October 2026", title: [Four backends, six targets: #comparison-status])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 14pt)[Test: #day(current-up.first_test_entry) – #day(current-up.last_test_entry) · TP = true positive · fixed day-7 execution.]
    #linebreak()
    #text(size: 14pt)[M1 Sharpe: *UP #metric(current-up.stats.m1_sharpe, digits: 4)* · DOWN #metric(current-down.stats.m1_sharpe, digits: 4). RF = Random Forest.]
    #v(7pt)
    #set text(size: 13.5pt)
    #set table(inset: (x: 8pt, y: 5pt))
    #let cells = ()
    #for (model, direction, label) in fits {
      cells += (label,)
      for mode in trial-results.modes {
        let r = get(model, direction, mode)
        if r == none {
          cells += (pending,)
        } else {
          let marker = if r.constraint_satisfied { "" } else { "*" }
          cells += (text(fill: if r.m2_sharpe < 0 { accent } else { blue }, weight: "bold", metric(r.m2_sharpe, digits: 3) + marker),)
        }
      }
    }
    #table(columns: (1.6fr, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr), align: left,
      [M2 fit], [TP], [TB ref], [k = 0.5], [k = 1], [k = 1.5], [k = 2], ..cells,
    )
    #v(8pt)
    #note[#text(size: 14pt)[AutoGluon / Kumo's 24 scores are verified. TabPFN / RF add 24 fits using GPU8's saved tuning parameters, fixed across targets within each direction. Pending cells have no reviewed score.]]
    #src[Annualized spread-equity Sharpe, 27 weekly observations. #text("*") = utility constraint failed; pipeline fallback threshold 0.5. New run: gpu8-targets-20261029-030611. Preparation → training → report; no new HPO. Exploratory Test.]
  ]

  slide(kicker: "Delta 1 · same backend and direction", title: [How much does Sharpe change versus the fresh TP fit?])[
    #set par(leading: 0.4em, spacing: 0.6em)
    #text(size: 15.5pt)[Δ Sharpe = target Sharpe − TP Sharpe · Test 2026-01-08 – 2026-07-18.]
    #v(6pt)
    #set text(size: 14pt)
    #set table(inset: (x: 8pt, y: 4pt))
    #let cells = ()
    #for (model, direction, label) in fits {
      cells += (label,)
      for mode in trial-results.modes.filter(m => m != "tp") {
        let r = get(model, direction, mode)
        cells += (if r == none { pending } else { delta-cell(r.delta_sharpe_vs_tp) },)
      }
    }
    #table(columns: (1.7fr, 1fr, 1fr, 1fr, 1fr, 1fr), align: left,
      [M2 fit], [TB ref], [k = 0.5], [k = 1], [k = 1.5], [k = 2], ..cells,
    )
    #v(8pt)
    #note[#text(size: 14pt)[AutoGluon DOWN at k = 0.5: *+1.483* versus TP. Kumo's volatility-barrier variants all score below its TP fit. The additional backend comparisons await reviewed results.]]
    #v(6pt)
    #text(size: 13.5pt)[This contrast includes the eligibility change: TB ref and TB-k remove *13 UP / 64 DOWN* early TON training proposals. The matched comparison follows.]
    #src[Same realized Test trades, fees, features and fixed day-7 execution. Fresh TP fits differ from Pablo's saved M2 fits. Deltas are descriptive; this inspected Test does not select an optimal k.]
  ]

  slide(kicker: "Delta 2 · matched training eligibility", title: [The label-change gain is smaller against TB reference])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 15.5pt)[Δ Sharpe = TB-k Sharpe − TB-ref Sharpe · TB ref keeps TP labels on the TB-eligible samples.]
    #v(6pt)
    #set text(size: 14pt)
    #set table(inset: (x: 9pt, y: 4pt))
    #let cells = ()
    #for (model, direction, label) in fits {
      cells += (label,)
      for mode in trial-results.modes.filter(m => m.starts-with("tb_k")) {
        let r = get(model, direction, mode)
        cells += (if r == none { pending } else { delta-cell(r.delta_sharpe_vs_tb_ref) },)
      }
    }
    #table(columns: (1.7fr, 1fr, 1fr, 1fr, 1fr), align: left,
      [M2 fit], [k = 0.5], [k = 1], [k = 1.5], [k = 2], ..cells,
    )
    #v(8pt)
    #grid(columns: (1fr, 1fr), gutter: 18pt,
      flow-node([AutoGluon · DOWN · k = 0.5], [Sharpe *1.822*: +0.370 vs TB ref; +0.079 vs M1.\ Return *+61.59%*; max drawdown *−26.55%*.\ TB-ref drawdown: −13.95%; M1: −17.04%.]),
      flow-node([No uniform TB improvement], [All four Kumo DOWN variants trail TB ref.\ AutoGluon/Kumo UP remain loss-making.\ Gains in this one run need fresh-period confirmation.]),
    )
    #src[All TB variants share training eligibility and Test trades. This is a label comparison with day-7 execution, not early barrier-exit trading. One fit per cell; 27 horizon returns; no significance or optimal-k claim.]
  ]
}
