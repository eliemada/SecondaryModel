"""Threshold selection must compare M1 and M2 on identical validation rows."""
from pathlib import Path

import numpy as np
import pytest
import torch

import m2_pipeline as pipeline
from Utils.selective_classification.calibration import _IdentityCalibrator


def fixture_data(drop_opt_returns=False, embargo_label=1, test_label=0):
    train, cal, gap, opt, test = [np.arange(i * 60, (i + 1) * 60) for i in range(5)]
    labels = np.r_[np.tile([0, 1], 30), np.r_[np.ones(10), np.zeros(50)],
                   np.full(60, embargo_label), np.r_[np.ones(30), np.zeros(30)],
                   np.full(60, test_label)].astype(float)
    returns = np.tile([.01, .02], 150)
    if drop_opt_returns:
        returns[opt[-10:]] = np.nan
    dataset = {
        "eng_features": np.full((300, 1), .6),
        "labels": torch.tensor(labels), "returns": torch.tensor(returns),
        "m1_pred_labels": torch.ones(300), "m1_true_labels": torch.tensor(labels),
    }
    return dataset, (train, cal, opt, test), (train, np.r_[cal, gap, opt], test)


@pytest.fixture
def evaluate(monkeypatch, tmp_path):
    class ConstantScores:
        def fit(self, x, y):
            assert len(y) == 60

        def predict_proba(self, x):
            return np.tile([.4, .6], (len(x), 1))

        def predict(self, x):
            return np.ones(len(x), dtype=int)

    selections, plots = [], []
    original_search = pipeline._find_best_utility_threshold

    def record_search(probs, returns, **kwargs):
        result = original_search(probs, returns, **kwargs)
        selections.append({"floor": kwargs["m1_precision"], "labels": kwargs["labels"].copy(),
                           "returns": returns.copy(), "result": result.copy()})
        return result

    monkeypatch.setattr(pipeline, "_build_tree_model", lambda *a, **k: ConstantScores())
    monkeypatch.setattr(pipeline, "resolve_feature_names", lambda n: ["score"])
    monkeypatch.setattr(pipeline, "MODELS_NO_SCALING", {"rf"})
    monkeypatch.setattr(pipeline, "calibrate_probabilities",
                        lambda *a, **k: {"calibrator": _IdentityCalibrator()})
    monkeypatch.setattr(pipeline, "_find_best_utility_threshold", record_search)
    monkeypatch.setattr(pipeline, "plot_confusion_matrix", lambda *a, **k: None)
    monkeypatch.setattr(pipeline, "plot_selective_return_distribution", lambda *a, **k: None)
    monkeypatch.setattr(pipeline, "plot_temporal_risk_coverage_curve_final",
                        lambda **kwargs: plots.append(kwargs))

    def run(mode, **data_kwargs):
        dataset, splits, raw = fixture_data(**data_kwargs)
        pipeline.temporal_eval(dataset, ["score"], Path(tmp_path), ["Reject", "Accept"], "tb_ref",
                               splits, direction="up", fee=.002, model_name="rf",
                               thres_mode=mode, split_indices_raw=raw)
        return selections[-1], [p for p in plots if p["split_name"] == "Val"][-1]

    return run


@pytest.mark.parametrize("mode", ["utility_nocal", "utility"])
@pytest.mark.parametrize("drop_opt_returns", [False, True])
def test_reference_uses_exact_optimizer_rows(evaluate, mode, drop_opt_returns):
    selected, plot = evaluate(mode, drop_opt_returns=drop_opt_returns)
    expected_n = (120 if mode == "utility_nocal" else 60) - (10 if drop_opt_returns else 0)
    assert len(selected["labels"]) == expected_n
    assert np.isfinite(selected["returns"]).all()
    assert selected["floor"] == pytest.approx(selected["labels"].mean())
    assert plot["m1_precision"] == pytest.approx(selected["floor"])
    # The model meets all constraints on its actual evaluation window.
    # Including the high-success embargo interval incorrectly causes fallback.
    assert selected["result"]["constraint_satisfied"]
    assert selected["result"]["selected_count"] == expected_n


@pytest.mark.parametrize("mode", ["utility_nocal", "utility"])
def test_embargo_and_test_outcomes_cannot_change_validation_selection(evaluate, mode):
    first, _ = evaluate(mode, embargo_label=1, test_label=0)
    second, _ = evaluate(mode, embargo_label=0, test_label=1)
    assert first["floor"] == second["floor"]
    assert first["result"] == second["result"]
