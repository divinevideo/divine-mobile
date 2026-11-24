"""Only API symbols and failure codes may leave the native diagnostic process."""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

from native_capture_harness import native_failure_status, require_capture_success, trace_capture_failure, trace_failure_signatures


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
        for stage in ['source', 'record_index', 'preview_index', 'factory', 'class', 'category', 'flags', 'control', 'mode', 'add']:
            with self.subTest(stage=stage):
                self.assertEqual(native_failure_status('capture-status mirror_' + stage + ':0xc00d36e6 metadata=unused'),
                                 ('mirror_' + stage, '0xc00d36e6'))

    def test_discards_unknown_operation_success_and_oversized_hex(self):
        for line in ['capture-status unrecognized:0x80070005',
                     'capture-status mirror_source:0x00000000',
                     'capture-status mirror_source:0x8007000500000000']:
            with self.subTest(line=line):
                self.assertIsNone(native_failure_status(line))


class TraceAttributePrivacyTest(unittest.TestCase):
    def diagnostics(self, trace):
        output = io.StringIO()
        completed = subprocess.CompletedProcess([], 0, trace.encode(), b'')
        with patch('native_capture_harness.capture_trace_tool', return_value=Path('mftrace.exe')):
            with patch('native_capture_harness.Path.is_file', return_value=True):
                with patch('native_capture_harness.subprocess.run', return_value=completed):
                    with contextlib.redirect_stdout(output):
                        trace_capture_failure([], Path('.'), {'DIVINE_CAPTURE_TRACE_LAUNCHER': 'owned-launcher'})
        return output.getvalue()

    def test_missing_key_without_hresult_keeps_only_known_sdk_attribute(self):
        output = self.diagnostics('CMFAttributesDetours::GetGUID @private-address '
                                  'attribute not found guidKey = MF_MT_SUBTYPE private-value')
        self.assertIn('DIVINE_CAPTURE_TRACE_ATTRIBUTE 1 CMFAttributesDetours::GetGUID MF_MT_SUBTYPE 0xc00d36e6', output)
        self.assertNotIn('private-', output)

    def test_unknown_keys_are_counted_without_disclosing_names_or_guids(self):
        output = self.diagnostics('CMFAttributesDetours::GetGUID attribute not found guidKey = private_value\n'
                                  'CMFAttributesDetours::GetUINT32 attribute not found guidKey = {00000000-0000-0000-0000-000000000001}')
        self.assertIn('DIVINE_CAPTURE_TRACE_UNKNOWN_ATTRIBUTE_COUNT 2', output)
        self.assertNotIn('private_value', output)
        self.assertNotIn('00000000', output)

    def test_keeps_occurrence_order_without_exporting_unrelated_fields(self):
        output = self.diagnostics('CMFAttributesDetours::GetUINT32 attribute not found guidKey = MF_MT_INTERLACE_MODE\n'
                                  'CMFAttributesDetours::GetGUID attribute not found guidKey = MF_MT_SUBTYPE')
        self.assertLess(output.index('1 CMFAttributesDetours::GetUINT32'), output.index('2 CMFAttributesDetours::GetGUID'))

    def test_success_or_unknown_method_does_not_become_a_missing_attribute(self):
        output = self.diagnostics('CMFAttributesDetours::GetGUID guidKey = MF_MT_SUBTYPE hr=0x00000000\n'
                                  'CMFAttributesDetours::private_method attribute not found guidKey = MF_MT_SUBTYPE')
        self.assertIn('DIVINE_CAPTURE_TRACE_ATTRIBUTE_COUNT 0', output)
        self.assertIn('DIVINE_CAPTURE_TRACE_UNKNOWN_ATTRIBUTE_COUNT 0', output)

    def test_known_name_in_a_value_cannot_be_mistaken_for_the_missing_key(self):
        output = self.diagnostics('CMFAttributesDetours::GetGUID attribute not found guidKey = private_key value=MF_MT_SUBTYPE')
        self.assertIn('DIVINE_CAPTURE_TRACE_ATTRIBUTE_COUNT 0', output)
        self.assertNotIn('MF_MT_SUBTYPE', output)

    def test_known_sdk_guid_is_rendered_as_its_public_name_only(self):
        output = self.diagnostics('CMFAttributesDetours::GetGUID attribute not found '
                                  'guidKey = {F7E34C9A-42E8-4714-B74B-CB29D72C35E5}')
        self.assertIn('CMFAttributesDetours::GetGUID MF_MT_SUBTYPE 0xc00d36e6', output)
        self.assertNotIn('F7E34C9A', output)

    def test_topology_missing_key_is_not_lost_at_the_effect_boundary(self):
        output = self.diagnostics('CMFTopologyNodeDetours::GetGUID attribute not found '
                                  'guidKey = MF_TOPONODE_TRANSFORM_OBJECTID')
        self.assertIn('CMFTopologyNodeDetours::GetGUID MF_TOPONODE_TRANSFORM_OBJECTID 0xc00d36e6', output)


class EffectFlagsControlTest(unittest.TestCase):
    def test_initialization_comparison_traces_both_cases_and_retains_failure(self):
        result = subprocess.CompletedProcess([], 1, '',
            'capture-stage effect_flags_applied\nDIVINE_CAPTURE_FAIL initialization initialization_failed')
        environment = {'DIVINE_CAPTURE_TEST_EFFECT_FLAGS': '1'}
        cases = []
        with patch('native_capture_harness.trace_capture_failure',
                   side_effect=lambda command, app, env: cases.append(
                       (env['DIVINE_CAPTURE_CASE'], env.get('DIVINE_CAPTURE_TEST_EFFECT_FLAGS')))):
            with contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, 'Native capture failed; exit=1'):
                    require_capture_success(result, 'windows', 'mirrored-video', [], Path('.'), environment)
        self.assertEqual(cases, [('video', None), ('mirrored-video', '1')])
        self.assertEqual(environment, {'DIVINE_CAPTURE_TEST_EFFECT_FLAGS': '1'})
        self.assertEqual(result.returncode, 1)

    def test_requested_variant_requires_actual_native_application(self):
        result = subprocess.CompletedProcess([], 0, 'DIVINE_CAPTURE_PASS', '')
        with self.assertRaisesRegex(RuntimeError, 'Effect flags variant was not applied'):
            require_capture_success(result, 'windows', 'mirrored-video', [], Path('.'),
                                    {'DIVINE_CAPTURE_TEST_EFFECT_FLAGS': '1'})

    def test_positive_control_does_not_hide_a_failed_capture(self):
        result = subprocess.CompletedProcess([], 1, '', 'capture-stage effect_flags_applied')
        with self.assertRaisesRegex(RuntimeError, 'Native capture failed'):
            require_capture_success(result, 'windows', 'mirrored-video', [], Path('.'),
                                    {'DIVINE_CAPTURE_TEST_EFFECT_FLAGS': '1'})

    def test_positive_control_and_successful_capture_are_both_accepted(self):
        result = subprocess.CompletedProcess([], 0, 'DIVINE_CAPTURE_PASS',
                                             'capture-stage effect_flags_applied')
        require_capture_success(result, 'windows', 'mirrored-video', [], Path('.'),
                                {'DIVINE_CAPTURE_TEST_EFFECT_FLAGS': '1'})


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
