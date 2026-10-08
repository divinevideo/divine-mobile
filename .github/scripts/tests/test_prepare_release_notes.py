"""Use a real repository to prove the inventory respects the candidate range."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[3] / 'mobile/scripts/prepare_release_notes.py'


class InventoryTest(unittest.TestCase):
    def test_range_grouping_and_draft_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args], text=True, env=env).strip()
            git('init', '-q')
            git('config', 'user.name', 'Test')
            git('config', 'user.email', 'test@example.invalid')
            git('commit', '--allow-empty', '-qm', 'feat: old feature')
            base = git('rev-parse', 'HEAD')
            git('commit', '--allow-empty', '-qm', 'feat(camera): new tool')
            git('commit', '--allow-empty', '-qm', 'fix: playback')
            head = git('rev-parse', 'HEAD')
            git('commit', '--allow-empty', '-qm', 'feat: not in release')
            output = Path(directory) / 'notes.md'
            result = subprocess.run(['python3', str(SCRIPT), '--base', base, '--head', head,
                                     '--output', str(output)], cwd=directory, capture_output=True, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            notes = output.read_text()
            self.assertTrue(notes.startswith('<!-- DRAFT -->'))
            self.assertIn('## New things to try\n\n- feat(camera): new tool', notes)
            self.assertIn('## Fixes and improvements\n\n- fix: playback', notes)
            self.assertNotIn('old feature', notes)
            self.assertNotIn('not in release', notes)
            rerun = subprocess.run(['python3', str(SCRIPT), '--base', base, '--head', head,
                                    '--output', str(output)], cwd=directory, capture_output=True, env=env)
            self.assertNotEqual(rerun.returncode, 0)
            self.assertEqual(output.read_text(), notes)


if __name__ == '__main__':
    unittest.main()
