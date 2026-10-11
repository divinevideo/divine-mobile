// ABOUTME: Attributes raw signer copies before deleting one inactive account.
// ABOUTME: Preserves foreign and uncertain bytes and verifies real absence.

part of 'signer_secure_store.dart';

extension _SignerAccountRemoval on SignerSecureStore {
  Future<void> _clearVerifiedAccount(
    String owner, {
    void Function()? ensureCurrent,
  }) async {
    final canonicalOwner = RegExp(r'^[0-9a-f]{64}$');
    if (!canonicalOwner.hasMatch(owner)) {
      throw ArgumentError.value(owner, 'owner');
    }
    final storage = _storage ?? const FlutterSecureStorage();
    final values = <String, String?>{};
    final unreadable = <String>{};
    var incomplete = false;
    final keys = [
      _kAmberPubkeyKey,
      _kAmberPackageKey,
      _kBunkerInfoKey,
      'keycast_session',
      _kKeycastRefreshTokenKey,
      _kKeycastAuthHandleKey,
      '${_kAmberPubkeyKey}_$owner',
      '${_kAmberPackageKey}_$owner',
      '${_kBunkerInfoKey}_$owner',
      _keycastSessionKey(owner),
    ];
    for (final key in keys) {
      ensureCurrent?.call();
      try {
        values[key] = await storage.read(key: key);
        ensureCurrent?.call();
      } on Object {
        ensureCurrent?.call();
        unreadable.add(key);
        incomplete = true;
      }
    }
    final groups = <List<String>>[];

    void inspectAmber(
      String pubkeyKey,
      String packageKey, {
      bool archive = false,
    }) {
      if (unreadable.contains(pubkeyKey) || unreadable.contains(packageKey)) {
        return;
      }
      final pubkey = values[pubkeyKey];
      final package = values[packageKey];
      if (pubkey == null && package == null) return;
      if (pubkey == null ||
          !canonicalOwner.hasMatch(pubkey) ||
          (package != null && package.isEmpty)) {
        incomplete = true;
        return;
      }
      if (pubkey != owner) {
        // A global foreign owner is legitimate. A foreign record stored under
        // Alice's archive coordinate is contradictory evidence, not Alice's.
        incomplete = incomplete || archive;
        return;
      }
      // Keep the owner marker while a paired package deletion is unverified.
      groups.add([if (package != null) packageKey, pubkeyKey]);
    }

    String? bunkerOwner(String raw) {
      try {
        if (!NostrRemoteSignerInfo.isBunkerUrl(raw)) return null;
        final uri = Uri.parse(raw);
        final owners = uri.queryParametersAll['userPubkey'];
        if (owners == null ||
            owners.length != 1 ||
            !canonicalOwner.hasMatch(owners.single) ||
            !canonicalOwner.hasMatch(uri.host)) {
          return null;
        }
        // Parsing validates the relay contract. Its temporary signing key is
        // never persisted or used to invent the explicit userPubkey owner.
        final info = NostrRemoteSignerInfo.parseBunkerUrl(raw);
        return info.userPubkey == owners.single ? owners.single : null;
      } on Object {
        return null;
      }
    }

    void inspectBunker(String key, {bool archive = false}) {
      if (unreadable.contains(key)) return;
      final raw = values[key];
      if (raw == null) return;
      final actualOwner = bunkerOwner(raw);
      if (actualOwner == null || (archive && actualOwner != owner)) {
        incomplete = true;
      } else if (actualOwner == owner) {
        groups.add([key]);
      }
    }

    KeycastSession? oauthSession(String raw) {
      try {
        final json = jsonDecode(raw);
        if (json is! Map<String, dynamic>) return null;
        final session = KeycastSession.fromJson(json);
        if (!canonicalOwner.hasMatch(session.userPubkey ?? '') ||
            session.bunkerUrl.isEmpty) {
          return null;
        }
        return session;
      } on Object {
        return null;
      }
    }

    final oauthKeys = [
      _kKeycastRefreshTokenKey,
      _kKeycastAuthHandleKey,
      'keycast_session',
    ];
    if (!oauthKeys.any(unreadable.contains) &&
        oauthKeys.any((key) => values[key] != null)) {
      final sessionRaw = values['keycast_session'];
      final session = sessionRaw == null ? null : oauthSession(sessionRaw);
      final refresh = values[_kKeycastRefreshTokenKey];
      final handle = values[_kKeycastAuthHandleKey];
      if (session == null ||
          (refresh != null && refresh != session.refreshToken) ||
          (handle != null && handle != session.authorizationHandle)) {
        incomplete = true;
      } else if (session.userPubkey == owner) {
        // Removing the session last preserves token attribution after failure.
        groups.add(oauthKeys.where((key) => values[key] != null).toList());
      }
    }
    final archiveKey = _keycastSessionKey(owner);
    if (!unreadable.contains(archiveKey) && values[archiveKey] != null) {
      final session = oauthSession(values[archiveKey]!);
      if (session?.userPubkey != owner) {
        incomplete = true;
      } else {
        groups.add([archiveKey]);
      }
    }
    inspectAmber(_kAmberPubkeyKey, _kAmberPackageKey);
    inspectAmber(
      '${_kAmberPubkeyKey}_$owner',
      '${_kAmberPackageKey}_$owner',
      archive: true,
    );
    inspectBunker(_kBunkerInfoKey);
    inspectBunker('${_kBunkerInfoKey}_$owner', archive: true);

    Future<void> verifyUnchanged() async {
      for (final entry in values.entries) {
        ensureCurrent?.call();
        final current = await storage.read(key: entry.key);
        ensureCurrent?.call();
        if (current != entry.value) {
          throw StateError('Signer evidence changed during account removal');
        }
      }
    }

    for (final group in groups) {
      try {
        for (final key in group) {
          await verifyUnchanged();
          ensureCurrent?.call();
          await storage.delete(key: key);
          ensureCurrent?.call();
          final remaining = await storage.read(key: key);
          ensureCurrent?.call();
          if (remaining != null) {
            throw StateError('Account signer removal did not persist');
          }
          values[key] = null;
        }
      } on Object {
        ensureCurrent?.call();
        incomplete = true;
      }
    }
    // Known foreign/unknown raw records must remain byte-for-byte unchanged;
    // owned selected records must remain absent on actual native readback.
    await verifyUnchanged();
    if (incomplete) {
      throw StateError('Account signer removal is incomplete');
    }
  }
}
