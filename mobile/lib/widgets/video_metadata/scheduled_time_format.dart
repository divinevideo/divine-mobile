// ABOUTME: Formats a scheduled publish time for display in the device's
// ABOUTME: locale and time zone (#3538).

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// "Tue, Sep 22, 8:00 PM" — the date in the current locale plus the clock
/// time in the device's 12/24-hour preference. [time] may be in any zone;
/// it is shown in the device's.
String formatScheduledDateTime(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.MMMEd(locale).format(local);
  return '$date, ${formatScheduledClockTime(context, local)}';
}

/// "8:00 PM" — the clock time only, in the device's 12/24-hour preference.
String formatScheduledClockTime(BuildContext context, DateTime time) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(time.toLocal()),
    alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
  );
}
