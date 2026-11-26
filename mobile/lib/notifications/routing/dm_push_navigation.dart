// ABOUTME: Account-scoped handoff of an already validated wrap tap to Messages.
import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart' as clock_pkg;
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/dm/minor_dm_approval.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/router/routes/shell.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

final String _tapPrefix = _randomTapPrefix();
var _nextTapId = 0;

String _randomTapPrefix() {
  final random = math.Random();
  // 0x7fffffff rather than a shift: `1 << 32` is 0 on the web.
  return '${random.nextInt(0x7fffffff).toRadixString(16)}'
      '${random.nextInt(0x7fffffff).toRadixString(16)}';
}

/// Held in memory for coalescing OS callbacks. A route never carries the wrap
/// or recipient in its URL; [token] is an opaque process-local identifier.
/// The 10 second deadline includes DM initialization and review-status checks.
class DmPushIntent {
  DmPushIntent(this.target) : _elapsed = clock_pkg.clock.stopwatch()..start();
  final OpenDirectMessageTarget target;
  final String token = '$_tapPrefix-${_nextTapId++}';
  final Stopwatch _elapsed;
  String? destination;
  bool finished = false;
  bool superseded = false;
  VoidCallback? _onCancel;

  void cancel() {
    superseded = true;
    _onCancel?.call();
  }

  Duration get remaining {
    final left = const Duration(seconds: 10) - _elapsed.elapsed;
    return left.isNegative ? Duration.zero : left;
  }
}

final _lastTap = Expando<DmPushIntent>('DM notification tap');

/// Returns the active tap intent from [extra] or the matching process-local
/// [token] after a redirect that stripped route extras.
DmPushIntent? activeDmPushIntent(
  ProviderContainer container, {
  Object? extra,
  String? token,
}) {
  if (extra is DmPushIntent && !extra.finished && !extra.superseded) {
    return extra;
  }
  if (token == null || token.isEmpty) return null;
  final active = _lastTap[container];
  if (active == null ||
      active.finished ||
      active.superseded ||
      active.token != token) {
    return null;
  }
  return active;
}

/// Returns the newly mounted account container only after normal activation.
final dmPushAccountSwitchProvider =
    Provider<Future<ProviderContainer?> Function(KnownAccount)>((ref) {
      final device = ref.read(deviceScopeProvider);
      final auth = ref.read(authServiceProvider);
      return (account) async {
        await swapAccount(
          deviceScope: device,
          controller: device.switchController,
          currentAuthService: auth,
          account: account,
        );
        return device.switchController.currentContainer;
      };
    });

void cancelPendingDmPush(ProviderContainer container) {
  final previous = _lastTap[container];
  previous?.cancel();
  _lastTap[container] = null;
}

bool _isWaitingOnIntent(Uri currentUri, DmPushIntent previous) {
  if (previous.finished || previous.superseded) return false;
  if (currentUri.path == const InboxRouteData().location &&
      currentUri.queryParameters['dmTap'] == previous.token) {
    return true;
  }
  if (currentUri.path == MinorAccountReviewScreen.path &&
      currentUri.queryParameters['dmTap'] == previous.token) {
    return true;
  }
  if (currentUri.path == MinorAccountReviewLoadingScreen.path) {
    final from = currentUri.queryParameters['from'];
    final fromUri = (from == null || from.isEmpty) ? null : Uri.tryParse(from);
    if (fromUri != null &&
        fromUri.path == const InboxRouteData().location &&
        fromUri.queryParameters['dmTap'] == previous.token) {
      return true;
    }
  }
  return false;
}

