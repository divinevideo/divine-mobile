// ABOUTME: Screen for NIP-46 nostrconnect:// client-initiated connections.
// ABOUTME: Displays QR code and URL for user to scan/copy into signer app.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Screen for NIP-46 client-initiated connections via nostrconnect:// URL.
class NostrConnectScreen extends ConsumerStatefulWidget {
  /// Route path for this screen.
  static const String path = RoutePaths.nostrConnect;

  /// Route name for this screen.
  static const String routeName = 'nostr-connect';

  const NostrConnectScreen({super.key});

  @override
  ConsumerState<NostrConnectScreen> createState() => _NostrConnectScreenState();
}

class _NostrConnectScreenState extends ConsumerState<NostrConnectScreen> {
  String? _connectUrl;
  NostrConnectState _sessionState = NostrConnectState.idle;
  // Retained only for the out-of-scope bunker:// path (_showPasteBunkerDialog).
  // The nostrconnect:// path uses _failureReason instead.
  String? _errorMessage;
  NostrConnectFailureReason? _failureReason;
  StreamSubscription<NostrConnectState>? _stateSubscription;
  bool _isWaiting = false;
  bool _switchedToBunker = false;
  int _sessionAttempt = 0;
  final Stopwatch _elapsedTimer = Stopwatch();
  Timer? _uiTimer;

