// ABOUTME: Modal dialog explaining video badge origins (Vine archive vs ProofMode verification)
// ABOUTME: Shows context-appropriate information based on video metadata

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal dialog explaining the origin and authenticity of video content
class BadgeExplanationModal extends StatelessWidget {
  const BadgeExplanationModal({super.key, required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final isVineArchive = video.isOriginalVine;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E), // Dark background
      title: _buildTitle(isVineArchive),
      content: SingleChildScrollView(
        child: isVineArchive
            ? _VineArchiveExplanation(video: video)
            : _ProofModeExplanation(video: video),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Close', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }

  Widget _buildTitle(bool isVineArchive) {
    return Row(
      children: [
        Icon(
          isVineArchive ? Icons.archive : Icons.verified_user,
          color: isVineArchive ? const Color(0xFF00BF8F) : Colors.blue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isVineArchive ? 'Original Vine Archive' : 'Video Verification',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Explanation content for archived Vine videos
class _VineArchiveExplanation extends StatelessWidget {
  const _VineArchiveExplanation({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This video is an original Vine recovered from the Internet Archive.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Before Vine shut down in 2017, ArchiveTeam and the Internet Archive worked to preserve millions of Vines for posterity. This content is part of that historic preservation effort.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        if (video.originalLoops != null && video.originalLoops! > 0) ...[
          Text(
            'Original stats: ${video.originalLoops} loops',
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: () async {
            final uri = Uri.parse('https://divine.video/dmca');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Learn more about the Vine archive preservation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Explanation content for ProofMode verified videos
class _ProofModeExplanation extends StatelessWidget {
  const _ProofModeExplanation({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This video\'s authenticity is verified using ProofMode technology.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _VerificationLevelCard(video: video),
        const SizedBox(height: 12),
        const Text(
          'ProofMode helps verify that videos are authentic and not AI-generated or manipulated.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final uri = Uri.parse('https://divine.video/proofmode');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Learn more about ProofMode verification',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Card showing verification level details with icon and description
class _VerificationLevelCard extends StatelessWidget {
  const _VerificationLevelCard({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final config = _getVerificationConfig(video);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(config.icon, size: 20, color: config.color),
            const SizedBox(width: 8),
            Text(
              config.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          config.description,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  _VerificationConfig _getVerificationConfig(VideoEvent video) {
    if (video.isVerifiedMobile) {
      return _VerificationConfig(
        icon: Icons.verified,
        color: Colors.green[700]!,
        title: 'Fully Verified',
        description:
            'This video has the highest level of proof - captured on a real device with hardware security verification. We can confirm it was recorded using Divine on an actual phone.',
      );
    } else if (video.isVerifiedWeb) {
      return _VerificationConfig(
        icon: Icons.shield_outlined,
        color: Colors.blue[700]!,
        title: 'Verified',
        description:
            'This video has cryptographic signatures proving it hasn\'t been altered since recording, but we can\'t verify the capture device.',
      );
    } else if (video.hasBasicProof) {
      return _VerificationConfig(
        icon: Icons.info_outline,
        color: Colors.orange[700]!,
        title: 'Basic Proof',
        description:
            'This video has minimal verification - just basic metadata signatures.',
      );
    } else {
      return _VerificationConfig(
        icon: Icons.shield_outlined,
        color: Colors.grey[600]!,
        title: 'Unverified',
        description:
            'We can\'t be sure this video is real and was recorded using Divine on a user\'s phone.',
      );
    }
  }
}

/// Configuration data for verification levels
class _VerificationConfig {
  const _VerificationConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}
