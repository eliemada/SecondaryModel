"""Per-mode config generation for the TB-target pilot (tb_pilot_plan.md Phase 2).

Fixtures build a minimal fake TB label tree (empty CSVs, just enough for the existence
checks) rather than depending on a real generator run, so these stay fast and isolated.
"""

from __future__ import annotations

import copy

import pytest
import yaml
from pydantic import ValidationError

from tb_pilot.make_configs import (
    discover_available_modes,
    override_for_mode,
    validate_tb_root,
    write_mode_configs,
)

GRAN = "1d"
SYMBOLS = ("BTCUSDT", "ETHUSDT")


@pytest.fixture
def base_config() -> dict:
    from pathlib import Path

    here = Path(__file__).resolve().parents[1]
    return yaml.safe_load((here / "src" / "config.yaml").read_text())


@pytest.fixture
def tb_root(tmp_path):
    root = tmp_path / "Kronos" / "TB" / "horizon_7"
    for mode in ("tb_ref", "tb_k100"):
        mode_dir = root / f"{GRAN}_{mode}"
        mode_dir.mkdir(parents=True)
        for symbol in SYMBOLS:
            (mode_dir / f"{symbol}_up.csv").write_text("date,close\n")
            (mode_dir / f"{symbol}_down.csv").write_text("date,close\n")
    (root / "manifest.json").write_text("{}")
    return root


def test_override_for_mode_changes_only_data_mode_and_output_paths(base_config):
    out = override_for_mode(base_config, mode="tb_k100", tb_root="Data_MLA/Kronos/Crypto/TB/horizon_7")

    assert out["paths"]["csv_dir"] == "Data_MLA/Kronos/Crypto/TB/horizon_7"
    assert out["paths"]["output_root"] == "Output_tbpilot/tb_k100"
    assert out["data"]["load"]["meta_label_mode"] == "tb_k100"
    assert out["evaluation"].get("val_backtest", False) is False

    # Everything else is untouched.
    untouched = copy.deepcopy(out)
    untouched["paths"] = copy.deepcopy(base_config["paths"])
    untouched["data"]["load"]["meta_label_mode"] = base_config["data"]["load"]["meta_label_mode"]
    assert untouched == base_config
    assert out["data"]["split"] == base_config["data"]["split"]
    assert out["data"]["features"] == base_config["data"]["features"]
    assert out["runtime"] == base_config["runtime"]
    assert out["experiment"] == base_config["experiment"]


def test_original_tp_baseline_changes_only_its_output_root(base_config):
    out = override_for_mode(base_config, "tp", "unused", "Output_tbexperiment/run-1")
    assert out["paths"]["output_root"] == "Output_tbexperiment/run-1/tp"
    out["paths"]["output_root"] = base_config["paths"]["output_root"]
    assert out == base_config


def test_eval_settings_are_inherited_instead_of_enabling_an_extra_backtest(base_config):
    base_config["evaluation"]["val_backtest"] = True
    assert override_for_mode(base_config, "tb_ref", "TB")["evaluation"] == base_config["evaluation"]


def test_tp_and_tb_must_have_the_same_symbols(base_config, tb_root, tmp_path):
    tp_root = tmp_path / "Kronos" / "TP"
    tp_dir = tp_root / f"{GRAN}_tp"
    tp_dir.mkdir(parents=True)
    base_config["paths"]["csv_dir"] = str(tp_root)
    (tp_dir / "BTCUSDT_up.csv").write_text("date,close\n")
    with pytest.raises(SystemExit, match="symbol mismatch"):
        write_mode_configs(base_config, ["tp", "tb_ref"], str(tb_root), tmp_path / "configs")
    for symbol in SYMBOLS:
        for direction in ("up", "down"):
            (tp_dir / f"{symbol}_{direction}.csv").write_text("date,close\n")
    written = write_mode_configs(base_config, ["tp", "tb_ref"], str(tb_root), tmp_path / "configs")
    assert set(written) == {"tp", "tb_ref"}


def test_override_for_mode_does_not_mutate_the_base_dict(base_config):
    before = copy.deepcopy(base_config)
    override_for_mode(base_config, mode="tb_ref", tb_root="Data_MLA/Kronos/Crypto/TB/horizon_7")
    assert base_config == before


