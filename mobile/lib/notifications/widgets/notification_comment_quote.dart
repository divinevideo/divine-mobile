// ABOUTME: Shared comment-quote primitive for notification rows. Renders
// ABOUTME: the quoted comment text with curly quotes and an optional
// ABOUTME: muted relative-timestamp suffix appended inline at the end.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_navigation.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_span_builder.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_support.dart';

/// Renders a notification's quoted comment beneath the message text.
///
/// The text is wrapped in curly quotes and rendered in
/// [VineTheme.bodyMediumFont]. When [timestamp] is non-empty the
/// formatted relative time (e.g. `2d`) is appended inline at the end of
/// the quote in the muted on-surface color — keeping the timestamp
/// anchored to the visual end of the row rather than floating between
/// the message text and the quote, which is what happens when the quote
/// is rendered as a separate widget below a message that already
/// includes its own trailing timestamp.
///
/// Capped at two lines so a long quote doesn't push the row's intrinsic
/// height past the rest of the list.
class NotificationCommentQuote extends ConsumerStatefulWidget {
  /// Creates a [NotificationCommentQuote].
  const NotificationCommentQuote({
    required this.text,
    this.timestamp,
    super.key,
  });

  /// The quoted comment body. Surrounding curly quotes are added by
  /// the widget — pass the raw string.
  final String text;

  /// Optional formatted relative timestamp (e.g. `2d`). When non-null
  /// and non-empty it's appended inline after the closing curly quote
  /// in muted styling.
  final String? timestamp;

  @override
  ConsumerState<NotificationCommentQuote> createState() =>
      _NotificationCommentQuoteState();
}

class _NotificationCommentQuoteState
    extends ConsumerState<NotificationCommentQuote> {
  List<InlineSpan> _currentBodySpans = const [];

  @override
  Widget build(BuildContext context) {
    final bodyStyle = VineTheme.bodyMediumFont(
      color: context.vineColors.primaryText,
    );
    final linkStyle = VineTheme.bodyMediumFont(
      color: VineTheme.info,
    ).copyWith(fontWeight: FontWeight.w600);
    final bodySpans = LinkifiedTextSpanBuilder(
      text: widget.text,
      defaultStyle: bodyStyle,
      linkStyle: linkStyle,
      mentionStyle: linkStyle,
      videoLabel: Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )?.clickableTextViewVideoLink,
      profileLabelForHex: _profileDisplayText,
      onHashtagTap: (hashtag) => _navigateToHashtagFeed(context, hashtag),
      onProfileTap: (hexPubkey) => _navigateToProfile(context, hexPubkey),
      onVideoTap: (routeReference) => _navigateToVideo(context, routeReference),
      onMentionTap: (username) => _navigateToSearch(context, username),
      onUrlTap: LinkifiedTextNavigation.launchRawUrl,
    ).build();
    _replaceCurrentBodySpans(bodySpans);

    final ts = widget.timestamp;
    final showTimestamp = ts != null && ts.isNotEmpty;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '“', style: bodyStyle),
          ..._currentBodySpans,
          TextSpan(text: '”', style: bodyStyle),
          if (showTimestamp)
            TextSpan(
              text: ' $ts',
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _profileDisplayText(String hexPubkey) {
    return LinkifiedTextSupport.profileDisplayText(ref, hexPubkey);
  }

  void _navigateToHashtagFeed(BuildContext context, String hashtag) {
    LinkifiedTextNavigation.navigateToHashtagFeed(context, hashtag);
  }

  void _navigateToProfile(BuildContext context, String hexPubkey) {
    LinkifiedTextNavigation.navigateToProfile(context, hexPubkey);
  }

  void _navigateToVideo(BuildContext context, String routeReference) {
    LinkifiedTextNavigation.navigateToVideo(context, routeReference);
  }

  void _navigateToSearch(BuildContext context, String username) {
    LinkifiedTextNavigation.navigateToSearch(context, username);
  }

  void _replaceCurrentBodySpans(List<InlineSpan> spans) {
    final previousSpans = _currentBodySpans;
    _currentBodySpans = spans;
    LinkifiedTextSupport.disposeSpans(previousSpans);
  }

  @override
  void dispose() {
    LinkifiedTextSupport.disposeSpans(_currentBodySpans);
    super.dispose();
  }
}
