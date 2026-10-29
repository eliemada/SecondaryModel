# Validation precision reference

The original pipeline compares threshold candidates on embargoed validation rows
with an M1 precision floor calculated on the unpurged date split. For the three
flagged UP fits, the optimizer uses 640 proposals while the reference uses 722.
The extra proposals raise the required precision enough to prevent a feasible
threshold. The comment that those windows match in `utility_nocal` was incorrect.

The correction in `temporal_eval()` computes the validation M1 reference after
return filtering, on exactly the rows passed to the threshold search:

- `utility_nocal`: Val-Cal plus filtered Val-Opt.
- `utility`: filtered Val-Opt only.

The validation plots receive the same reference. The original threshold grid,
minimum trade count, utility formula and fallback rule are retained. A fallback
can still be legitimate on other data; the correction does not force a threshold
to pass.

Saved validation probabilities reproduce all three original fallbacks. Aligning
the reference rows produces these feasible selections, without retraining or
using Test returns:

| UP fit | Original M1 floor | Matched M1 floor | Selected threshold | Validation utility |
|---|---:|---:|---:|---:|
| AutoGluon TB ref | 55.4017% | 51.7188% | 0.549748744 | 2.1441 |
| AutoGluon TB k=1 | 56.9252% | 53.5938% | 0.609913588 | 2.5280 |
| TabPFN TB k=0.5 | 54.7091% | 50.7813% | 0.509765625 | 4.8954 |

These are validation selections, not revised Test Sharpes. The published
Pablo-matched matrix continues to describe the original runs. A corrected Test
comparison must apply the rule to every cell, not only the three flagged cells.

Six focused regression checks execute `temporal_eval()` with deterministic model
scores. They cover both calibration modes, missing Val-Opt returns, matching the
plotted precision reference, and invariance to embargo/Test labels. Those six
checks and 38 existing comparison/baseline checks pass (44 total).

The deck's other qualifications are separate: its Test period contains 27
non-overlapping seven-day equity returns, and the grid has one fit per cell.
Correcting the precision window does not add observations or independent fits.

Evidence: [validation replay](threshold_fallback_audit.json). The reproducible audit script lives in the thesis repo
at `report/triple_barrier/analysis/audit_threshold_fallbacks.py`.