  // Cache AuthService for use in dispose (can't use ref.read in dispose)
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _startOrResumeSession();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _uiTimer?.cancel();
    _elapsedTimer.stop();
    // Android can route the signer callback through GoRouter before the
    // app-links stream finishes handling it. In that short handoff, preserve
    // the active NIP-46 session so the replacement route can reattach.
    if (!_authService.isNostrConnectCallbackHandoffActive) {
      _authService.cancelNostrConnect();
    } else {
      _authService.preserveNostrConnectForCallbackHandoff();
    }
    super.dispose();
  }

  void _startOrResumeSession() {
    final activeUrl = _authService.nostrConnectUrl;
    final activeState = _authService.nostrConnectState;
    if (activeUrl != null &&
        (activeState == NostrConnectState.generating ||
            activeState == NostrConnectState.listening)) {
      _resumeActiveSession(activeUrl, activeState ?? NostrConnectState.idle);
      return;
    }

    _startSession();
  }

  void _resumeActiveSession(String activeUrl, NostrConnectState activeState) {
    _authService.claimNostrConnectCallbackHandoff();
    final attempt = ++_sessionAttempt;
    unawaited(_stateSubscription?.cancel());
    _stateSubscription = null;
    _uiTimer?.cancel();
    _uiTimer = null;
    _elapsedTimer
      ..stop()
      ..reset()
      ..start();
    _isWaiting = false;
    _switchedToBunker = false;

    Log.info(
      'Resuming active nostrconnect session after signer callback',
      name: 'NostrConnectScreen',
      category: LogCategory.auth,
    );

    setState(() {
      _connectUrl = activeUrl;
      _sessionState = activeState;
      _errorMessage = null;
      _failureReason = null;
    });

    _stateSubscription = _authService.nostrConnectStateStream?.listen((state) {
      if (!mounted || attempt != _sessionAttempt) return;
      setState(() {
        _sessionState = state;
      });
      if (state == NostrConnectState.listening) {
        unawaited(_waitForConnection(attempt));
      }
    });

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && attempt == _sessionAttempt) setState(() {});
    });

    if (activeState == NostrConnectState.listening) {
      unawaited(_waitForConnection(attempt));
    }
  }

  Future<void> _startSession() async {
    final attempt = ++_sessionAttempt;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    _uiTimer?.cancel();
    _uiTimer = null;
    _elapsedTimer
      ..stop()
      ..reset();
    _isWaiting = false;
    _switchedToBunker = false;

    setState(() {
      _connectUrl = null;
      _sessionState = NostrConnectState.generating;
      _errorMessage = null;
      _failureReason = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final session = await authService.initiateNostrConnect();

      if (!mounted || attempt != _sessionAttempt) return;

      setState(() {
        _connectUrl = session.connectUrl;
        _sessionState = NostrConnectState.listening;
      });

      // Listen to state changes
      _stateSubscription = session.stateStream.listen((state) {
        if (!mounted || attempt != _sessionAttempt) return;
        setState(() {
          _sessionState = state;
        });
      });

      // Start the timer for UI updates
      _elapsedTimer.start();
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });

      // Start waiting for the connection
      _waitForConnection(attempt);
    } catch (e) {
      Log.error(
        'Failed to start nostrconnect session: $e',
        name: 'NostrConnectScreen',
        category: LogCategory.auth,
      );
      if (!mounted || attempt != _sessionAttempt) return;
      setState(() {
        _sessionState = NostrConnectState.error;
        _failureReason = NostrConnectFailureReason.startFailed;
      });
    }
  }

  Future<void> _waitForConnection(int attempt) async {
    if (_isWaiting) return;
    _isWaiting = true;

    final authService = ref.read(authServiceProvider);
    final result = await authService.waitForNostrConnectResponse();

    if (!mounted || attempt != _sessionAttempt) return;

    _isWaiting = false;
    _elapsedTimer.stop();
    _uiTimer?.cancel();

    // If the user switched to a bunker connection via the paste dialog,
    // ignore the nostrconnect session result to avoid interfering with
    // the bunker auth flow.
    if (_switchedToBunker) return;

    if (result.success) {
      // Navigate to home on success
      context.go(VideoFeedPage.pathForIndex(0));
    } else {
      // Drive the UI state from the reason so the failure actually renders.
      // timeout/cancelled keep their dedicated UI branches; everything else
      // surfaces through the error branch.
      setState(() {
        _failureReason = result.nostrConnectFailureReason;
        _sessionState = switch (result.nostrConnectFailureReason) {
          NostrConnectFailureReason.timedOut => NostrConnectState.timeout,
          NostrConnectFailureReason.cancelled => NostrConnectState.cancelled,
          _ => NostrConnectState.error,
        };
      });
    }
  }

  void _retry() {
    _elapsedTimer.reset();
    _startSession();
  }

  Future<void> _copyUrl() async {
    if (_connectUrl == null) return;

    await Clipboard.setData(ClipboardData(text: _connectUrl!));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.authUrlCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareUrl() async {
    if (_connectUrl == null) return;

    await showShareSheet(
      context,
      ShareParams(text: _connectUrl, title: context.l10n.authConnectToDivine),
    );
  }

  Future<void> _showPasteBunkerDialog() async {
    final controller = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.vineColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.vineColors.onSurfaceMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.authPasteBunkerUrl,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.authBunkerUrlHint,
                hintStyle: TextStyle(
                  color: context.vineColors.accentPositive,
                ),
                filled: true,
                fillColor: context.vineColors.surfaceContainer,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: context.vineColors.accentPositive,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: context.vineColors.accentPositive,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              onSubmitted: (value) => context.popModalIfMounted(value.trim()),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    // Validate it's a bunker URL
    if (!NostrRemoteSignerInfo.isBunkerUrl(result)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authInvalidBunkerUrl),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }

    // Cancel the current nostrconnect session and prevent its completion
    // callback from interfering with the bunker auth flow.
    _switchedToBunker = true;
    _sessionAttempt++;
    _authService.cancelNostrConnect();
    _stateSubscription?.cancel();
    _uiTimer?.cancel();
    _elapsedTimer.stop();

    // Show loading state
    setState(() {
      _sessionState = NostrConnectState.connected;
    });

    // Authenticate with bunker URL
    try {
      final authService = ref.read(authServiceProvider);
      final authResult = await authService.connectWithBunker(result);

      if (!mounted) return;

      if (authResult.success) {
        context.go(VideoFeedPage.pathForIndex(0));
      } else {
        setState(() {
          _sessionState = NostrConnectState.error;
          _errorMessage = context.l10n.authFailedToConnect;
        });
      }
    } catch (e) {
      Log.error(
        'Nostr Connect session failed: $e',
        name: 'NostrConnectScreen',
        category: LogCategory.ui,
      );
      if (!mounted) return;
      setState(() {
        _sessionState = NostrConnectState.error;
        _errorMessage = context.l10n.authFailedToConnect;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: switch (_sessionState) {
          NostrConnectState.idle || NostrConnectState.generating => _QrContent(
            connectUrl: '',
            statusMessage: context.l10n.authGeneratingConnection,
            isLoading: true,
            onBack: () => context.pop(),
            onCopyUrl: _copyUrl,
            onShareUrl: _shareUrl,
            onAddBunker: _showPasteBunkerDialog,
          ),
          NostrConnectState.listening => _QrContent(
            connectUrl: _connectUrl ?? '',
            statusMessage: context.l10n.authWaitingForConnection(
              _elapsedTimer.elapsed.inSeconds,
            ),
            onBack: () => context.pop(),
            onCopyUrl: _copyUrl,
            onShareUrl: _shareUrl,
            onAddBunker: _showPasteBunkerDialog,
          ),
          NostrConnectState.connected => _QrContent(
            connectUrl: _connectUrl ?? '',
            statusMessage: context.l10n.authConnectedAuthenticating,
            isLoading: true,
            onBack: () => context.pop(),
            onCopyUrl: _copyUrl,
            onShareUrl: _shareUrl,
            onAddBunker: _showPasteBunkerDialog,
          ),
          NostrConnectState.timeout => _ErrorContent(
            title: context.l10n.authConnectionTimedOut,
            message: context.l10n.authApproveConnection,
            onRetry: _retry,
            onBack: () => context.pop(),
          ),
          NostrConnectState.cancelled => _ErrorContent(
            title: context.l10n.authConnectionCancelled,
            message: context.l10n.authConnectionCancelledMessage,
            onRetry: _retry,
            onBack: () => context.pop(),
          ),
          NostrConnectState.error => _ErrorContent(
            title: context.l10n.authConnectionFailed,
            message: _failureReason != null
                ? resolveNostrConnectFailureMessage(
                    context.l10n,
                    _failureReason,
                  )
                : (_errorMessage ?? context.l10n.authUnknownError),
            onRetry: _retry,
            onBack: () => context.pop(),
          ),
        },
      ),
    );
  }
}

