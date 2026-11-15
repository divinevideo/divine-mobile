"""Runs the Node provenance tests from the Python CI configuration suite.

`ci-config-tests` only runs `python3 -m unittest discover`, so without this
wrapper the Node tests for the preview deploy helper never run in CI.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path


NODE_TEST_PATH = (
    Path(__file__).resolve().parent / "mobile_preview_provenance.test.cjs"
)


class MobilePreviewProvenanceNodeTest(unittest.TestCase):
    def test_node_provenance_suite_passes(self) -> None:
        node = shutil.which("node")
        if node is None:
            if os.environ.get("CI"):
                self.fail("node is required in CI to run the provenance tests")
            self.skipTest("node is not installed")

        result = subprocess.run(
            [node, "--test", str(NODE_TEST_PATH)],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(
            result.returncode,
            0,
            msg=f"node --test failed:\n{result.stdout}\n{result.stderr}",
        )


if __name__ == "__main__":
    unittest.main()
