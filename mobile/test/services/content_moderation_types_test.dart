// ABOUTME: Tests for the content-moderation value types (report reasons,
// ABOUTME: severity, mute entries, moderation result).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/content_moderation.dart';

void main() {
  group(MuteListEntry, () {
    final entry = MuteListEntry(
      type: 'pubkey',
      value: 'abc123',
      reason: ContentFilterReason.harassment,
      severity: ContentSeverity.hide,
      createdAt: DateTime.utc(2026, 6, 13, 12),
      note: 'repeated abuse',
    );

    test('toJson serializes enums by name and date as ISO-8601', () {
      expect(entry.toJson(), {
        'type': 'pubkey',
        'value': 'abc123',
        'reason': 'harassment',
        'severity': 'hide',
        'createdAt': '2026-06-13T12:00:00.000Z',
        'note': 'repeated abuse',
      });
    });

    test('fromJson round-trips a serialized entry', () {
      final restored = MuteListEntry.fromJson(entry.toJson());
      expect(restored.type, entry.type);
      expect(restored.value, entry.value);
      expect(restored.reason, entry.reason);
      expect(restored.severity, entry.severity);
      expect(restored.createdAt, entry.createdAt);
      expect(restored.note, entry.note);
    });

    test('fromJson falls back to safe defaults for unknown enum names', () {
      final restored = MuteListEntry.fromJson({
        'type': 'pubkey',
        'value': 'abc123',
        'reason': 'not_a_real_reason',
        'severity': 'not_a_real_severity',
        'createdAt': '2026-06-13T12:00:00.000Z',
        'note': null,
      });
      expect(restored.reason, ContentFilterReason.other);
      expect(restored.severity, ContentSeverity.hide);
      expect(restored.note, isNull);
    });

    test('toNIP51Tag omits the note when absent', () {
      final noNote = MuteListEntry(
        type: 'keyword',
        value: 'spammy',
        reason: ContentFilterReason.spam,
        severity: ContentSeverity.warning,
        createdAt: DateTime.utc(2026),
      );
      expect(noNote.toNIP51Tag(), ['keyword', 'spammy']);
      expect(entry.toNIP51Tag(), ['pubkey', 'abc123', 'repeated abuse']);
    });
  });

  group(ModerationResult, () {
    test('clean is an allow-through result', () {
      expect(ModerationResult.clean.shouldFilter, isFalse);
      expect(ModerationResult.clean.severity, ContentSeverity.info);
      expect(ModerationResult.clean.reasons, isEmpty);
      expect(ModerationResult.clean.matchingEntries, isEmpty);
      expect(ModerationResult.clean.warningMessage, isNull);
    });
  });

  group(contentFilterReasonToNip56Type, () {
    test('maps every reason to a canonical NIP-56 report type string', () {
      const expected = {
        ContentFilterReason.spam: 'spam',
        ContentFilterReason.harassment: 'profanity',
        ContentFilterReason.violence: 'illegal',
        ContentFilterReason.sexualContent: 'nudity',
        ContentFilterReason.copyright: 'illegal',
        ContentFilterReason.falseInformation: 'other',
        ContentFilterReason.childSafety: 'other',
        ContentFilterReason.csam: 'illegal',
        ContentFilterReason.underageUser: 'other',
        ContentFilterReason.aiGenerated: 'other',
        ContentFilterReason.other: 'other',
      };

      // Pin the table to the enum first: without this a newly added reason
      // with a wrong mapping arm would pass, since the loop below only
      // visits the keys the table already names.
      expect(expected.keys.toSet(), ContentFilterReason.values.toSet());

      for (final entry in expected.entries) {
        expect(
          contentFilterReasonToNip56Type(entry.key),
          entry.value,
          reason: '${entry.key} should map to NIP-56 type "${entry.value}"',
        );
      }
    });
  });

  group(contentFilterReasonToNip32Label, () {
    test('maps every reason to a distinct NS- label', () {
      const expected = {
        ContentFilterReason.spam: 'NS-spam',
        ContentFilterReason.harassment: 'NS-harassment',
        ContentFilterReason.violence: 'NS-violence',
        ContentFilterReason.sexualContent: 'NS-sexualContent',
        ContentFilterReason.copyright: 'NS-copyright',
        ContentFilterReason.falseInformation: 'NS-falseInformation',
        ContentFilterReason.childSafety: 'NS-childSafety',
        ContentFilterReason.csam: 'NS-csam',
        ContentFilterReason.underageUser: 'NS-underageUser',
        ContentFilterReason.aiGenerated: 'NS-aiGenerated',
        ContentFilterReason.other: 'NS-other',
      };

      expect(expected.keys.toSet(), ContentFilterReason.values.toSet());

      for (final entry in expected.entries) {
        expect(
          contentFilterReasonToNip32Label(entry.key),
          entry.value,
          reason:
              '${entry.key} is a cross-repo wire value consumed by '
              'divine-web, divine-relay-manager, and '
              'divine-moderation-service -- renaming it reclassifies '
              'reports in three services',
        );
      }
    });

    test('is lossless where the NIP-56 mapping collapses reasons', () {
      // The whole reason the DM carries this label as well as the NIP-56
      // type: these five reasons are indistinguishable after the NIP-56
      // collapse, and divine-moderation-service pins report_type on
      // whichever ingestion path writes first.
      const collapsed = [
        ContentFilterReason.aiGenerated,
        ContentFilterReason.childSafety,
        ContentFilterReason.underageUser,
        ContentFilterReason.csam,
        ContentFilterReason.copyright,
      ];

      expect(
        collapsed.map(contentFilterReasonToNip56Type).toSet(),
        hasLength(2),
      );
      expect(
        collapsed.map(contentFilterReasonToNip32Label).toSet(),
        hasLength(collapsed.length),
      );
    });
  });
}
