// ABOUTME: Cubit backing the RelaySettingsScreen — relay snapshot,
// ABOUTME: NIP-11 capability cache, and the add/remove/retry/restore actions.
// ABOUTME: Validation lives here so the View only renders the result.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_state.dart';
import 'package:openvine/repositories/relay_list_repository.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';

/// Cubit backing `RelaySettingsScreen`.
///
/// Owns:
/// - A snapshot of `nostrClient.configuredRelays` ([RelaySettingsState.relays]),
///   re-snapshotted after every mutation. The pre-migration screen worked
///   around the non-reactive service by calling `setState({})` after add /
///   remove / retry / restore — this is the principled replacement.
/// - A per-relay NIP-11 capability cache ([RelaySettingsState.capabilities])
///   that mirrors the pre-migration `_capabilitiesCache` /
///   `_capabilitiesLoading` map pair.
///
/// Transient action outcomes (`added` / `invalidUrl` / `failed` /
/// `removed` / etc.) flow back through the `Future<…Outcome>` return
/// values — same `Future<Result>`-return template as #4794. The View picks
/// localized snackbar copy based on the outcome instead of state having to
/// carry error strings.
///
/// URL validation (scheme + loopback carve-out for `ws://`) lives in the
/// Cubit so it's testable without pumping the View.
class RelaySettingsCubit extends Cubit<RelaySettingsState> {
  RelaySettingsCubit({
    required NostrClient nostrClient,
    required RelayListRepository relayListRepository,
    required RelayCapabilityService relayCapabilityService,
    required VideoEventService videoEventService,
  }) : _nostrClient = nostrClient,
       _relayListRepository = relayListRepository,
       _relayCapabilityService = relayCapabilityService,
       _videoEventService = videoEventService,
       super(const RelaySettingsState());

  final NostrClient _nostrClient;
  final RelayListRepository _relayListRepository;
  final RelayCapabilityService _relayCapabilityService;
  final VideoEventService _videoEventService;

  /// The environment default relay URL (e.g. the staging relay on staging),
  /// used by the View to name the relay in the restore-default confirmation.
  String get defaultRelayUrl => _nostrClient.defaultRelayUrl;

  void load() {
    emit(state.copyWith(relays: _nostrClient.configuredRelays));
  }

  /// Re-snapshot the relay list from the service. Called after each mutation
  /// so the View's relay list rebuilds without `setState({})`.
  void refreshRelays() {
    emit(state.copyWith(relays: _nostrClient.configuredRelays));
  }

  /// Fetch NIP-11 capabilities for [relayUrl] once.
  ///
  /// No-op when a fetch is already in flight or completed — matches the
  /// pre-migration `_capabilitiesLoading[..] == true` /
  /// `_capabilitiesCache.containsKey(..)` short-circuits.
  Future<void> fetchCapabilities(String relayUrl) async {
    final existing = state.capabilities[relayUrl];
    if (existing != null && (existing.loading || existing.fetched)) return;

    _setEntry(relayUrl, const RelayCapabilityEntry(loading: true));
    try {
      final capabilities = await _relayCapabilityService.getRelayCapabilities(
        relayUrl,
      );
      if (isClosed) return;
      _setEntry(
        relayUrl,
        RelayCapabilityEntry(fetched: true, capabilities: capabilities),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (isClosed) return;
      _setEntry(relayUrl, const RelayCapabilityEntry(fetched: true));
    }
  }

  /// Validate + add [relayUrl] to the service. Returns an outcome the View
  /// maps to localized snackbar copy.
  Future<AddRelayOutcome> addRelay(String relayUrl) async {
    final trimmed = relayUrl.trim();
    if (trimmed.isEmpty) return AddRelayOutcome.invalidUrl;

    // Relays are WebSocket-only. Anything else is structurally invalid;
    // `ws://` against a non-loopback host is the separate "insecure" case
    // (#3362).
    final uri = Uri.tryParse(trimmed);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'wss' && scheme != 'ws') return AddRelayOutcome.invalidUrl;
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return AddRelayOutcome.invalidUrl;
    }
    if (!isRelayUrlAllowed(trimmed)) return AddRelayOutcome.insecureUrl;

