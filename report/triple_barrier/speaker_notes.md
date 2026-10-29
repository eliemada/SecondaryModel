# Speaker notes — triple barriers and meta-labeling

Results updated 29 October 2026. The full deck now has 30 pages; pages 28–30 contain
the completed target matrix and the two delta comparisons. The methodology notes
below retain their original 22 October section numbering.

## Current result update

All 24 AutoGluon/Kumo fits completed on Pablo's configured dates. Realized Test:
2026-01-08–2026-07-18; M1 UP Sharpe −2.5744, DOWN +1.7423. All UP M2 Sharpes
remain negative, and every TB-k UP score is below that backend's fresh TP score.

AutoGluon DOWN k=0.5: Sharpe 1.8216, delta +1.4831 versus fresh TP, +0.3695
versus matched TB ref, +0.0793 versus M1. Return +61.5904%; drawdown −26.5509%,
worse than TB ref's −13.9467%. Kumo's four volatility-barrier targets trail its
TP in both directions. Kumo DOWN TB ref scores 2.0008 and retains TP labels.

TB ref controls for 77 early TON training proposals removed by the eligibility
rule (13 UP, 64 DOWN); realized Test trades remain identical. Two AutoGluon UP
cells, TB ref and k=1, failed the utility constraint and used the pipeline's 0.5
fallback threshold. New TP fits differ from Pablo's saved M2 scores; all deltas
use the newly fitted model's own controls.

We replayed all 144 M1/M2 metrics within 0.0001 from the saved trade CSVs. This is
an exploratory comparison with 27 horizon returns and one fit per cell, not a
significance test or an optimal-k selection. Trade execution remains fixed at
day 7. See README.md and the linked CSV for all scores and both delta definitions.

Reviewed source: the supplied López de Prado (2018), *Advances in Financial Machine Learning*, especially §§3.2–3.7, with §7.4 for validation and §10.3 for sizing. Page numbers refer to the printed book.

## The explanation in one minute

M1 proposes a trade: for example, buy at 100. Before observing the future, specify its exit policy and cost assumptions.

Later, actual prices reveal its outcome. With triple barriers, the trade closes at the first profit-taking level, stop-loss level or time limit. A stop at 97 and costs of 0.2% produce a net return of −3.2%, hence meta-label 0. A later recovery to 103 does not change the outcome of the trade that already closed.

M2 learns from many historical examples. Its inputs describe what was known when M1 proposed the trade; its target describes the later outcome. For a new proposal, M2 predicts the probability of success. A separate rule uses that prediction to accept, skip or size the trade.

**Triple barriers define a path-dependent outcome. Meta-labeling learns which proposals to take.** Our current dataset already uses meta-labeling, evaluated at day 7.

## 1 — Title

Introduce M1 as the primary forecasting model, Kronos in our project, and M2 as the model evaluating M1's proposals.

The questions are: where does ground truth come from, how do barriers define an outcome, and what does M2 add? The schematic paths and selection counts are illustrations. Empirical results are identified separately.

## 2 — What is the ground truth based on?

Say: “The model makes a prediction. The market later supplies prices. We apply our trade rule to those prices to calculate the answer.”

The upper row contains choices fixed at entry. The lower row contains observed prices and the calculated target.

- M1 proposes buying at 100.
- Profit target: 104; stop: 97; time limit: day 7.
- Observed prices begin 100 → 101 → 97.
- Under the assumed fill rule, the trade stops at 97.
- Gross return = 97/100 − 1 = −3%.
- Net return = −3% − 0.2% = −3.2%.
- Meta-label = 0.

Ground truth is a reproducible answer to a specified question. Prices are observed; the label is calculated from those prices and our conventions. Changing the exit or success criterion changes the target.

M1 supplies the proposed side. Its forecasted future prices do not supply the realized outcome. M2's predicted probability is not its own target. Hypothetical trades can be labeled without actual execution.

Source: AFML §§3.2–3.6, pp. 43–51.

## 3 — Two methods answer two different questions

