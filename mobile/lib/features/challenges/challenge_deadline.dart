import 'package:intl/intl.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Formats an already-localized instant, retaining its real timezone label.
String challengeDeadlineText(AppLocalizations l10n, DateTime localEnd) =>
    l10n.challengeLocalDeadline(
      DateFormat.yMMMd(l10n.localeName).add_Hm().format(localEnd),
      localEnd.timeZoneName,
    );

bool _zonesReady = false;

/// Uses the signed IANA zone without relabeling a UTC instant as local time.
/// Unknown zone spellings remain available in technical details.
String? challengeOrganizerTimeText(
  AppLocalizations l10n,
  DateTime instant,
  String zone,
) {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  try {
    final local = tz.TZDateTime.from(instant, tz.getLocation(zone));
    return l10n.challengeOrganizerTime(
      DateFormat.yMMMd(l10n.localeName).add_Hm().format(local),
      '${local.timeZoneName}, $zone',
    );
  } on tz.LocationNotFoundException {
    return null;
  }
}
