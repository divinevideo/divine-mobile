// ABOUTME: Shows upload failure sheets and publish-success snackbars app-wide
// ABOUTME: Split out of main.dart so the composition root can mount it (#3337)

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';
import 'package:openvine/features/post_publish/view/post_publish_confirmation_sheet.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/post_publish_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/upload_failure_sheet.dart';

/// Listens for background upload completions and shows the appropriate UI.
///
/// Uses [NavigatorKeys.root] to obtain a [BuildContext] inside the
/// [Navigator] tree, which [showModalBottomSheet] and [ScaffoldMessenger]
/// require.
///
/// **Failure tracking:** Tracks the set of currently-failed draft IDs so that
/// only *new* failures trigger a sheet. When a draft is retried or dismissed
/// its ID leaves the failed set, so a subsequent failure is detected as new.
///
/// **Success tracking (publish-flow continuity, #4626):** Reads
/// [BackgroundPublishState.recentlySucceededIds] — populated by the bloc only
/// on a true [PublishSuccess], never on [BackgroundPublishVanished] — so a
/// vanished upload cannot produce a false "published" snackbar. If the user is
/// not yet authenticated at the moment of success (mid re-auth redirect), the
/// count is buffered and shown once authentication is restored.
@visibleForTesting
class UploadFailureListener extends StatefulWidget {
  const UploadFailureListener({required this.child, super.key});

  final Widget child;

  @override
  State<UploadFailureListener> createState() => _UploadFailureListenerState();
}

class _UploadFailureListenerState extends State<UploadFailureListener> {
  var _lastKnownFailedIds = <String>{};
  var _lastKnownSucceededIds = <String>{};
  var _pendingSuccessCount = 0;
  PostPublishConfirmationOffer? _pendingConfirmationOffer;
  PublishedVideo? _pendingPublishedVideo;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackgroundPublishBloc, BackgroundPublishState>(
      listener: (context, state) {
        final container = ProviderScope.containerOf(context);
        final authService = container.read(authServiceProvider);

        // Use the bloc's own recentlyPublished so we never confuse a
        // BackgroundPublishVanished removal with a true publish success.
        final newlyPublished = state.recentlyPublished
            .where((video) => !_lastKnownSucceededIds.contains(video.draftId))
            .toList();
        _lastKnownSucceededIds = state.recentlySucceededIds;
        final succeededCount = newlyPublished.length;
        final confirmationOffer = container
            .read(postPublishExperimentProvider)
            .completed(newlyPublished.map((video) => video.draftId).toSet());
        // The confirmation navigates to and shares one video, so it only
        // applies when exactly one landed.
        final publishedVideo = succeededCount == 1
            ? newlyPublished.single
            : null;

        if (succeededCount > 0) {
          if (authService.isAuthenticated) {
            // Show immediately — user is still in-app. If the root navigator
            // context is unavailable the snackbar would be silently dropped,
            // so buffer it and replay once the context is ready.
            if (!_showPublishSuccess(
              succeededCount,
              offer: confirmationOffer,
              video: publishedVideo,
              container: container,
            )) {
              _pendingSuccessCount += succeededCount;
              _pendingConfirmationOffer ??= confirmationOffer;
              _pendingPublishedVideo ??= publishedVideo;
            }
          } else {
            // Buffer for when auth is restored after re-auth redirect.
            _pendingSuccessCount += succeededCount;
            _pendingConfirmationOffer ??= confirmationOffer;
            _pendingPublishedVideo ??= publishedVideo;
          }
        }

        final currentFailedIds = state.uploads
            .where((u) => u.result is PublishError)
            .map((u) => u.draft.id)
            .toSet();

        // Don't show failure sheets while the user is not authenticated
        // (e.g. still on the login screen after a cold start).
        // Also don't update _lastKnownFailedIds so these failures are
        // detected as "new" once the user eventually authenticates.
        if (!authService.isAuthenticated) {
          return;
        }

        // Auth is now confirmed — flush buffered successes from re-auth window.
        if (_pendingSuccessCount > 0 &&
            _showPublishSuccess(
              _pendingSuccessCount,
              offer: _pendingConfirmationOffer,
              video: _pendingPublishedVideo,
              container: container,
            )) {
          _pendingSuccessCount = 0;
          _pendingConfirmationOffer = null;
          _pendingPublishedVideo = null;
        }

        final newFailedIds = currentFailedIds.difference(_lastKnownFailedIds);
        container.read(postPublishExperimentProvider).failed(newFailedIds);
        _lastKnownFailedIds = currentFailedIds;

        if (newFailedIds.isEmpty) return;

        final navContext = NavigatorKeys.root.currentContext;
        if (navContext == null || !navContext.mounted) return;

        final newFailures = state.uploads
            .where((u) => newFailedIds.contains(u.draft.id))
            .toList();

        _showFailureSheetsSequentially(container, navContext, newFailures);
      },
      child: widget.child,
    );
  }
}

