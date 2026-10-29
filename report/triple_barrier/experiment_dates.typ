// Keep result dates tied to saved evidence, independently of the working config.
#import "../intro/theme.typ": *
#import "slides.typ": *
#let diagnostics = json("analysis/out/brief_fit20_summary.json")
#let benchmark = json("analysis/out/benchmark_periods.json").periods
#let trial-results = json("pilot_results/paper_mtm_20261029/slide_data.json")
#let comparison-status = str(trial-results.completed) + " / " + str(trial-results.expected) + " fits reviewed"
#let current-up = trial-results.baseline.up
#let current-down = trial-results.baseline.down
#let sample-splits = trial-results.actual_splits
#let reference = trial-results.paper_reference
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
      [*Train*], [#day(sample-splits.idx_train.first)], [#day(sample-splits.idx_train.last)],
      [*Validation*], [#day(sample-splits.idx_cal.first)], [#day(sample-splits.idx_opt.last)],
      [*Test*], [#current-up.entry_start], [#current-up.entry_end],
    )
    #src[Test dates are entry dates. Final day-7 exits: #current-up.equity_end.]
  ]
}

#let gpu8-baseline-slide() = {
  slide(kicker: "Verified against Pablo's paper", title: [M1 Baseline])[
    #text(size: 15.5pt)[Cash-MTM · day-7 exits · 0.2% fee · valued through #current-up.equity_end.]
    #v(12pt)
    #set text(size: 17pt)
    #set table(inset: (x: 9pt, y: 8pt))
    #table(columns: (0.7fr, 1fr, 1fr, 1.2fr, 1fr), align: (left, right, right, right, right),
      [M1 side], [Return], [Sharpe], [Max drawdown], [Trades],
      [UP], percentage(current-up.return_pct), text(fill: accent, weight: "bold", metric(current-up.sharpe, digits: 4)), percentage(current-up.max_drawdown_pct), str(current-up.n_trades),
      [DOWN], percentage(current-down.return_pct), metric(current-down.sharpe, digits: 4), percentage(current-down.max_drawdown_pct), str(current-down.n_trades),
    )
    #v(10pt)
    #grid(columns: (1fr, 1fr, 1fr), gutter: 20pt,
      stat([48 / 48], [M1 baselines match the paper]),
      stat(str(current-up.n_horizon_returns), [Weekly returns\ #current-up.n_bars daily bars]),
      stat(percentage(reference.first().bh_total_return), [Buy-and-hold return]),
    )
    #v(8pt)
    #note[#text(size: 15pt)[*UP loses money; DOWN gains.* All six targets share the same M1 Test trades.]]
    #src[roi_ext_mtm.csv reproduced: same M1 trades, engine and final exits. Annualized seven-day Sharpe ×√(365.25/7); 28 observations.]
  ]
}

#let gpu8-cash-slide() = {
  let cost = trial-results.engine_bridge.find(r => r.direction == "UP" and r.engine == "cash_book_extended")
  let marked = trial-results.engine_bridge.find(r => r.direction == "UP" and r.engine == "cash_mtm_extended")
  slide(kicker: "Paper backtest", title: [MTM Valuation])[
    #text(size: 15.5pt)[#current-up.n_trades UP trades · all positions closed by #current-up.equity_end.]
    #v(15pt)
    #set text(size: 16pt)
    #set table(inset: (x: 9pt, y: 12pt))
    #table(columns: (2.15fr, 1fr, 1.2fr, 0.8fr), align: (left, right, right, right),
      [Equity calculation], [Total return], [Max drawdown], [Sharpe],
      [Cash · positions held at entry cost], percentage(cost.return_pct), percentage(cost.max_drawdown_pct), metric(cost.sharpe),
      [*Cash-MTM · paper method*], percentage(marked.return_pct), percentage(marked.max_drawdown_pct), metric(marked.sharpe),
    )
    #v(18pt)
    #grid(columns: (1fr, 1fr), gutter: 20pt,
      flow-node([Same final return], [*#percentage(marked.return_pct)* after every trade closes.\ Same trades and capital allocation.]),
      flow-node([Different path], [MTM values open positions at each close.\ It changes drawdown and Sharpe.]),
    )
    #src[Entries end #current-up.entry_end; exits continue for 7 days. M1 requests 10% of free cash per trade; oversubscribed entries fill pro rata.]
  ]
}

