"""Local tests of runtime selection, not native iOS tests."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("ios_qa", Path(__file__).with_name("run-ios-reference-qa.py"))
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


def runtime(version, available=True, platform="iOS"):
    return {"name": f"{platform} {version}", "version": version, "isAvailable": available, "identifier": f"fixture.{platform}.{version}"}


class SelectionTests(unittest.TestCase):
    def inventory(self, runtimes):
        return {"devicetypes": [{"name": "iPhone 16", "identifier": "fixture.iPhone16"}], "runtimes": runtimes}

    def test_xcode_minor_version_does_not_need_matching_ios_runtime(self):
        device, selected = qa.select_simulator(self.inventory([runtime("26.5")]))
        self.assertEqual(device["name"], "iPhone 16")
        self.assertEqual(selected["version"], "26.5")

    def test_latest_available_ios_version_not_lexicographic_or_watchos(self):
        _, selected = qa.select_simulator(self.inventory([runtime("26.9"), runtime("26.10"), runtime("27.0", False), runtime("30.0", platform="watchOS")]))
        self.assertEqual(selected["version"], "26.10")

    def test_same_size_fallback_and_missing_device_fail_closed(self):
        inventory = self.inventory([runtime("26.5")])
        inventory["devicetypes"] = [{"name": "iPhone 15", "identifier": "fixture.iPhone15"}]
        self.assertEqual(qa.select_simulator(inventory)[0]["name"], "iPhone 15")
        inventory["devicetypes"] = [{"name": "iPhone 16 Pro Max"}]
        with self.assertRaisesRegex(RuntimeError, "reference-size"):
            qa.select_simulator(inventory)

    def test_missing_or_too_old_runtime_is_explained(self):
        for values in [[], [runtime("26.5", False)], [runtime("16.4")]]:
            with self.assertRaisesRegex(RuntimeError, "No installed available iOS"):
                qa.select_simulator(self.inventory(values))


if __name__ == "__main__":
    unittest.main()
