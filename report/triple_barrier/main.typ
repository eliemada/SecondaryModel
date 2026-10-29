// Teaching deck, checked against López de Prado (2018), §§3.2–3.7.
// Compile: rtk proxy typst compile --root report report/triple_barrier/main.typ report/triple_barrier/main.pdf
// Speaker explanations, conventions and source locations: speaker_notes.md.
#import "../intro/theme.typ": *
#import "slides.typ": *
#import "experiment_dates.typ": experiment-dates-slide, gpu8-baseline-slide, gpu8-cash-slide, gpu8-reference-slide, gpu8-target-matrix-slide, current-up, metric, comparison-status, benchmark-dates, benchmark-test-dates
#import "diagrams.typ": ground-truth-schema, historical-schema, live-schema

#show: setup

#title-slide(
  kicker: "MASTER PROJECT · UNDERSTANDING THE LABELS",
  title: [Triple barriers\ & meta-labeling],
  subtitle: [Where the ground truth comes from,\ how the trade is evaluated, and what M2 adds.],
  meta: (
    ("Author", [Elie Bruno · NII Tokyo]),
    ("Reading", [López de Prado · Advances in Financial Machine Learning · Chapter 3]),
    ("Update", [29 October 2026 · UP M1 Sharpe #metric(current-up.stats.m1_sharpe, digits: 4) · #comparison-status]),
  ),
)

#experiment-dates-slide()
#gpu8-baseline-slide()
#gpu8-cash-slide()
#gpu8-reference-slide()

#slide(kicker: "01 · Ground truth", title: [What is the ground truth based on?])[
  #text(size: 20pt)[*The observed future price path, evaluated under a rule fixed at entry.*]
  #v(12pt)
  #ground-truth-schema
  #v(14pt)
  #note[#text(size: 16pt)[M1 supplies the proposed direction. Actual future prices supply the outcome.\
  The ground-truth label is calculated from that outcome.]]
  #src[AFML §§3.2–3.6. Illustrative long trade; assumed fill at the barrier and total cost of 0.2%.]
]

#slide(kicker: "02 · The distinction", title: [Two methods answer two different questions])[
  #v(14pt)
  #grid(columns: (1fr, 1fr), gutter: 24pt,
    card([When does the trade end?], [
      *Triple-barrier method*
      #v(12pt)
      Follow the price until profit-taking, stop-loss or the time limit.
      #v(12pt)
      Output: an *exit time* and a *realized return*.
    ], kicker: "Define the outcome", height: 7.4cm),
    card([Should we take M1's trade?], [
      *Meta-labeling*
      #v(12pt)
      Learn whether a proposed long or short trade will have a successful outcome.
      #v(12pt)
      Output: a *probability* used to accept, skip or size the trade.
    ], kicker: "Predict the outcome", tone: blue, fill: blue-soft, height: 7.4cm),
  )
  #v(18pt)
  #note[#text(size: 17pt)[They can be combined. Meta-labeling also works with a fixed exit at day 7.]]
  #src[AFML §3.4 (barriers), §§3.6–3.7 (meta-labeling).]
]

#slide(kicker: "03 · Why the path matters", title: [The day-7 price can hide an earlier loss])[
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
  #note[#text(size: 17pt)[Same M1 forecast, same market path. A different exit rule gives a different ground truth.]]
  #src[Illustration, not market data. Profit at 104; stop at 97; time limit day 7; cost 0.2%.]
]

#slide(kicker: "04 · Triple-barrier mechanics", title: [Close the trade at whichever barrier comes first])[
  #text(size: 18pt)[Example: buy at 100 · take profit at 104 · stop at 97 · close by day 7.]
  #v(8pt)
  #align(center, image("figures/teaching_outcomes.svg", width: 93%, height: 7.2cm, fit: "contain"))
  #v(0pt)
  #align(center)[$ tau = min(t_"profit", t_"stop", t_"expiry") $]
  #v(0pt)
  #note[#text(size: 17pt)[The first touch determines the exit. The return at that exit determines the label.]]
  #src[AFML §3.4, pp. 45–47. Three illustrative paths, shown as gross returns on a long trade.]
]

