// ABOUTME: Content warning overlay widget for potentially sensitive content
// ABOUTME: Provides user control over viewing filtered content with clear warnings

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/content_moderation_types.dart';

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

  Widget _buildWarningOverlay(BuildContext context) {
    final warningDetails = _warningDetails(context);

    return Container(
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
          Row(
            children: [
              DivineIcon(
                icon: _getWarningIcon(widget.moderationResult.severity),
                color: context.vineColors.primaryText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getWarningTitle(
                        context,
                        widget.moderationResult.severity,
                      ),
                      style: TextStyle(
                        color: context.vineColors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (warningDetails != null)
                      Text(
                        warningDetails,
                        style: TextStyle(
                          color: context.vineColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.moderationResult.reasons.isNotEmpty)
            Wrap(
              spacing: 8,
              children: widget.moderationResult.reasons
                  .map(
                    (reason) => Chip(
                      label: Text(
                        context.l10n.reportReasonTitle(reason),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: context.vineColors.onSurface.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _revealContent,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.vineColors.primaryText,
                    side: BorderSide(color: context.vineColors.primaryText),
                  ),
                  child: Text(context.l10n.contentWarningViewAnyway),
                ),
              ),
              if (widget.showControls) ...[
                const SizedBox(width: 12),
                if (widget.onReport != null)
                  IconButton(
                    onPressed: widget.onReport,
                    icon: DivineIcon(
                      icon: DivineIconName.flag,
                      color: context.vineColors.primaryText,
                    ),
                    tooltip: context.l10n.contentWarningReportContentTooltip,
                  ),
                if (widget.onBlock != null)
                  IconButton(
                    onPressed: widget.onBlock,
                    icon: DivineIcon(
                      icon: DivineIconName.prohibit,
                      color: context.vineColors.primaryText,
                    ),
                    tooltip: context.l10n.contentWarningBlockUserTooltip,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedContent(BuildContext context) {
    final warningDetails = _warningDetails(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.vineColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.error, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DivineIcon(
            icon: DivineIconName.prohibit,
            color: context.vineColors.primaryText,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.contentWarningBlockedTitle,
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (warningDetails != null)
            Text(
              warningDetails,
              style: TextStyle(
                color: context.vineColors.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          Text(
            context.l10n.contentWarningBlockedPolicy,
            style: TextStyle(
              color: context.vineColors.onSurfaceVariant,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String? _warningDetails(BuildContext context) {
    final warningMessage = widget.moderationResult.warningMessage;
    if (warningMessage != null) {
      return warningMessage;
    }

    final reasons = widget.moderationResult.reasons;
    if (reasons.isNotEmpty) {
      return context.l10n.reportReasonSubtitle(reasons.first);
    }
    return null;
  }

  void _revealContent() {
    setState(() {
      _isRevealed = true;
    });
    _animationController.forward();
  }

  Color _getWarningColor(ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return VineTheme.info;
      case ContentSeverity.warning:
        return VineTheme.warning;
      case ContentSeverity.hide:
        return VineTheme.error;
      case ContentSeverity.block:
        return context.vineColors.errorContainer;
    }
  }

  DivineIconName _getWarningIcon(ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return DivineIconName.info;
      case ContentSeverity.warning:
        return DivineIconName.warning;
      case ContentSeverity.hide:
        return DivineIconName.eyeSlash;
      case ContentSeverity.block:
        return DivineIconName.prohibit;
    }
  }

  String _getWarningTitle(BuildContext context, ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return context.l10n.contentWarningNoticeTitle;
      case ContentSeverity.warning:
        return context.l10n.contentWarningSensitiveContent;
      case ContentSeverity.hide:
        return context.l10n.contentWarningPotentiallyHarmfulTitle;
      case ContentSeverity.block:
        return context.l10n.contentWarningBlockedTitle;
    }
  }
}

/// Quick content warning for less severe content
class QuickContentWarning extends StatelessWidget {
  const QuickContentWarning({
    required this.child,
    required this.warningText,
    super.key,
    this.icon = DivineIconName.warning,
    this.color = VineTheme.warning,
    this.onTap,
  });
  final Widget child;
  final String warningText;
  final DivineIconName icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      PositionedDirectional(
        top: 8,
        end: 8,
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
                DivineIcon(
                  icon: icon,
                  color: context.vineColors.primaryText,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  warningText,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
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
                  VineTheme.backgroundColor.withValues(alpha: 0.8),
                  BlendMode.srcOver,
                )
              : const ColorFilter.mode(
                  VineTheme.transparent,
                  BlendMode.multiply,
                ),
          child: widget.thumbnail,
        ),

        // Warning overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.backgroundColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DivineIcon(
                  icon: DivineIconName.warning,
                  color: VineTheme.primaryText,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.contentWarningSensitiveContent,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
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
                        child: Text(
                          context.l10n.contentWarningView,
                          style: TextStyle(
                            color: context.vineColors.primaryText,
                          ),
                        ),
                      ),
                    if (widget.onReport != null)
                      TextButton(
                        onPressed: widget.onReport,
                        child: Text(
                          context.l10n.contentWarningReportAction,
                          style: const TextStyle(color: VineTheme.error),
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
