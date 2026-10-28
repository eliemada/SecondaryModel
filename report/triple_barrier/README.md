# Triple-barrier target experiment: slides and evidence

The current decks use Pablo's GPU8 Test window, **2026-01-08–2026-07-18**.
The independently reproduced M1 spread-equity baseline has UP Sharpe **−2.5744**
and DOWN Sharpe **+1.7423**. The new AutoGluon/Kumo target comparison was queued
with **0 of 24 fits completed** when these slides were built on 2026-10-28.
Pablo's saved M2 scores are labeled as reference results.

- [Short presentation](prendinger_brief.pdf): 12 slides.
- [Full presentation](main.pdf): 28 slides.
- [Historical target trial](earlier_target_trial.pdf): 4 slides, with the completed
  earlier experiment on **2025-10-09–2026-01-18**. Its positive UP scores belong to
  that earlier period.

Pages 3 and 5 of the current decks highlight the negative UP Sharpes. The final
matrix explicitly marks the new fits as pending. The cash comparison distinguishes
positions held at entry cost from positions marked to current closing prices;
neither is the spread-equity calculation.

## Rebuild the PDFs

From the repository root, with Typst installed:

```sh
typst compile --root report report/triple_barrier/prendinger_brief.typ report/triple_barrier/prendinger_brief.pdf
typst compile --root report report/triple_barrier/main.typ report/triple_barrier/main.pdf
typst compile --root report report/triple_barrier/earlier_target_trial.typ report/triple_barrier/earlier_target_trial.pdf
```

The required figures, JSON/YAML inputs, shared theme and logos accompany the
sources. Inter and New Computer Modern are the intended fonts; font availability
can affect layout on another machine.

The GitHub copy is a presentation build snapshot. Dataset caches, model weights,
private administrative files and temporary previews are excluded. Python analysis
and download helpers in the original thesis workspace are separate from this
standalone Typst build. Speaker notes retain their original research provenance
and workspace references.