Triple-barrier labeling combines an exit rule with an outcome-to-label mapping. First find the exit; then calculate the label.

Meta-labeling assumes a side has already been proposed by an external model or rule. M2 learns whether the proposal succeeds. The primary source can be ML, a technical rule or a discretionary signal.

A fixed-horizon profitability target is already a meta-label when conditioned on the proposed side. Adding barriers does not create M2.

Source: AFML §3.4; §§3.6–3.7.

## 4 — The day-7 price can hide an earlier loss

Follow the solid line until the stop. The dashed continuation is the market after the stopped trade has ended.

| Day | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| Price | 100 | 101 | 97 | 98 | 99 | 101 | 102 | 103 |

Holding until day 7 gives +2.8% net and label 1. Using the stop gives −3.2% net and label 0.

Both calculations are valid for their respective hypothetical trades. The fixed-horizon target answers a different question. If the intended strategy uses that stop, the barrier target describes its outcome more faithfully.

These examples assume exact barrier fills and fixed 0.2% total costs. They are not a full execution simulator.

Source: AFML §§3.2 and 3.4.

## 5 — Close at whichever barrier comes first

Record first profit-touch time, first stop-touch time and expiry. A barrier never reached has infinite touch time. Exit at the earliest of the three.

| First event | Exit day | Gross return | Net return |
|---|---:|---:|---:|
| Profit at 104 | 3 | +4% | +3.8% |
| Stop at 97 | 2 | −3% | −3.2% |
| Expiry at 101 | 7 | +1% | +0.8% |

These panels are separate long-trade scenarios. At this stage emphasize the exit event, not a universal +1/−1/0 mapping.

Source: AFML §3.4, pp. 45–47.

## 6 — Choose distances at entry

The book uses a volatility-based target width and multipliers for profit-taking and stop-loss. Its example volatility estimator uses an exponentially weighted standard deviation with span 100.

Our experiments choose width σ₀√7 and symmetric multipliers a = b = k. Square-root-of-time scaling assumes approximately uncorrelated returns with sufficiently stable variance; it is an approximation and is not required by the triple-barrier method.

The +4%/−3% examples are chosen for readable arithmetic. Barriers may be asymmetric and are fixed for that event; this is not a trailing-stop example.

Use side-adjusted gross return R(t) = s[P(t)/P₀ − 1]:

- Profit if R(t) reaches +a·v₀.
- Stop if R(t) reaches −b·v₀.
- Otherwise close at expiry.

For a short from 100, profit +4% corresponds to price 96; stop −3% corresponds to price 103. On a return-to-the-trade chart, profit remains the upper line even though a profitable short has falling prices.

Scaling normalizes barrier distances; it does not ensure identical actual risk or hit rates across assets.

Source: AFML §3.3, Snippets 3.1–3.2, and §3.6.

## 7 — Direction labels versus meta-labels

Take a path staying inside both policies' barriers and expiring at 99 after entry at 100.

A directional target describes the price move: DOWN, or −1 under the sign convention. Our current directional classes also call this DOWN because −1% is below −0.2%.

A meta-target describes the trade:

- Long: −1% − 0.2% = −1.2%, hence z = 0.
- Short: +1% − 0.2% = +0.8%, hence z = 1.

Zero means an unsuccessful proposal. It is not a short position or an instruction to reverse M1. SAME proposals are excluded from M2 in our dataset.

For directional labeling, AFML §3.4 permits expiry labels of zero or the return sign; the author prefers the sign. Snippet 3.5 implements the sign version. This optional convention must not be silently substituted for a profitability meta-target.

Source: AFML §§3.4–3.6, Snippets 3.5 and 3.7.

## 8 — The exact meta-label

g = s(Pτ/P₀ − 1) − c, and z = 1 if g > 0, otherwise 0.

s is +1 long or −1 short; c is assumed total cost as a fraction of entry notional. Here c = 0.002. This is a simple unlevered-return convention, not a general funding or margin model.

