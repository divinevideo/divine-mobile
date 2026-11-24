"""Only API symbols and failure codes may leave the native diagnostic process."""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

from native_capture_harness import native_failure_status, require_capture_success, trace_failure_signatures


class TraceFailureSignaturesTest(unittest.TestCase):
    def test_retains_known_api_and_hresult_only(self):
        text = ('CMFCaptureEngineDetours::Initialize hr=0x80070005 '
                'attribute=private-log-value')
        self.assertEqual(trace_failure_signatures(text),
                         [('CMFCaptureEngineDetours::Initialize', '0x80070005')])

    def test_drops_unknown_symbols_and_attributes(self):
        text = 'PrivateClass::private_value status=0xC00D36B0 attribute=private-log-value'
        self.assertEqual(trace_failure_signatures(text),
                         [('unattributed', '0xc00d36b0')])

    def test_drops_unknown_methods_on_known_classes(self):
        text = 'CMFCaptureEngineDetours::private_value hr=0x80070005'
        self.assertEqual(trace_failure_signatures(text),
                         [('unattributed', '0x80070005')])

    def test_ignores_success_codes_and_addresses(self):
        text = ('CMFCaptureEngineDetours::Initialize hr=0x00000000 '
                'address=0x80070005 address=0x8007000500000000')
        self.assertEqual(trace_failure_signatures(text), [])

    def test_collapses_repeated_failures(self):
        text = 'CMFMediaEventDetours::GetStatus status=0x80070005\n' * 3
        self.assertEqual(trace_failure_signatures(text),
                         [('CMFMediaEventDetours::GetStatus', '0x80070005')])


class NativeFailureStatusTest(unittest.TestCase):
    def test_keeps_only_known_mirror_operation_and_hresult(self):
        for stage in ['source', 'record_index', 'preview_index', 'factory', 'class', 'control', 'mode', 'add']:
            with self.subTest(stage=stage):
                self.assertEqual(native_failure_status('capture-status mirror_' + stage + ':0xc00d36e6 metadata=unused'),
                                 ('mirror_' + stage, '0xc00d36e6'))

    def test_discards_unknown_operation_success_and_oversized_hex(self):
        for line in ['capture-status unrecognized:0x80070005',
                     'capture-status mirror_source:0x00000000',
                     'capture-status mirror_source:0x8007000500000000']:
            with self.subTest(line=line):
                self.assertIsNone(native_failure_status(line))


class TraceRoutingTest(unittest.TestCase):
    def failure(self, stream='stderr', stage='initialization'):
        return subprocess.run([
            sys.executable, '-c',
            "import sys; sys." + stream + ".write('DIVINE_CAPTURE_FAIL " + stage +
            " initialization_failed\\n'); sys.exit(1)",
        ], capture_output=True, text=True, check=False)

    def test_real_stderr_failure_reaches_diagnostic_and_remains_failed(self):
        result = self.failure()
        output = io.StringIO()
        with patch('native_capture_harness.capture_trace_tool', return_value=None):
            with contextlib.redirect_stdout(output):
                with self.assertRaisesRegex(RuntimeError, 'Native capture failed; exit=1'):
                    require_capture_success(result, 'windows', 'audio', [], Path('.'), {})
        self.assertEqual(output.getvalue(), 'DIVINE_CAPTURE_TRACE_TOOL unavailable\n')
        self.assertEqual(result.returncode, 1)

    def test_trace_without_owned_launcher_stays_failed_without_execution(self):
        result = self.failure()
        output = io.StringIO()
        with patch('native_capture_harness.capture_trace_tool', return_value=Path('mftrace.exe')):
            with contextlib.redirect_stdout(output):
                with self.assertRaisesRegex(RuntimeError, 'Native capture failed; exit=1'):
                    require_capture_success(result, 'windows', 'audio', [], Path('.'), {})
        self.assertEqual(output.getvalue(), 'DIVINE_CAPTURE_TRACE_TOOL present\n'
                         'DIVINE_CAPTURE_TRACE_STAGE launcher_unavailable\n')

    def test_stdout_control_also_reaches_diagnostic(self):
        result = self.failure('stdout')
        output = io.StringIO()
        with patch('native_capture_harness.capture_trace_tool', return_value=None):
            with contextlib.redirect_stdout(output):
                with self.assertRaises(RuntimeError):
                    require_capture_success(result, 'windows', 'audio', [], Path('.'), {})
        self.assertEqual(output.getvalue(), 'DIVINE_CAPTURE_TRACE_TOOL unavailable\n')

    def test_other_failures_stay_failed_without_launching_trace(self):
        for platform, case, stage in [('linux', 'audio', 'initialization'),
                                      ('windows', 'video', 'initialization'),
                                      ('windows', 'audio', 'recording')]:
            result = self.failure(stage=stage)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                with self.assertRaises(RuntimeError):
                    require_capture_success(result, platform, case, [], Path('.'), {})
            self.assertEqual(output.getvalue(), '')

    def test_success_needs_no_diagnostic(self):
        result = subprocess.CompletedProcess([], 0, 'DIVINE_CAPTURE_PASS', '')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            require_capture_success(result, 'windows', 'audio', [], Path('.'), {})
        self.assertEqual(output.getvalue(), '')


if __name__ == '__main__':
    unittest.main()
