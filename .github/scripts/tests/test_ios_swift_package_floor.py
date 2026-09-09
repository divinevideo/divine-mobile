import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "scripts"
    / "ensure_ios_swift_package_floor.rb"
)


class IosSwiftPackageFloorTest(unittest.TestCase):
    def _run(self, declaration: str | None) -> tuple[subprocess.CompletedProcess[str], str]:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "Package.swift"
            platforms = (
                f"    platforms: [\n        {declaration}\n    ],\n"
                if declaration is not None
                else ""
            )
            manifest.write_text(
                "let package = Package(\n"
                '    name: "FlutterGeneratedPluginSwiftPackage",\n'
                f"{platforms}"
                ")\n"
            )
            result = subprocess.run(
                ["ruby", str(SCRIPT), str(manifest)],
                check=False,
                text=True,
                capture_output=True,
            )
            return result, manifest.read_text()

    def test_raises_legacy_and_current_flutter_floors(self) -> None:
        for declaration in (
            '.iOS("13.0")',
            ".iOS(.v13)",
            '.iOS("15.0")',
            ".iOS(.v15)",
        ):
            with self.subTest(declaration=declaration):
                result, contents = self._run(declaration)

                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn('.iOS("16.0")', contents)
                self.assertNotIn(declaration, contents)

    def test_keeps_supported_and_future_floors(self) -> None:
        for declaration in ('.iOS("16.0")', ".iOS(.v16)", '.iOS("17.0")'):
            with self.subTest(declaration=declaration):
                result, contents = self._run(declaration)

                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn(declaration, contents)

    def test_adds_the_floor_when_platforms_are_absent(self) -> None:
        result, contents = self._run(None)

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('.iOS("16.0")', contents)

    def test_rejects_a_platforms_block_without_ios(self) -> None:
        result, contents = self._run('.macOS("12.0")')

        self.assertNotEqual(0, result.returncode)
        self.assertIn("platforms block to declare an iOS target", result.stderr)
        self.assertNotIn('.iOS("16.0")', contents)


if __name__ == "__main__":
    unittest.main()
