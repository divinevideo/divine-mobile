import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train.versions import (  # noqa: E402
    Version,
    bump_patch,
    parse_version,
    pubspec_version,
)


class ReleaseTrainVersionsTest(unittest.TestCase):
    def test_parse_pads_missing_components(self) -> None:
        self.assertEqual(parse_version("1.1"), Version(1, 1, 0))

    def test_parse_rejects_non_numeric(self) -> None:
        with self.assertRaises(ValueError):
            parse_version("1.0.x")

    def test_parse_rejects_non_ascii_digits(self) -> None:
        for text in ("١.0.28", "1.０.28", "1.0.٢٨"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_version(text)

    def test_versions_order_numerically(self) -> None:
        self.assertGreater(parse_version("1.0.10"), parse_version("1.0.9"))

    def test_bump_patch(self) -> None:
        self.assertEqual(bump_patch(Version(1, 0, 28)), Version(1, 0, 29))

    def test_str_joins_components(self) -> None:
        self.assertEqual(str(Version(1, 0, 28)), "1.0.28")

    def test_pubspec_version_reads_marketing_version(self) -> None:
        self.assertEqual(
            pubspec_version("name: openvine\nversion: 1.0.28+820\n"),
            Version(1, 0, 28),
        )

    def test_pubspec_version_requires_build_suffix(self) -> None:
        for text in ("version: 1.0.28\n", "version: 1.0+820\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                pubspec_version(text)

    def test_pubspec_version_rejects_non_ascii_version_or_build(self) -> None:
        for text in ("version: ١.0.28+820\n", "version: 1.0.28+٨٢٠\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                pubspec_version(text)


if __name__ == "__main__":
    unittest.main()