Snippet 3.7 multiplies realized return by the side and maps nonpositive returns to zero. The book's snippet does not deduct our 0.2% cost; that is our extension.

Expiry at 101 gives +0.8% net and label 1. Expiry at 99 gives −1.2% and label 0. Expiry at 100.1 gives −0.1% and label 0. Exactly zero net return is also label 0.

A profit touch can fail to cover costs if the gross target is too small. Computing net return is the general rule; automatically mapping a profit touch to 1 assumes it exceeds costs.

## 9 — Historical training

For every eligible historical proposal, save entry-time inputs, M1 outputs and side, exit-policy parameters, first exit time, modeled realized return and target z.

Train M2 on **entry-time inputs → eventual z**. Include successful and unsuccessful proposals. Using only proposals accepted by an earlier M2 can introduce selection bias.

Future prices, realized exit times, returns and targets are not live inputs. A label is available only when its event has ended. Exclude overlapping labels when fitting on training folds.

If M1 is fitted locally, generate its training proposals out of sample with time-respecting cross-fitting. Freezing a pretrained model keeps its parameters fixed but does not itself audit its pretraining data.

Source: AFML §§3.6–3.7 and §7.4.

## 10 — A live decision

M1 proposes a side. M2 estimates P(z = 1 | current inputs, side, chosen policy).

With the illustrative 0.60 cutoff:

- SHORT and p = 0.75 → accept the short.
- SHORT and p = 0.40 → skip.

The actual future path is absent from this decision. It will later allow evaluation.

Model probabilities may need calibration. Choose thresholds on validation using the trading objective. Neither 0.5 nor 0.6 is universal. Sizing is a separate mapping to an amount; M1 keeps the direction.

Source: AFML §3.6 and §10.3.

## 11 — What M2 adds

These counts are illustrative, not measured:

| M2 decision | Profitable | Unprofitable | Total |
|---|---:|---:|---:|
| Take | 32 | 8 | 40 |
| Skip | 23 | 37 | 60 |
| All proposals | 55 | 45 | 100 |

Taking all proposals wins 55% of the time. The selected subset wins 80%, at 40% coverage. It retains 32/55 ≈ 58% of the original winners.

Selection also misses 23 winners. This example does not guarantee improved F1, profit or Sharpe. Payoff sizes, turnover, costs and exposure matter.

Source: AFML §3.7, pp. 51–53.

## 12 — We already use meta-labeling

The current pipeline constructs:

- “pred_class”: UP/DOWN/SAME from M1's predicted day-7 return.
- “gt_class”: the same ±0.2% classification from the observed day-7 return.
- “meta_label”: 1 if these classes agree for an UP/DOWN proposal, otherwise 0.
- SAME proposals have no meta-label and are excluded.

For eligible sides this equals 1[s·ret_7 > 0.002].

Verified source locations:

- code/Synthetic-Generation/forecaster/predict_universe.py, labels around lines 179–187.
- code/Synthetic-Generation/forecaster/predict_synthetic.py, the corresponding synthetic labels.
- code/Synthetic-Generation/data/complete/README.md, dataset definitions.
- report/triple_barrier/analysis/label_counts.py, barrier meta-labels.

Triple barriers change the evaluation time from day 7 to the first exit. M1 and M2 keep their roles.

Distinguish the dataset's fixed-horizon target from the separate live engine's exit policy. For M2 to predict executed-trade profitability directly, label that execution policy. A barrier target used as an auxiliary target for day-7 trading is possible, but its benefit must be tested.

## 13 — The day-7 hurdle is a separate target

Current labels ask whether the proposed side beats costs at day 7. A volatility hurdle asks whether its day-7 gain exceeds a chosen magnitude. Triple barriers ask whether it beats costs at the first exit.

The saved vol_threshold.py uses s·ret_7 > kσ₀√7; it does not explicitly take the maximum with the fee. Adding that floor would define a modified experiment and require recomputing counts.

Small gains are not automatically noise. A larger hurdle changes the task; it does not automatically improve M2.