def test_override_for_mode_rejects_an_invalid_mode_name(base_config):
    with pytest.raises(ValidationError):
        override_for_mode(base_config, mode="not_a_real_mode", tb_root="Data_MLA/Kronos/Crypto/TB/horizon_7")


def test_discover_available_modes_lists_what_the_tree_actually_has(tb_root):
    assert discover_available_modes(tb_root, gran=GRAN) == {"tb_ref", "tb_k100"}


def test_validate_tb_root_passes_for_modes_present_in_the_tree(tb_root):
    validate_tb_root(tb_root, modes=["tb_ref", "tb_k100"], gran=GRAN)


def test_validate_tb_root_rejects_a_mode_the_tree_does_not_have(tb_root):
    with pytest.raises(SystemExit):
        validate_tb_root(tb_root, modes=["tb_ref", "tb_k999"], gran=GRAN)


def test_validate_tb_root_rejects_a_missing_root(tmp_path):
    with pytest.raises(SystemExit):
        validate_tb_root(tmp_path / "does_not_exist", modes=["tb_ref"], gran=GRAN)


def test_validate_tb_root_rejects_a_root_with_no_manifest(tmp_path):
    root = tmp_path / "TB" / "horizon_7"
    (root / f"{GRAN}_tb_ref").mkdir(parents=True)
    with pytest.raises(SystemExit):
        validate_tb_root(root, modes=["tb_ref"], gran=GRAN)


def test_validate_tb_root_rejects_a_symbol_mismatch_between_modes(tb_root):
    # Simulate a partial/crashed regenerate: tb_k100 is missing one symbol's files.
    (tb_root / f"{GRAN}_tb_k100" / "ETHUSDT_up.csv").unlink()
    (tb_root / f"{GRAN}_tb_k100" / "ETHUSDT_down.csv").unlink()
    with pytest.raises(SystemExit, match="symbol mismatch"):
        validate_tb_root(tb_root, modes=["tb_ref", "tb_k100"], gran=GRAN)


def test_write_mode_configs_writes_one_valid_yaml_per_mode(base_config, tb_root, tmp_path):
    out_dir = tmp_path / "configs"
    written = write_mode_configs(
        base_config,
        modes=["tb_ref", "tb_k100"],
        tb_root_str=str(tb_root),
        out_dir=out_dir,
        gran=GRAN,
    )

    assert set(written) == {"tb_ref", "tb_k100"}
    for mode, path in written.items():
        assert path.exists()
        loaded = yaml.safe_load(path.read_text())
        assert loaded["data"]["load"]["meta_label_mode"] == mode
        assert loaded["paths"]["output_root"] == f"Output_tbpilot/{mode}"
        # Round-trips through the schema cleanly too (not just a dict dump).
        from tb_pilot.schemas import SecondaryModelConfig
        from Utils.utils import _load_config

        SecondaryModelConfig.model_validate(loaded)
        assert _load_config(str(path)) == loaded


def test_configs_reject_a_label_root_the_original_multi_gran_loader_cannot_resolve(base_config, tmp_path):
    with pytest.raises(SystemExit, match="requires the TB root to end in horizon_"):
        write_mode_configs(base_config, ["tb_ref"], str(tmp_path / "labels"), tmp_path / "configs")


def test_configs_reject_paths_that_fail_the_pipeline_backbone_check(base_config, tb_root, tmp_path):
    import shutil

    anonymous_root = tmp_path / "labels" / "horizon_7"
    shutil.copytree(tb_root, anonymous_root)
    with pytest.raises(ValueError, match="Mismatch between 'm1' model and 'csv_dir'"):
        write_mode_configs(base_config, ["tb_ref"], str(anonymous_root), tmp_path / "configs")


def test_write_mode_configs_clears_stale_yaml_from_a_previous_invocation(base_config, tb_root, tmp_path):
    out_dir = tmp_path / "configs"
    write_mode_configs(base_config, modes=["tb_ref", "tb_k100"], tb_root_str=str(tb_root), out_dir=out_dir, gran=GRAN)
    assert {p.name for p in out_dir.glob("*.yaml")} == {"tb_ref.yaml", "tb_k100.yaml"}

    write_mode_configs(base_config, modes=["tb_ref"], tb_root_str=str(tb_root), out_dir=out_dir, gran=GRAN)
    assert {p.name for p in out_dir.glob("*.yaml")} == {"tb_ref.yaml"}
