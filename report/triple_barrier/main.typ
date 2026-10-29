// Teaching deck, checked against López de Prado (2018), §§3.2–3.7.
// Compile: rtk proxy typst compile --root report report/triple_barrier/main.typ report/triple_barrier/main.pdf
// Speaker explanations, conventions and source locations: speaker_notes.md.
#import "../intro/theme.typ": *
#import "slides.typ": *
#import "experiment_dates.typ": experiment-dates-slide, gpu8-baseline-slide, gpu8-cash-slide, gpu8-reference-slide, gpu8-target-matrix-slide, current-up, metric, comparison-status, benchmark-dates, benchmark-test-dates
#import "diagrams.typ": ground-truth-schema, historical-schema, live-schema

#show: setup

#title-slide(
  kicker: "MASTER PROJECT · M2 TARGETS",
  title: [Triple Barriers\ & Meta-Labeling],
  subtitle: [Trade outcomes, training labels and M2 results],
  meta: (
    ("Author", [Elie Bruno · NII Tokyo]),
    ("Reading", [López de Prado · AFML · Chapter 3]),
    ("Baseline", [Cash-MTM · M1 UP Sharpe: #metric(current-up.sharpe, digits: 4)]),
    ("Updated", [29 October 2026 · #comparison-status]),
  ),
)

#experiment-dates-slide()
#gpu8-baseline-slide()
#gpu8-cash-slide()
#gpu8-reference-slide()

#slide(kicker: "01 · Ground truth", title: [Ground Truth])[
  #text(size: 20pt)[*Future prices determine the label under a fixed exit rule.*]
  #v(12pt)
  #ground-truth-schema
  #v(14pt)
  #note[#text(size: 16pt)[M1 chooses the direction. The observed trade outcome determines the label.]]
  #src[AFML §§3.2–3.6. Illustrative long trade; assumed barrier fill; cost 0.2%.]
]

#slide(kicker: "02 · The distinction", title: [Barriers and Meta-Labels])[
  #v(14pt)
  #grid(columns: (1fr, 1fr), gutter: 24pt,
    card([Define the exit], [
      *Triple-barrier method*
      #v(12pt)
      First profit, stop or expiry.
      #v(12pt)
      Output: *exit time and return*.
    ], height: 6.4cm),
    card([Select the trade], [
      *Meta-labeling*
      #v(12pt)
      Predict whether M1's proposal succeeds.
      #v(12pt)
      Output: *score to accept, skip or size*.
    ], tone: blue, fill: blue-soft, height: 6.4cm),
  )
  #v(18pt)
  #note[#text(size: 17pt)[Meta-labeling works with either barrier exits or a fixed day-7 exit.]]
  #src[AFML §3.4 (barriers), §§3.6–3.7 (meta-labeling).]
]

#slide(kicker: "03 · Why the path matters", title: [Price Path Matters])[
  #grid(columns: (1.8fr, 1fr), gutter: 18pt, align: horizon,
    image("figures/teaching_path.svg", width: 100%),
    [
      #card([Hold until day 7], [
        Buy at 100 → sell at 103\
        Net return: *+2.8%*\
        Meta-label: *1*
      ], tone: blue, fill: blue-soft)
      #v(14pt)
      #card([Exit at the stop], [
        Buy at 100 → sell at 97\
        Net return: *−3.2%*\
        Meta-label: *0*
      ])
    ],
  )
  #v(12pt)
  #note[#text(size: 17pt)[Same forecast and price path; different exit, different label.]]
  #src[Illustration, not market data. Profit at 104; stop at 97; time limit day 7; cost 0.2%.]
]

#slide(kicker: "04 · Triple-barrier mechanics", title: [First Barrier Hit])[
  #text(size: 18pt)[Example: buy at 100 · take profit at 104 · stop at 97 · close by day 7.]
  #v(8pt)
  #align(center, image("figures/teaching_outcomes.svg", width: 93%, height: 7.2cm, fit: "contain"))
  #v(0pt)
  #align(center)[$ tau = min(t_"profit", t_"stop", t_"expiry") $]
  #v(0pt)
  #note[#text(size: 17pt)[First touch → exit → net return → label.]]
  #src[AFML §3.4, pp. 45–47. Three illustrative paths, shown as gross returns on a long trade.]
]

