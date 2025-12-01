// ABOUTME: Widget for hashtag input with parsing and suggestion functionality
// ABOUTME: Handles hashtag extraction, validation, and visual feedback for video metadata

import 'package:flutter/material.dart';

class HashtagInputWidget extends StatefulWidget {
  const HashtagInputWidget({
    required this.onHashtagsChanged,
    super.key,
    this.initialValue = '',
    this.maxHashtags = 10,
  });
  final String initialValue;
  final Function(List<String>) onHashtagsChanged;
  final int maxHashtags;

  @override
  State<HashtagInputWidget> createState() => _HashtagInputWidgetState();
}

class _HashtagInputWidgetState extends State<HashtagInputWidget> {
  late TextEditingController _controller;
  List<String> _hashtags = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _parseHashtags(widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parseHashtags(String text) {
    final regex = RegExp(r'#\w+');
    final matches = regex.allMatches(text);
    _hashtags = matches.map((match) => match.group(0)!).toList();
    widget.onHashtagsChanged(_hashtags);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _controller,
        enableInteractiveSelection: true,
        decoration: InputDecoration(
          hintText: 'Add hashtags... #vine #nostr',
          border: const OutlineInputBorder(),
          suffixText: '${_hashtags.length}/${widget.maxHashtags}',
        ),
        onChanged: _parseHashtags,
        maxLines: 2,
      ),
      if (_hashtags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _hashtags
              .map(
                (hashtag) => Chip(
                  label: Text(hashtag),
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.1),
                ),
              )
              .toList(),
        ),
      ],
    ],
  );
}