#slide(kicker: "05 · Choosing the barriers", title: [Set the distances using information available at entry])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Scale the distances by volatility], [
      Let $v_0$ be a return-volatility estimate known at entry.
      #v(8pt)
      Profit target: $+a v_0$\
      Stop-loss: $-b v_0$\
      Time limit: $h$ bars
      #v(8pt)
      $a$ and $b$ may differ.
    ]),
    card([Our experiment's choice], [
      $v_0 = sigma_0 sqrt(h), quad h = 7$
      #v(8pt)
      $sigma_0$: EWMA estimate of daily-return volatility, using past prices.
      #v(8pt)
      $sqrt(h)$ is a horizon-scaling approximation. The method does not require it.
    ], tone: blue, fill: blue-soft),
  )
  #v(19pt)
  #note[#text(size: 17pt)[For a *short* trade, profit is below the entry price and the stop is above it.\
  Apply the barriers to the trade's return, with its direction accounted for.]]
  #src[AFML §3.3 and Snippets 3.1–3.2. Our symmetric experiments use a = b = k; the +4%/−3% examples are illustrative.]
]

#slide(kicker: "06 · Two kinds of target", title: [A direction label and a meta-label mean different things])[
  #text(size: 19pt)[Suppose price goes from *100 to 99* by expiry, with no earlier barrier touch.]
  #v(18pt)
  #grid(columns: (1fr, 1.25fr), gutter: 23pt,
    card([What did the market do?], [
      *Direction label: DOWN*
      #v(12pt)
      The price fell by 1%.
      #v(12pt)
      In a directional target, this can be encoded as $-1$.
    ], kicker: "Label the price movement", height: 7cm),
    card([Did M1's proposed trade pay?], [
      #set table(inset: (x: 6pt, y: 8pt))
      #table(columns: (1fr, 1fr, auto), align: (left, right, center),
        [M1 side], [Net return], [$z$],
        [Long], [−1.2%], [*0*],
        [Short], [+0.8%], [*1*],
      )
      #v(10pt)
      A falling price can be a *successful short*.
    ], kicker: "Label the proposed trade", tone: blue, fill: blue-soft, height: 7cm),
  )
  #v(14pt)
  #note[#text(size: 17pt)[Meta-label *0 means “this proposal failed”*. It does not mean “take the opposite side”.]]
  #src[AFML §3.5 versus §3.6, especially Snippets 3.5 and 3.7. Net returns use the illustrative 0.2% cost.]
]

#slide(kicker: "07 · The exact ground-truth rule", title: [Meta-label 1 means a positive net trade return])[
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
  #note[#text(size: 17pt)[Expiry is an exit condition. It can produce either meta-label.]]
  #src[AFML Snippet 3.7 labels positive side-adjusted returns as 1. Subtracting c = 0.2% is our cost-aware extension.]
]

#slide(kicker: "08 · Historical training", title: [Build the labels first; then train M2 to predict them])[
  #v(12pt)
  #historical-schema
  #v(18pt)
  #note[#text(size: 16pt)[Future prices are used to calculate the *training target*.\
  The *inputs* are the features and M1 outputs that were available at entry.]]
  #src[AFML §§3.6–3.7. Labels can be calculated for hypothetical trades; actual execution is not required.]
]

#slide(kicker: "09 · A new trading decision", title: [At decision time, the outcome is still unknown])[
  #v(15pt)
  #live-schema
  #v(16pt)
  #note[#text(size: 16pt)[M2 predicts the chance of success; it does not receive the future price path or the label.\
  The 0.60 cutoff is illustrative. Choose the decision rule on validation data.]]
  #src[AFML §§3.6–3.7; probability-based bet sizing in §10.3. Calibration and payoff sizes matter for using p.]
]

#slide(kicker: "10 · What M2 adds", title: [M2 can filter the weaker proposals from M1])[
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
  #text(size: 17pt)[The 60 skipped proposals include *23 missed winners* and *37 avoided losers*.]
  #v(13pt)
  #note[#text(size: 16pt)[The aim is better selection, with fewer trades. This improvement must be measured.\
  Win rate alone does not determine profit: the sizes of wins and losses also matter.]]
  #src[Illustrative counts, not experimental results. AFML §3.7 motivates the precision–recall trade-off.]
]

#slide(kicker: "11 · Our M1 → M2 pipeline", title: [We already use meta-labeling. Barriers change the target.])[
  #v(12pt)
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Our current dataset], [
      M1: Kronos proposes UP or DOWN.\
      M2: predicts whether that proposal succeeds.
      #v(12pt)
      Exit: *day 7*
      #v(8pt)
      $z_"fixed" = bb(1)[s (P_7/P_0 - 1) > c]$
      #v(10pt)
      “Would holding this side for 7 days pay?”
    ], kicker: "Fixed-horizon meta-label", height: 8cm),
    card([With triple-barrier labels], [
      M1 and M2 keep the same roles.\
      The outcome follows a different trade.
      #v(12pt)
      Exit: *first profit, stop or expiry*
      #v(8pt)
      $z_"TB" = bb(1)[s (P_tau/P_0 - 1) > c]$
      #v(10pt)
      “Would this side pay under these exits?”
    ], kicker: "Triple-barrier meta-label", tone: blue, fill: blue-soft, height: 8cm),
  )
  #v(14pt)
  #note[#text(size: 16pt)[The added value is a target that reflects the chosen exit policy.\
  When M2 is meant to predict trade profitability, label that same trade.]]
  #src[Current dataset: Synthetic-Generation/data/complete/README.md. Barrier labels: analysis/label_counts.py.]
]

