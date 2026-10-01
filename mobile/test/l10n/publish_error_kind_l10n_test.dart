// ABOUTME: Tests the PublishErrorKind -> localized-string mapping.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/publish_error_kind_l10n.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('PublishErrorKindL10n', () {
    test('maps every kind to a non-empty message', () {
      for (final kind in PublishErrorKind.values) {
        final message = l10n.publishErrorMessage(kind);
        expect(message, isNotEmpty, reason: 'no message for $kind');
      }
    });

    test('maps every kind to a distinct message', () {
      final messages = PublishErrorKind.values
          .map((kind) => l10n.publishErrorMessage(kind, serverName: 'srv'))
          .toList();
      expect(
        messages.toSet(),
        hasLength(messages.length),
        reason: 'two kinds resolve to the same copy',
      );
    });

    test('interpolates the server name for server kinds', () {
      const serverKinds = [
        PublishErrorKind.serverNotFound,
        PublishErrorKind.serverInternalError,
        PublishErrorKind.serverDown,
      ];
      for (final kind in serverKinds) {
        final message = l10n.publishErrorMessage(
          kind,
          serverName: 'media.divine.video',
        );
        expect(
          message,
          contains('media.divine.video'),
          reason: '$kind did not interpolate the server name',
        );
      }
    });

    test('falls back to the localized unknown-server label', () {
      final message = l10n.publishErrorMessage(
        PublishErrorKind.serverNotFound,
      );
      expect(message, contains(l10n.publishErrorUnknownServer));
    });

    test('is localized per locale (en differs from de for the same kind)', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final de = lookupAppLocalizations(const Locale('de'));
      expect(
        en.publishErrorMessage(PublishErrorKind.generic),
        isNot(equals(de.publishErrorMessage(PublishErrorKind.generic))),
      );
    });
  });
}
