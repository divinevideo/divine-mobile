// ABOUTME: Callback and factory port typedefs injected into AuthService.
// ABOUTME: Re-exported by auth_service.dart, like its sibling auth contracts.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Callback to pre-fetch following list from REST API before auth state is set.
///
/// Called during login setup to populate SharedPreferences cache so the
/// router redirect has accurate following data before it fires synchronously.
typedef PreFetchFollowingCallback = Future<void> Function(String pubkeyHex);

/// Port for launching the NIP-46 bunker auth URL in an external browser.
///
/// Returns whether the URL could be launched. Wired in the app layer to
/// url_launcher so this service carries no Flutter-plugin dependency for the
/// launch; when unset (tests), the auth URL is logged as unlaunchable instead
/// of hitting a platform channel.
typedef AuthUrlLauncher = Future<bool> Function(Uri url);

/// Callback invoked before AuthService clears the outgoing session identity.
typedef BeforeSessionTeardownCallback = Future<void> Function();

/// Factory for NIP-46 remote signers. Injected in tests so startup restore can
/// exercise unreachable signer behavior without opening relay sockets.
typedef RemoteSignerFactory = NostrRemoteSigner Function(
  int relayMode,
  NostrRemoteSignerInfo info,
);