#slide(kicker: "12 · A separate alternative", title: [A larger day-7 threshold asks a different question])[
  #v(10pt)
  #set text(size: 17pt)
  #set table(inset: (x: 10pt, y: 12pt))
  #table(columns: (1fr, 1fr, 1.7fr), align: left,
    [Target], [When evaluated], [What makes z = 1?],
    [Current meta-label], [Day 7], [The proposed side earns more than costs.],
    [Larger return hurdle], [Day 7], [The proposed side earns more than a chosen volatility-scaled threshold.],
    [Triple-barrier meta-label], [First exit], [The proposed side earns more than costs at that exit.],
  )
  #v(20pt)
  #note[#text(size: 17pt)[A volatility threshold changes *how large the gain must be*.\
  Triple barriers change *when the trade ends*. Both change the definition of success.]]
  #src[AFML §§3.2–3.4. Our existing threshold experiment uses s·r₇ > kσ₀√7; it is a separate target.]
]

#slide(kicker: "13 · What our measurements say", title: [The existing experiment has not established a gain])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([5.9% of labels change], [
      With symmetric $plus.minus sigma_0 sqrt(7)$ barriers:
      #v(10pt)
      Positive labels: *54.7% → 52.7%*
      #v(10pt)
      254,952 historical daily Kronos calls.
    ], kicker: "Label comparison", height: 6.4cm),
    card([Δ Sharpe: −0.06], [
      Barrier-trained M2 versus the current target, with both exiting at day 7.
      #v(10pt)
      95% interval: *−0.57 to +0.30*
      #v(10pt)
      This interval includes zero.
    ], kicker: "Label-only benchmark", tone: blue, fill: blue-soft, height: 6.4cm),
  )
  #v(16pt)
  #note[#text(size: 16pt)[These results concern this setup. They do not establish that barriers never help.\
  A changed definition of success needs evaluation under the intended trading policy.]]
  #src[Separate LightGBM benchmark, 3 seeds; 20% validation cutoff. #benchmark-dates Saved label_counts.csv and label_benchmark.csv.]
]

#slide(kicker: "14 · For our synthetic-data work", title: [Use the same label rule on real and synthetic paths])[
  #v(14pt)
  #grid(columns: (1.1fr, auto, 1.2fr, auto, 0.7fr), gutter: 12pt, align: horizon,
    [
      #flow-node([Real example], [Observed past + actual future], tone: accent, fill: soft)
      #v(16pt)
      #flow-node([Synthetic example], [Generated past + generated future])
    ],
    arrow,
    flow-node([Same labeling procedure], [
      Run frozen M1 on the past.\
      Evaluate its side on the future.\
      Use the same exits and costs.
    ]),
    arrow,
    flow-node([Train M2], [Inputs at entry\ + calculated z]),
  )
  #v(23pt)
  #note[#text(size: 17pt)[A synthetic label is correct *for the generated path*.\
  Whether that helps on real markets must be checked on held-out real data.]]
  #v(15pt)
  #text(size: 16pt)[The generated future is used for labels; M1 and M2 inputs use the generated past only.]
  #src[Application to this thesis. The labeling rule follows AFML ch. 3; improvement from augmentation is a research question.]
]

#slide(kicker: "15 · The answer to remember", title: [Observed prices → trade outcome → meta-label → M2])[
  #v(14pt)
  #grid(columns: (1fr, auto, 1fr, auto, 1fr), gutter: 13pt, align: horizon,
    flow-node([Triple barriers], [Specify when the proposed trade ends.], tone: accent, fill: soft),
    arrow,
    flow-node([Ground-truth label], [Did that trade earn a positive net return?], tone: accent, fill: soft),
    arrow,
    flow-node([M2], [Predict the chance of that outcome for a new proposal.]),
  )
  #v(27pt)
  #text(size: 21pt)[*What is the addition?*]
  #v(10pt)
  #text(size: 19pt)[Triple barriers add the *price path and exit policy* to the target.\
  Meta-labeling adds *selection, and potentially sizing*, to M1's direction.]
  #v(22pt)
  #note[#text(size: 17pt)[First define the trade we want to run. Then calculate its labels and test whether M2 helps select it.]]
  #src[AFML §§3.4–3.7. Triple barriers are a labeling method; improved prediction and profit require evidence.]
]