## 14 — Existing evidence

The presentation uses previously saved results, checked against CSV/JSON outputs. No model or full backtest was rerun for this edit.

On 254,952 daily proposals, k = 1 changes 15,084 labels (5.9164%). Positives decrease from 139,453 (54.6977%) to 134,295 (52.6746%).

The three-seed label-only experiment retains day-7 exits:

- Current target: test Sharpe −0.7258.
- k = 1 target: −0.7901.
- Difference −0.0643; nominal 95% interval [−0.5665, +0.3035].

The interval includes zero; this establishes neither improvement nor equivalence.

The separate single-seed benchmark.py has a different label-only result (+0.0346). Do not mix the two runs. Its full label-and-exit comparison is −0.2337 [−1.3231, +0.5492].

The cutoff selects 20% on validation; test coverage can differ. Multiple rules have been examined on this period. Treat the comparisons as exploratory and use fresh data or a predeclared walk-forward design to confirm newly selected rules.

## 15 — Synthetic data

For real examples, M1 sees the observed past and its proposal is evaluated on the observed future. For synthetic examples, M1 sees the generated past and its proposal is evaluated on the generated future.

Apply consistent feature availability, volatility estimation, exit policies and cost conventions. The generated future creates the target but must not become a predictor input.

A synthetic label is ground truth within the generated scenario. It does not establish what real markets would do. Test augmentation on held-out real data.

This is an application to the thesis, not a claim that AFML proves our generator is useful.

## 16 — The answer to remember

Say: “Observed future prices determine the trade outcome under our chosen rule. Triple barriers make the exit depend on the path. The meta-label records whether M1's proposed trade succeeded. M2 predicts that outcome before it happens.”

We already have M1 → M2. Adding barriers changes what success means. Its motivation is consistency with the intended trade; better prediction or profit still requires evidence.

## 17 — Reading guide

Snippet 3.7 directly answers the ground-truth question: realized return multiplied by proposed side, followed by the binary mapping. Our additional step is subtracting costs.

Use the printed page numbers on the slide to return to the supplied book.

## 18–21 — Saved experiments

Slide 18 is the appendix divider.

Slide 19 reproduces label_counts.csv, pooled across periods. Touches use daily highs/lows and barriers ±kσ₀√7.

Slide 20 reproduces test rows from label_benchmark.csv at validation coverage parameter 0.2. The cutoffs stay fixed on test, so actual test trade counts differ. Intervals use a paired 10-day block bootstrap with 2,000 repetitions.

Slide 21 uses benchmark_ci.json. Its M2 results use one seed, unlike slide 20. The full proposal changes both labels and exits.

These findings are specific to the data, model and execution assumptions. Small label changes do not prove triple barriers cannot help.

## 22 — Timing and execution

The book's Snippet 3.2 searches closes. Our tb.py also supports high/low touches. The latter assumes barrier fills; close-based detection uses the observed close, which can overshoot a barrier.

Daily high and low do not reveal which barrier was touched first when both were crossed. Our code counts a double touch as a stop: an assumption, not observed sequencing. Intrabar data can improve ordering; gaps and slippage need appropriate fill modeling.

A fixed 0.2% cost does not model all funding, borrowing and execution effects.

Purge overlapping label intervals from training and apply embargoes when the split design requires them. Our complete dataset excludes rows flagged “embargo”; the flag marks horizons crossing period boundaries. “embargo == False” means those flagged rows have been excluded, not that the split has no boundary protection.

## 23 — Probability and size

The training target is binary, not a ground-truth number of shares. M2's probability can inform a separate sizing rule.

Write position = s·q(p), with q(p) ≥ 0. Zero means skip. Fixed size for accepted trades is already a valid selection implementation; continuous sizing is optional.

With only two net payoffs, gain G or loss L, expected return is pG − (1−p)L. Break-even requires p > L/(G+L). Gains of 1 and losses of 2 require p > 2/3. Real payoffs vary, particularly at expiry, so probability alone is generally insufficient.

