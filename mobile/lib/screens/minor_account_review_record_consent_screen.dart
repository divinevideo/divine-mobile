// ABOUTME: In-app parent-consent capture screen. Records a guided consent
// ABOUTME: video, lets the parent review or retake it, and falls back to email.

import 'dart:async';

import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_capture_cubit.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_flow_cubit.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_playback_cubit.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_submit_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/consent_camera_lifecycle.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/minor_account_review_routes.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/minor_account_review_checklist_card.dart';

/// Player boundary for the recorded consent preview.
final minorConsentPreviewControllerProvider =
    Provider<DivineVideoPlayerController Function()>(
      (ref) => DivineVideoPlayerController.new,
    );

/// Records the parent-consent video in-app, then lets the parent review it.
///
/// Reachable only while `FeatureFlag.minorConsentInAppRecording` is on; the
/// email route on [MinorAccountReviewParentConsentScreen] stays available as a
/// fallback either way.
class MinorAccountReviewRecordConsentScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'minor-account-review-record-consent';

  /// Path for this route.
  static const String path = RoutePaths.minorAccountReviewConsentRecord;

  /// Creates the capture screen.
  const MinorAccountReviewRecordConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch (not read) so the auto-disposed recorder stays alive for this
    // screen's lifetime and is released when the screen unmounts.
    final recorder = ref.watch(minorConsentRecorderProvider);
    final permissions = ref.watch(permissionsServiceProvider);
    final setWakelock = ref.watch(minorConsentWakelockProvider);
    final deleteClip = ref.watch(minorConsentDeleteClipProvider);
    return MultiBlocProvider(
      key: ValueKey(recorder),
      providers: [
        BlocProvider(
          key: ValueKey(permissions),
          create: (_) => CameraPermissionBloc(
            permissionsService: permissions,
            requestGalleryPermission: false,
          ),
        ),
        BlocProvider(
          key: ValueKey((recorder, setWakelock)),
          create: (_) => MinorConsentCaptureCubit(
            deleteClip: deleteClip,
            recorder: recorder,
            setWakelock: setWakelock,
          ),
        ),
        BlocProvider(
          create: (context) => MinorConsentFlowCubit(
            initializeCamera: context
                .read<MinorConsentCaptureCubit>()
                .initialize,
            releaseCamera: context
                .read<MinorConsentCaptureCubit>()
                .releaseRecorder,
            deleteClip: deleteClip,
            refreshPermissions: () => context.read<CameraPermissionBloc>().add(
              const CameraPermissionRefresh(),
            ),
            requestPermissions: () => context.read<CameraPermissionBloc>().add(
              const CameraPermissionRequest(),
            ),
          ),
        ),
      ],
      child: const _RecordConsentView(),
    );
  }
}

class _RecordConsentView extends ConsumerStatefulWidget {
  const _RecordConsentView();

  @override
  ConsumerState<_RecordConsentView> createState() => _RecordConsentViewState();
}

