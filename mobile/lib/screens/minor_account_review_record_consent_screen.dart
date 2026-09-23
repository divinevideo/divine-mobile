// ABOUTME: In-app parent-consent capture screen. Records a guided consent
// ABOUTME: video, lets the parent review or retake it, and falls back to email.

import 'dart:async';

import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_capture_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permissions_service/permissions_service.dart';

/// Records the parent-consent video in-app, then lets the parent review it.
///
/// This is the primary consent path; the email route on
/// [MinorAccountReviewParentConsentScreen] stays available as a fallback.
class MinorAccountReviewRecordConsentScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'minor-account-review-record-consent';

  /// Path for this route.
  static const String path = RoutePaths.minorAccountReviewConsentRecord;

  /// Creates the capture screen.
  const MinorAccountReviewRecordConsentScreen({super.key, this.onUseVideo});

  /// Called with the recorded clip's path when the parent accepts it.
  ///
  /// Submission is wired by the following task; leaving it null keeps the
  /// review screen renderable on its own.
  final ValueChanged<String>? onUseVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch (not read) so the auto-disposed recorder stays alive for this
    // screen's lifetime and is released when the screen unmounts.
    final recorder = ref.watch(minorConsentRecorderProvider);
    return BlocProvider(
      create: (_) => MinorConsentCaptureCubit(recorder: recorder),
      child: _RecordConsentView(onUseVideo: onUseVideo),
    );
  }
}

class _RecordConsentView extends ConsumerStatefulWidget {
  const _RecordConsentView({this.onUseVideo});

  final ValueChanged<String>? onUseVideo;

  @override
  ConsumerState<_RecordConsentView> createState() => _RecordConsentViewState();
}