#slide(kicker: "05 · Choosing the barriers", title: [Setting Barrier Widths])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Volatility scaling], [
      $v_0$: volatility known at entry.
      #v(8pt)
      Profit target: $+a v_0$\
      Stop-loss: $-b v_0$\
      Time limit: $h$ bars
      #v(8pt)
      $a$ and $b$ may differ.
    ]),
    card([Our choice], [
      $v_0 = sigma_0 sqrt(h), quad h = 7$
      #v(8pt)
      $sigma_0$: EWMA daily volatility from past prices.
      #v(8pt)
      $sqrt(h)$ scaling is an approximation.
    ], tone: blue, fill: blue-soft),
  )
  #v(19pt)
  #note[#text(size: 17pt)[For a short: profit below entry, stop above.]]
  #src[AFML §3.3, Snippets 3.1–3.2. Experiments use a = b = k; +4%/−3% examples are illustrative.]
]

#slide(kicker: "06 · Two kinds of target", title: [Direction and Success])[
  #text(size: 19pt)[Price: *100 → 99* at expiry; no earlier barrier touch.]
  #v(18pt)
  #grid(columns: (1fr, 1.25fr), gutter: 23pt,
    card([Market direction], [
      *Direction label: DOWN*
      #v(12pt)
      The price fell by 1%.
      #v(12pt)
      Directional label: $-1$.
    ], height: 6.4cm),
    card([Trade success], [
      #set table(inset: (x: 6pt, y: 8pt))
      #table(columns: (1fr, 1fr, auto), align: (left, right, center),
        [M1 side], [Net return], [$z$],
        [Long], [−1.2%], [*0*],
        [Short], [+0.8%], [*1*],
      )
      #v(10pt)
      Falling prices can reward a short.
    ], tone: blue, fill: blue-soft, height: 6.4cm),
  )
  #v(14pt)
  #note[#text(size: 17pt)[*Label 0 = failed proposal.* It does not reverse M1's direction.]]
  #src[AFML §§3.5–3.6; Snippets 3.5 and 3.7. Cost: 0.2%.]
]

#slide(kicker: "07 · The exact ground-truth rule", title: [The Meta-Label Rule])[
  #align(center)[$
    g = s (P_tau / P_0 - 1) - c
    quad quad
    z = cases(1 & "if " g > 0, 0 & "otherwise")
  $]
  #align(center)[#small[$s$: +1 long / −1 short · $P_0$: entry · $P_tau$: exit · $c$: total cost]]
  #v(12pt)
  #set text(size: 17pt)
  #set table(inset: (x: 9pt, y: 7pt))
  #table(columns: (1.7fr, 0.8fr, 1fr, 0.5fr), align: (left, right, right, center),
    [Long trade starting at 100], [Exit price], [Net return], [$z$],
    [Profit reached first], [104], [+3.8%], [*1*],
    [Stop reached first], [97], [−3.2%], [*0*],
    [Expiry, small gain], [101], [+0.8%], [*1*],
    [Expiry, loss], [99], [−1.2%], [*0*],
    [Expiry, gain below costs], [100.1], [−0.1%], [*0*],
  )
  #v(15pt)
  #note[#text(size: 17pt)[Expiry can produce either label: profit = 1, otherwise = 0.]]
  #src[AFML Snippet 3.7; our rule subtracts 0.2% costs.]
]

#slide(kicker: "08 · Historical training", title: [Training M2])[
  #v(12pt)
  #historical-schema
  #v(18pt)
  #note[#text(size: 16pt)[*Inputs*: known at entry. *Targets*: calculated from future outcomes.]]
  #src[AFML §§3.6–3.7. Labels can describe hypothetical trades.]
]

