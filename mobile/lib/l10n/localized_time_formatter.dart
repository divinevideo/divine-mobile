// ABOUTME: Locale-aware wrapper around TimeFormatter.
// ABOUTME: Maps TimeFormatter output to l10n strings from ARB.

import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Provides locale-aware time formatting by combining
/// [TimeFormatter] logic with [AppLocalizations] strings.
///
/// The [TimeFormatter] package remains l10n-free.
/// This wrapper lives in the app layer and supplies the
/// localized labels.
abstract class LocalizedTimeFormatter {
  /// Age at which [formatPostAge] switches from elapsed time to a full date.
  static const int _absoluteDateAfterDays = 7;

  /// Formats a Unix timestamp (seconds) into a localized
  /// short relative time string.
  ///
  /// Examples: "now", "3m", "2h", "3d", "2w", "1mo", "1y"
  static String formatRelative(AppLocalizations l10n, int unixSeconds) {
    final now = clock.now();
    final then = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final difference = now.difference(then);

    if (difference.inMinutes < 1) return l10n.timeNow;
    if (difference.inMinutes < 60) {
      return l10n.timeShortMinutes(difference.inMinutes);
    }
    if (difference.inHours < 24) {
      return l10n.timeShortHours(difference.inHours);
    }
    if (difference.inDays < 7) {
      return l10n.timeShortDays(difference.inDays);
    }
    if (difference.inDays < 60) {
      return l10n.timeShortWeeks(difference.inDays ~/ 7);
    }
    if (difference.inDays < 365) {
      return l10n.timeShortMonths(difference.inDays ~/ 30);
    }
    return l10n.timeShortYears(difference.inDays ~/ 365);
  }

  /// Formats a Unix timestamp (seconds) into a localized
  /// verbose relative time string.
  ///
  /// Examples: "Now", "3m ago", "2h ago"
  static String formatRelativeVerbose(AppLocalizations l10n, int unixSeconds) {
    final now = clock.now();
    final then = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final difference = now.difference(then);

    if (difference.inMinutes < 1) return l10n.timeVerboseNow;
    final short = formatRelative(l10n, unixSeconds);
    return l10n.timeAgo(short);
  }

  /// Formats a Unix timestamp (seconds) into a localized
  /// date label for chat dividers.
  ///
  /// Returns localized "Today", "Yesterday", the locale day
  /// name for the past week, or locale "Month Day" for older.
  static String formatDateLabel(
    AppLocalizations l10n,
    int unixSeconds, {
    String? locale,
  }) {
    final now = clock.now();
    final date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDay).inDays;

