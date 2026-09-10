// ABOUTME: State for RelaySettingsCubit — configured-relay snapshot plus a
// ABOUTME: per-relay NIP-11 capability cache. Transient action outcomes use
// ABOUTME: Future<Result>-return on the cubit (no error strings in state).

import 'package:equatable/equatable.dart';
import 'package:openvine/services/relay_capability_service.dart';

/// Per-relay NIP-11 capability fetch state.
///
/// `loading` is true while a `fetchCapabilities` call is in flight. Once
/// resolved, `capabilities` is the parsed NIP-11 document, or `null` if the
/// relay didn't respond / responded without a document — both are "fetched"
/// states that should stop the loading spinner.
class RelayCapabilityEntry extends Equatable {
  const RelayCapabilityEntry({
    this.loading = false,
    this.fetched = false,
    this.capabilities,
  });

  final bool loading;

  /// True once a fetch attempt has completed (regardless of result).
  ///
  /// Used to short-circuit re-fetches: the original screen had
  /// `if (_capabilitiesCache.containsKey(relayUrl)) return;` — this flag
  /// preserves that semantic.
  final bool fetched;

  /// Parsed NIP-11 capabilities. `null` after a fetched-but-empty response.
  final RelayCapabilities? capabilities;

  @override
  List<Object?> get props => [loading, fetched, capabilities];
}

/// State for `RelaySettingsCubit`.
///
/// [relays] is a snapshot of `nostrService.configuredRelays` taken at
/// `load()` time and after every mutation. The pre-migration screen worked
/// around the non-reactive service by calling `setState({})` after each
/// add/remove; the Cubit replaces that with a re-snapshot + emit.
class RelaySettingsState extends Equatable {
  const RelaySettingsState({
    this.relays = const [],
    this.capabilities = const {},
  });

  /// Snapshot of `nostrService.configuredRelays`.
  final List<String> relays;

  /// Per-relay capability cache.
  final Map<String, RelayCapabilityEntry> capabilities;

  RelaySettingsState copyWith({
    List<String>? relays,
    Map<String, RelayCapabilityEntry>? capabilities,
  }) {
    return RelaySettingsState(
      relays: relays ?? this.relays,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  @override
  List<Object?> get props => [relays, capabilities];
}

/// Outcome of `RelaySettingsCubit.addRelay(...)`.
enum AddRelayOutcome {
  /// URL parsed and was accepted by the service.
  added,

  /// URL was saved locally, but the account relay list did not publish yet.
  addedLocalOnly,

  /// URL was empty or didn't use a `wss://` / `ws://` scheme.
  invalidUrl,

  /// URL used cleartext `ws://` against a non-loopback host (#3362).
  insecureUrl,

  /// URL was saved, but the relay did not accept a connection yet.
  addedConnectionPending,

  /// URL was saved without a connection and did not publish to the account yet.
  addedConnectionPendingLocalOnly,

  /// The service refused the URL or threw.
  failed,
}

/// Outcome of `RelaySettingsCubit.removeRelay(...)`.
enum RemoveRelayOutcome { removed, removedLocalOnly, failed }

/// Outcome of `RelaySettingsCubit.restoreDefaultRelay()`.
enum RestoreDefaultRelayOutcome {
  restored,
  restoredLocalOnly,
  restoredConnectionPending,
  restoredConnectionPendingLocalOnly,
  failed,
}

/// Outcome of `RelaySettingsCubit.retryConnection()`.
///
/// The View uses [connectedCount] to render the success snackbar (which
/// embeds the count via l10n).
class RetryConnectionOutcome extends Equatable {
  const RetryConnectionOutcome._({required this.kind, this.connectedCount = 0});

  const RetryConnectionOutcome.connected(int count)
    : this._(kind: RetryConnectionOutcomeKind.connected, connectedCount: count);
  const RetryConnectionOutcome.notConnected()
    : this._(kind: RetryConnectionOutcomeKind.notConnected);
  const RetryConnectionOutcome.stillConnecting()
    : this._(kind: RetryConnectionOutcomeKind.stillConnecting);
  const RetryConnectionOutcome.failed()
    : this._(kind: RetryConnectionOutcomeKind.failed);

  final RetryConnectionOutcomeKind kind;
  final int connectedCount;

  @override
  List<Object?> get props => [kind, connectedCount];
}

enum RetryConnectionOutcomeKind {
  /// The reconnect finished and at least one relay is connected.
  connected,

  /// The reconnect finished and nothing connected.
  notConnected,

  /// The reconnect had not finished when we stopped waiting, so nothing is
  /// known yet. Distinct from [notConnected]: reporting a failure here tells
  /// the user the retry failed while it is still succeeding.
  stillConnecting,

  /// The reconnect threw.
  failed,
}