#slide(kicker: "09 · A new trading decision", title: [Using M2])[
  #v(15pt)
  #live-schema
  #v(16pt)
  #note[#text(size: 16pt)[M2 sees only entry-time inputs. Choose the cutoff on validation data.]]
  #src[AFML §§3.6–3.7 and §10.3. The 0.60 cutoff is illustrative; calibration and payoffs matter.]
]

#slide(kicker: "10 · What M2 adds", title: [Trade Selection])[
  #grid(columns: (1fr, auto, 1fr), gutter: 17pt, align: horizon,
    card([100 proposed trades], [
      *55* profitable · *45* unprofitable
      #v(16pt)
      #stat[55%][Win rate if all proposals are taken]
    ], kicker: "M1 proposes", height: 6.4cm),
    arrow,
    card([40 accepted trades], [
      *32* profitable · *8* unprofitable
      #v(16pt)
      #stat[80%][Win rate among accepted proposals]
    ], kicker: "M2 selects", tone: blue, fill: blue-soft, height: 6.4cm),
  )
  #v(15pt)
  #text(size: 17pt)[Skipped: *23 missed winners* and *37 avoided losers*.]
  #v(13pt)
  #note[#text(size: 16pt)[Higher win rate can help; profit also depends on win and loss sizes.]]
  #src[Illustrative counts, not results. AFML §3.7: precision–recall trade-off.]
]

#slide(kicker: "11 · Our M1 → M2 pipeline", title: [Fixed and Barrier Targets])[
  #v(12pt)
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Day-7 target], [
      Exit: *day 7*
      #v(8pt)
      $z_"fixed" = bb(1)[s (P_7/P_0 - 1) > c]$
      #v(10pt)
      Did the day-7 return cover costs?
    ], height: 6.4cm),
    card([Barrier target], [
      Exit: *first profit, stop or expiry*
      #v(8pt)
      $z_"TB" = bb(1)[s (P_tau/P_0 - 1) > c]$
      #v(10pt)
      Did the barrier-exit return cover costs?
    ], tone: blue, fill: blue-soft, height: 6.4cm),
  )
  #v(14pt)
  #note[#text(size: 16pt)[Kronos keeps the direction; the label defines what M2 learns to predict.]]
  #src[Current four-backend trial changes labels only; all backtests keep day-7 exits. Label rules: analysis/label_counts.py.]
]

#slide(kicker: "12 · A separate alternative", title: [Return Hurdles and Exits])[
  #v(10pt)
  #set text(size: 17pt)
  #set table(inset: (x: 10pt, y: 12pt))
  #table(columns: (1fr, 1fr, 1.7fr), align: left,
    [Target], [When evaluated], [What makes z = 1?],
    [Current meta-label], [Day 7], [Return exceeds costs.],
    [Larger return hurdle], [Day 7], [Return exceeds a volatility-scaled threshold.],
    [Triple-barrier meta-label], [First exit], [Return at exit exceeds costs.],
  )
  #v(20pt)
  #note[#text(size: 17pt)[A hurdle changes the required gain. Barriers change the exit time.]]
  #src[AFML §§3.2–3.4. Our existing threshold experiment uses s·r₇ > kσ₀√7; it is a separate target.]
]

#slide(kicker: "13 · What our measurements say", title: [Earlier LightGBM Benchmark])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([5.9% of labels change], [
      Symmetric $plus.minus sigma_0 sqrt(7)$ barriers.
      #v(10pt)
      Positive labels: *54.7% → 52.7%*
      #v(10pt)
      254,952 historical daily Kronos calls.
    ], kicker: "Label comparison", height: 6.4cm),
    card([Δ Sharpe: −0.06], [
      Barrier target vs day-7 target; same day-7 exits.
      #v(10pt)
      95% interval: *−0.57 to +0.30*
      #v(10pt)
      This interval includes zero.
    ], kicker: "Label-only benchmark", tone: blue, fill: blue-soft, height: 6.4cm),
  )
  #v(16pt)
  #note[#text(size: 16pt)[This earlier benchmark did not establish a gain.]]
  #src[Separate LightGBM study; daily equal-weight portfolio; 3 seeds; 20% validation cutoff. #benchmark-dates]
]

