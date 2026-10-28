"""The submission gate must agree with the untouched production backtest."""
import importlib.util
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
import torch
from sklearn.preprocessing import StandardScaler

from Utils.backtest import engine
from Utils.edge import _compute_embargo_splits
from Utils.utils import GRAN_TO_ID

spec = importlib.util.spec_from_file_location("gpu8_trial", Path(__file__).parents[1] / "slurm/gpu8_trial.py")
trial = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trial)


@pytest.mark.parametrize("direction", ["up", "down"])
def test_gate_matches_production_when_test_returns_are_missing(tmp_path, monkeypatch, direction):
    dates = pd.date_range("2025-01-01", periods=180)
    cfg = {"data": {"load": {"forecast_horizon": 7, "m1": "kronos"},
                    "split": {"train_end": "2025-01-31", "val_end": "2025-03-01"}},
           "evaluation": {"fee_per_trade": 0.002}}
    splits = _compute_embargo_splits(dates, "2025-01-31", "2025-03-01", 7, "1d")
    test = splits["idx_test"]
    returns = np.random.default_rng(42).normal(0.001, 0.025, len(dates))
    missing = test[[0, len(test) // 2, -3, -2, -1]]
    returns[missing] = np.nan
    dataset = {"dates": list(dates), "returns": torch.tensor(returns),
               "labels": torch.tensor((np.nan_to_num(returns) > 0).astype(float)),
               "asset_ids": torch.zeros(len(dates), dtype=torch.long), "asset_map": {0: "BTCUSDT"},
               "gran_ids": torch.full((len(dates),), GRAN_TO_ID["1d"]),
               "eng_features": torch.zeros((len(dates), 1)),
               "m1_pred_labels": None, "m1_pred_returns": None, "m1_true_labels": None}
    close = pd.DataFrame({"date": dates, "asset": "BTCUSDT", "close": np.linspace(100, 105, len(dates))})
    monkeypatch.setattr(engine, "_load_raw_close_prices", lambda *args, **kwargs: close)
    monkeypatch.setattr("matplotlib.figure.Figure.savefig", lambda *args, **kwargs: None)

    class ApproveAll:
        def predict_proba(self, x):
            return np.tile([0.2, 0.8], (len(x), 1))

    production = engine.run_feature_backtest(
        dataset, (splits["idx_train"], splits["idx_cal"], splits["idx_opt"], test),
        {"model": ApproveAll(), "scaler": StandardScaler().fit(np.zeros((1, 1))), "col_indices": [0],
         "val_op": {"threshold": 0.5, "constraint_satisfied": True}},
        cfg, tmp_path, ["Reject", "Approve"], "tp", "1d", direction,
        model_name="autogluon", fee=0.002)
    checked = trial.baseline(dataset, cfg, direction, production)
    trades = pd.read_csv(tmp_path / "10_backtest_all_trades.csv", parse_dates=["date"])
    assert checked["dropped_nan_test_returns"] == len(missing)
    assert checked["stats"]["n_total_trades"] == len(test) - len(missing)
    assert pd.Timestamp(checked["first_test_entry"]) == trades.date.min()
    assert pd.Timestamp(checked["last_test_entry"]) == trades.date.max()
    assert all(np.isfinite(v) for v in checked["stats"].values())
    # The gate must still reject a genuine change to finite trade returns.
    dataset["returns"][test[1]] += 0.1
    with pytest.raises(ValueError, match="M1 baseline mismatch"):
        trial.baseline(dataset, cfg, direction, production)