AFML §10.3 gives one probability-to-size transformation. The slide's expected-value equation is an elementary illustration, not that transformation or a universal optimum.

## Revision and rebuild

The earlier PDF, source and notes are retained in archive/before_clarity_review_2026-10-22.zip.

From the repository root, compile with:

    rtk proxy typst compile --root report report/triple_barrier/main.typ report/triple_barrier/main.pdf

To redraw only the two illustrative SVGs, using the existing environment with Matplotlib:

    rtk proxy code/Synthetic-Generation/.venv/bin/python report/triple_barrier/analysis/teaching_figures.py

Existing empirical outputs and charts are unchanged. The included teaching SVGs allow compilation without rerunning Python.

## Run history — GPU8 checks and the earlier target trial

Four opening evidence slides now separate dates, show the newly verified M1 baseline, explain the spread/cash valuation difference and present Pablo's saved M2 reference. The current config cutoffs are start 2024-07-01, train end 2025-08-31, validation end 2025-12-31 and data end 2026-08-01. All 280 TP input CSVs match GPU8 byte for byte. Pablo's actual saved 1d Test entries are 2026-01-08–2026-07-18. The historical AG/Kumo matrix retains its earlier 2025-10-09–2026-01-18 Test period; the new matrix uses the GPU8 Test dates.

The separate LightGBM benchmark's eligible entry ranges are train 2024-07-01–2025-08-24, validation 2025-09-01–2025-12-24 and Test 2026-01-01–2026-09-23. The training-label diagnostic charts use 2024-07-01–2025-08-24. Dates are read from saved evidence; configured cutoffs, entry dates and final liquidation dates are different quantities.

Replaying the eight downloaded GPU8 trade streams for both M1 and M2 reproduces all 48 spread-equity return/drawdown/Sharpe metrics within 0.0001; CSV returns have six decimal places. This verifies the backtest calculation on saved decisions, not classifier training. GPU8's observed source revision is 5b61d08 versus 9a272f5 for our earlier completed trial; its AutoGluon fit includes LightGBM learners absent from that earlier Izar fit. The new isolated checkout uses 5b61d08 and pins the observed major package versions, including LightGBM. Full training reproduction remains unverified. The cash-account report also differs from spread equity: M1 UP cash return −43.60% and drawdown −45.35%, versus spread return −54.2478% and Sharpe −2.5744, over the same GPU8 Test dates.

Rerun submitted on 2026-10-27 UTC: `gpu8-targets-20261027-153632`, preparation 3233005, training array 3233006, report 3233007. The 24 fits are AutoGluon/Kumo × TP, matched TB reference, k = 0.5/1/1.5/2 × UP/DOWN, daily with fixed 7-bar execution. The base YAML retains Pablo's model list; explicit CLI overrides select these two backends and 1d. Training and Test backtests run without separate HPO, edge or regime analysis jobs. Preparation checks all 280 input checksums, package versions, learner availability and the saved M1 Test baseline in every target arm before allowing fits. Python patch version and hardware differ, so identical M2 predictions are not promised. The inspected Test remains exploratory. The local one-off watcher `analysis/sync_gpu8_trial.py` downloads artifacts and logs for up to 12 hours while the computer and VPN remain available. It does not replace slide metrics automatically. The current matrix now contains all 24 completed scores; the earlier-date matrix is preserved in earlier_target_trial.pdf.

Checked on 2026-10-28: that preparation failed, so none of its 24 production fits ran. The custom checker omitted the production backtest's NaN-return filter. Fixed only the checker, with UP/DOWN regression comparisons against the untouched `run_feature_backtest`; 77 tests pass. The existing TP-UP cache contains 32 Test rows without realized returns. After the production filter, its 1,045 trades reproduce M1 return −54.247780%, maximum drawdown −57.991160% and Sharpe −2.574429, on 192 daily bars / 27 weekly returns, 2026-01-08–2026-07-18. Replacement run `gpu8-targets-20261028-104504`: preparation 3233490, training array 3233491, report 3233492. The blocked old dependencies were cancelled and the download watcher restarted for the replacement.