#slide(kicker: "14 · For our synthetic-data work", title: [Synthetic Training Labels])[
  #v(14pt)
  #grid(columns: (1.1fr, auto, 1.2fr, auto, 0.7fr), gutter: 12pt, align: horizon,
    [
      #flow-node([Real example], [Observed past + actual future], tone: accent, fill: soft)
      #v(16pt)
      #flow-node([Synthetic example], [Generated past + generated future])
    ],
    arrow,
    flow-node([Same label rule], [
      Frozen M1 on past prices.\
      Same exits and costs on future prices.
    ]),
    arrow,
    flow-node([Train M2], [Inputs at entry\ + calculated z]),
  )
  #v(23pt)
  #note[#text(size: 17pt)[Train on generated paths; confirm any benefit on held-out real data.]]
  #src[AFML ch. 3 applied to this thesis. Generated futures provide labels; model inputs use only the generated past.]
]

#slide(kicker: "15 · The answer to remember", title: [From Outcomes to Decisions])[
  #v(14pt)
  #grid(columns: (1fr, auto, 1fr, auto, 1fr), gutter: 13pt, align: horizon,
    flow-node([Triple barriers], [Choose the exit.], tone: accent, fill: soft),
    arrow,
    flow-node([Ground-truth label], [Did the trade profit after costs?], tone: accent, fill: soft),
    arrow,
    flow-node([M2], [Predict success for a new proposal.]),
  )
  #v(27pt)
  #text(size: 19pt)[*Barriers*: define the outcome.\
  *Meta-labeling*: select M1's proposals.]
  #v(22pt)
  #note[#text(size: 17pt)[Define the trade, calculate the labels, then test M2.]]
  #src[AFML §§3.4–3.7. Better prediction and profit require evidence.]
]

#slide(kicker: "Reading guide", title: [Book References])[
  #set text(size: 18pt)
  #set table(inset: (x: 10pt, y: 10pt))
  #table(columns: (1.4fr, 1.6fr), align: left,
    [Question], [López de Prado (2018), AFML],
    [Why does the price path matter?], [§§3.2–3.4 · pp. 43–47],
    [What is a directional label?], [§3.5 · pp. 48–50 · Snippet 3.5],
    [What is a meta-label?], [§3.6 · pp. 50–51 · Snippet 3.7],
    [What does the second model add?], [§3.7 · pp. 51–53],
    [How can probability inform size?], [§10.3 · pp. 142–144],
    [How do we avoid overlapping-label leakage?], [§7.4 · pp. 105–109],
  )
  #v(18pt)
  #small[Printed-book pages. Examples are illustrative; 0.2% costs and a 7-day horizon are our choices.]
]

#section("A", [Supporting Experiments], answer: [Earlier benchmarks and evaluation assumptions])

#slide(kicker: "Appendix · Label counts", title: [Label Changes])[
  #set text(size: 18pt)
  #set table(inset: (x: 10pt, y: 10pt))
  #table(columns: (1.4fr, 1fr, 1fr, 1fr), align: (left, right, right, right),
    [Target], [Positive], [Negative], [Labels changed],
    [Day 7], [139,453], [115,499], [—],
    [Barrier k = 0.5], [128,936], [126,016], [23.5%],
    [Barrier k = 1], [134,295], [120,657], [5.9%],
    [Barrier k = 1.5], [137,022], [117,930], [2.0%],
    [Barrier k = 2], [138,265], [116,687], [0.9%],
  )
  #v(20pt)
  #note[#text(size: 17pt)[Tighter barriers change more labels; performance still needs testing.]]
  #src[254,952 calls; all periods pooled. #benchmark-dates High/low touches; same-bar ties = stop. Saved label_counts.csv.]
]

