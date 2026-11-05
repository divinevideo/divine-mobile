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

  /// Part of Divine's imported library: published on its own by an account
  /// in [kSoundLibraryPublisherPubkeys]. Like [isDivine] it is curated, so
  /// it carries no community mark, but it gets no Divine boost.
  bool get isLibrary =>
      kSoundLibraryPublisherPubkeys.contains(pubkey) &&
      sourceVideoReference == null;

  /// Published by somebody outside Divine. Divine's own, library and private
  /// sounds sit in the same lists, so a list marks the ones that are.
  bool get isCommunitySound =>
      !isDivine && !isLibrary && attributionEventId != null;
}
