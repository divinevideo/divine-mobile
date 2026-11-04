// MPL-2.0
import 'dart:convert';
import 'dart:typed_data';

import 'package:concord_protocol/src/derivations.dart';

/// CORD-05 generation-four bootstrap material. Tokens unlock a bundle only;
/// neither these relays nor the bundle preview confer community authority.
class ConcordInviteFragment {
  ConcordInviteFragment._(this.token, this.relays);

  factory ConcordInviteFragment.decode(String fragment) {
    final bytes = base64Url.decode(base64Url.normalize(fragment.trim()));
    var offset = 0;
    void need(int count) {
      if (offset + count > bytes.length) {
        throw const FormatException('Concord invite fragment is truncated');
      }
    }

    int read() {
      need(1);
      return bytes[offset++];
    }

    if (read() != 4) {
      throw const FormatException('Unsupported Concord invite version');
    }
    final flags = read();
    const dictionary = {
      1: 'wss://jskitty.com/nostr',
      2: 'wss://asia.vectorapp.io/nostr',
      3: 'wss://relay.ditto.pub',
      4: 'wss://relay.dreamith.to',
    };
    final relays = <String>[];
    if (flags & 1 != 0) {
      relays.addAll(dictionary.values);
    } else {
      final count = read();
      if (count > 3) throw const FormatException('Too many bootstrap relays');
      for (var i = 0; i < count; i++) {
        final lead = read();
        if (lead > 0 && lead < 255) {
          if (dictionary[lead] case final relay?) relays.add(relay);
        } else {
          final length = read();
          need(length);
          final text = utf8.decode(bytes.sublist(offset, offset + length));
          offset += length;
          relays.add(lead == 255 ? text : 'wss://$text');
        }
      }
    }
    need(16);
    final token = Uint8List.fromList(bytes.sublist(offset, offset + 16));
    offset += 16;
    if (offset != bytes.length) {
      throw const FormatException('Trailing Concord invite fragment bytes');
    }
    return ConcordInviteFragment._(token, List.unmodifiable(relays));
  }

  final Uint8List token;
  final List<String> relays;
}

/// Validated membership material. Its name and private-channel previews are
/// cosmetic: only an owner-rooted Control fold may expose a room to the UI.
class ConcordInviteBundle {
  ConcordInviteBundle._(this.raw);

  factory ConcordInviteBundle.fromJson(
    Map<String, dynamic> json, {
    required int nowMs,
  }) {
    String key(String name) {
      final value = json[name];
      if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
        throw FormatException('Invalid Concord bundle $name');
      }
      return value;
    }

    final community = key('community_id');
    final owner = key('owner');
    final salt = key('owner_salt');
    key('community_root');
    if (deriveCommunityId(owner, salt) != community) {
      throw const FormatException('Concord community owner mismatch');
    }
    if (json['control_pk'] != null) key('control_pk');
    final epoch = json['root_epoch'];
    if (epoch is! int || epoch < 0) {
      throw const FormatException('Invalid Concord root epoch');
    }
    final channels = json['channels'];
    if (channels is List && channels.length > 256) {
      throw const FormatException('Too many Concord bundle channels');
    }
    final expires = json['expires_at'];
    if (expires is num && nowMs > expires) {
      throw const FormatException('Concord invite has expired');
    }
    return ConcordInviteBundle._(Map.unmodifiable(json));
  }

  final Map<String, dynamic> raw;
  String get communityId => raw['community_id'] as String;
  String get owner => raw['owner'] as String;
  String get ownerSalt => raw['owner_salt'] as String;
  String get communityRoot => raw['community_root'] as String;
  int get rootEpoch => raw['root_epoch'] as int;
  String? get controlPubkey => raw['control_pk'] as String?;
}

Uint8List inviteBundleKey(List<int> token) {
  if (token.length != 16) throw ArgumentError('Concord invite token size');
  return hkdfSeed(token, 'concord/invite-key', Uint8List(32));
}