Cash-report qualification from the 2026-10-28 replay: the saved GPU8 cash figures match holding open positions at entry cost (`close=None`): UP M1 return −43.604521%, drawdown −45.352308%, Sharpe −2.794523. The current cash emitter supplies close prices and marks open positions to market: the identical saved trades give −43.660917%, −48.753022%, and −2.142022. No deployed cash code was changed. These saved and current cash reports are not the same valuation convention; neither is the spread-equity baseline. The small terminal-return difference also reflects the final-bar entries: the exit loop runs before those entries, so they remain open at the endpoint and their mark includes the fee. This does not establish a fully liquidated cash return. Evidence: `pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/cash_reference_diagnostics.json`.

Independent local daily input checks also passed for all six targets × both directions, using the original data preparation and equity functions with only 1d loaded. Every target has the same realized Test trade identities and M1 metrics within its direction. DOWN M1: return +30.440865%, maximum drawdown −17.036193%, Sharpe +1.742319, 2,580 realized trades. TP drops 32 UP and 90 DOWN Test rows lacking realized returns. The replacement cluster preparation subsequently passed for every target and direction before all 24 fits completed. Evidence: `pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/local_daily_baselines.json`. The loader's actual eligible training entries begin 2024-06-30 despite the configured 2024-07-01 start because of its context-window convention; training ends 2025-08-31. Val-Cal entries are 2025-09-08–2025-10-18 and Val-Opt 2025-10-26–2025-12-31. These original pipeline conventions are preserved.

The earlier three result slides are now preserved in the separate `earlier_target_trial.pdf`, built from `target_trial_slides.typ` and `pilot_results/original_test/slide_data.json`. They use the earlier Test window, 9 October 2025 to 18 January 2026: 20 source assets, AutoGluon and Kumo, six targets, UP/DOWN, fixed day-7 execution. The current decks end with the completed 24-fit matrix and two delta tables for Pablo's 2026-01-08–2026-07-18 Test window, with the verified negative UP baseline −2.5744. Do not read the historical positive-UP matrix as results of the current rerun.

For the historical trial only, M1 UP Sharpe is 0.5625 and return +1.8003%. Compare TB with the same backend's matched TB-reference result in that window and direction. The generator's 120-day history rule excludes 77 early TON training calls (13 UP, 64 DOWN). TB reference applies that same filter to the original labels, so it isolates label effects; differences from unfiltered TP also include the eligibility change. The generated `original_test/experiment_test.md` contains these historical numbers. The completed GPU8-date results are in `gpu8_target_trial/gpu8-targets-20261028-104504/experiment_test.csv`.

The backtest retains spread-equity smoothing, average-concentration normalization and horizon annualization. There are 14 weekly return observations. Differences are exploratory, not significance tests or confirmation of a k chosen on Test. AutoGluon's installed environment omits some optional learners; Kumo uses its existing large-model default.

All 24 fits and the final report completed successfully on 27 October 2026. Kumo with k = 1 raises Sharpe versus its matched reference from 1.291 to 2.182 UP and from 4.129 to 4.956 DOWN. Its DOWN Sharpe remains below original TP (5.353), and its DOWN total return falls versus the matched reference (104.21% to 77.77%). AutoGluon with k = 2 raises Sharpe versus its matched reference from 0.712 to 1.184 UP and from 5.507 to 6.353 DOWN, also with lower DOWN return (131.98% to 113.04%). k = 0.5 hurts DOWN sharply for both backends. Some backend/k combinations improve Sharpe on this window; this does not establish universal improvement or a confirmed optimal k.

The older training-tail validation chart is withdrawn: although disjoint from fitting, its threshold was optimized on later validation dates. Do not transplant its conclusions into this Test matrix or describe the inspected Test as sealed. Detailed French notes and run provenance are in `prendinger_notes.md`.