#slide(kicker: "Appendix · Labels only", title: [Label-Only Benchmark])[
  #set text(size: 17pt)
  #set table(inset: (x: 9pt, y: 9pt))
  #table(columns: (1.3fr, 0.7fr, 0.9fr, 1.4fr), align: (left, right, right, right),
    [M2 target], [Test trades], [Test Sharpe], [Δ Sharpe · 95% interval],
    [Day 7], [20,976], [−0.73], [Reference],
    [Barrier k = 0.5], [17,386], [−1.16], [−0.44 · [−1.28, +0.25]],
    [Barrier k = 1], [20,398], [−0.79], [−0.06 · [−0.57, +0.30]],
    [Barrier k = 1.5], [20,904], [−0.74], [−0.01 · [−0.30, +0.19]],
    [Barrier k = 2], [20,896], [−0.72], [+0.00 · [−0.12, +0.10]],
  )
  #v(18pt)
  #note[#text(size: 16pt)[All intervals include zero. No confirmed improvement in this benchmark.]]
  #src[Separate LightGBM study; daily equal-weight portfolio; 3 seeds; 20% validation cutoff; 10-day block bootstrap. #benchmark-test-dates]
]

#slide(kicker: "Appendix · Other exits", title: [Exit-Policy Benchmark])[
  #set text(size: 17pt)
  #set table(inset: (x: 9pt, y: 11pt))
  #table(columns: (2fr, 0.7fr, 1fr), align: (left, right, right),
    [Comparison on the test period], [Δ Sharpe], [95% interval],
    [M1 only: volatility barriers vs day 7], [−0.67], [−1.17 to −0.25],
    [M1 only: volatility barriers vs fixed ±10%], [+0.49], [+0.04 to +1.06],
    [M2: barrier label + exit vs current label + exit], [−0.23], [−1.32 to +0.55],
  )
  #v(19pt)
  #note[#text(size: 17pt)[Exit changes and label changes must be evaluated separately.]]
  #src[Separate daily equal-weight portfolio; 10-day block bootstrap; M2 uses one seed. #benchmark-test-dates]
]

#slide(kicker: "Appendix · Honest evaluation", title: [Evaluation Assumptions])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Timing and validation], [
      - Use entry-time inputs only.
      - Generate M1 calls out of sample.
      - Purge overlaps; apply embargoes.
      - Validate choices, confirm on fresh data.
    ], tone: blue, fill: blue-soft),
    card([Execution assumptions], [
      - Book snippets: closing prices.
      - Our labels: daily highs and lows.
      - Same-candle double touch: stop first.
      - Assumed barrier fills; 0.2% costs.
    ]),
  )
  #src[AFML Snippet 3.2 and §7.4; tb.py and benchmark.py. Gaps, slippage, funding and borrow costs need further modeling.]
]

#slide(kicker: "Appendix · Probability and size", title: [Probability and Position Size])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Prediction to position], [
      $p = P(z = 1 | "inputs", s)$.
      #v(12pt)
      A separate rule sets the size $q(p)$.
      #v(12pt)
      $ "position" = s dot q(p), quad q(p) >= 0 $
      #v(10pt)
      Zero size = skip; M1 keeps the side.
    ], tone: blue, fill: blue-soft),
    card([Payoffs matter], [
      Win: net gain $G$. Loss: net cost $L$.
      #v(10pt)
      $ E[g] = p G - (1-p)L $
      $ E[g] > 0 <=> p > L/(G+L) $
      #v(10pt)
      Gain 1, lose 2 →\
      break-even probability = *66.7%*.
    ]),
  )
  #v(16pt)
  #note[#text(size: 16pt)[A 50% cutoff need not break even. Account for payoffs and risk.]]
  #src[AFML §§3.6 and 10.3. Two-payoff example; the book uses a different sizing formula.]
]

// Current GPU8-date trial; earlier completed results have their own historical PDF.
#gpu8-target-matrix-slide()
