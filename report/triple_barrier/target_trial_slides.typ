// Historical result slides used by earlier_target_trial.typ. Never fill missing fits with zero.
#import "../intro/theme.typ": *
#import "slides.typ": *
#let trial = json("pilot_results/original_test/slide_data.json")
#let number(x, digits: 2) = str(calc.round(x, digits: digits))
#let percent(x) = number(x) + "%"
#let tp-row(model, direction) = trial.rows.find(r => r.mode == "tp" and r.model == model and r.direction == direction)
#let status = str(trial.completed) + " / " + str(trial.expected) + " fits received"

#let target-trial-slides() = {
  slide(kicker: "Completed earlier-date trial · design", title: [Two backends, six targets, one execution policy])[
    #text(size: 16pt)[AutoGluon and Kumo · separate UP / DOWN fits in every cell · 24 fits in total.]
    #v(12pt)
    #set text(size: 15pt)
    #set table(inset: (x: 8pt, y: 12pt))
    #table(columns: (1.25fr, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr), align: left,
      [Backend], [TP], [TB ref], [k = 0.5], [k = 1], [k = 1.5], [k = 2],
      [AutoGluon], [UP / DOWN], [UP / DOWN], [UP / DOWN], [UP / DOWN], [UP / DOWN], [UP / DOWN],
      [Kumo], [UP / DOWN], [UP / DOWN], [UP / DOWN], [UP / DOWN], [UP / DOWN], [UP / DOWN],
    )
    #v(14pt)
    #grid(columns: (1fr, 1fr), gutter: 20pt,
      flow-node([Use the saved run's dates], [Frozen Kronos calls · 20 source assets · 1d\ Train: #trial.splits.start_date – #trial.splits.train_end\ Validation ends #trial.splits.val_end · cost 0.2%]),
      flow-node([Keep a matched control], [TP = original fixed-horizon baseline\ TB ref = TP labels with TB's history filter\ k changes labels; trades still exit at day 7.]),
    )
    #v(13pt)
    #note[#text(size: 14.5pt)[The TB history filter removes *77 early TON training calls* (13 UP, 64 DOWN). Compare k with the *same backend's TB reference* to isolate label effects; retain original TP as the reproduction anchor.]]
    #src[Saved run config; data ends #trial.splits.end_date · utility_nocal · #status. These are the earlier cutoffs, before matching the current GPU8 config.]
  ]

  slide(kicker: "Completed earlier-date trial · baseline", title: [The earlier UP M1 baseline is reproduced])[
    #text(size: 16pt)[Test entries: #trial.baseline.up.period_start – #trial.baseline.up.period_end · fixed-horizon TP labels · net returns.]
    #v(12pt)
    #set text(size: 15pt)
    #set table(inset: (x: 9pt, y: 8pt))
    #let rows = ()
    #for direction in ("up", "down") {
      let b = trial.baseline.at(direction)
      rows += (upper(direction), [M1 · all calls], percent(b.return_pct), number(b.sharpe), percent(b.max_drawdown_pct), [100%])
      for model in ("autogluon", "kumo") {
        let r = tp-row(model, direction)
        rows += (upper(direction), if model == "autogluon" { [AutoGluon · TP] } else { [Kumo · TP] }, percent(r.m2_total_return_pct), number(r.m2_sharpe), percent(r.m2_max_drawdown_pct), percent(r.coverage_pct))
      }
    }
    #table(columns: (0.65fr, 1.6fr, 1fr, 0.8fr, 1.05fr, 1fr), align: (left, left, right, right, right, right),
      [Side], [Strategy], [Return], [Sharpe], [Max drawdown], [Coverage], ..rows,
    )
    #v(14pt)
    #note[#text(size: 15pt)[UP M1: *Sharpe 0.5625*, *return +1.80%* — the earlier repo baseline. DOWN is a different set of proposals in a favourable short-selling window; compare targets within each direction.]]
    #src[Saved Test summaries; original spread-equity engine. #trial.baseline.up.n_horizon_returns non-overlapping 7-day returns; annualization ×√(365.25/7). Short-window, exploratory estimates.]
  ]

  slide(kicker: "Completed earlier-date trial · target comparison", title: [Does TB help the same backend?])[
    #text(size: 15pt)[Test entries: #trial.baseline.up.period_start – #trial.baseline.up.period_end · #status.]
    #v(7pt)
    #align(center, image("figures/target_trial_sharpe_matrix.svg", width: 100%, height: 6.5cm, fit: "contain"))
    #v(7pt)
    #note[#text(size: 14.5pt)[Cell: *Test Sharpe*. Δ and colour: change versus the same backend's *matched TB reference*.\
    A positive difference is descriptive evidence on this window; it is not a confidence interval or confirmation of a selected k.]]
    #src[Original Test path; M1 trades, fees, metrics and features checked across received fits. Updated #trial.updated_at. The earlier training-tail validation chart is withdrawn: its cutoff was selected on later dates.]
  ]
}