class _RecordConsentViewState extends ConsumerState<_RecordConsentView> {
  bool _cameraReady = false;
  bool _accessDenied = false;
  String? _pendingVideoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCamera());
  }

  /// Requests camera and microphone access, then initializes the preview.
  ///
  /// A refusal lands the screen on the email fallback rather than a dead end.
  Future<void> _prepareCamera() async {
    final permissions = ref.read(permissionsServiceProvider);
    final allowed = await _ensureAccess(permissions);
    if (!mounted) return;
    if (!allowed) {
      setState(() => _accessDenied = true);
      return;
    }
    try {
      await context.read<MinorConsentCaptureCubit>().initialize();
    } catch (_) {
      if (!mounted) return;
      setState(() => _accessDenied = true);
      return;
    }
    if (!mounted) return;
    setState(() => _cameraReady = true);
  }

  Future<bool> _ensureAccess(PermissionsService permissions) async {
    final camera = await permissions.checkCameraStatus();
    final cameraGranted =
        camera == PermissionStatus.granted ||
        await permissions.requestCameraPermission() == PermissionStatus.granted;
    if (!cameraGranted) return false;

    final microphone = await permissions.checkMicrophoneStatus();
    return microphone == PermissionStatus.granted ||
        await permissions.requestMicrophonePermission() ==
            PermissionStatus.granted;
  }

  Future<void> _onRecord() async {
    final outputDirectory = (await getTemporaryDirectory()).path;
    if (!mounted) return;
    await context.read<MinorConsentCaptureCubit>().start(
      outputDirectory: outputDirectory,
    );
  }

  Future<void> _onStop() async {
    await context.read<MinorConsentCaptureCubit>().stop();
  }

  void _onRetake() => context.read<MinorConsentCaptureCubit>().retake();

  void _onUseVideo(String filePath) {
    final callback = widget.onUseVideo;
    if (callback != null) {
      callback(filePath);
      return;
    }
    // No injected seam: this screen owns the confirm-and-submit step. Release
    // the camera as soon as the clip is accepted — the file stays usable for
    // upload while the parent confirms their email — then swap the view.
    unawaited(_acceptVideo(filePath));
  }

  Future<void> _acceptVideo(String filePath) async {
    await context.read<MinorConsentCaptureCubit>().releaseRecorder();
    if (!mounted) return;
    setState(() => _pendingVideoPath = filePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.minorAccountReviewRecordConsentTitle,
        showBackButton: true,
      ),
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _pendingVideoPath != null
                ? MinorConsentSubmitView(
                    videoPath: _pendingVideoPath!,
                    onUseEmailFallback: () => context.push(
                      MinorAccountReviewParentConsentScreen.path,
                    ),
                  )
                : BlocBuilder<
                    MinorConsentCaptureCubit,
                    MinorConsentCaptureState
                  >(
                    builder: (context, state) {
                      return switch (state) {
                        MinorConsentCaptureIdle() =>
                          _accessDenied
                              ? const _DeniedPane()
                              : _CapturePane(
                                  cameraReady: _cameraReady,
                                  onRecord: _onRecord,
                                ),
                        MinorConsentCaptureRecording() => _RecordingPane(
                          cameraReady: _cameraReady,
                          onStop: _onStop,
                        ),
                        MinorConsentCaptureReview(:final filePath) =>
                          _ReviewPane(
                            filePath: filePath,
                            onRetake: _onRetake,
                            onUseVideo: () => _onUseVideo(filePath),
                          ),
                        MinorConsentCaptureDenied() => const _DeniedPane(),
                        MinorConsentCaptureError() => _ErrorPane(
                          onRetry: _onRetake,
                        ),
                      };
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Confirm-and-submit step for the in-app parent-consent flow.
///
/// Shows the accepted clip's parent email field, submits it with the local
/// video via [MinorAccountReviewRepository.submitParentConsent], and swaps to
/// the receipt view on success. A failure keeps [videoPath] intact, leaves the
/// submit control in place as a retry, and keeps the email fallback visible.
class MinorConsentSubmitView extends ConsumerStatefulWidget {
  /// Creates the confirm-and-submit step for [videoPath].
  const MinorConsentSubmitView({
    required this.videoPath,
    required this.onUseEmailFallback,
    super.key,
  });

  /// Local path of the accepted consent clip.
  final String videoPath;

  /// Invoked when the parent chooses the email / private-link fallback.
  final VoidCallback onUseEmailFallback;

  @override
  ConsumerState<MinorConsentSubmitView> createState() =>
      _MinorConsentSubmitViewState();
}

class _MinorConsentSubmitViewState
    extends ConsumerState<MinorConsentSubmitView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _submittedEmail;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit(String caseId) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (kDebugMode) {
        final overrideService = ref.read(
          minorAccountReviewOverrideServiceProvider,
        );
        final localOverride = overrideService.getOverride();
        if (localOverride?.currentCase?.id == caseId) {
          await overrideService.setOverride(
            localOverride!.copyWith(
              currentCase: localOverride.currentCase!.copyWith(
                state: MinorReviewCaseState.submittedForReview,
                instructions: MinorReviewInstructions(
                  title: context.l10n.minorAccountReviewSubmissionReceivedTitle,
                  body: context
                      .l10n
                      .minorAccountReviewSubmissionReceivedLocalBody,
                ),
              ),
            ),
          );
        } else {
          await ref
              .read(minorAccountReviewRepositoryProvider)
              .submitParentConsent(
                caseId: caseId,
                email: email,
                videoPath: widget.videoPath,
              );
        }
      } else {
        await ref
            .read(minorAccountReviewRepositoryProvider)
            .submitParentConsent(
              caseId: caseId,
              email: email,
              videoPath: widget.videoPath,
            );
      }
      ref.invalidate(currentMinorAccountReviewStatusProvider);
      ref.invalidate(protectedMinorStatusProvider);
      if (!mounted) return;
      setState(() => _submittedEmail = email);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.l10n.minorAccountReviewRecordConsentSubmitError;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final submittedEmail = _submittedEmail;
    if (submittedEmail != null) {
      return _SubmitSuccessPane(email: submittedEmail);
    }

    final caseId = ref
        .watch(currentMinorAccountReviewStatusProvider)
        .value
        ?.currentCase
        ?.id;
    final validationMessages = AuthValidationMessages.fromL10n(l10n);

    return _Pane(
      children: [
        Text(
          l10n.minorAccountReviewRecordConsentConfirmEmailTitle,
          style: VineTheme.headlineSmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: DivineAuthTextField(
            label: l10n.minorAccountReviewParentContactFieldLabel,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (value) => Validators.validateEmail(
              value,
              messages: validationMessages,
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: VineTheme.bodyMediumFont(color: VineTheme.error),
          ),
        ],
        const SizedBox(height: 24),
        DivineButton(
          label: _isSubmitting
              ? l10n.minorAccountReviewSubmitting
              : l10n.minorAccountReviewRecordConsentSubmitCta,
          expanded: true,
          onPressed: (_isSubmitting || caseId == null)
              ? null
              : () => _submit(caseId),
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: l10n.minorAccountReviewRecordConsentEmailInsteadCta,
          type: DivineButtonType.secondary,
          expanded: true,
          onPressed: _isSubmitting ? null : widget.onUseEmailFallback,
        ),
      ],
    );
  }
}

/// Receipt shown once the consent video has been submitted.
class _SubmitSuccessPane extends StatelessWidget {
  const _SubmitSuccessPane({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        Text(
          context.l10n.minorAccountReviewSubmissionReceivedTitle,
          style: VineTheme.headlineMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.minorAccountReviewSubmissionReceivedBody(email),
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
      ],
    );
  }
}

/// Shared page frame: scrollable column with consistent padding.
class _Pane extends StatelessWidget {
  const _Pane({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: children,
    );
  }
}

/// Idle state: live preview, the prompt card, and the record control.
class _CapturePane extends StatelessWidget {
  const _CapturePane({required this.cameraReady, required this.onRecord});

  final bool cameraReady;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        _CameraPreview(ready: cameraReady),
        const SizedBox(height: 20),
        Text(
          context.l10n.minorAccountReviewRecordConsentBody,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        const SizedBox(height: 16),
        _PromptCard(
          title: context.l10n.minorAccountReviewRecordConsentPromptTitle,
          items: [
            context.l10n.minorAccountReviewParentConsentChecklistKid,
            context.l10n.minorAccountReviewParentConsentChecklistPermission,
            context.l10n.minorAccountReviewParentConsentChecklistAgeBand,
            context.l10n.minorAccountReviewParentConsentChecklistSupervision,
          ],
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: context.l10n.minorAccountReviewRecordConsentRecordCta,
          leadingIcon: DivineIconName.videoCamera,
          expanded: true,
          onPressed: cameraReady ? onRecord : null,
        ),
      ],
    );
  }
}