    if (diff == 0) return l10n.timeToday;
    if (diff == 1) return l10n.timeYesterday;
    if (diff < 7) return DateFormat.EEEE(locale).format(date);
    return DateFormat('MMMM d', locale).format(date);
  }

  /// Formats a Unix timestamp (seconds) for conversation list
  /// timestamps with localized labels.
  static String formatConversationTimestamp(
    AppLocalizations l10n,
    int unixSeconds, {
    String? locale,
  }) {
    final now = clock.now();
    final date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return l10n.timeNow;
    if (diff.inMinutes < 60) {
      return l10n.timeShortMinutes(diff.inMinutes);
    }

    final dayDiff = _calendarDayDiff(now, date);
    if (dayDiff == 0) return l10n.timeShortHours(diff.inHours);
    return _formatByDayDiff(l10n, dayDiff, date, now, locale: locale);
  }

  /// Formats a Unix timestamp (seconds) for message bubble
  /// timestamps with localized labels.
  ///
  /// When [use24Hour] is true, same-day timestamps render with a
  /// 24-hour clock (`DateFormat.Hm`). Otherwise they use the locale's
  /// preferred 12h/24h style via `DateFormat.jm`. Pass
  /// `MediaQuery.of(context).alwaysUse24HourFormat` from the callsite
  /// so the OS-level clock override is honoured.
  static String formatMessageTime(
    AppLocalizations l10n,
    int unixSeconds, {
    String? locale,
    bool use24Hour = false,
  }) {
    final now = clock.now();
    final date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return l10n.timeVerboseNow;

    final dayDiff = _calendarDayDiff(now, date);
    if (dayDiff == 0) {
      return use24Hour
          ? DateFormat.Hm(locale).format(date)
          : DateFormat.jm(locale).format(date);
    }
    return _formatByDayDiff(l10n, dayDiff, date, now, locale: locale);
  }

  /// Formats a [Duration] into a localized relative time ago
  /// string. Useful for model display methods that receive
  /// localization from the UI layer.
  ///
  /// Examples: "just now", "5m ago", "2h ago", "3d ago"
  static String formatDurationAgo(AppLocalizations l10n, Duration duration) {
    if (duration.inMinutes < 1) return l10n.timeJustNow;
    if (duration.inMinutes < 60) {
      return l10n.timeMinutesAgo(duration.inMinutes);
    }
    if (duration.inHours < 24) {
      return l10n.timeHoursAgo(duration.inHours);
    }
    return l10n.timeDaysAgo(duration.inDays);
  }

  /// Formats a [DateTime] as a notification-list timestamp.
  ///
  /// Returns [formatRelativeVerbose] for timestamps within the last 7
  /// days, otherwise an absolute compact date.
  ///
  /// Prefers [MaterialLocalizations.formatCompactDate] when a
  /// [context] is supplied (auto-respects in-app locale and honours
  /// the framework's compact-date conventions). Falls back to
  /// [DateFormat.yMd] with the passed [locale] otherwise.
  static String formatNotificationTimestamp(
    AppLocalizations l10n,
    DateTime timestamp, {
    String? locale,
    BuildContext? context,
  }) {
    final now = clock.now();
    final localTimestamp = timestamp.toLocal();
    final difference = now.difference(localTimestamp);

    if (difference.inDays < 7) {
      final unixSeconds = localTimestamp.millisecondsSinceEpoch ~/ 1000;
      return formatRelativeVerbose(l10n, unixSeconds);
    }
    if (context != null) {
      return MaterialLocalizations.of(
        context,
      ).formatCompactDate(localTimestamp);
    }
    return DateFormat.yMd(locale).format(localTimestamp);
  }

  /// Formats a post timestamp for a video card's meta line.
  ///
  /// Recent posts read as elapsed time ("3h ago"); anything a week or older
  /// falls back to an absolute date carrying the year ("Apr 22, 2014"), so a
  /// classic Vine reads as an artifact rather than as neglect.
  ///
  /// Examples: "Now", "3h ago", "2d ago", "Apr 22, 2014"
  static String formatPostAge(
    AppLocalizations l10n,
    int unixSeconds, {
    String? locale,
  }) {
    // Formatted in local time like every other method here: DateFormat reads
    // the DateTime's field accessors, so formatting a UTC value renders the
    // UTC calendar day. A Vine published near midnight UTC would otherwise
    // show a day late for every viewer in the Americas.
    final date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final difference = clock.now().difference(date);

    if (difference.inDays >= _absoluteDateAfterDays) {
      return DateFormat.yMMMd(locale).format(date);
    }
    return formatRelativeVerbose(l10n, unixSeconds);
  }

  /// Formats a [Duration] into a localized draft age string.
  ///
  /// Examples: "Just now", "5m ago", "2h ago", "3d ago"
  static String formatDraftAge(AppLocalizations l10n, Duration duration) {
    if (duration.inMinutes < 1) return l10n.draftTimeJustNow;
    if (duration.inMinutes < 60) {
      return l10n.timeMinutesAgo(duration.inMinutes);
    }
    if (duration.inHours < 24) {
      return l10n.timeHoursAgo(duration.inHours);
    }
    return l10n.timeDaysAgo(duration.inDays);
  }

  static int _calendarDayDiff(DateTime now, DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    return today.difference(messageDay).inDays;
  }

  static String _formatByDayDiff(
    AppLocalizations l10n,
    int dayDiff,
    DateTime date,
    DateTime now, {
    String? locale,
  }) {
    if (dayDiff == 1) return l10n.timeYesterday;
    if (dayDiff >= 2 && dayDiff <= 6) {
      return DateFormat.EEEE(locale).format(date);
    }
    if (date.year == now.year) {
      return DateFormat.MMMd(locale).format(date);
    }
    return DateFormat.yMMMd(locale).format(date);
  }
}
