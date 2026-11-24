"""Only API symbols and failure codes may leave the native diagnostic process."""
import unittest

from native_capture_harness import trace_failure_signatures


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


if __name__ == '__main__':
    unittest.main()
