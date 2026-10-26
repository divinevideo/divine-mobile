"""Command-boundary regressions for the prebuilt native acceptance path."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class PrebuiltProfileTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='consent-profile-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        scripts = self.root / 'local_stack'
        scripts.mkdir()
        source = Path(__file__).resolve().parents[1]
        for name in ['profile.sh', 'android_sdk.sh', 'merge_logs.py']:
            shutil.copy(source / name, scripts / name)
        mobile = self.root / 'mobile'
        mobile.mkdir()
        (mobile / 'target.dart').write_text('void main() {}\n')
        binary = self.root / 'bin'
        binary.mkdir()
        self.commands = self.root / 'commands.log'
        for name, body in {
            'emulator': 'exit 0',
            'patrol': "echo 'patrol_cli v4.7.0'",
            'adb': 'printf "adb %s\\n" "$*" >> "$PROFILE_COMMAND_LOG"\nexit 0',
            'flutter': 'printf "flutter %s\\n" "$*" >> "$PROFILE_COMMAND_LOG"\nexit "${PROFILE_DRIVE_EXIT:-0}"',
        }.items():
            path = binary / name
            path.write_text('#!/bin/sh\n' + body + '\n')
            path.chmod(0o755)
        self.apk = self.root / 'integration.apk'
        self.apk.write_bytes(b'synthetic APK command fixture')
        self.backend_log = self.root / 'backend.log'
        self.backend_log.write_text('synthetic local backend ready\n')
        self.env = {
            **os.environ, 'PATH': f'{binary}{os.pathsep}{os.environ["PATH"]}',
            'PUB_CACHE': str(self.root / 'pub-cache'),
            'ANDROID_SERIAL': 'emulator-test',
            'PROFILE_COMMAND_LOG': str(self.commands),
            'E2E_BACKEND_LOG': str(self.backend_log),
            'E2E_PREBUILT_APK': str(self.apk),
            'E2E_TEST_PERMISSIONS': 'android.permission.CAMERA android.permission.RECORD_AUDIO',
        }

    def run_profile(self):
        return subprocess.run(
            ['bash', 'local_stack/profile.sh', 'target.dart'], cwd=self.root,
            env=self.env, text=True, capture_output=True, timeout=15,
        )

    def test_prebuilt_path_runs_driver_without_building(self):
        result = self.run_profile()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands.read_text()
        self.assertIn(f'adb -s emulator-test install -r -t {self.apk}', commands)
        self.assertIn('flutter drive --driver=test_driver/integration_test.dart', commands)
        self.assertIn(f'--use-application-binary={self.apk}', commands)
        self.assertIn('android.permission.CAMERA', commands)
        self.assertIn('android.permission.RECORD_AUDIO', commands)
        self.assertNotIn('flutter build', commands)
        self.assertNotIn('flutter test', commands)
        self.assertEqual(len(list((self.root / 'mobile/test_reports').glob('*.jsonl'))), 1)

    def test_driver_failure_is_reported(self):
        self.env['PROFILE_DRIVE_EXIT'] = '37'
        result = self.run_profile()
        self.assertEqual(result.returncode, 37)
        self.assertIn('Tests FAILED', result.stderr)

    def test_missing_apk_does_not_launch_driver(self):
        self.apk.unlink()
        result = self.run_profile()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('prebuilt integration APK not found', result.stdout)
        self.assertNotIn('flutter drive', self.commands.read_text())

    def test_missing_backend_log_stops_before_device_commands(self):
        self.backend_log.unlink()
        result = self.run_profile()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('E2E_BACKEND_LOG must name', result.stderr)
        self.assertFalse(self.commands.exists())


if __name__ == '__main__':
    unittest.main()
