import 'package:intl/intl.dart';
import 'package:openvine/l10n/l10n.dart';

/// Formats an already-localized instant, retaining its real timezone label.
String challengeDeadlineText(AppLocalizations l10n, DateTime localEnd) =>
    l10n.challengeLocalDeadline(
      DateFormat.yMMMd(l10n.localeName).add_Hm().format(localEnd),
      localEnd.timeZoneName,
    );