/// A closed conversation can be opened again by tapping the notification.
void openDmPush(ProviderContainer container, OpenMessagesTarget target) {
  final router = container.read(goRouterProvider);
  if (target is! OpenDirectMessageTarget) {
    cancelPendingDmPush(container);
    router.go(const InboxRouteData(messages: true).location);
    return;
  }
  final previous = _lastTap[container];
  final matches = router.routerDelegate.currentConfiguration;
  final top = matches.isEmpty ? null : matches.last;
  final currentUri = top is ImperativeRouteMatch
      ? top.matches.uri
      : router.routeInformationProvider.value.uri;
  final current = currentUri.toString();
  if (previous?.target == target &&
      (current == previous?.destination ||
          _isWaitingOnIntent(currentUri, previous!))) {
    return;
  }
  cancelPendingDmPush(container);
  final intent = DmPushIntent(target);
  _lastTap[container] = intent;
  router.go(
    InboxRouteData(messages: true, dmTap: intent.token).location,
    extra: intent,
  );
}

/// Mounted inside the existing Messages entry (or the restricted-account review
/// screen for moderation taps). Its children and the normal protected-minor
/// gates remain usable while ingest catches up.
class DmPushListener extends ConsumerStatefulWidget {
  const DmPushListener({
    required this.intent,
    required this.child,
    this.hostPath,
    this.moderationOnly = false,
    super.key,
  });
  final DmPushIntent intent;
  final Widget child;
  final String? hostPath;
  final bool moderationOnly;

  @override
  ConsumerState<DmPushListener> createState() => _DmPushListenerState();
}

class _DmPushListenerState extends ConsumerState<DmPushListener> {
  late final GoRouter _router;
  Timer? _timeout;
  StreamSubscription<DmWrapLookup>? _lookup;
  ProviderSubscription<NostrSessionReadiness>? _session;
  bool _confirmingSwitch = false;
  String? _observedOwner;

  bool get _active =>
      mounted && !widget.intent.finished && !widget.intent.superseded;
  String get _hostPath => widget.hostPath ?? const InboxRouteData().location;
  bool get _atHost =>
      _router.routeInformationProvider.value.uri.path == _hostPath;
  String get _owner => widget.intent.target.receiverPubkey;