#let gpu8-reference-slide() = {
  slide(kicker: "Paper reference · cash-MTM", title: [Pablo's Results])[
    #text(size: 15.5pt)[Kronos · 1d · TP labels · final exits #current-up.equity_end.]
    #v(10pt)
    #set text(size: 14.5pt)
    #set table(inset: (x: 8pt, y: 7pt))
    #let num = metric
    #let pct = percentage
    #let get(model, direction) = reference.find(r => r.model == model and r.direction == direction)
    #let u = get("autogluon", "up")
    #let d = get("autogluon", "down")
    #let cells = ([M1 · all calls], pct(u.m1_total_return), text(fill: accent, weight: "bold", num(u.m1_sharpe)), pct(d.m1_total_return), num(d.m1_sharpe))
    #for (model, label) in (("rf", "Random Forest"), ("autogluon", "AutoGluon"), ("ctts", "CTTS"), ("tabpfn", "TabPFN"), ("tabicl", "TabICL")) {
      let u = get(model, "up")
      let d = get(model, "down")
      cells += (label, pct(u.m2_total_return), text(fill: accent, weight: "bold", num(u.m2_sharpe)), pct(d.m2_total_return), num(d.m2_sharpe))
    }
    #table(columns: (1.45fr, 1fr, 1fr, 1fr, 1fr), align: (left, right, right, right, right),
      [Strategy], [UP return], [UP Sharpe], [DOWN return], [DOWN Sharpe], ..cells,
    )
    #v(12pt)
    #note[#text(size: 14.5pt)[*M1 matches exactly.* Our M2 models are new fits; their predictions differ from these saved models.]]
    #src[roi_ext_mtm.csv; 150 replay checks across 10 Kronos daily cells. Same engine, fees and exit calendar for the following target comparison.]
  ]
}

#let gpu8-target-matrix-slide() = {
  let fits = (("autogluon", "up", [AutoGluon · UP]), ("autogluon", "down", [AutoGluon · DOWN]),
              ("kumo", "up", [Kumo · UP]), ("kumo", "down", [Kumo · DOWN]),
              ("tabpfn", "up", [TabPFN · UP]), ("tabpfn", "down", [TabPFN · DOWN]),
              ("rf", "up", [RF · UP]), ("rf", "down", [RF · DOWN]))
  let get(model, direction, mode) = trial-results.rows.find(r => r.model == model and r.direction == direction and r.mode == mode)
  let ag-down = get("autogluon", "down", "tb_k150")
  let tab-down = get("tabpfn", "down", "tb_k100")
  let rf-up = get("rf", "up", "tb_k150")
  let signed(x) = (if x >= 0 { "+" } else { "" }) + metric(x, digits: 3)
  let delta-cell(x) = text(fill: if x < 0 { accent } else { blue }, weight: "bold", signed(x))
  let pending = text(fill: muted, "Pending")

  slide(kicker: "Training targets", title: [TP and TB Labels])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 16pt)[*Frozen M1 proposes trades; TB builds labels for M2.* TP checks profit at day 7 after fees.]
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
    #note[#text(size: 15pt)[*TP = true-positive meta-labeling, not take profit.* All backtests keep day-7 exits.]]
    #src[TP rule verified on 18,230 complete proposals. Labels use future outcomes; M2 inputs use only information available at entry.]
  ]

  slide(kicker: "Four backends · " + comparison-status, title: [Test Sharpe])[
    #set par(leading: 0.35em, spacing: 0.5em)
    #text(size: 14pt)[Cash-MTM · entries #current-up.entry_start – #current-up.entry_end · final exit #current-up.equity_end.]
    #linebreak()
    #text(size: 14pt)[M1 Sharpe: *UP #metric(current-up.sharpe, digits: 4)* · DOWN #metric(current-down.sharpe, digits: 4). RF = Random Forest.]
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
    #note[#text(size: 14pt)[*All UP scores are negative.* Highest observed DOWN: *TabPFN k = 1 (#metric(tab-down.m2_sharpe, digits: 3))*.]]
    #src[Annualized cash-MTM Sharpe; 28 weekly returns. #text("*") = original threshold fell back to 0.5. One fit per cell; exploratory results.]
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
    #note[#text(size: 14pt)[DOWN: *AutoGluon k = 1.5 #signed(ag-down.delta_sharpe_vs_tp)* · *TabPFN k = 1 #signed(tab-down.delta_sharpe_vs_tp)* versus TP.]]
    #v(6pt)
    #text(size: 13.5pt)[Includes the sample filter: TB removes *13 UP / 64 DOWN* early TON training proposals.]
    #src[Cash-MTM through #current-up.equity_end · 28 weekly returns. Same M1 trades, fees and sizing rule; fresh TP controls. Descriptive deltas.]
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
      flow-node([TabPFN DOWN · k = 1], [Sharpe *#metric(tab-down.m2_sharpe, digits: 3)* · gain *#signed(tab-down.delta_sharpe_vs_tb_ref)*.\ M1 DOWN: *#metric(current-down.sharpe, digits: 3)*.]),
      flow-node([RF UP · k = 1.5], [Sharpe *#metric(rf-up.m2_sharpe, digits: 3)* · gain *#signed(rf-up.delta_sharpe_vs_tb_ref)*.\ Return *#percentage(rf-up.m2_total_return_pct)*: still loses money.]),
    )
    #src[Cash-MTM through #current-up.equity_end · 28 weekly returns; one fit per cell. Gains vary by backend and direction; no optimal-k claim.]
  ]
}