/// Maps a [NostrConnectFailureReason] to a localized, user-facing message.
///
/// Lives at the UI layer so the nostr_sdk package never carries English copy.
/// `timedOut`/`cancelled` are rendered via their own [NostrConnectState]
/// branches, so they fall through to the generic message defensively.
@visibleForTesting
String resolveNostrConnectFailureMessage(
  AppLocalizations l10n,
  NostrConnectFailureReason? reason,
) {
  return switch (reason) {
    NostrConnectFailureReason.startFailed => l10n.authNostrConnectStartFailed,
    NostrConnectFailureReason.noExpectedSecret =>
      l10n.authNostrConnectInvalidSession,
    NostrConnectFailureReason.postConnectFailed =>
      l10n.authNostrConnectSetupFailed,
    NostrConnectFailureReason.timedOut ||
    NostrConnectFailureReason.cancelled ||
    null => l10n.authUnknownError,
  };
}

/// Main QR code content with actions and compatibility table.
///
/// The same layout backs the generating and authenticating states: instead of
/// a separate spinner screen, the payload-dependent parts (QR code and action
/// bar) shimmer via [Skeletonizer] while [isLoading] is `true`, so the chrome
/// never shifts between states.
class _QrContent extends StatelessWidget {
  const _QrContent({
    required this.connectUrl,
    required this.statusMessage,
    required this.onBack,
    required this.onCopyUrl,
    required this.onShareUrl,
    required this.onAddBunker,
    this.isLoading = false,
  });

  final String connectUrl;
  final String statusMessage;
  final VoidCallback onBack;
  final VoidCallback onCopyUrl;
  final VoidCallback onShareUrl;
  final VoidCallback onAddBunker;

  /// Whether the session payload is still pending. Skeletonizes the QR code
  /// and action bar. [Skeletonizer]'s `ignorePointers` blocks touch but not
  /// the semantics tree, so the action bar is also disabled for screen
  /// readers by nulling its callbacks (see [_ActionBar.isLoading]) — otherwise
  /// a double-tap could open the bunker sheet and drop the live session.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Back button — outside the skeleton so it stays tappable while
          // the session is still generating.
          AuthBackButton(onPressed: onBack),

          const SizedBox(height: 32),

          // Title
          Text(
            context.l10n.authScanSignerApp,
            style: TextStyle(
              fontFamily: VineTheme.fontFamilyBricolage,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.vineColors.primaryText,
            ),
          ),

          const SizedBox(height: 32),