  @override
  void initState() {
    super.initState();
    widget.intent._onCancel = _finish;
    _router = ref.read(goRouterProvider);
    _router.routeInformationProvider.addListener(_onLocation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active && _atHost) unawaited(_begin());
    });
  }

  void _onLocation() {
    if (!_atHost && !_confirmingSwitch) _finish();
  }

  void _finish({bool unavailable = false}) {
    if (widget.intent.finished) return;
    widget.intent.finished = true;
    _timeout?.cancel();
    _session?.close();
    unawaited(_lookup?.cancel());
    if (unavailable && mounted && _atHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.dmNotificationMessageUnavailable,
        ),
      );
    }
  }

  Future<void> _begin() async {
    try {
      final auth = ref.read(authServiceProvider);
      final initialOwner = auth.currentPublicKeyHex;
      _observedOwner = initialOwner;
      if (initialOwner != null && initialOwner != _owner) {
        await _offerSwitch();
        return;
      }
      final remaining = widget.intent.remaining;
      if (remaining <= Duration.zero) {
        _finish(unavailable: true);
        return;
      }
      _timeout = Timer(remaining, () => _finish(unavailable: true));
      _session = ref.listenManual(nostrSessionProvider, (_, state) {
        if (!_active) return;
        if (state.phase == NostrSessionPhase.tearingDown ||
            (_observedOwner != null && state.pubkey != _observedOwner)) {
          _finish();
          return;
        }
        if (state.pubkey == null) return;
        if (state.pubkey != _owner) {
          if (_observedOwner == null) {
            _observedOwner = state.pubkey;
            _timeout?.cancel();
            unawaited(
              _offerSwitch().catchError((Object _) {
                if (_active) _finish(unavailable: true);
              }),
            );
          }
          return;
        }
        _observedOwner = state.pubkey;
        if (!state.isReadyForActiveClient || _lookup != null) return;
        final repo = ref.read(dmRepositoryProvider);
        _lookup = repo
            .watchWrapLookup(
              ownerPubkey: _owner,
              giftWrapId: widget.intent.target.giftWrapId,
            )
            .listen(
              _onLookup,
              onError: (Object _) => _finish(unavailable: true),
            );
      }, fireImmediately: true);
    } on Object {
      if (_active) _finish(unavailable: true);
    }
  }

  void _onLookup(DmWrapLookup result) {
    if (!_active ||
        !_atHost ||
        ref.read(authServiceProvider).currentPublicKeyHex != _owner) {
      return;
    }
    if (result is DmWrapPending) return;
    if (result is! DmWrapFound) {
      _finish(unavailable: true);
      return;
    }
    final participants = List<String>.unmodifiable(result.participants);
    final reviewStatus = ref
        .read(currentMinorAccountReviewStatusProvider)
        .value;
    final restrictedToModeration =
        widget.moderationOnly || (reviewStatus?.isRestricted ?? false);
    if (restrictedToModeration) {
      final allowedModerationId = moderationConversationIdFor(
        currentPubkey: _owner,
        reviewCase: reviewStatus?.currentCase,
      );
      if (allowedModerationId == null ||
          result.conversationId != allowedModerationId) {
        _finish(unavailable: true);
        return;
      }
    }
    // Observe all eligibility changes until the last synchronous navigation
    // decision. The destination applies its live protected-minor gate as well.
    if (ref.read(isDmRestrictedProvider) &&
        !allParticipantsApprovedForMinor(
          participants,
          ref.read(officialAccountsServiceProvider).isReadableByProtectedMinor,
        )) {
      _finish(unavailable: true);
      return;
    }
    final location = !restrictedToModeration && result.isRequest
        ? RequestPreviewRouteData(id: result.conversationId).location
        : ConversationRouteData(
            id: result.conversationId,
            messageId: result.messageId,
          ).location;
    widget.intent.destination = location;
    _finish();
    unawaited(_router.push<void>(location, extra: participants));
  }

  Future<void> _offerSwitch() async {
    final auth = ref.read(authServiceProvider);
    final accounts = await auth.getKnownAccounts();
    if (!mounted ||
        !_active ||
        !_atHost ||
        auth.currentPublicKeyHex != _observedOwner) {
      return;
    }
    final account = accounts
        .where((account) => account.pubkeyHex == _owner)
        .firstOrNull;
    if (account == null) {
      _finish(unavailable: true);
      return;
    }
    final publish = context.read<BackgroundPublishBloc>();
    final inFlight = publish.state.uploads
        .where((upload) => upload.result == null)
        .length;
    final l10n = context.l10n;
    final message = [
      l10n.dmNotificationSwitchAccountPrompt(NostrKeyUtils.npubOrHex(_owner)),
      if (inFlight > 0) l10n.settingsUploadInProgressMessage(inFlight),
    ].join('\n\n');
    final agree = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: l10n.settingsSwitchAccount,
      closeSemanticLabel: l10n.commonClose,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(message),
        ),
        Builder(
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              spacing: 8,
              children: [
                DivineButton(
                  label: l10n.settingsSwitchAccount,
                  expanded: true,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
                DivineButton(
                  label: l10n.commonCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    if (!mounted ||
        !_active ||
        !_atHost ||
        auth.currentPublicKeyHex != _observedOwner) {
      return;
    }
    if (agree != true) {
      _finish();
      return;
    }
    final intent = widget.intent;
    final target = intent.target;
    final switchAccount = ref.read(dmPushAccountSwitchProvider);
    await publish.parkInFlight();
    if (!mounted ||
        !_active ||
        !_atHost ||
        auth.currentPublicKeyHex != _observedOwner) {
      return;
    }
    _confirmingSwitch = true;
    final next = await switchAccount(account);
    intent.finished = true;
    if (!intent.superseded &&
        next != null &&
        next.read(authServiceProvider).currentPublicKeyHex ==
            target.receiverPubkey) {
      openDmPush(next, target);
    }
  }

  @override
  void dispose() {
    widget.intent._onCancel = null;
    _router.routeInformationProvider.removeListener(_onLocation);
    _timeout?.cancel();
    _session?.close();
    unawaited(_lookup?.cancel());
    widget.intent.finished = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
