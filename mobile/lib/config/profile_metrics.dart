// ABOUTME: Product thresholds for how profile engagement metrics are shown.
// ABOUTME: Shared by profile, message-request, and feed surfaces.

/// Smallest lifetime loop total a profile shows to visitors.
///
/// Below this the Loops figure is omitted from visitor profile headers,
/// message-request previews, and feed cards: repeatedly showing a small total
/// beside a new creator's name can discourage viewers from watching. Owners
/// still see their own total on their profile header.
///
/// A product call, not a technical one — the single value to change if the
/// bar sits wrong.
///
/// The floor applies to feed cards and message-request previews even when the
/// viewer is the creator. It is a product choice, not a cache or formatting
/// rule.
const int profileLoopsVisibilityFloor = 10000;
