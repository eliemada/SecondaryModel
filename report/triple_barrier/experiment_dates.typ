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
    #note[#text(size: 15.5pt)[Buy-and-hold also lost money in this period. All six targets share M1's Test trades. *New AutoGluon / Kumo comparison: pending*, 0 / 24 fits completed.]]
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
    #note[#text(size: 15pt)[These are *Pablo's saved TP results*. The new AutoGluon / Kumo target matrix uses the same dates and a verified M1 baseline; its M2 results are *pending*.]]
    #src[Saved GPU8 outputs fetched 2026-10-27. Replayed 8 runs (M1 and M2): 48 metrics agree within 0.0001; CSV returns have 6 decimals. 27 weekly horizon returns. Classifiers have not been refit to reproduce these outputs.]
  ]
}

#let gpu8-target-matrix-slide() = {
  slide(kicker: "Current experiment · Pablo's dates", title: [The new M2 target comparison is still pending])[
    #text(size: 15pt)[Test: #day(current-up.first_test_entry) – #day(current-up.last_test_entry) · AutoGluon / Kumo · fixed day-7 execution.]
    #v(8pt)
    #grid(columns: (1fr, 1fr), gutter: 24pt,
      flow-node([UP M1 Sharpe: #metric(current-up.stats.m1_sharpe, digits: 4)], [Verified baseline · return #percentage(current-up.stats.m1_total_return)], tone: accent, fill: soft),
      flow-node([DOWN M1 Sharpe: #metric(current-down.stats.m1_sharpe, digits: 4)], [Verified baseline · return #percentage(current-down.stats.m1_total_return)]),
    )
    #v(10pt)
    #set text(size: 14.5pt)
    #set table(inset: (x: 8pt, y: 5pt))
    #let cells = ()
    #for label in ([AutoGluon · UP], [AutoGluon · DOWN], [Kumo · UP], [Kumo · DOWN]) {
      cells += (label, ..range(6).map(n => text(fill: muted, "Pending")))
    }
    #table(columns: (1.6fr, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr), align: left,
      [M2 fit], [TP], [TB ref], [k = 0.5], [k = 1], [k = 1.5], [k = 2], ..cells,
    )
    #v(8pt)
    #note[#text(size: 15pt)[*0 / 24 new fits completed at this update.* The earlier positive-UP target matrix is preserved in the separate historical PDF, using Test dates 2025-10-09–2026-01-18.]]
    #src[Status checked 2026-10-28. First submission stopped during preparation; the checker is fixed and the rerun is queued. Matched TB ref isolates label changes; all six targets share the verified M1 Test trade set.]
  ]
}
