// ABOUTME: The `@mention` alternative shared by the caption tokenizers, so
// ABOUTME: the render path and the publish path cannot drift apart.

/// Matches an `@handle`, capturing the handle without its `@`.
///
/// A dot or hyphen is admitted only when a word character follows it, because
/// Divine handles carry both — a NIP-05 local part allows `.`, `-` and `_` —
/// while a trailing one is sentence punctuation. That keeps `@st.allison.` a
/// mention of `st.allison` plus a period, and holds the handle to 31
/// characters.
///
/// Shared rather than written twice because the render path
/// (`LinkifiedTextSpanBuilder`) and the publish path
/// (`MentionResolutionService`) must tokenize a caption identically: fixing
/// #8717 meant changing this pattern in both, and any later change carries
/// the same lockstep hazard. Both append it last, after URL/email, hashtag,
/// bech32 and bare hex. `notification_repository` deliberately omits a
/// mention alternative and does not consume this.
///
/// Free of backslash escapes, so it needs no `r` prefix and composes into a
/// raw literal unchanged. Restore the prefix if that changes: Dart resolves
/// an unknown escape such as `\w` to the bare letter, silently altering the
/// pattern.
const mentionTokenPattern =
    '@([a-zA-Z](?:[a-zA-Z0-9_]|[.-](?=[a-zA-Z0-9_])){0,30})';