    try {
      final success = await _nostrClient.addRelay(
        trimmed,
        source: RelayAddSource.user,
      );
      refreshRelays();
      if (!success) {
        if (!_hasRelayConfigured(trimmed)) return AddRelayOutcome.failed;
        return await _publishRelayListAfterLocalChange()
            ? AddRelayOutcome.addedConnectionPending
            : AddRelayOutcome.addedConnectionPendingLocalOnly;
      }
      return await _publishRelayListAfterLocalChange()
          ? AddRelayOutcome.added
          : AddRelayOutcome.addedLocalOnly;
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      return AddRelayOutcome.failed;
    }
  }

  Future<RemoveRelayOutcome> removeRelay(String relayUrl) async {
    try {
      final success = await _nostrClient.removeRelay(
        relayUrl,
        source: RelayRemoveSource.user,
      );
      refreshRelays();
      // A `false` return only means "nothing to remove"; the relay is gone
      // either way unless it is still configured.
      if (!success && _hasRelayConfigured(relayUrl)) {
        return RemoveRelayOutcome.failed;
      }
      return await _publishRelayListAfterLocalChange()
          ? RemoveRelayOutcome.removed
          : RemoveRelayOutcome.removedLocalOnly;
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      return RemoveRelayOutcome.failed;
    }
  }

  Future<RestoreDefaultRelayOutcome> restoreDefaultRelay() async {
    try {
      final success = await _nostrClient.addRelay(
        defaultRelayUrl,
        source: RelayAddSource.user,
      );
      refreshRelays();
      if (!success) {
        if (!_hasDefaultRelayConfigured()) {
          return RestoreDefaultRelayOutcome.failed;
        }
        return await _publishRelayListAfterLocalChange()
            ? RestoreDefaultRelayOutcome.restoredConnectionPending
            : RestoreDefaultRelayOutcome.restoredConnectionPendingLocalOnly;
      }
      return await _publishRelayListAfterLocalChange()
          ? RestoreDefaultRelayOutcome.restored
          : RestoreDefaultRelayOutcome.restoredLocalOnly;
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      return RestoreDefaultRelayOutcome.failed;
    }
  }

  Future<RetryConnectionOutcome> retryConnection() async {
    try {
      final outcome = await _nostrClient.forceReconnectAll();
      final connectedCount = _nostrClient.connectedRelayCount;
      if (connectedCount > 0) {
        await _videoEventService.resetAndResubscribeAll();
        return RetryConnectionOutcome.connected(connectedCount);
      }
      // Nothing connected YET is only a failure once the cycle has actually
      // finished. A caller that joined shortly before the shared deadline gets
      // here with dials still open, and calling that a failure contradicts the
      // reconnect that is still running.
      if (outcome == ForceReconnectOutcome.stillDialling) {
        return const RetryConnectionOutcome.stillConnecting();
      }
      return const RetryConnectionOutcome.notConnected();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      return const RetryConnectionOutcome.failed();
    }
  }

  void _setEntry(String relayUrl, RelayCapabilityEntry entry) {
    final updated = Map<String, RelayCapabilityEntry>.from(state.capabilities)
      ..[relayUrl] = entry;
    emit(state.copyWith(capabilities: updated));
  }

  bool _hasDefaultRelayConfigured() {
    return _hasRelayConfigured(defaultRelayUrl);
  }

  bool _hasRelayConfigured(String relayUrl) {
    return state.relays.any((relay) => relayUrlsEquivalent(relay, relayUrl));
  }

  Future<bool> _publishRelayListAfterLocalChange() async {
    final result = await _relayListRepository.publishConfiguredRelayList();
    final error = result.error;
    final stackTrace = result.stackTrace;
    if (error != null) {
      addError(error, stackTrace ?? StackTrace.current);
    }
    return !result.localOnly;
  }
}
