// ABOUTME: Widget that renders text with clickable hashtags
// ABOUTME: Parses hashtags in text and makes them tappable for navigation

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/utils/hashtag_extractor.dart';
import 'package:openvine/utils/unified_logger.dart';

/// A widget that displays text with clickable hashtags
class ClickableHashtagText extends StatelessWidget {
  const ClickableHashtagText({
    required this.text,
    super.key,
    this.style,
    this.hashtagStyle,
    this.maxLines,
    this.overflow,
    this.onVideoStateChange,
  });
  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final Function()? onVideoStateChange;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract hashtags from the text
    final hashtags = HashtagExtractor.extractHashtags(text);

    // If no hashtags, return simple text
    if (hashtags.isEmpty) {
      return SelectableText(text, style: style, maxLines: maxLines);
    }

    // Build text spans with clickable hashtags
    final spans = _buildTextSpans(context);

    return SelectableText.rich(TextSpan(children: spans), maxLines: maxLines);
  }

  List<TextSpan> _buildTextSpans(BuildContext context) {
    final spans = <TextSpan>[];
    final defaultStyle =
        style ?? const TextStyle(color: Colors.white70, fontSize: 14);
    final tagStyle =
        hashtagStyle ??
        const TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );

    // Regular expression to find hashtags
    final hashtagRegex = RegExp(r'#(\w+)', caseSensitive: false);

    var lastEnd = 0;
    for (final match in hashtagRegex.allMatches(text)) {
      // Add text before the hashtag
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      // Add the clickable hashtag
      final hashtag = match.group(1)!;
      spans.add(
        TextSpan(
          text: match.group(0), // Include the # symbol
          style: tagStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _navigateToHashtagFeed(context, hashtag),
        ),
      );

      lastEnd = match.end;
    }

    // Add any remaining text after the last hashtag
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return spans;
  }

  void _navigateToHashtagFeed(BuildContext context, String hashtag) {
    Log.debug(
      '📍 Navigating to hashtag grid: #$hashtag',
      name: 'ClickableHashtagText',
      category: LogCategory.ui,
    );

    // Notify parent about video state change if callback provided
    onVideoStateChange?.call();

    // Navigate to hashtag grid view (no index = grid mode)
    context.goHashtag(hashtag);
  }
}
