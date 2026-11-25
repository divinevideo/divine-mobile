// ABOUTME: Account-scoped handoff of an already validated wrap tap to Messages.
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
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
import 'package:openvine/utils/nostr_key_utils.dart';

/// Held in memory for coalescing OS callbacks. A route never carries the wrap
/// or recipient in its URL. The 10 second deadline includes DM initialization.
class DmPushIntent {
  DmPushIntent(this.target);
  final OpenDirectMessageTarget target;
  final clock = Stopwatch()..start();
  String? destination;
  bool finished = false;
  bool superseded = false;
  VoidCallback? _onCancel;

  void cancel() {
    superseded = true;
    _onCancel?.call();
  }

  Duration get remaining => const Duration(seconds: 10) - clock.elapsed;
}

final _lastTap = Expando<DmPushIntent>('DM notification tap');

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

/// A closed conversation can be opened again by tapping the notification.
void openDmPush(ProviderContainer container, OpenMessagesTarget target) {
  final router = container.read(goRouterProvider);
  final inbox = const InboxRouteData(messages: true).location;
  if (target is! OpenDirectMessageTarget) {
    cancelPendingDmPush(container);
    router.go(inbox);
    return;
  }
  final previous = _lastTap[container];
  final matches = router.routerDelegate.currentConfiguration;
  final top = matches.isEmpty ? null : matches.last;
  final current = top is ImperativeRouteMatch
      ? top.matches.uri.toString()
      : router.routeInformationProvider.value.uri.toString();
  if (previous?.target == target &&
      (current == previous?.destination ||
          (current == inbox && !(previous?.finished ?? true)))) {
    return;
  }
  cancelPendingDmPush(container);
  final intent = DmPushIntent(target);
  _lastTap[container] = intent;
  router.go(inbox, extra: intent);
}

/// Mounted inside the existing Messages entry. Its children and the normal
/// protected-minor gates remain usable while ingest catches up.
class DmPushListener extends ConsumerStatefulWidget {
  const DmPushListener({required this.intent, required this.child, super.key});
  final DmPushIntent intent;
  final Widget child;

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
  bool get _atInbox =>
      _router.routeInformationProvider.value.uri.path ==
      const InboxRouteData().location;
  String get _owner => widget.intent.target.receiverPubkey;

  @override
  void initState() {
    super.initState();
    widget.intent._onCancel = _finish;
    _router = ref.read(goRouterProvider);
    _router.routeInformationProvider.addListener(_onLocation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active && _atInbox) unawaited(_begin());
    });
  }

  void _onLocation() {
    if (!_atInbox && !_confirmingSwitch) _finish();
  }

  void _finish({bool unavailable = false}) {
    if (widget.intent.finished) return;
    widget.intent.finished = true;
    _timeout?.cancel();
    _session?.close();
    unawaited(_lookup?.cancel());
    if (unavailable && mounted && _atInbox) {
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
      _timeout = Timer(
        widget.intent.remaining,
        () => _finish(unavailable: true),
      );
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
        !_atInbox ||
        ref.read(authServiceProvider).currentPublicKeyHex != _owner) {
      return;
    }
    if (result is DmWrapPending) return;
    if (result is! DmWrapFound) {
      _finish(unavailable: true);
      return;
    }
    // Observe all eligibility changes until the last synchronous navigation
    // decision. The destination applies its live protected-minor gate as well.
    if (ref.read(isDmRestrictedProvider) &&
        !result.participants.every(
          ref.read(officialAccountsServiceProvider).isReadableByProtectedMinor,
        )) {
      _finish(unavailable: true);
      return;
    }
    final location = result.isRequest
        ? RequestPreviewRouteData(id: result.conversationId).location
        : ConversationRouteData(
            id: result.conversationId,
            messageId: result.messageId,
          ).location;
    widget.intent.destination = location;
    _finish();
    unawaited(_router.push<void>(location));
  }

  Future<void> _offerSwitch() async {
    final auth = ref.read(authServiceProvider);
    final accounts = await auth.getKnownAccounts();
    if (!mounted ||
        !_active ||
        !_atInbox ||
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
        !_atInbox ||
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
        !_atInbox ||
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
