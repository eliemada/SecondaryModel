// Schemas distinguish information available at entry from outcomes observed later.
// Labels are training targets; they are never live inputs to M2.
#import "../intro/theme.typ": *
#import "slides.typ": flow-node, arrow, blue, blue-soft

#let ground-truth-schema = [
  #set par(leading: 0.45em, spacing: 6pt)
  #text(size: 11pt, fill: blue, weight: "semibold")[AT ENTRY · FIX THE QUESTION]
  #v(7pt)
  #grid(columns: (1fr, auto, 1fr, auto, 1.15fr), gutter: 12pt, align: horizon,
    flow-node([M1 proposes a trade], [Example: UP → buy\ Entry price: 100]),
    arrow,
    flow-node([Specify the trade], [Profit at 104 · stop at 97\ Time limit: day 7]),
    arrow,
    flow-node([Freeze the rule], [Fix the exit policy\ and cost assumptions.]),
  )
  #v(12pt)
  #text(size: 11pt, fill: accent, weight: "semibold")[AFTERWARDS · OBSERVE THE ANSWER]
  #v(7pt)
  #grid(columns: (1fr, auto, 1fr, auto, 1.15fr), gutter: 12pt, align: horizon,
    flow-node([Actual market prices], [100 → 101 → 97 → …\ Stop hit on day 2.], tone: accent, fill: soft),
    arrow,
    flow-node([Calculate the outcome], [Buy at 100, exit at 97\ −3% − 0.2% costs = −3.2%], tone: accent, fill: soft),
    arrow,
    flow-node([Ground truth: z = 0], [This proposed trade lost money.\ M2 will learn to predict z.], tone: accent, fill: soft),
  )
]

#let historical-schema = [
  #set par(leading: 0.45em, spacing: 6pt)
  #grid(columns: (1fr, auto, 1fr, auto, 1fr), gutter: 12pt, align: horizon,
    flow-node([1 · Save the inputs], [At entry: market features\ + M1's forecast and side.]),
    arrow,
    flow-node([2 · Observe the future], [Follow actual prices until\ profit, stop or time limit.], tone: accent, fill: soft),
    arrow,
    flow-node([3 · Calculate z], [1 if net return > 0;\ 0 otherwise.], tone: accent, fill: soft),
  )
  #v(10pt)
  #align(center)[#text(size: 23pt, fill: muted)[↓] #h(10pt) #text(size: 16pt)[Repeat for historical M1 proposals]]
  #v(8pt)
  #grid(columns: (1.6fr, auto, 1fr), gutter: 14pt, align: horizon,
    flow-node([Training examples], [Entry-time inputs → eventual target z\ Both profitable and unprofitable proposals.]),
    arrow,
    flow-node([Fit M2], [Learn which entry-time conditions\ are associated with z = 1.]),
  )
]

#let live-schema = [
  #set par(leading: 0.45em, spacing: 6pt)
  #grid(columns: (1.1fr, auto, 1fr, auto, 1fr), gutter: 13pt, align: horizon,
    flow-node([A new M1 proposal], [Today's features + forecast\ M1 chooses long or short.]),
    arrow,
    flow-node([Trained M2], [Estimates p = P(z = 1)\ for that proposed trade.]),
    arrow,
    flow-node([Decision rule], [Take M1's side or skip.\ Optional: determine size.]),
  )
  #v(22pt)
  #grid(columns: (1fr, 1fr), gutter: 18pt,
    flow-node([Example · take], [M1: SHORT · M2: p = 0.75\ With a 0.60 cutoff: take the SHORT.]),
    flow-node([Example · skip], [M1: SHORT · M2: p = 0.40\ With the same cutoff: no position.], tone: muted, fill: soft),
  )
]
