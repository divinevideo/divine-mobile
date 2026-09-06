// ABOUTME: Declarative permission gate that wraps camera screen
// ABOUTME: Renders permission UI or camera based on CameraPermissionBloc state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/widgets/takeover_close_button.dart';
import 'package:openvine/widgets/tv_static_message_screen.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:unified_logger/unified_logger.dart';

/// A declarative gate widget that handles camera/microphone permissions.
///
/// On direct navigation to the recorder (quick actions, deep links) a
/// still-requestable permission fires the native OS dialog immediately via
/// [_onPermissionState] — no in-app priming screen. A denial that stays
/// requestable pops back so the next camera tap re-prompts.
///
/// Renders appropriate UI based on permission state:
/// - loading: Shows a loading indicator
/// - canRequest: Shows a loading indicator while the native dialog is up
/// - requiresSettings: Shows the prompt with a Go to Settings button
/// - authorized: Renders the [child] (camera screen)
/// - error: Shows an error screen with a Retry button
///
/// Handles app lifecycle to refresh permissions when returning from background.
class CameraPermissionGate extends StatefulWidget {
  const CameraPermissionGate({required this.child, super.key});

  /// The widget to render when permissions are authorized (typically camera screen)
  final Widget child;

  @override
  State<CameraPermissionGate> createState() => _CameraPermissionGateState();
}

class _CameraPermissionGateState extends State<CameraPermissionGate>
    with WidgetsBindingObserver {
  bool _wasInBackground = false;

  /// Guards the one auto-request per mount so a denial that stays requestable
  /// doesn't immediately re-trigger the native dialog in a loop.
  bool _autoRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Log.info(
      '🔐 CameraPermissionGate initState',
      name: 'CameraPermissionGate',
      category: LogCategory.video,
    );

    // Always refresh permission check when screen opens
    // This handles cases where user denied previously and is returning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<CameraPermissionBloc>();
      Log.info(
        '🔐 Current permission state: ${bloc.state.runtimeType}',
        name: 'CameraPermissionGate',
        category: LogCategory.video,
      );
      if (bloc.state is! CameraPermissionLoaded) {
        Log.info(
          '🔐 Triggering permission refresh',
          name: 'CameraPermissionGate',
          category: LogCategory.video,
        );
        bloc.add(const CameraPermissionRefresh());
      } else {
        // Already resolved before the gate mounted (the app-level bloc warms
        // the check at startup). The listener won't fire for this initial
        // state, so drive the auto-request here.
        _onPermissionState(bloc.state);
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
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // Refresh permissions when returning from real background (e.g., Settings app)
        if (_wasInBackground) {
          _wasInBackground = false;
          context.read<CameraPermissionBloc>().add(
            const CameraPermissionRefresh(),
          );
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _wasInBackground = true;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _popBack() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go(VideoFeedPage.pathForIndex(0));
    }
  }

  /// Drives the direct-request flow for a still-requestable permission:
  /// fire the native OS dialog immediately (no in-app priming screen) the
  /// first time, and pop back on a denial that leaves it requestable so the
  /// next camera tap re-prompts. A permanent denial resolves to
  /// [CameraPermissionStatus.requiresSettings] and is surfaced by the builder.
  void _onPermissionState(CameraPermissionState state) {
    if (!mounted) return;
    if (state is! CameraPermissionLoaded) return;
    if (state.status != CameraPermissionStatus.canRequest) return;

    if (!_autoRequested) {
      _autoRequested = true;
      context.read<CameraPermissionBloc>().add(const CameraPermissionRequest());
    } else {
      _popBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CameraPermissionBloc, CameraPermissionState>(
      listener: (context, state) {
        Log.info(
          '🔐 Permission state changed: ${state.runtimeType}',
          name: 'CameraPermissionGate',
          category: LogCategory.video,
        );
        _onPermissionState(state);
      },
      builder: (context, state) {
        Log.debug(
          '🔐 Building with state: ${state.runtimeType}',
          name: 'CameraPermissionGate',
          category: LogCategory.video,
        );

        if (kIsWeb) {
          return _PermissionScreen(
            title: context.l10n.cameraPermissionWebUnsupportedTitle,
            description: context.l10n.cameraPermissionWebUnsupportedDescription,
            buttonLabel: context.l10n.cameraPermissionBackToFeed,
            onAction: _popBack,
            onClose: _popBack,
          );
        }

        return switch (state) {
          CameraPermissionInitial() => _LoadingIndicator(onClose: _popBack),
          CameraPermissionLoading() => _LoadingIndicator(onClose: _popBack),
          CameraPermissionError() => _PermissionScreen(
            title: context.l10n.cameraPermissionErrorTitle,
            description: context.l10n.cameraPermissionErrorDescription,
            buttonLabel: context.l10n.cameraPermissionRetry,
            onAction: () {
              context.read<CameraPermissionBloc>().add(
                const CameraPermissionRefresh(),
              );
            },
            onClose: _popBack,
          ),
          CameraPermissionLoaded(:final status) => switch (status) {
            CameraPermissionStatus.authorized => widget.child,
            // Requestable permission fires the native OS dialog directly via
            // [_onPermissionState]; no in-app priming screen. The indicator
            // covers the brief window while the dialog is up.
            CameraPermissionStatus.canRequest => _LoadingIndicator(
              onClose: _popBack,
            ),
            CameraPermissionStatus.requiresSettings => _PermissionScreen(
              title: context.l10n.cameraPermissionAllowAccessTitle,
              description: context.l10n.cameraPermissionAllowAccessDescription,
              buttonLabel: context.l10n.cameraPermissionGoToSettings,
              onAction: () {
                context.read<CameraPermissionBloc>().add(
                  const CameraPermissionOpenSettings(),
                );
              },
              onClose: _popBack,
            ),
          },
        };
      },
    );
  }
}

/// Centered loading indicator with an optional escape hatch.
///
/// The direct-navigation gate path (quick actions, deep links) can land here on
/// a still-requestable permission whose native dialog was dismissed with the
/// back button — the `permission_handler` hang that pins the bloc in
/// [CameraPermissionLoading]. [onClose] lets the user bail back to the feed
/// instead of being trapped on the spinner; re-entering re-fires the request.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: DivineCircularProgressIndicator(
              color: context.vineColors.accentPositive,
            ),
          ),
          if (onClose case final onClose?)
            SafeArea(
              bottom: false,
              child: TakeoverCloseButton(
                onPressed: onClose,
                semanticLabel: context.l10n.videoRecorderCloseLabel,
              ),
            ),
        ],
      ),
    );
  }
}

/// Permission screen with TV static background, sticker, title, description,
/// and a primary action button. Used for all permission states.
class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onAction,
    required this.onClose,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TvStaticMessageScreen(
      sticker: .alert,
      title: title,
      description: description,
      actionLabel: buttonLabel,
      onAction: onAction,
      onClose: onClose,
      closeSemanticLabel: context.l10n.videoRecorderCloseLabel,
      footer: IgnorePointer(
        child: Container(
          padding: const .only(top: 8),
          color: context.vineColors.surfaceContainerHigh,
          child: const Opacity(
            opacity: 0.25,
            child: VideoRecorderBottomBar(),
          ),
        ),
      ),
    );
  }
}