          Skeletonizer(
            enabled: isLoading,
            enableSwitchAnimation: true,
            effect: vineSkeletonEffectOf(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QR code card
                _QrCodeCard(connectUrl: connectUrl, isLoading: isLoading),

                const SizedBox(height: 20),

                // Status indicator — the message is real copy in every state,
                // so it is kept rather than turned into a text bone.
                Skeleton.keep(child: _StatusIndicator(message: statusMessage)),

                const SizedBox(height: 32),

                // Action bar
                _ActionBar(
                  isLoading: isLoading,
                  onCopyUrl: onCopyUrl,
                  onShareUrl: onShareUrl,
                  onAddBunker: onAddBunker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Compatibility table
          const _CompatibilityTable(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// QR code displayed in a rounded card.
class _QrCodeCard extends StatelessWidget {
  const _QrCodeCard({required this.connectUrl, required this.isLoading});

  final String connectUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.vineColors.outline),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // A QR code is machine-readable, not chrome: the quiet zone has
            // to stay white behind the black modules in both appearance
            // modes, or scanners lose the contrast they need.
            color: VineTheme.whiteText,
            borderRadius: BorderRadius.circular(12),
          ),
          // Replaced rather than skeletonized in place: in the steady loading
          // state the encoder never runs over the placeholder payload. (The
          // switch animation still builds one throwaway `QrImageView('')`
          // mid-transition; harmless — an empty payload encodes fine.)
          child: Skeleton.replace(
            replace: isLoading,
            width: 200,
            height: 200,
            replacement: Skeleton.leaf(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vineColors.skeleton,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            child: QrImageView(
              data: connectUrl,
              size: 200,
              backgroundColor: VineTheme.whiteText,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
        ),
      ),
    );
  }
}

/// Spinner with the current session status message.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: DivineCircularProgressIndicator(
              strokeWidth: 2,
              color: context.vineColors.accentPositive,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.vineColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action bar with Copy URL, Share, and Add bunker buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onCopyUrl,
    required this.onShareUrl,
    required this.onAddBunker,
    this.isLoading = false,
  });

  final VoidCallback onCopyUrl;
  final VoidCallback onShareUrl;
  final VoidCallback onAddBunker;

  /// While loading, the buttons are handed `null` callbacks so they publish
  /// no tap action — inert to both touch and screen readers. [Skeletonizer]'s
  /// `ignorePointers` only blocks touch, so nulling here is what keeps a
  /// double-tap from activating a bone.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: .horizontal,
          child: Container(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.vineColors.outline),
            ),
            padding: const .symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: .spaceAround,
              spacing: 10,
              children: [
                _ActionButton(
                  icon: DivineIcon(
                    icon: DivineIconName.linkSimple,
                    color: context.vineColors.accentPositive,
                  ),
                  label: context.l10n.authCopyUrl,
                  onTap: isLoading ? null : onCopyUrl,
                ),
                _ActionButton(
                  icon: DivineIcon(
                    icon: DivineIconName.shareFat,
                    color: context.vineColors.accentPositive,
                  ),
                  label: context.l10n.authShare,
                  onTap: isLoading ? null : onShareUrl,
                ),
                _ActionButton(
                  icon: DivineIcon(
                    icon: DivineIconName.plus,
                    color: context.vineColors.accentPositive,
                  ),
                  label: context.l10n.authAddBunker,
                  onTap: isLoading ? null : onAddBunker,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Single action button in the action bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;

  /// `null` while the session is loading, so the button is inert to both
  /// touch and screen-reader activation.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            icon,
            Text(
              label,
              style: TextStyle(
                color: context.vineColors.accentPositive,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: .center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compatibility table showing signer apps and their platform support.
class _CompatibilityTable extends StatelessWidget {
  const _CompatibilityTable();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.authCompatibleSignerApps,
                  style: TextStyle(
                    color: context.vineColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ),
              _platformIcon(context, DivineIconName.androidLogo),
              const SizedBox(width: 24),
              _platformIcon(context, DivineIconName.appleLogo),
              const SizedBox(width: 24),
              _platformIcon(context, DivineIconName.globe),
            ],
          ),
        ),

        // Signer rows
        const _SignerRow(name: 'Amber', android: true, ios: false, web: false),
        const _SignerRow(name: 'Primal', android: true, ios: true, web: true),
        const _SignerRow(
          name: 'Nostr Connect',
          android: true,
          ios: true,
          web: false,
        ),
        const _SignerRow(
          name: 'nsecBunker',
          android: false,
          ios: false,
          web: true,
        ),
      ],
    );
  }

  Widget _platformIcon(BuildContext context, DivineIconName icon) {
    return DivineIcon(
      icon: icon,
      color: context.vineColors.secondaryText,
      size: 22,
    );
  }
}

/// Single row in the signer compatibility table.
class _SignerRow extends StatelessWidget {
  const _SignerRow({
    required this.name,
    required this.android,
    required this.ios,
    required this.web,
  });

  final String name;
  final bool android;
  final bool ios;
  final bool web;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.vineColors.outline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _checkOrEmpty(context, android),
          const SizedBox(width: 24),
          _checkOrEmpty(context, ios),
          const SizedBox(width: 24),
          _checkOrEmpty(context, web),
        ],
      ),
    );
  }

  Widget _checkOrEmpty(BuildContext context, bool supported) {
    return SizedBox(
      width: 22,
      child: supported
          ? DivineIcon(
              icon: DivineIconName.check,
              color: context.vineColors.accentPositive,
              size: 22,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Error state with retry option.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AuthBackButton(onPressed: onBack),
          const Spacer(),
          Center(
            child: Column(
              children: [
                const DivineIcon(
                  icon: DivineIconName.warningCircle,
                  color: VineTheme.error,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.vineColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      // Ink on a fixed brand fill, so it is a constant rather
                      // than a token: `background` follows the appearance and
                      // turned the label near-white on the green in light
                      // (1.9:1), beside an icon that was already `onPrimary`.
                      foregroundColor: VineTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    icon: const DivineIcon(
                      icon: DivineIconName.arrowClockwise,
                      size: 16,
                      color: VineTheme.onPrimary,
                    ),
                    label: Text(
                      context.l10n.authTryAgain,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
