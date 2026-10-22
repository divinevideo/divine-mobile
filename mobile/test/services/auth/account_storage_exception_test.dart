// ABOUTME: Keeps expected account storage failures out of crash reporting.
// ABOUTME: Verifies the typed failure carries an actionable storage reason.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/auth/account_storage_exception.dart';

void main() {
  group(AccountStorageException, () {
    test('is operational and does not become a programming crash report', () {
      const error = AccountStorageException('Account readback did not match');
      expect(error, isA<Exception>());
      expect(asReportableError(error, context: 'account storage test'), isNull);
      expect(error.message, 'Account readback did not match');
      expect(error.toString(), contains(error.message));
    });
  });
}
