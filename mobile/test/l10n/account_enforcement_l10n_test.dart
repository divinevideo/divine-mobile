// ABOUTME: Tests the AccountEnforcementKind -> localized-copy mapping, and that
// ABOUTME: no enforcement state can borrow the good-standing copy.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/account_enforcement_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('AccountEnforcementL10n', () {
    test('maps every kind to a non-empty heading', () {
      for (final kind in AccountEnforcementKind.values) {
        expect(
          l10n.accountEnforcementHeading(kind),
          isNotEmpty,
          reason: 'no heading for $kind',
        );
      }
    });

    test('never maps a kind to an empty body', () {
      for (final kind in AccountEnforcementKind.values) {
        final body = l10n.accountEnforcementBody(kind);
        if (body == null) continue;
        expect(body, isNotEmpty, reason: 'empty body for $kind');
      }
    });

    test('maps every kind to a distinct heading', () {
      final headings = AccountEnforcementKind.values
          .map(l10n.accountEnforcementHeading)
          .toList();

      expect(headings.toSet(), hasLength(headings.length));
    });

    test(
      'noRestrictionReported resolves to the all-clear, with no body to explain it',
      () {
        expect(
          l10n.accountEnforcementHeading(
            AccountEnforcementKind.noRestrictionReported,
          ),
          l10n.accountStatusAllClearHeading,
        );
        expect(
          l10n.accountEnforcementBody(
            AccountEnforcementKind.noRestrictionReported,
          ),
          isNull,
          reason: 'a second line here could only describe how Divine checks',
        );
      },
    );

    test('every other kind keeps a body', () {
      for (final kind in AccountEnforcementKind.values) {
        if (kind == AccountEnforcementKind.noRestrictionReported) continue;
        expect(l10n.accountEnforcementBody(kind), isNotNull, reason: '$kind');
      }
    });
  });
}
