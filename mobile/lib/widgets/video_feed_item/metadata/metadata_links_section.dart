// ABOUTME: Links section for the metadata expanded sheet: the web pages a
// ABOUTME: video's link stickers point to, each opened in the browser on tap.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web page; pluggable for tests.
typedef MetadataLinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The web pages [video] links to, from its link stickers, each shown by its
/// full address without the scheme, so the domain can be read before the
/// page is opened.
///
/// Shows nothing for a video without links.
class MetadataLinksSection extends StatelessWidget {
  const MetadataLinksSection({
    required this.video,
    this.launcher = _openInBrowser,
    super.key,
  });

  final VideoEvent video;

  /// Opens a link; replaced in tests.
  final MetadataLinkLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final urls = video.linkUrls;
    if (urls.isEmpty) return const SizedBox.shrink();
    return MetadataSection(
      label: context.l10n.metadataLinksLabel,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final url in urls) _LinkRow(url: url, launcher: launcher),
        ],
      ),
    );
  }
}

/// One link: a globe and the address, opened in the browser on tap.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.url, required this.launcher});

  final String url;
  final MetadataLinkLauncher launcher;

  /// [url] without its scheme, `www.` and a trailing slash.
  String get _shown {
    var shown = url.replaceFirst(
      RegExp('^https?://', caseSensitive: false),
      '',
    );
    if (shown.startsWith('www.')) shown = shown.substring(4);
    if (shown.endsWith('/')) shown = shown.substring(0, shown.length - 1);
    return shown;
  }

  Future<void> _open(BuildContext context) async {
    final opened = await launcher(Uri.parse(url));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.profileCouldNotOpenWebsite,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.vineColors.accentPositive;
    return Semantics(
      button: true,
      label: context.l10n.profileWebsiteSemanticLabel(url),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            spacing: 8,
            children: [
              DivineIcon(icon: DivineIconName.globe, size: 16, color: color),
              Expanded(
                child: Text(
                  _shown,
                  style: VineTheme.bodyLargeFont(color: color),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
