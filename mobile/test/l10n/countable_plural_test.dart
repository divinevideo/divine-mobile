// ABOUTME: Guards the countable ARB keys against regressing to a flat value.
// ABOUTME: A flat value still compiles and still renders the count — it just
// ABOUTME: stops inflecting the noun, which no other test in the repo catches.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Every countable key fixed by #3633, as a closure over the raw count.
///
/// Tier-2 keys take `(int countValue, String count)` — the int selects the
/// plural form, the String is the displayed (compact) numeral. The display
/// value is irrelevant to grammar, so the count's own digits stand in.
Map<String, String Function(AppLocalizations, int)> get _countableKeys => {
  // Tier 1 — already int-typed, value-only change.
  'listVideoCount': (l, n) => l.listVideoCount(n),
  'soundVideoCount': (l, n) => l.soundVideoCount(n),
  'profileFollowerCountUsers': (l, n) => l.profileFollowerCountUsers(n),
  'monetizationSettingsConfiguredCount': (l, n) =>
      l.monetizationSettingsConfiguredCount(n),
  'monetizationTipsSettingsConfiguredCount': (l, n) =>
      l.monetizationTipsSettingsConfiguredCount(n),
  'settingsStorageApproxVideos': (l, n) => l.settingsStorageApproxVideos(n),
  'videoEditorStopMotionFramesPerImageValueSemanticLabel': (l, n) =>
      l.videoEditorStopMotionFramesPerImageValueSemanticLabel(n),
  'relaySettingsConnectedToRelays': (l, n) =>
      l.relaySettingsConnectedToRelays(n),
  'relaySettingsSubscriptionsSummary': (l, n) =>
      l.relaySettingsSubscriptionsSummary(n),
  'relayDiagnosticRelayCount': (l, n) => l.relayDiagnosticRelayCount(n),
  'relayDiagnosticVideosCount': (l, n) => l.relayDiagnosticVideosCount(n),
  'relayDiagnosticFoundVideoEvents': (l, n) =>
      l.relayDiagnosticFoundVideoEvents(n),
  'relayDiagnosticConnectedToRelays': (l, n) =>
      l.relayDiagnosticConnectedToRelays(n),
  // Tier 1b — no call site today (#3630). Pluralized anyway: once the baseline
  // exempts a key the ratchet stays silent, so a later call site would ship
  // "1 videos" with nothing to catch it.
  'shareMenuVideoCount': (l, n) => l.shareMenuVideoCount(n),
  'shareMenuFollowSetsAvailable': (l, n) => l.shareMenuFollowSetsAvailable(n),
  'videoFeedLoopCountLabel': (l, n) => l.videoFeedLoopCountLabel(n),
  'settingsDeveloperModeTapsRemaining': (l, n) =>
      l.settingsDeveloperModeTapsRemaining(n),
  // Tier 2 — selector int + displayed String (Design X).
  'analyticsViewsCount': (l, n) => l.analyticsViewsCount(n, '$n'),
  'analyticsCommentsCount': (l, n) => l.analyticsCommentsCount(n, '$n'),
  'analyticsInteractionsCount': (l, n) => l.analyticsInteractionsCount(n, '$n'),
  'analyticsRepostsCount': (l, n) => l.analyticsRepostsCount(n, '$n'),
  'categoryVideoCount': (l, n) => l.categoryVideoCount(n, '$n'),
  'messageRequestVideosCount': (l, n) => l.messageRequestVideosCount(n, '$n'),
  'messageRequestFollowersCount': (l, n) =>
      l.messageRequestFollowersCount(n, '$n'),
  'relaySettingsEventsSummary': (l, n) => l.relaySettingsEventsSummary(n, '$n'),
};

void main() {
  group('countable ARB keys', () {
    test('English inflects the noun between one and many', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final flat = <String>[];

      for (final entry in _countableKeys.entries) {
        final one = entry.value(en, 1);
        final many = entry.value(en, 2);
        // Strip the interpolated digits: what remains is the noun phrase. If a
        // key is flat, the two are identical once the count is removed.
        if (one.replaceAll('1', '') == many.replaceAll('2', '')) {
          flat.add('${entry.key}: "$one" vs "$many"');
        }
      }

      expect(
        flat,
        isEmpty,
        reason:
            'These keys render the same noun for 1 and 2, so they lost their '
            'ICU plural arms and now ship text like "1 videos" (#3633).\n'
            '${flat.join('\n')}',
      );
    });

    test('every countable key still interpolates the count', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final missing = <String>[];

      for (final entry in _countableKeys.entries) {
        // 7 is arbitrary but unambiguous: it cannot appear as a hardcoded
        // digit in a `one`/`other` arm the way 0, 1 or 2 can.
        if (!entry.value(en, 7).contains('7')) {
          missing.add('${entry.key}: "${entry.value(en, 7)}"');
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'These keys dropped the count placeholder, so the number never '
            'reaches the user.\n${missing.join('\n')}',
      );
    });

    // Polish and Romanian were correct before #3633 and must stay correct: a
    // bulk "propagate the English shape to every locale" pass would silently
    // flatten them, and gen-l10n would not complain.
    test('Polish keeps its one/few/many arms', () {
      final pl = lookupAppLocalizations(const Locale('pl'));
      expect(pl.listVideoCount(1), '1 film');
      expect(pl.listVideoCount(2), '2 filmy');
      expect(pl.listVideoCount(5), '5 filmów');
      expect(pl.profileFollowerCountUsers(1), '1 użytkownik');
      expect(pl.profileFollowerCountUsers(2), '2 użytkowników');
    });

    test('Romanian keeps its one/few/other arms', () {
      final ro = lookupAppLocalizations(const Locale('ro'));
      expect(ro.listVideoCount(1), '1 videoclip');
      expect(ro.listVideoCount(2), '2 videoclipuri');
      // Romanian takes "de" above 19.
      expect(ro.listVideoCount(100), '100 de videoclipuri');
    });
  });
}
