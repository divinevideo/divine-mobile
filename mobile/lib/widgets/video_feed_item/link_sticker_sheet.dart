// ABOUTME: The sheet a link sticker on a video opens: where the link goes,
// ABOUTME: its whole domain shown before the viewer leaves Divine for it.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opens a link the viewer chose in the sheet; replaced in tests.
typedef LinkStickerLauncher = Future<void> Function(
  BuildContext context,
  String url,
);

Future<void> _openLink(BuildContext context, String url) =>
    openExternalLink(context, url, requireConfirmationForUntrusted: false);

/// Opens [url], a link on a video: one to Divine or its subdomains straight
/// away, in the app where it leads to a screen there; any other once the
/// viewer has seen where it goes in [showLinkStickerSheet].
Future<void> openVideoLink(BuildContext context, String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return isTrustedExternalLinkHost(host)
      ? openExternalLink(context, url)
      : showLinkStickerSheet(context, url);
}

/// Shows where [url] goes, the whole domain large and the address below it,
/// and opens it when the viewer taps it, the way the profile's support sheet
/// opens its links.
Future<void> showLinkStickerSheet(
  BuildContext context,
  String url, {
  LinkStickerLauncher launch = _openLink,
}) {
  return context.showVideoPausingVineBottomSheet<void>(
    scrollable: false,
    expanded: false,
    contentTitle: context.l10n.messageExternalLinkDialogTitle,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          context.l10n.videoStickerLinkSheetBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      ),
      LinkStickerSheetTile(url: url, launch: launch),
      const SizedBox(height: 8),
    ],
  );
}

/// The link in [showLinkStickerSheet]: its whole domain, its address and an
/// arrow out of the app.
@visibleForTesting
class LinkStickerSheetTile extends StatelessWidget {
  const LinkStickerSheetTile({
    required this.url,
    required this.launch,
    super.key,
  });

  final String url;
  final LinkStickerLauncher launch;

  /// The host [url] goes to, without `www.`.
  String get _domain {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        minTileHeight: 56,
        leading: DivineIcon(
          icon: DivineIconName.linkSimple,
          color: context.vineColors.accentPositive,
        ),
        // Never cut short: a long host hides where it really goes at its
        // end, as in `divine.video.login.example.com`.
        title: Text(
          _domain,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        subtitle: Text(
          url,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceVariant,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: DivineIcon(
          icon: DivineIconName.arrowUpRight,
          color: context.vineColors.onSurfaceVariant,
          size: 20,
        ),
        onTap: () => runDetached(
          _launchAndClose(context),
          'open a link sticker',
          logName: 'LinkStickerSheetTile',
          category: LogCategory.ui,
        ),
      ),
    );
  }

  Future<void> _launchAndClose(BuildContext context) async {
    await launch(context, url);
    if (context.mounted) Navigator.of(context).pop();
  }
}
