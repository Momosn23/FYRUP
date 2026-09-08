"""Synthetic image fixtures test the comparison tool, NOT the iOS interface."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image

spec = importlib.util.spec_from_file_location("reference_compare", Path(__file__).with_name("compare-reference-screens.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ComparisonTests(unittest.TestCase):
    def test_preserves_aspect_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory(prefix="fyrup-compare-fixture-") as directory:
            root = Path(directory)
            Image.new("RGB", (187, 334), "white").save(root / "reference.png")
            Image.new("RGB", (1179, 2556), "white").save(root / "native.png")
            (root / "native.json").write_text(json.dumps({"widthPoints": 393, "heightPoints": 852,
                "source": "Production SwiftUI views - comparison TOOL fixture only"}), encoding="utf-8")
            args = [root / "reference.png", root / "native.png", root / "native.json", root / "result"]
            report = module.compare(*args)
            self.assertEqual(report["normalizedSizes"], [(393, 702), (393, 852)])
            self.assertEqual(report["visualAcceptance"], "NOT REVIEWED")
            with self.assertRaises(FileExistsError):
                module.compare(*args)

    def test_rejects_mockup_metadata(self):
        with tempfile.TemporaryDirectory(prefix="fyrup-compare-fixture-") as directory:
            root = Path(directory)
            (root / "mock.json").write_text('{"source":"mockup"}', encoding="utf-8")
            with self.assertRaises(ValueError):
                module.compare(root / "missing.png", root / "missing2.png", root / "mock.json", root / "result")


if __name__ == "__main__":
    unittest.main()
