// ABOUTME: Share service for generating Nostr event links and handling share actions
// ABOUTME: Supports nevent links, external app sharing, and clipboard operations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:share_plus/share_plus.dart';

/// Service for handling video sharing functionality
class ShareService {
  static const String _appUrl = 'https://divine.video';

  /// Generate a Nostr event link (nevent format) for a video
  String generateNostrEventLink(VideoEvent video) {
    try {
      // Create nevent bech32 encoded link
      final eventId = video.id;

      // For now, create a simple nevent link format
      // In a full implementation, this would use proper bech32 encoding
      final neventLink = 'nostr:nevent1$eventId';
      return neventLink;
    } catch (e) {
      Log.error(
        'Error generating Nostr event link: $e',
        name: 'ShareService',
        category: LogCategory.system,
      );
      return 'nostr:note1${video.id}';
    }
  }

  /// Generate a web app link for a video
  String generateWebLink(VideoEvent video) {
    return '$_appUrl/video/${video.id}';
  }

  /// Generate shareable text content
  String generateShareText(VideoEvent video) {
    final content = video.content;
    final webLink = generateWebLink(video);

    // Extract hashtags for better sharing
    final hashtags = _extractHashtags(content);
    final hashtagText = hashtags.isNotEmpty ? ' ${hashtags.join(' ')}' : '';

    // Truncate content if too long
    final truncatedContent = content.length > 100
        ? '${content.substring(0, 100)}...'
        : content;

    return '$truncatedContent$hashtagText\n\n$webLink';
  }

  /// Copy link to clipboard
  Future<void> copyToClipboard(String text, BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Error copying to clipboard: $e',
        name: 'ShareService',
        category: LogCategory.system,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy link'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Share via native platform share sheet
  Future<void> shareViaSheet(VideoEvent video, BuildContext context) async {
    try {
      final shareText = generateShareText(video);
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: 'Check out this video on divine'),
      );
    } catch (e) {
      Log.error(
        'Error sharing via sheet: $e',
        name: 'ShareService',
        category: LogCategory.system,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Show share options bottom sheet
  void showShareOptions(VideoEvent video, BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _ShareOptionsBottomSheet(video: video, shareService: this),
    );
  }

  /// Extract hashtags from content
  List<String> _extractHashtags(String content) {
    final regex = RegExp(r'#\w+');
    return regex.allMatches(content).map((match) => match.group(0)!).toList();
  }
}

/// Bottom sheet widget for share options
class _ShareOptionsBottomSheet extends StatelessWidget {
  const _ShareOptionsBottomSheet({
    required this.video,
    required this.shareService,
  });
  final VideoEvent video;
  final ShareService shareService;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        const Text(
          'Share Video',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Share options
        _buildShareOption(
          context,
          icon: Icons.share,
          title: 'Share to Apps',
          subtitle: 'Share via messaging, social apps',
          onTap: () {
            Navigator.pop(context);
            shareService.shareViaSheet(video, context);
          },
        ),

        _buildShareOption(
          context,
          icon: Icons.link,
          title: 'Copy Web Link',
          subtitle: 'Copy shareable web link',
          onTap: () {
            Navigator.pop(context);
            final webLink = shareService.generateWebLink(video);
            shareService.copyToClipboard(webLink, context);
          },
        ),

        _buildShareOption(
          context,
          icon: Icons.bolt,
          title: 'Copy Nostr Link',
          subtitle: 'Copy nevent link for Nostr clients',
          onTap: () {
            Navigator.pop(context);
            final nostrLink = shareService.generateNostrEventLink(video);
            shareService.copyToClipboard(nostrLink, context);
          },
        ),

        const SizedBox(height: 20),
      ],
    ),
  );

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon, size: 24),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
  );
}
