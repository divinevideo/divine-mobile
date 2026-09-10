// ABOUTME: ProfileWebsiteRow — tappable website link row for profile headers.
// ABOUTME: Renders the Kind-0 `website` field with a globe icon.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pluggable URL launcher for tests.
typedef WebsiteUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// A single-line tappable row showing the `website` field from a Kind-0 profile.
///
/// Strips the URL scheme for display. Shows a snackbar when the system cannot
/// open the URL. Override [launcher] in tests.
class ProfileWebsiteRow extends StatelessWidget {
  /// Creates a [ProfileWebsiteRow] for [url].
  const ProfileWebsiteRow({
    required this.url,
    super.key,
    this.launcher = _defaultLauncher,
  });

  /// The raw website URL from the Kind-0 `website` field.
  final String url;

  /// URL launcher hook for tests.
  final WebsiteUrlLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final displayUrl = _displayUrl(url);
    final launchUri = _launchUri(url);
    return Semantics(
      button: true,
      label: context.l10n.profileWebsiteSemanticLabel(url),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: launchUri == null ? null : () => _onTap(context, launchUri),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              DivineIcon(
                icon: DivineIconName.globe,
                size: 14,
                color: context.vineColors.accentPositive,
              ),
              Flexible(
                child: Text(
                  displayUrl,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.accentPositive,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, Uri uri) async {
    final launched = await launcher(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.profileCouldNotOpenWebsite,
        ),
      );
    }
  }
}

/// Strips the URL scheme (and optionally `www.`) for display.
String _displayUrl(String raw) {
  var display = raw.trim();
  display = display.replaceFirst(
    RegExp('^https?://', caseSensitive: false),
    '',
  );
  if (display.startsWith('www.')) display = display.substring(4);
  if (display.endsWith('/')) display = display.substring(0, display.length - 1);
  return display;
}

/// Returns the [Uri] to launch, adding `https://` when the raw value has no
/// scheme. Returns `null` for unparseable values.
Uri? _launchUri(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final withScheme =
      trimmed.startsWith(RegExp('https?://', caseSensitive: false))
      ? trimmed
      : 'https://$trimmed';
  return Uri.tryParse(withScheme);
}