/// Recording state: live preview plus the stop control.
class _RecordingPane extends StatelessWidget {
  const _RecordingPane({required this.cameraReady, required this.onStop});

  final bool cameraReady;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        _CameraPreview(ready: cameraReady),
        const SizedBox(height: 24),
        DivineButton(
          label: context.l10n.minorAccountReviewRecordConsentStopCta,
          expanded: true,
          onPressed: onStop,
        ),
      ],
    );
  }
}

/// Review state: play back the clip, then retake or accept it.
class _ReviewPane extends StatelessWidget {
  const _ReviewPane({
    required this.filePath,
    required this.onRetake,
    required this.onUseVideo,
  });

  final String filePath;
  final VoidCallback onRetake;
  final VoidCallback onUseVideo;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        _ClipPlayback(filePath: filePath),
        const SizedBox(height: 20),
        Text(
          context.l10n.minorAccountReviewRecordConsentReviewTitle,
          style: VineTheme.headlineSmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.minorAccountReviewRecordConsentReviewBody,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: context.l10n.minorAccountReviewRecordConsentUseVideoCta,
          expanded: true,
          onPressed: onUseVideo,
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: context.l10n.minorAccountReviewRecordConsentRetakeCta,
          type: DivineButtonType.secondary,
          expanded: true,
          onPressed: onRetake,
        ),
      ],
    );
  }
}

/// Camera unavailable or refused: explain and route to the email fallback.
class _DeniedPane extends StatelessWidget {
  const _DeniedPane();

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        _MessageCard(
          title: context.l10n.minorAccountReviewRecordConsentDeniedTitle,
          body: context.l10n.minorAccountReviewRecordConsentDeniedBody,
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: context.l10n.minorAccountReviewRecordConsentEmailInsteadCta,
          leadingIcon: DivineIconName.envelope,
          expanded: true,
          onPressed: () =>
              context.push(MinorAccountReviewParentConsentScreen.path),
        ),
      ],
    );
  }
}

/// Recording stopped without a file: offer a retry that keeps the flow alive.
class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        _MessageCard(
          title: context.l10n.minorAccountReviewRecordConsentErrorTitle,
          body: context.l10n.minorAccountReviewRecordConsentErrorBody,
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: context.l10n.minorAccountReviewRecordConsentTryAgainCta,
          expanded: true,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

/// Live camera viewfinder, reusing the shared [CameraPreviewWidget].
///
/// The recorder wraps the same `DivineCamera` singleton this widget renders,
/// so the frames shown here are the ones being recorded.
class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.minorAccountReviewRecordConsentPreviewLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 320,
          width: double.infinity,
          child: ready
              ? const CameraPreviewWidget(fit: BoxFit.cover)
              : ColoredBox(color: context.vineColors.surfaceContainerHigh),
        ),
      ),
    );
  }
}

/// Plays back the just-recorded local clip.
class _ClipPlayback extends StatefulWidget {
  const _ClipPlayback({required this.filePath});

  final String filePath;

  @override
  State<_ClipPlayback> createState() => _ClipPlaybackState();
}

class _ClipPlaybackState extends State<_ClipPlayback> {
  late final DivineVideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = DivineVideoPlayerController();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _controller.initialize();
      await _controller.setSource(VideoClip.file(widget.filePath));
      await _controller.play();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 320,
        width: double.infinity,
        child: ColoredBox(
          color: context.vineColors.surfaceContainerHigh,
          child: _ready
              ? DivineVideoPlayer(controller: _controller)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The on-screen prompt the parent reads aloud or shows to the camera.
class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: ExcludeSemantics(
                      child: DivineIcon(
                        icon: DivineIconName.checkCircle,
                        size: 16,
                        color: VineTheme.vineGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Title-and-body card used by the denied and error states.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
