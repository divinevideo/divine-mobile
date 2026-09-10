import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_navigation.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_span_builder.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_support.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

class SelectableLinkifiedText extends ConsumerStatefulWidget {
  const SelectableLinkifiedText({
    required this.text,
    super.key,
    this.style,
    this.linkStyle,
    this.mentionStyle,
    this.onUrlTap,
    this.mentionProfilePubkeys = const [],
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextStyle? mentionStyle;
  final Future<void> Function(String rawUrl)? onUrlTap;
  final List<String> mentionProfilePubkeys;

  @override
  ConsumerState<SelectableLinkifiedText> createState() =>
      _SelectableLinkifiedTextState();
}

class _SelectableLinkifiedTextState
    extends ConsumerState<SelectableLinkifiedText> {
  List<InlineSpan> _currentSpans = const [];

  @override
  Widget build(BuildContext context) {
    // Unpaired surrogates in sender-controlled content crash the
    // paragraph builder during layout (#6111).
    final text = sanitizeUtf16(widget.text);
    if (text.isEmpty) {
      _replaceCurrentSpans(const []);
      return const SizedBox.shrink();
    }

    final defaultStyle =
        widget.style ??
        TextStyle(color: context.vineColors.onSurfaceVariant, fontSize: 14);
    final linkStyle =
        widget.linkStyle ??
        const TextStyle(
          color: VineTheme.info,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    final mentionStyle =
        widget.mentionStyle ?? linkStyle.copyWith(fontWeight: FontWeight.w600);
    final spans = LinkifiedTextSpanBuilder(
      text: text,
      defaultStyle: defaultStyle,
      linkStyle: linkStyle,
      mentionStyle: mentionStyle,
      videoLabel: Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )?.clickableTextViewVideoLink,
      profileLabelForHex: _profileDisplayText,
      profilePubkeyForMention: _profilePubkeyForMention,
      onHashtagTap: (hashtag) => _navigateToHashtagFeed(context, hashtag),
      onProfileTap: (hexPubkey) => _navigateToProfile(context, hexPubkey),
      onVideoTap: (routeReference) => _navigateToVideo(context, routeReference),
      onMentionTap: (username) => _navigateToMention(context, username),
      onUrlTap: _handleUrlTap,
      // A WidgetSpan seeds the editing controller with U+FFFC, so a copied
      // bio would lose the character. Copy fidelity over brand color here.
      allowWidgetSpans: false,
    ).build();

    if (!_hasClickableOrStylableToken(spans, defaultStyle)) {
      _replaceCurrentSpans(const []);
      return SelectableText(text, style: widget.style);
    }

    _replaceCurrentSpans(spans);
    return SelectableText.rich(TextSpan(children: _currentSpans));
  }

  String _profileDisplayText(String hexPubkey) {
    return LinkifiedTextSupport.profileDisplayText(ref, hexPubkey);
  }

  String? _profilePubkeyForMention(String username) {
    return LinkifiedTextSupport.profilePubkeyForMention(
      ref,
      username,
      widget.mentionProfilePubkeys,
    );
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

  void _navigateToMention(BuildContext context, String username) {
    unawaited(_resolveAndNavigateToMention(context, username));
  }

  Future<void> _resolveAndNavigateToMention(
    BuildContext context,
    String username,
  ) async {
    final resolvedPubkey = await _resolveMentionPubkey(username);
    if (!context.mounted) return;

    if (resolvedPubkey != null) {
      _navigateToProfile(context, resolvedPubkey);
      return;
    }

    LinkifiedTextNavigation.navigateToSearch(context, username);
  }

  Future<String?> _resolveMentionPubkey(String username) async {
    return LinkifiedTextSupport.resolveProfilePubkeyForMention(
      ref.read(profileRepositoryProvider),
      username,
    );
  }

  Future<void> _handleUrlTap(String rawUrl) async {
    await LinkifiedTextNavigation.handleUrlTap(
      rawUrl,
      customHandler: widget.onUrlTap,
    );
  }

  /// Defensive: a non-[TextSpan] cannot be painted by the plain
  /// `SelectableText` fast path. None is emitted for this widget today — the
  /// builder runs with `allowWidgetSpans: false` — but if one ever arrives it
  /// takes the rich path rather than being dropped.
  bool _hasClickableOrStylableToken(List<InlineSpan> spans, TextStyle style) =>
      spans.any(
        (span) =>
            span is! TextSpan || span.recognizer != null || span.style != style,
      );

  void _replaceCurrentSpans(List<InlineSpan> spans) {
    final previousSpans = _currentSpans;
    _currentSpans = spans;
    LinkifiedTextSupport.disposeSpans(previousSpans);
  }

  @override
  void dispose() {
    LinkifiedTextSupport.disposeSpans(_currentSpans);
    super.dispose();
  }
}
