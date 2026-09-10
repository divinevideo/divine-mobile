// ABOUTME: Tests for LocalizedTimeFormatter — locale-aware wrapper around
// ABOUTME: TimeFormatter that maps to AppLocalizations strings.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';

final _fixedNow = DateTime(2026, 3, 10, 15, 30);

Future<AppLocalizations> _loadL10n(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l10n = context.l10n;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return l10n;
}

int _unixSecondsAgo(Duration duration) {
  return _fixedNow.subtract(duration).millisecondsSinceEpoch ~/ 1000;
}

String _localizedLocalDate(String locale, int unixSeconds) {
  return DateFormat.yMMMd(locale).format(
    DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal(),
  );
}

T _withFixedClock<T>(T Function() callback) {
  return withClock(Clock.fixed(_fixedNow), callback);
}

void main() {
  setUpAll(initializeDateFormatting);

  group(LocalizedTimeFormatter, () {
    group('formatRelative', () {
      testWidgets('returns localized "now" for <1 minute', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final ts = _unixSecondsAgo(const Duration(seconds: 30));

        _withFixedClock(() {
          expect(LocalizedTimeFormatter.formatRelative(en, ts), equals('now'));
          expect(
            LocalizedTimeFormatter.formatRelative(de, ts),
            equals('jetzt'),
          );
        });
      });

      testWidgets('returns minutes for <1 hour', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final ts = _unixSecondsAgo(const Duration(minutes: 5));

        _withFixedClock(() {
          expect(LocalizedTimeFormatter.formatRelative(en, ts), equals('5m'));
          expect(
            LocalizedTimeFormatter.formatRelative(de, ts),
            equals('5 Min'),
          );
        });
      });

      testWidgets('returns hours for <1 day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final ts = _unixSecondsAgo(const Duration(hours: 14));

        _withFixedClock(() {
          expect(LocalizedTimeFormatter.formatRelative(en, ts), equals('14h'));
        });
      });

      testWidgets('returns days for <1 week', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final ts = _unixSecondsAgo(const Duration(days: 3));

        _withFixedClock(() {
          expect(LocalizedTimeFormatter.formatRelative(en, ts), equals('3d'));
        });
      });

      testWidgets('returns weeks for <60 days', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final ts = _unixSecondsAgo(const Duration(days: 14));

        _withFixedClock(() {
          expect(LocalizedTimeFormatter.formatRelative(en, ts), equals('2w'));
        });
      });

      testWidgets('returns months for <1 year', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final ts = _unixSecondsAgo(const Duration(days: 90));

        _withFixedClock(() {
          expect(LocalizedTimeFormatter.formatRelative(en, ts), equals('3mo'));
        });
      });

      testWidgets('returns years for >=1 year', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final ts = _unixSecondsAgo(const Duration(days: 400));

        _withFixedClock(() {
          expect(LocalizedTimeFormatter.formatRelative(en, ts), equals('1y'));
        });
      });
    });

    group('formatRelativeVerbose', () {
      testWidgets('returns localized "Now" for <1 minute', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final ts = _unixSecondsAgo(const Duration(seconds: 10));

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatRelativeVerbose(en, ts),
            equals('Now'),
          );
          expect(
            LocalizedTimeFormatter.formatRelativeVerbose(de, ts),
            equals('Jetzt'),
          );
        });
      });

      testWidgets('returns localized "{time} ago" for older', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final ts = _unixSecondsAgo(const Duration(minutes: 3));

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatRelativeVerbose(en, ts),
            equals('3m ago'),
          );
          expect(
            LocalizedTimeFormatter.formatRelativeVerbose(de, ts),
            equals('vor 3 Min'),
          );
        });
      });
    });

    group('formatDateLabel', () {
      testWidgets('returns localized "Today" for current day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final now = _fixedNow;
        final earlierToday = DateTime(now.year, now.month, now.day, 12);
        final safeTime = earlierToday.isAfter(now)
            ? DateTime(now.year, now.month, now.day, 0, 1)
            : earlierToday;
        final ts = safeTime.millisecondsSinceEpoch ~/ 1000;

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatDateLabel(en, ts),
            equals('Today'),
          );
          expect(
            LocalizedTimeFormatter.formatDateLabel(de, ts),
            equals('Heute'),
          );
        });
      });

      testWidgets('returns localized "Yesterday"', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final now = _fixedNow;
        final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
        final ts = yesterday.millisecondsSinceEpoch ~/ 1000;

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatDateLabel(en, ts),
            equals('Yesterday'),
          );
          expect(
            LocalizedTimeFormatter.formatDateLabel(de, ts),
            equals('Gestern'),
          );
        });
      });

      testWidgets('returns weekday name for 2-6 days ago', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final ts = _unixSecondsAgo(const Duration(days: 3));

        final result = _withFixedClock(
          () => LocalizedTimeFormatter.formatDateLabel(
            en,
            ts,
            locale: 'en',
          ),
        );
        const weekdays = {
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        };
        expect(weekdays.contains(result), isTrue, reason: 'got: $result');
      });

      testWidgets('uses passed locale for older dates', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        // Fixed date so en ("January 15") and de ("15. Januar") always differ.
        const ts = 1579046400;

        final enResult = _withFixedClock(
          () => LocalizedTimeFormatter.formatDateLabel(
            en,
            ts,
            locale: 'en',
          ),
        );
        final deResult = _withFixedClock(
          () => LocalizedTimeFormatter.formatDateLabel(
            en,
            ts,
            locale: 'de',
          ),
        );
        expect(enResult, isNotEmpty);
        expect(deResult, isNotEmpty);
        expect(enResult, isNot(equals(deResult)));
      });
    });

    group('formatConversationTimestamp', () {
      testWidgets('returns localized "now" for <1 minute', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final ts = _unixSecondsAgo(const Duration(seconds: 10));

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatConversationTimestamp(en, ts),
            equals('now'),
          );
          expect(
            LocalizedTimeFormatter.formatConversationTimestamp(de, ts),
            equals('jetzt'),
          );
        });
      });

      testWidgets('returns minutes for <1 hour', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final ts = _unixSecondsAgo(const Duration(minutes: 30));

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatConversationTimestamp(en, ts),
            equals('30m'),
          );
        });
      });

      testWidgets('returns hours for same day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final now = _fixedNow;
        final earlierToday = now.copyWith(hour: 1, minute: 0);
        if (now.difference(earlierToday).inMinutes < 60) return;
        final ts = earlierToday.millisecondsSinceEpoch ~/ 1000;

        final result = _withFixedClock(
          () => LocalizedTimeFormatter.formatConversationTimestamp(en, ts),
        );
        expect(result, endsWith('h'));
      });

      testWidgets('returns "Yesterday" for previous day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final now = _fixedNow;
        final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
        final ts = yesterday.millisecondsSinceEpoch ~/ 1000;

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatConversationTimestamp(en, ts),
            equals('Yesterday'),
          );
          expect(
            LocalizedTimeFormatter.formatConversationTimestamp(de, ts),
            equals('Gestern'),
          );
        });
      });
    });

    group('formatMessageTime', () {
      testWidgets('returns localized "Now" for <60 seconds', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final ts = _unixSecondsAgo(const Duration(seconds: 30));

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatMessageTime(en, ts),
            equals('Now'),
          );
          expect(
            LocalizedTimeFormatter.formatMessageTime(de, ts),
            equals('Jetzt'),
          );
        });
      });

      testWidgets('renders time-of-day for same calendar day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final now = _fixedNow;
        final earlierToday = now.subtract(const Duration(hours: 2));
        if (earlierToday.day != now.day) return;
        final ts = earlierToday.millisecondsSinceEpoch ~/ 1000;

        final result = _withFixedClock(
          () => LocalizedTimeFormatter.formatMessageTime(
            en,
            ts,
            locale: 'en',
          ),
        );
        expect(result, matches(RegExp(r'^\d{1,2}:\d{2}\s?(AM|PM)?$')));
      });

      testWidgets(
        'use24Hour: true renders 24-hour clock regardless of locale',
        (tester) async {
          final en = await _loadL10n(tester, const Locale('en'));
          final now = _fixedNow;
          final earlierToday = now.subtract(const Duration(hours: 2));
          if (earlierToday.day != now.day) return;
          final ts = earlierToday.millisecondsSinceEpoch ~/ 1000;

          final result = _withFixedClock(
            () => LocalizedTimeFormatter.formatMessageTime(
              en,
              ts,
              locale: 'en',
              use24Hour: true,
            ),
          );
          expect(result, matches(RegExp(r'^\d{1,2}:\d{2}$')));
          expect(result, isNot(contains('AM')));
          expect(result, isNot(contains('PM')));
        },
      );

      testWidgets('use24Hour: false keeps locale-default 12h in en', (
        tester,
      ) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final now = _fixedNow;
        final earlierToday = now.subtract(const Duration(hours: 2));
        if (earlierToday.day != now.day) return;
        final ts = earlierToday.millisecondsSinceEpoch ~/ 1000;

        final result = _withFixedClock(
          () => LocalizedTimeFormatter.formatMessageTime(
            en,
            ts,
            locale: 'en',
          ),
        );
        expect(result, anyOf(contains('AM'), contains('PM')));
      });

      testWidgets('returns "Yesterday" for previous day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final now = _fixedNow;
        final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
        final ts = yesterday.millisecondsSinceEpoch ~/ 1000;

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatMessageTime(en, ts),
            equals('Yesterday'),
          );
          expect(
            LocalizedTimeFormatter.formatMessageTime(de, ts),
            equals('Gestern'),
          );
        });
      });
    });

    group('formatNotificationTimestamp', () {
      testWidgets('returns localized relative string for <7d', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));
        final ts = _fixedNow.subtract(const Duration(hours: 3));

        _withFixedClock(() {
          expect(
            LocalizedTimeFormatter.formatNotificationTimestamp(en, ts),
            equals('3h ago'),
          );
          expect(
            LocalizedTimeFormatter.formatNotificationTimestamp(de, ts),
            equals('vor 3 Std'),
          );
        });
      });

      testWidgets(
        'uses MaterialLocalizations.formatCompactDate when context is '
        'supplied and the timestamp is older than 7 days',
        (tester) async {
          late AppLocalizations l10n;
          late BuildContext capturedContext;
          final ts = _fixedNow.subtract(const Duration(days: 30));

          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  l10n = context.l10n;
                  capturedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          final result = _withFixedClock(
            () => LocalizedTimeFormatter.formatNotificationTimestamp(
              l10n,
              ts,
              context: capturedContext,
            ),
          );
          final expected = MaterialLocalizations.of(
            capturedContext,
          ).formatCompactDate(ts.toLocal());
          expect(result, equals(expected));
        },
      );

      testWidgets(
        'falls back to DateFormat.yMd(locale) when no context is supplied',
        (tester) async {
          final en = await _loadL10n(tester, const Locale('en'));
          final ts = DateTime(2026, 1, 9, 12);

          _withFixedClock(() {
            expect(
              LocalizedTimeFormatter.formatNotificationTimestamp(
                en,
                ts,
                locale: 'en',
              ),
              equals(DateFormat.yMd('en').format(ts.toLocal())),
            );
            expect(
              LocalizedTimeFormatter.formatNotificationTimestamp(
                en,
                ts,
                locale: 'de',
              ),
              equals(DateFormat.yMd('de').format(ts.toLocal())),
            );
          });
        },
      );
    });

    group('formatDurationAgo', () {
      testWidgets('returns localized "just now" for <1 minute', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));

        expect(
          LocalizedTimeFormatter.formatDurationAgo(
            en,
            const Duration(seconds: 30),
          ),
          equals('just now'),
        );
        expect(
          LocalizedTimeFormatter.formatDurationAgo(
            de,
            const Duration(seconds: 30),
          ),
          equals('gerade eben'),
        );
      });

      testWidgets('returns minutes for <1 hour', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));

        expect(
          LocalizedTimeFormatter.formatDurationAgo(
            en,
            const Duration(minutes: 5),
          ),
          equals('5m ago'),
        );
        expect(
          LocalizedTimeFormatter.formatDurationAgo(
            de,
            const Duration(minutes: 5),
          ),
          equals('vor 5 Min'),
        );
      });

      testWidgets('returns hours for <1 day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        expect(
          LocalizedTimeFormatter.formatDurationAgo(
            en,
            const Duration(hours: 3),
          ),
          equals('3h ago'),
        );
      });

      testWidgets('returns days for >=1 day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        expect(
          LocalizedTimeFormatter.formatDurationAgo(en, const Duration(days: 2)),
          equals('2d ago'),
        );
      });
    });

    group('formatDraftAge', () {
      testWidgets('returns localized "Just now" for <1 minute', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));
        final de = await _loadL10n(tester, const Locale('de'));

        expect(
          LocalizedTimeFormatter.formatDraftAge(
            en,
            const Duration(seconds: 30),
          ),
          equals('Just now'),
        );
        expect(
          LocalizedTimeFormatter.formatDraftAge(
            de,
            const Duration(seconds: 30),
          ),
          equals('Gerade eben'),
        );
      });

      testWidgets('returns minutes for <1 hour', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        expect(
          LocalizedTimeFormatter.formatDraftAge(en, const Duration(minutes: 7)),
          equals('7m ago'),
        );
      });

      testWidgets('returns hours for <1 day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        expect(
          LocalizedTimeFormatter.formatDraftAge(en, const Duration(hours: 5)),
          equals('5h ago'),
        );
      });

      testWidgets('returns days for >=1 day', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        expect(
          LocalizedTimeFormatter.formatDraftAge(en, const Duration(days: 4)),
          equals('4d ago'),
        );
      });
    });

    group('formatPostAge', () {
      testWidgets('returns elapsed time just under a week', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        expect(
          _withFixedClock(
            () => LocalizedTimeFormatter.formatPostAge(
              en,
              _unixSecondsAgo(const Duration(days: 6, hours: 23)),
            ),
          ),
          equals('6d ago'),
        );
      });

      testWidgets('switches to a full date at one week', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        expect(
          _withFixedClock(
            () => LocalizedTimeFormatter.formatPostAge(
              en,
              _unixSecondsAgo(const Duration(days: 7)),
            ),
          ),
          equals('Mar 3, 2026'),
        );
      });

      testWidgets('carries the year on a classic Vine date', (tester) async {
        final en = await _loadL10n(tester, const Locale('en'));

        // Without the year an archive post is indistinguishable from
        // something posted this spring. The day itself is timezone-dependent
        // (the sibling test pins the local-vs-UTC contract), so assert the
        // year and the absolute form.
        final rendered = _withFixedClock(
          () => LocalizedTimeFormatter.formatPostAge(en, 1398168000),
        );

        expect(rendered, contains('2014'));
        expect(rendered, isNot(contains('ago')));
      });

      // NOTE: inert on CI. Mobile CI runs ubuntu-24.04 with no TZ override, so
      // the process timezone is UTC, `toLocal()` is the identity, and both
      // sides of this comparison collapse to the same string whichever way the
      // implementation goes — removing `toLocal()` from formatPostAge keeps
      // this green. It only bites on a developer machine outside UTC, which is
      // where the bug it pins was found. Making it real on CI needs the suite
      // running under a non-UTC TZ, which is a workflow change, not a test
      // change. Kept deliberately: it costs nothing and catches the regression
      // locally. Do not read it as CI coverage.
      testWidgets('renders the local calendar day, not the UTC one (off-UTC '
          'machines only)', (
        tester,
      ) async {
        final en = await _loadL10n(tester, const Locale('en'));

        // 2014-04-22T00:00Z. Anywhere west of UTC this is still Apr 21
        // locally, so formatting the UTC value would print the wrong day.
        const midnightUtc = 1398124800;
        final expected = _localizedLocalDate('en', midnightUtc);

        expect(
          _withFixedClock(
            () => LocalizedTimeFormatter.formatPostAge(en, midnightUtc),
          ),
          equals(expected),
        );
      });

      testWidgets('localizes the absolute date', (tester) async {
        final de = await _loadL10n(tester, const Locale('de'));
        const midnightUtc = 1398124800;
        final expected = _localizedLocalDate('de', midnightUtc);

        expect(
          _withFixedClock(
            () => LocalizedTimeFormatter.formatPostAge(
              de,
              midnightUtc,
              locale: 'de',
            ),
          ),
          equals(expected),
        );
      });

      testWidgets('localizes the relative form', (tester) async {
        final de = await _loadL10n(tester, const Locale('de'));

        expect(
          _withFixedClock(
            () => LocalizedTimeFormatter.formatPostAge(
              de,
              _unixSecondsAgo(const Duration(hours: 3)),
              locale: 'de',
            ),
          ),
          isNot(equals('3h ago')),
        );
      });
    });
  });
}
