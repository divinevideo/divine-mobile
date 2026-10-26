// ABOUTME: Synthetic local identity adapter shared by consent acceptance runners.
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:openvine/services/auth_service.dart';

class SyntheticConsentSigner extends Fake implements AuthService {
  SyntheticConsentSigner(this.privateKey);
  final String privateKey;

  @override
  bool get isAuthenticated => true;

  @override
  String get currentPublicKeyHex => getPublicKey(privateKey);

  @override
  String get currentNpub => Nip19.encodePubKey(currentPublicKeyHex);

  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  }) async => Event(
    currentPublicKeyHex,
    kind,
    tags ?? [],
    content,
    createdAt: createdAt,
  )..sign(privateKey);
}