/// Confirms that [count] background uploads completed.
///
/// Returns `true` when something was shown.
///
/// A single video published by the treatment arm, while the user is still
/// standing on their own profile, gets the full confirmation sheet: a preview
/// plus View and Share. Everything else — the control arm, a batch, a video
/// with no `d` tag, or a user who has already navigated on — gets the plain
/// snackbar. A modal sheet is fine as a payoff for the screen you are looking
/// at and an ambush anywhere else, since the publish finishes in the
/// background and can land minutes later.
///
/// Uses [NavigatorKeys.root] to resolve both localization and
/// [ScaffoldMessenger] from inside the app tree. The listener itself is mounted
/// above [MaterialApp], so its own [BuildContext] does not have localization or
/// scaffold ancestors in production — reading l10n from it is what threw the
/// null check in #7289 before the root context was adopted.
///
/// Both ancestors are resolved nullably: `mounted` only says the element still
/// exists, not that it can still reach its inherited ancestors — a deactivated
/// element reports `mounted` while every ancestor lookup returns null. Failing
/// closed here hands the count back to the caller's buffer/replay path instead
/// of throwing out of the bloc listener.
bool _showPublishSuccess(
  int count, {
  required ProviderContainer container,
  PostPublishConfirmationOffer? offer,
  PublishedVideo? video,
}) {
  final navContext = NavigatorKeys.root.currentContext;
  if (navContext == null || !navContext.mounted) return false;
  final l10n = Localizations.of<AppLocalizations>(navContext, AppLocalizations);
  final messenger = ScaffoldMessenger.maybeOf(navContext);
  if (l10n == null || messenger == null) return false;

  final stableId = video?.stableId;
  // Router state is consulted last so the control arm never builds it.
  if (count == 1 &&
      offer != null &&
      stableId != null &&
      _isOnOwnProfile(container)) {
    unawaited(
      PostPublishConfirmationSheet.show(
        context: navContext,
        thumbnailBytes: video!.thumbnailBytes,
        onView: () => _onConfirmationView(container, offer, stableId),
        onShare: () =>
            _onConfirmationShare(navContext, container, offer, stableId),
      ),
    );
    return true;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        l10n.uploadPublishedCountMessage(count),
        style: VineTheme.bodyMediumFont(color: navContext.vineColors.onNav),
      ),
      backgroundColor: navContext.vineColors.nav,
      behavior: SnackBarBehavior.floating,
    ),
  );
  return true;
}

/// Whether the router is currently showing the signed-in user's own profile.
bool _isOnOwnProfile(ProviderContainer container) {
  final pubkeyHex = container.read(authServiceProvider).currentPublicKeyHex;
  if (pubkeyHex == null) return false;
  // Same primitive routerLocationStreamProvider reads, and unlike
  // routerDelegate.currentConfiguration it cannot assert on an empty stack.
  final location = container
      .read(goRouterProvider)
      .routeInformationProvider
      .value
      .uri;
  return isOwnProfileLocation(location.path, pubkeyHex);
}

void _onConfirmationView(
  ProviderContainer container,
  PostPublishConfirmationOffer offer,
  String stableId,
) {
  unawaited(container.read(postPublishExperimentProvider).viewTapped(offer));
  // Push, not go: closing the video has to pop back to the profile the
  // creator was standing on rather than resetting to the feed.
  unawaited(
    container
        .read(goRouterProvider)
        .push<void>(RoutePaths.videoDetailForId(stableId)),
  );
}

void _onConfirmationShare(
  BuildContext context,
  ProviderContainer container,
  PostPublishConfirmationOffer offer,
  String stableId,
) {
  unawaited(container.read(postPublishExperimentProvider).shareTapped(offer));
  // The platform sheet rather than the in-app one: that needs a hydrated
  // VideoEvent, and seconds after publish the event is often not yet
  // resolvable from Funnelcake or any relay. The rich sheet stays one tap
  // away on the video detail screen.
  unawaited(
    showShareSheet(
      context,
      ShareParams(text: VideoSharingService.shareUrlForStableId(stableId)),
    ),
  );
}

/// Shows failure bottom sheets one after another for each failed upload.
Future<void> _showFailureSheetsSequentially(
  ProviderContainer container,
  BuildContext context,
  List<BackgroundUpload> failedUploads,
) async {
  for (final upload in failedUploads) {
    if (!context.mounted) return;
    if (upload.result case PublishError(
      kind: PublishErrorKind.accountRestricted,
    )) {
      refreshAccountEnforcementAfterRestriction(container);
    }
    await showUploadFailureSheet(context, upload);
  }
}
