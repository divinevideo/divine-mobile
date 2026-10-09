// ABOUTME: How a DM peer that may be a Divine moderation key is presented.
// ABOUTME: A pure leaf, so the DM layer can name peers without importing the
// ABOUTME: release-pinned account configuration that decides the answer.

/// How the app presents a DM peer that may be a Divine moderation key.
///
/// Official branding follows recorded custody (#9963): the answer comes from
/// `moderationPresentationOf` in `official_accounts.dart`, which the DM layer
/// never imports. It receives the result.
enum ModerationPresentation {
  /// Not a moderation key: present it like any other account.
  ordinary,

  /// Divine's official name and bundled wordmark: the current key, or a
  /// retired key nobody can sign as.
  official,

  /// A retired key someone could still sign as. Official branding is
  /// withdrawn: a neutral "former moderation account" name and the default
  /// avatar, because presenting it as Divine would say the team is on the
  /// other end of a key that someone outside the team may hold.
  former,
}

/// Resolves [ModerationPresentation] for a pubkey. Injected into the BLoCs that
/// match on the rendered name, so they agree with the widgets without reading
/// the register themselves.
typedef ModerationPresentationResolver = ModerationPresentation Function(
  String pubkeyHex,
);