class _RecordConsentViewState extends ConsumerState<_RecordConsentView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CameraPermissionBloc>().add(
          const CameraPermissionRefresh(),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final flow = context.read<MinorConsentFlowCubit>();
    if (flow.state.cameraReady) {
      unawaited(
        context.read<MinorConsentCaptureCubit>().handleAppLifecycleState(
          ConsentCameraLifecycle.values.byName(state.name),
        ),
      );
    }
    flow.visibilityChanged(
      background:
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden,
      resumed: state == AppLifecycleState.resumed,
    );
  }

  void _onPermissionState(CameraPermissionState state) {
    final permission = switch (state) {
      CameraPermissionLoaded(:final status) => switch (status) {
        CameraPermissionStatus.authorized => ConsentPermission.authorized,
        CameraPermissionStatus.canRequest => ConsentPermission.canRequest,
        CameraPermissionStatus.requiresSettings =>
          ConsentPermission.requiresSettings,
      },
      CameraPermissionError() => ConsentPermission.error,
      _ => ConsentPermission.loading,
    };
    context.read<MinorConsentFlowCubit>().permissionChanged(permission);
  }

  void _retryPermissions() {
    final state = context.read<CameraPermissionBloc>().state;
    context.read<MinorConsentFlowCubit>().retryPermissions(
      canRequest:
          state is CameraPermissionLoaded &&
          state.status == CameraPermissionStatus.canRequest,
    );
  }

  void _openSettings() => context.read<CameraPermissionBloc>().add(
    const CameraPermissionOpenSettings(),
  );

  Future<void> _onRecord() async {
    try {
      final directory = await ref.read(minorConsentOutputDirectoryProvider)();
      if (!mounted) return;
      await context.read<MinorConsentCaptureCubit>().start(
        outputDirectory: directory,
      );
    } catch (_) {
      if (mounted) context.read<MinorConsentCaptureCubit>().fail();
    }
  }

  Future<void> _retakeSubmission() async {
    // Release the old native owner before invalidation constructs its successor.
    await ref.read(minorConsentRecorderProvider).dispose();
    if (mounted) ref.invalidate(minorConsentRecorderProvider);
  }

  Future<void> _onStop() => context.read<MinorConsentCaptureCubit>().stop();
  void _onRetake() => context.read<MinorConsentCaptureCubit>().retake();
  void _onUseVideo(String path) =>
      unawaited(context.read<MinorConsentFlowCubit>().accept(path));

  void _onUseEmailFallback() {
    if (context.canPop()) {
      context.pop();
    } else {
      const MinorAccountReviewParentConsentRouteData().pushReplacement(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<MinorConsentFlowCubit>().state;
    return BlocListener<CameraPermissionBloc, CameraPermissionState>(
      listener: (context, state) => _onPermissionState(state),
      child: Scaffold(
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
              child: flow.accepted && flow.videoPath != null
                  ? MinorConsentSubmitView(
                      videoPath: flow.videoPath!,
                      onUseEmailFallback: _onUseEmailFallback,
                      onRetake: () => unawaited(_retakeSubmission()),
                      onUploadStarted: context
                          .read<MinorConsentFlowCubit>()
                          .uploadStarted,
                      onUploadFinished: context
                          .read<MinorConsentFlowCubit>()
                          .uploadFinished,
                    )
                  : BlocListener<
                      MinorConsentCaptureCubit,
                      MinorConsentCaptureState
                    >(
                      listenWhen: (_, current) =>
                          current is MinorConsentCaptureReview,
                      listener: (context, state) {
                        if (state is MinorConsentCaptureReview) {
                          context.read<MinorConsentFlowCubit>().recorded(
                            state.filePath,
                          );
                        }
                      },
                      child:
                          BlocBuilder<
                            MinorConsentCaptureCubit,
                            MinorConsentCaptureState
                          >(
                            builder: (context, state) {
                              return switch (state) {
                                MinorConsentCaptureIdle() =>
                                  flow.accessDenied
                                      ? _DeniedPane(
                                          onUseEmailFallback:
                                              _onUseEmailFallback,
                                          onRetry: flow.requiresSettings
                                              ? null
                                              : _retryPermissions,
                                          onOpenSettings: flow.requiresSettings
                                              ? _openSettings
                                              : null,
                                        )
                                      : _CapturePane(
                                          cameraReady: flow.cameraReady,
                                          onRecord: _onRecord,
                                        ),
                                MinorConsentCaptureRecording() =>
                                  _RecordingPane(
                                    cameraReady: flow.cameraReady,
                                    onStop: _onStop,
                                  ),
                                MinorConsentCaptureReview(:final filePath) =>
                                  _ReviewPane(
                                    filePath: filePath,
                                    onRetake: _onRetake,
                                    onUseVideo: () => _onUseVideo(filePath),
                                  ),
                                MinorConsentCaptureDenied() => _DeniedPane(
                                  onUseEmailFallback: _onUseEmailFallback,
                                ),
                                MinorConsentCaptureError() => _ErrorPane(
                                  onRetry: _onRetake,
                                ),
                              };
                            },
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirm-and-submit step for the in-app parent-consent flow.
///
/// Owns the [MinorConsentSubmitCubit] that performs the upload; the form below
/// only renders its state. A failure keeps [videoPath] intact, leaves the
/// submit control in place as a retry, and keeps the email fallback visible.
class MinorConsentSubmitView extends ConsumerWidget {
  /// Creates the confirm-and-submit step for [videoPath].
  const MinorConsentSubmitView({
    required this.videoPath,
    required this.onUseEmailFallback,
    this.onRetake,
    this.onUploadStarted,
    this.onUploadFinished,
    super.key,
  });

  /// Local path of the accepted consent clip.
  final String videoPath;

  /// Invoked when the parent chooses the email / private-link fallback.
  final VoidCallback onUseEmailFallback;

  /// Called when the consent upload starts, before any await.
  final VoidCallback? onRetake;

  final VoidCallback? onUploadStarted;

  /// Called once the consent upload has returned, success or failure.
  final VoidCallback? onUploadFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, and keyed on identity, so an account switch that rebuilds the
    // repository replaces the cubit rather than leaving it on the old one.
    final repository = ref.watch(minorAccountReviewRepositoryProvider);
    // The upload can outlive this widget: the parent may leave while it is in
    // flight. A WidgetRef throws once its widget unmounts, so the refresh goes
    // through the container, which lives as long as the app's ProviderScope.
    final container = ProviderScope.containerOf(context, listen: false);
    return BlocProvider<MinorConsentSubmitCubit>(
      key: ValueKey(repository),
      create: (_) => MinorConsentSubmitCubit(
        submission: ParentConsentSubmission(),
        repository: repository,
        onSubmitted: () {
          container
            ..invalidate(currentMinorAccountReviewStatusProvider)
            ..invalidate(protectedMinorStatusProvider);
        },
        onUploadStarted: onUploadStarted,
        onUploadFinished: onUploadFinished,
      ),
      child: _MinorConsentSubmitForm(
        videoPath: videoPath,
        onUseEmailFallback: onUseEmailFallback,
        onRetake: onRetake,
      ),
    );
  }
}

class _MinorConsentSubmitForm extends ConsumerStatefulWidget {
  const _MinorConsentSubmitForm({
    required this.videoPath,
    required this.onUseEmailFallback,
    this.onRetake,
  });

  final VoidCallback? onRetake;
  final String videoPath;
  final VoidCallback onUseEmailFallback;

  @override
  ConsumerState<_MinorConsentSubmitForm> createState() =>
      _MinorConsentSubmitFormState();
}

class _MinorConsentSubmitFormState
    extends ConsumerState<_MinorConsentSubmitForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit(String? caseId) {
    if (!_formKey.currentState!.validate()) return;
    unawaited(
      context.read<MinorConsentSubmitCubit>().submit(
        caseId: caseId,
        email: _emailController.text.trim(),
        videoPath: widget.videoPath,
        // Only read when a developer override is simulating this case; the
        // repository decides, so the copy is resolved here where l10n lives.
        localReceipt: MinorReviewInstructions(
          title: context.l10n.minorAccountReviewVideoSubmittedTitle,
          body: context.l10n.minorAccountReviewVideoSubmittedBody,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<MinorConsentSubmitCubit>().state;
    if (state.submittedEmail != null) {
      return const _SubmitSuccessPane();
    }

    final isSubmitting = state.status == MinorConsentSubmitStatus.submitting;
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
            enabled: state.canEditEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(caseId),
            validator: (value) => Validators.validateEmail(
              value,
              messages: validationMessages,
            ),
          ),
        ),
        if (state.status == MinorConsentSubmitStatus.failure) ...[
          const SizedBox(height: 12),
          Text(
            state.rejectionStatus == null
                ? l10n.minorAccountReviewRecordConsentSubmitError
                : l10n.minorAccountReviewRecordConsentRejected,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onErrorContainer,
            ),
          ),
        ],
        const SizedBox(height: 24),
        DivineButton(
          label: isSubmitting
              ? l10n.minorAccountReviewSubmitting
              : l10n.minorAccountReviewRecordConsentSubmitCta,
          expanded: true,
          onPressed:
              isSubmitting ||
                  state.rejectionStatus == 413 ||
                  state.rejectionStatus == 415
              ? null
              : () => _submit(caseId),
        ),
        if (state.rejectionStatus != null && widget.onRetake != null) ...[
          const SizedBox(height: 12),
          DivineButton(
            label: l10n.minorAccountReviewRecordConsentRetakeCta,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: widget.onRetake,
          ),
        ],
        const SizedBox(height: 12),
        DivineButton(
          label: l10n.minorAccountReviewRecordConsentEmailInsteadCta,
          type: DivineButtonType.secondary,
          expanded: true,
          onPressed: isSubmitting ? null : widget.onUseEmailFallback,
        ),
      ],
    );
  }
}

/// Receipt shown once the consent video has been submitted.
class _SubmitSuccessPane extends StatelessWidget {
  const _SubmitSuccessPane();

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        Text(
          context.l10n.minorAccountReviewVideoSubmittedTitle,
          style: VineTheme.headlineMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.minorAccountReviewVideoSubmittedBody,
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
        const _ConsentPromptCard(),
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

/// What the parent says on camera, shown before and during recording.
class _ConsentPromptCard extends StatelessWidget {
  const _ConsentPromptCard();

  @override
  Widget build(BuildContext context) {
    return MinorAccountReviewChecklistCard(
      title: context.l10n.minorAccountReviewRecordConsentPromptTitle,
      items: [
        context.l10n.minorAccountReviewParentConsentChecklistKid,
        context.l10n.minorAccountReviewParentConsentChecklistPermission,
        context.l10n.minorAccountReviewParentConsentChecklistAgeBand,
        context.l10n.minorAccountReviewParentConsentChecklistSupervision,
      ],
    );
  }
}

/// Recording state: live preview, the stop control, and the prompt card the
/// parent reads from while recording. Stop sits above the card so it stays in
/// view on a short screen.
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
        const SizedBox(height: 16),
        const _ConsentPromptCard(),
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
    return BlocProvider(
      create: (_) => MinorConsentPlaybackCubit(),
      child: _ReviewPaneBody(
        filePath: filePath,
        onRetake: onRetake,
        onUseVideo: onUseVideo,
      ),
    );
  }
}

class _ReviewPaneBody extends StatelessWidget {
  const _ReviewPaneBody({
    required this.filePath,
    required this.onRetake,
    required this.onUseVideo,
  });
  final String filePath;
  final VoidCallback onRetake;
  final VoidCallback onUseVideo;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<MinorConsentPlaybackCubit>().state;
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
          onPressed: playback == MinorConsentPlaybackState.ready
              ? onUseVideo
              : null,
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
  const _DeniedPane({
    required this.onUseEmailFallback,
    this.onOpenSettings,
    this.onRetry,
  });

  final VoidCallback onUseEmailFallback;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      children: [
        _MessageCard(
          title: context.l10n.minorAccountReviewRecordConsentDeniedTitle,
          body: context.l10n.minorAccountReviewRecordConsentDeniedBody,
        ),
        const SizedBox(height: 24),
        if (onRetry != null) ...[
          DivineButton(
            label: context.l10n.minorAccountReviewRecordConsentTryAgainCta,
            expanded: true,
            onPressed: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        if (onOpenSettings != null) ...[
          DivineButton(
            label: context.l10n.cameraPermissionGoToSettings,
            expanded: true,
            onPressed: onOpenSettings,
          ),
          const SizedBox(height: 12),
        ],
        DivineButton(
          label: context.l10n.minorAccountReviewRecordConsentEmailInsteadCta,
          leadingIcon: DivineIconName.envelope,
          expanded: true,
          onPressed: onUseEmailFallback,
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
class _ClipPlayback extends ConsumerStatefulWidget {
  const _ClipPlayback({required this.filePath});

  final String filePath;

  @override
  ConsumerState<_ClipPlayback> createState() => _ClipPlaybackState();
}

class _ClipPlaybackState extends ConsumerState<_ClipPlayback> {
  late DivineVideoPlayerController _controller;
  Future<void>? _loading;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(minorConsentPreviewControllerProvider)();
    unawaited(_load());
  }

  Future<void> _load() {
    final cubit = context.read<MinorConsentPlaybackCubit>();
    return _loading = cubit.load(
      () async {
        if (_controller.isInitialized) {
          await _controller.dispose();
          if (!mounted) return;
          _controller = ref.read(minorConsentPreviewControllerProvider)();
        }
        await _controller.initialize();
        await _controller.setSource(VideoClip.file(widget.filePath));
        await _controller.play();
        if (_controller.state.status == PlaybackStatus.error) {
          throw StateError('Consent preview could not decode');
        }
      },
      waitForFrame: () => _controller.firstFrameRendered,
      errors: () => _controller.stateStream.map(
        (state) => state.status == PlaybackStatus.error,
      ),
    );
  }

  Future<void> _disposePlayer() async {
    await _loading;
    await _controller.dispose();
  }

  @override
  void dispose() {
    unawaited(_disposePlayer());
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
          child: switch (context.watch<MinorConsentPlaybackCubit>().state) {
            MinorConsentPlaybackState.ready => DivineVideoPlayer(
              controller: _controller,
            ),
            MinorConsentPlaybackState.failure => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(context.l10n.videoErrorPlaybackStartFailed),
                DivineButton(
                  label: context.l10n.videoErrorRetry,
                  onPressed: () => unawaited(_load()),
                ),
              ],
            ),
            MinorConsentPlaybackState.decoding => Stack(
              fit: StackFit.expand,
              children: [
                DivineVideoPlayer(controller: _controller),
                const Center(child: DivineCircularProgressIndicator()),
              ],
            ),
            MinorConsentPlaybackState.loading => const Center(
              child: DivineCircularProgressIndicator(),
            ),
          },
        ),
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
