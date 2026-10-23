/// Constants shared by the notification list-item widgets and the
/// type-icon / avatar-stack primitives.
class NotificationConstants {
  /// Diameter of an actor avatar rendered inside a notification row.
  static const double avatarSize = 32;

  /// Corner radius for a notification avatar (Figma: 0.4 × [avatarSize]).
  static const double avatarCornerRadius = 12.8;

  /// Most avatars a grouped row stacks before showing an overflow count.
  static const int maxStackedAvatars = 3;

  /// Empirical breakpoint where 320px-wide video notification rows start
  /// clipping once the trailing thumbnail shares the main row.
  static const double largeTextStackThreshold = 1.33;

  /// Empirical breakpoint where 320px-wide actor notification rows start
  /// clipping once the Follow back button shares the avatar row.
  static const double actorRowLargeTextStackThreshold = 1.15;
}
