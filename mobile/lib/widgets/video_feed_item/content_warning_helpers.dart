// ABOUTME: Shared content warning overlay and label helpers.
// ABOUTME: Used by FeedVideos, PooledFullscreenVideoFeedScreen,
// ABOUTME: and the old VideoFeedItem.

import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_filter_service.dart';

/// Whether a video should be gated behind the full-screen content warning UI.
///
/// Only `warnLabels` should gate playback because they already reflect the
/// user's effective content-filter preference. Creator-applied
/// `contentWarningLabels` may still render a smaller badge when visible.
bool shouldShowContentWarningOverlay({
  required List<String> contentWarningLabels,
  required List<String> warnLabels,
}) => warnLabels.isNotEmpty;

/// Returns the labels that should be shown in the content warning overlay.
///
/// Prefer `warnLabels` when available because they already reflect the
/// matched categories for the user's current filter settings.
List<String> contentWarningOverlayLabels({
  required List<String> contentWarningLabels,
  required List<String> warnLabels,
}) => warnLabels.isNotEmpty ? warnLabels : contentWarningLabels;

/// Persist a "hide" preference for the provided content-warning labels.
Future<void> hideContentWarningsLikeThese({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> labels,
}) async {
  final service = ref.read(contentFilterServiceProvider);
  await service.initialize();

  final matchedLabels = labels
      .map(ContentLabel.fromValue)
      .whereType<ContentLabel>()
      .toSet();

  if (matchedLabels.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.contentWarningNoFilterYet)),
    );
    return;
  }

  for (final label in matchedLabels) {
    await service.setPreference(label, ContentFilterPreference.hide);
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.contentWarningHiddenConfirmation)),
  );
}

/// Full-screen content warning overlay with blur for videos with warn labels.
///
/// Shows a blurred backdrop with warning text, matched content labels,
/// and a "View Anyway" button to reveal the video.
class ContentWarningBlurOverlay extends StatelessWidget {
  const ContentWarningBlurOverlay({
    required this.labels,
    required this.onReveal,
    super.key,
    this.onHideSimilar,
  });

  final List<String> labels;
  final VoidCallback onReveal;
  final VoidCallback? onHideSimilar;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.backgroundColor.withValues(alpha: 0.6),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DivineIcon(
                    icon: DivineIconName.warning,
                    color: VineTheme.contentWarningAmber,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.contentWarningSensitiveContent,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels
                        .map((l) => humanizeContentLabel(context, l))
                        .join(', '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DivineButton(
                    label: context.l10n.contentWarningViewAnyway,
                    type: DivineButtonType.tertiary,
                    onPressed: onReveal,
                  ),
                  if (onHideSimilar != null) ...[
                    const SizedBox(height: 12),
                    DivineButton(
                      label: context.l10n.contentWarningHideAllLikeThis,
                      type: DivineButtonType.ghost,
                      onPressed: onHideSimilar,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Convert a NIP-32 content-warning label value to a localized
/// human-readable string.
String humanizeContentLabel(BuildContext context, String label) {
  final l10n = context.l10n;
  switch (label) {
    case 'nudity':
      return l10n.contentWarningNudity;
    case 'sexual':
      return l10n.contentWarningSexualContent;
    case 'porn':
      return l10n.contentWarningPornography;
    case 'graphic-media':
      return l10n.contentWarningGraphicMedia;
    case 'violence':
      return l10n.contentWarningViolence;
    case 'self-harm':
      return l10n.contentWarningSelfHarm;
    case 'drugs':
      return l10n.contentWarningDrugUse;
    case 'alcohol':
      return l10n.contentWarningAlcohol;
    case 'tobacco':
      return l10n.contentWarningTobacco;
    case 'gambling':
      return l10n.contentWarningGambling;
    case 'profanity':
      return l10n.contentWarningProfanity;
    case 'flashing-lights':
      return l10n.contentWarningFlashingLights;
    case 'ai-generated':
      return l10n.contentWarningAiGenerated;
    case 'spoiler':
      return l10n.contentWarningSpoiler;
    case 'content-warning':
      return l10n.contentWarningSensitiveContent;
    default:
      return l10n.contentWarningLabel;
  }
}
