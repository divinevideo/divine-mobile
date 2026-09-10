// ABOUTME: Type-safe result enum for the More sheet actions
// ABOUTME: Replaces string-based returns for better type safety

/// Type-safe result from the More sheet actions.
///
/// Used to communicate user actions from [MoreSheetContent] back to the caller.
enum MoreSheetResult {
  /// User tapped copy public key.
  copy,

  /// User confirmed unfollow action.
  unfollow,

  /// User tapped report.
  report,

  /// User confirmed block action.
  blockConfirmed,

  /// User confirmed unblock action.
  unblockConfirmed,

  /// User tapped add-to-list (curated lists feature).
  addToList,

  /// User tapped get embed code (own profile only).
  embedCode,
}
