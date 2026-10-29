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
  slide(kicker: "Pablo GPU8 · actual sample dates", title: [Data Splits])[
    #v(30pt)
    #set text(size: 22pt)
    #set table(inset: (x: 14pt, y: 18pt))
    #table(columns: (1fr, 1fr, 1fr), align: left,
      [Split], [Start], [End],
      [*Train*], [#day(current-up.splits.idx_train.first)], [#day(current-up.splits.idx_train.last)],
      [*Validation*], [#day(current-up.splits.idx_cal.first)], [#day(current-up.splits.idx_opt.last)],
      [*Test*], [#day(current-up.first_test_entry)], [#day(current-up.last_test_entry)],
    )
  ]
}

#let gpu8-baseline-slide() = {
  slide(kicker: "Verified against GPU8", title: [M1 Baseline])[
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
      stat([12 / 12], [Baseline checks passed]),
      stat(str(current-up.n_horizon_returns), [Weekly returns\ #current-up.n_calendar_bars daily bars]),
      stat(percentage(reference-period.bh_total_return), [Buy-and-hold return]),
    )
    #v(8pt)
    #note[#text(size: 15pt)[*UP loses money; DOWN gains.* All six targets share the same M1 Test trades.]]
    #src[Saved GPU8 M1 metrics reproduced within 0.0001. Spread equity smooths returns; Sharpe annualization ×√(365.25/7). Exploratory Test.]
  ]
}

#let gpu8-cash-slide() = {
  let cost = cash-replay.rows.find(r => r.direction == "up" and r.exposure == 0.1 and not r.mark_to_market)
  let marked = cash-replay.rows.find(r => r.direction == "up" and r.exposure == 0.1 and r.mark_to_market)
  slide(kicker: "The “−45%” figure", title: [Loss and Drawdown])[
    #text(size: 15.5pt)[#current-up.stats.n_total_trades UP trades · #day(current-up.first_test_entry) – #day(current-up.last_test_entry).]
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
      flow-node([Return vs drawdown], [*−43.60%*: total loss at the endpoint.\ *−45.35%*: largest fall from a prior peak.]),
      flow-node([Valuation matters], [Marking open positions to market reveals\ a larger drawdown: *−48.75%*.]),
    )
    #src[Saved UP trades replayed 2026-10-28. Cash exposure: 10%; endpoint equity can include open positions. Compare results using the same valuation rule.]
  ]
}

#let gpu8-reference-slide() = {
  slide(kicker: "GPU8 reference", title: [Pablo's Saved Results])[
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
    #note[#text(size: 15pt)[*Saved UP scores are negative.* Our new comparison uses a fresh TP fit for each backend.]]
    #src[48 saved metrics replayed within 0.0001. M1, dates and engine match; new M2 fits on Izar differ from Pablo's saved classifiers.]
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

  slide(kicker: "Training targets", title: [TP and TB Labels])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 16pt)[*TP = true-positive meta-labeling.* Did the proposal profit at day 7 after the 0.2% fee?]
    #v(8pt)
    #grid(columns: (1fr, 1fr), gutter: 20pt,
      flow-node([Label 1], [Positive net return at day 7.]),
      flow-node([Label 0], [Zero or negative net return at day 7.]),
    )
    #v(8pt)
    #set text(size: 15pt)
    #set table(inset: (x: 8pt, y: 5pt))
    #table(columns: (0.7fr, 2.5fr, 2.2fr), align: left,
      [Column], [M2 training target], [Purpose],
      [*TP*], [Original day-7 label], [Baseline],
      [*TB ref*], [TP label on TB-eligible samples], [Control for the sample filter],
      [*TB k*], [Net outcome at profit / stop / expiry], [Test a different label],
    )
    #v(8pt)
    #note[#text(size: 15pt)[*TP does not mean take profit.* All backtests keep day-7 exits.]]
    #src[TP rule verified on 18,230 complete proposals. Labels use future outcomes; M2 inputs use only information available at entry.]
  ]

  slide(kicker: "Four backends · " + comparison-status, title: [Test Sharpe])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 14pt)[Test: #day(current-up.first_test_entry) – #day(current-up.last_test_entry) · day-7 exits.]
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
    #note[#text(size: 14pt)[*All UP scores are negative.* Highest DOWN Sharpe: *Kumo TB ref, 2.001*.]]
    #src[Annualized spread-equity Sharpe; 27 weekly returns. #text("*") = utility constraint failed; threshold defaults to 0.5. One fit per cell; exploratory results.]
  ]

  slide(kicker: "Same backend and direction", title: [Change vs TP])[
    #set par(leading: 0.4em, spacing: 0.6em)
    #text(size: 15.5pt)[Δ Sharpe = target − TP · positive values mean improvement.]
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
    #note[#text(size: 14pt)[DOWN at k = 0.5: *AutoGluon +1.483* and *TabPFN +0.687* versus TP.]]
    #v(6pt)
    #text(size: 13.5pt)[Includes the sample filter: TB removes *13 UP / 64 DOWN* early TON training proposals.]
    #src[Test 2026-01-08–2026-07-18. Fresh TP controls; same Test trades, fees, features and day-7 exits. Descriptive deltas; no optimal-k claim.]
  ]

  slide(kicker: "Same eligible training samples", title: [Change vs TB Reference])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 15.5pt)[Δ Sharpe = TB-k − TB ref · compare labels on the same samples.]
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
      flow-node([TabPFN DOWN · k = 0.5], [Sharpe *1.569* · gain *+0.580*.\ Still below M1 DOWN: *1.742*.]),
      flow-node([RF UP · k = 1.5], [Sharpe *−1.388* · gain *+0.130*.\ Return *−34.61%*: still loses money.]),
    )
    #src[Test 2026-01-08–2026-07-18. Day-7 exits; 27 weekly returns; one fit per cell. Gains vary by backend and direction; no significance or optimal-k claim.]
  ]
}
