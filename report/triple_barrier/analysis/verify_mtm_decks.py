"""Check the rendered PDFs against the audited MTM data, including deltas and markers."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

REPORT = Path(__file__).resolve().parents[1]
EVIDENCE = REPORT / "pilot_results/paper_mtm_20261029"
NUMBER = re.compile(r"[+-]?\d+\.\d+\*?")
MODELS = [("autogluon", "AutoGluon"), ("kumo", "Kumo"), ("tabpfn", "TabPFN"), ("rf", "RF")]


def main() -> None:
    data = json.loads((EVIDENCE / "slide_data.json").read_text())
    lookup = {(r["model"], r["direction"], r["mode"]): r for r in data["rows"]}
    reports = []
    for name, expected_pages in [("prendinger_brief", 15), ("main", 31)]:
        pdf = REPORT / f"{name}.pdf"
        text = subprocess.check_output(["pdftotext", "-layout", str(pdf), "-"], text=True).replace("−", "-")
        pages = [p for p in text.split("\f") if p.strip()]
        assert len(pages) == expected_pages, (name, len(pages))
        for stale in ["spread-equity", "27 weekly", "-2.5744", "1.7423", "Kumo TB ref, 2.001", "1.5687"]:
            assert stale not in text, (name, stale)
        for value in ["2024-06-30", "2025-08-31", "2025-09-08", "2025-12-31", "2026-01-08", "2026-07-18", "2026-07-25"]:
            assert value in pages[1], (name, value)

        checked, stars = 0, 0
        for page, field, modes in [
            (pages[-3], "m2_sharpe", data["modes"]),
            (pages[-2], "delta_sharpe_vs_tp", data["modes"][1:]),
            (pages[-1], "delta_sharpe_vs_tb_ref", data["modes"][2:]),
        ]:
            for model, label in MODELS:
                for direction in ["up", "down"]:
                    prefix = f"{label} · {direction.upper()}"
                    matches = [line.strip() for line in page.splitlines() if line.strip().startswith(prefix)]
                    assert len(matches) == 1, (name, prefix, matches)
                    values = NUMBER.findall(matches[0][len(prefix):])
                    assert len(values) == len(modes), (name, prefix, values)
                    for value, mode in zip(values, modes):
                        expected = lookup[model, direction, mode]
                        assert abs(float(value.rstrip("*")) - expected[field]) <= 0.000501, (name, prefix, field, mode)
                        if field == "m2_sharpe":
                            assert value.endswith("*") == (not expected["constraint_satisfied"]), (name, prefix, mode)
                            stars += value.endswith("*")
                        checked += 1
        assert stars == 3

        labels = [("m1", "M1 · all calls"), ("rf", "Random Forest"), ("autogluon", "AutoGluon"),
                  ("ctts", "CTTS"), ("tabpfn", "TabPFN"), ("tabicl", "TabICL")]
        for model, label in labels:
            matches = [line.strip() for line in pages[4].splitlines() if line.strip().startswith(label)]
            assert len(matches) == 1, (name, label, matches)
            values = NUMBER.findall(matches[0][len(label):])
            assert len(values) == 4, (name, label, values)
            targets = []
            for side in ["up", "down"]:
                r = next(x for x in data["paper_reference"] if x["model"] == ("autogluon" if model == "m1" else model) and x["direction"] == side)
                targets.extend([r["m1_total_return" if model == "m1" else "m2_total_return"],
                                r["m1_sharpe" if model == "m1" else "m2_sharpe"]])
            for actual, wanted in zip(values, targets):
                assert abs(float(actual) - wanted) <= 0.00501, (name, label, actual, wanted)
                checked += 1
        for side in ["up", "down"]:
            line = next(line.strip() for line in pages[2].splitlines() if line.strip().startswith(side.upper() + " "))
            values = re.findall(r"[+-]?\d+(?:\.\d+)?", line[len(side):])
            r = data["baseline"][side]
            targets = [r["return_pct"], r["sharpe"], r["max_drawdown_pct"], r["n_trades"]]
            assert len(values) == 4, (name, side, values)
            for actual, wanted, tolerance in zip(values, targets, [0.00501, 0.000051, 0.00501, 0]):
                assert abs(float(actual) - wanted) <= tolerance, (name, side, actual, wanted)
                checked += 1
        assert "28 weekly returns" in pages[-3]
        assert "1.161" in pages[-3] and "TabPFN k = 1" in pages[-3]
        assert "-18.15%" in pages[-1]
        if name == "main":
            for index in [17, 23, 24]:
                assert "Separate" in pages[index] and "equal-weight portfolio" in pages[index], (name, index + 1)

        bbox = ET.fromstring(subprocess.check_output(["pdftotext", "-bbox", str(pdf), "-"]))
        words = 0
        for page in bbox.iter():
            if page.tag.rsplit("}", 1)[-1] != "page":
                continue
            width, height = float(page.attrib["width"]), float(page.attrib["height"])
            for word in page.iter():
                if word.tag.rsplit("}", 1)[-1] != "word":
                    continue
                c = {k: float(word.attrib[k]) for k in ["xMin", "yMin", "xMax", "yMax"]}
                assert c["xMin"] >= -0.5 and c["yMin"] >= -0.5 and c["xMax"] <= width + 0.5 and c["yMax"] <= height + 0.5, (name, word.text, c)
                words += 1
        reports.append({"pdf": pdf.name, "sha256": hashlib.sha256(pdf.read_bytes()).hexdigest(),
                        "pages": len(pages), "numeric_table_cells_checked": checked,
                        "fallback_markers": stars, "words_within_page": words, "stale_current_metrics_absent": True})
    result = {"method": "Independent PDF text and coordinate extraction; compare every current table cell with audited MTM data.",
              "slide_data_sha256": hashlib.sha256((EVIDENCE / "slide_data.json").read_bytes()).hexdigest(), "decks": reports}
    (EVIDENCE / "deck_verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
