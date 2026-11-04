// ABOUTME: Tells Divine's own sounds from the community's: shipped with the
// ABOUTME: app, or published by one of Divine's sound accounts.

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/config/official_accounts.dart';

/// Whether a sound is one of Divine's own.
extension DivineSound on AudioEvent {
  /// Shipped with the app, or published on its own by an account in
  /// [kDivineSoundPublisherPubkeys]. Decided by who signed the event, which
  /// nobody else can forge, rather than by a tag anyone could set. The sound
  /// of a video such an account posted is not one: that is a post like any
  /// other, not part of Divine's library.
  bool get isDivine =>
      isBundled ||
      (kDivineSoundPublisherPubkeys.contains(pubkey) &&
          sourceVideoReference == null);
}