#slide(kicker: "Reading guide", title: [Where these ideas appear in the book])[
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
  #small[Page numbers refer to the printed book. All schematic price paths and filtering counts are illustrative.\
  The 0.2% cost and 7-day experiments are our conventions, not universal requirements of the method.]
]

#section("A", [Appendix: experiments and implementation], answer: [Supporting results and assumptions for discussion.])

#slide(kicker: "Appendix · Label counts", title: [Tighter barriers change more training labels])[
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
  #note[#text(size: 17pt)[A changed label is a changed target, not evidence of a better predictor.]]
  #src[254,952 calls; all periods pooled. #benchmark-dates High/low touches; same-bar ties = stop. Saved label_counts.csv.]
]

#slide(kicker: "Appendix · Labels only", title: [Changing M2's target while still exiting at day 7])[
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
  #note[#text(size: 16pt)[Each cutoff selects the top 20% on validation and is then held fixed.\
  The number of accepted test trades can differ. None of these intervals excludes zero.]]
  #src[#benchmark-test-dates Saved label_benchmark.csv; LightGBM per side; predictions averaged over 3 seeds; paired 10-day block bootstrap.]
]

#slide(kicker: "Appendix · Other exits", title: [Changing the exit is a separate experiment])[
  #set text(size: 17pt)
  #set table(inset: (x: 9pt, y: 11pt))
  #table(columns: (2fr, 0.7fr, 1fr), align: (left, right, right),
    [Comparison on the test period], [Δ Sharpe], [95% interval],
    [M1 only: volatility barriers vs day 7], [−0.67], [−1.17 to −0.25],
    [M1 only: volatility barriers vs fixed ±10%], [+0.49], [+0.04 to +1.06],
    [M2: barrier label + exit vs current label + exit], [−0.23], [−1.32 to +0.55],
  )
  #v(19pt)
  #note[#text(size: 17pt)[Changing labels and changing execution answer different experimental questions.\
  These saved comparisons do not establish an improvement from the full proposal.]]
  #src[#benchmark-test-dates Saved benchmark_ci.json; 10-day block bootstrap. M2 rows use a single-seed model, unlike the label-only table.]
]

#slide(kicker: "Appendix · Honest evaluation", title: [A valid label also needs realistic timing and execution])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([Information and validation], [
      - Features and volatility use information available at entry.
      - Generate M1 calls out of sample if M1 is trained locally.
      - Purge labels that overlap held-out periods; embargo where needed.
      - Select rules on validation; use fresh data for confirmation.
    ], tone: blue, fill: blue-soft),
    card([Price observation and fills], [
      - The book's snippets check observed closes.
      - Our experiments check daily highs and lows.
      - Both barriers in one candle: order is unknown; our code assumes stop first.
      - Barrier fills and fixed 0.2% costs are simplifying assumptions.
    ]),
  )
  #src[AFML Snippet 3.2 and §7.4; local tb.py and benchmark.py. Gaps, slippage, funding and borrow costs need appropriate execution modeling.]
]

#slide(kicker: "Appendix · Probability and size", title: [The binary target is not a position size])[
  #grid(columns: (1fr, 1fr), gutter: 22pt,
    card([From prediction to position], [
      M2 produces a score interpreted as\
      $p = P(z = 1 | "inputs", s)$.
      #v(12pt)
      A separate rule maps that score to a nonnegative amount $q(p)$.
      #v(12pt)
      $ "position" = s dot q(p), quad q(p) >= 0 $
      #v(10pt)
      Zero size = skip; M1 keeps the side.
    ], tone: blue, fill: blue-soft),
    card([Probability alone is insufficient], [
      With net gain $G$ on a win and net loss magnitude $L$ on a loss:
      #v(10pt)
      $ E[g] = p G - (1-p)L $
      $ E[g] > 0 <=> p > L/(G+L) $
      #v(10pt)
      Toy example: gain 1, lose 2 →\
      break-even probability = *66.7%*.
    ]),
  )
  #v(16pt)
  #note[#text(size: 16pt)[Use calibrated probabilities, realistic payoffs and a risk budget.\
  A 50% probability cutoff is not automatically the trading break-even point.]]
  #src[AFML §3.6 and §10.3. Expected-value equation is an illustrative two-payoff calculation, not the book's sizing formula.]
]

// Current GPU8-date trial; earlier completed results have their own historical PDF.
#gpu8-target-matrix-slide()
