// ABOUTME: Product thresholds for how profile engagement metrics are shown.
// ABOUTME: Shared by profile headers and message-request previews.

/// Smallest lifetime loop total a profile shows to visitors.
///
/// Below this the Loops figure is omitted from visitor profile headers and
/// message-request previews: repeatedly showing a small total beside a new
/// creator's name can discourage viewers from watching. Owners still see
/// their own total on their profile header.
///
/// A product call, not a technical one — the single value to change if the
/// bar sits wrong.
///
/// Feed cards do not apply this floor. Their "Total loops:" line shows a
/// known total at any size, because the label removes the ambiguity that made
/// a small bare number read as a warning (#9453).
const int profileLoopsVisibilityFloor = 10000;
