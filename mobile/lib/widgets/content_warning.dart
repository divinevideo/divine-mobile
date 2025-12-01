// ABOUTME: Content warning overlay widget for potentially sensitive content
// ABOUTME: Provides user control over viewing filtered content with clear warnings

import 'package:flutter/material.dart';
import 'package:openvine/services/content_moderation_service.dart';

/// Content warning overlay for filtered content
class ContentWarning extends StatefulWidget {
  const ContentWarning({
    required this.child,
    required this.moderationResult,
    super.key,
    this.onReport,
    this.onBlock,
    this.showControls = true,
  });
  final Widget child;
  final ModerationResult moderationResult;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final bool showControls;

  @override
  State<ContentWarning> createState() => _ContentWarningState();
}

class _ContentWarningState extends State<ContentWarning>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If content is clean or user has revealed it, show normally
    if (!widget.moderationResult.shouldFilter || _isRevealed) {
      return widget.child;
    }

    // For blocked content, show permanent warning
    if (widget.moderationResult.severity == ContentSeverity.block) {
      return _buildBlockedContent(context);
    }

    // For hidden content, show warning overlay
    return _buildWarningOverlay(context);
  }

  Widget _buildWarningOverlay(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _getWarningColor(
        widget.moderationResult.severity,
      ).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _getWarningColor(widget.moderationResult.severity),
        width: 2,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Warning icon and title
        Row(
          children: [
            Icon(
              _getWarningIcon(widget.moderationResult.severity),
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getWarningTitle(widget.moderationResult.severity),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.moderationResult.warningMessage != null)
                    Text(
                      widget.moderationResult.warningMessage!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Filter reason chips
        if (widget.moderationResult.reasons.isNotEmpty)
          Wrap(
            spacing: 8,
            children: widget.moderationResult.reasons
                .map(
                  (reason) => Chip(
                    label: Text(
                      reason.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            // Show content button
            Expanded(
              child: OutlinedButton(
                onPressed: _revealContent,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('View Anyway'),
              ),
            ),

            if (widget.showControls) ...[
              const SizedBox(width: 12),

              // Report button
              if (widget.onReport != null)
                IconButton(
                  onPressed: widget.onReport,
                  icon: const Icon(Icons.flag_outlined),
                  color: Colors.white,
                  tooltip: 'Report Content',
                ),

              // Block button
              if (widget.onBlock != null)
                IconButton(
                  onPressed: widget.onBlock,
                  icon: const Icon(Icons.block_outlined),
                  color: Colors.white,
                  tooltip: 'Block User',
                ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _buildBlockedContent(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.red.shade800,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red, width: 2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.block, color: Colors.white, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Content Blocked',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.moderationResult.warningMessage != null)
          Text(
            widget.moderationResult.warningMessage!,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        Text(
          'This content has been blocked due to policy violations.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  void _revealContent() {
    setState(() {
      _isRevealed = true;
    });
    _animationController.forward();
  }

  Color _getWarningColor(ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return Colors.blue;
      case ContentSeverity.warning:
        return Colors.orange;
      case ContentSeverity.hide:
        return Colors.red.shade600;
      case ContentSeverity.block:
        return Colors.red.shade800;
    }
  }

  IconData _getWarningIcon(ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return Icons.info_outline;
      case ContentSeverity.warning:
        return Icons.warning_amber_outlined;
      case ContentSeverity.hide:
        return Icons.visibility_off_outlined;
      case ContentSeverity.block:
        return Icons.block;
    }
  }

  String _getWarningTitle(ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return 'Content Notice';
      case ContentSeverity.warning:
        return 'Sensitive Content';
      case ContentSeverity.hide:
        return 'Potentially Harmful Content';
      case ContentSeverity.block:
        return 'Content Blocked';
    }
  }
}

/// Quick content warning for less severe content
class QuickContentWarning extends StatelessWidget {
  const QuickContentWarning({
    required this.child,
    required this.warningText,
    super.key,
    this.icon = Icons.warning_amber_outlined,
    this.color = Colors.orange,
    this.onTap,
  });
  final Widget child;
  final String warningText;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned(
        top: 8,
        right: 8,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  warningText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// Content warning for video thumbnails
class VideoContentWarning extends StatefulWidget {
  const VideoContentWarning({
    required this.thumbnail,
    required this.moderationResult,
    super.key,
    this.onPlay,
    this.onReport,
  });
  final Widget thumbnail;
  final ModerationResult moderationResult;
  final VoidCallback? onPlay;
  final VoidCallback? onReport;

  @override
  State<VideoContentWarning> createState() => _VideoContentWarningState();
}

class _VideoContentWarningState extends State<VideoContentWarning> {
  bool _showWarning = true;

  @override
  void initState() {
    super.initState();
    _showWarning = widget.moderationResult.shouldFilter;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showWarning) {
      return widget.thumbnail;
    }

    return Stack(
      children: [
        // Blurred background
        ImageFiltered(
          imageFilter: widget.moderationResult.severity == ContentSeverity.block
              ? ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.8),
                  BlendMode.srcOver,
                )
              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
          child: widget.thumbnail,
        ),

        // Warning overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Sensitive Content',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (widget.moderationResult.severity !=
                        ContentSeverity.block)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showWarning = false;
                          });
                          widget.onPlay?.call();
                        },
                        child: const Text(
                          'View',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    if (widget.onReport != null)
                      TextButton(
                        onPressed: widget.onReport,
                        child: const Text(
                          'Report',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
