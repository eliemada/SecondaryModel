// Historical results preserved separately from the current GPU8-date presentation.
#import "slides.typ": *
#import "target_trial_slides.typ": target-trial-slides, trial, status

#show: setup
#set document(title: "Historical M2 target trial — October 2025 to January 2026", author: "Elie Bruno")

#title-slide(
  kicker: "HISTORICAL APPENDIX",
  title: [Earlier Target Trial],
  subtitle: [AutoGluon and Kumo · earlier Test dates],
  meta: (
    ("Test entries", [#trial.baseline.up.period_start – #trial.baseline.up.period_end]),
    ("Train ends", [#trial.splits.train_end · validation ends #trial.splits.val_end]),
    ("Status", [#status]),
    ("Current Test", [2026-01-08–2026-07-18 · see prendinger_brief.pdf / main.pdf]),
  ),
)

#target-trial-slides()
