// ABOUTME: Product thresholds for how profile engagement metrics are shown.
// ABOUTME: Shared by the profile header and the message-request preview.

/// Smallest lifetime loop total a profile shows to visitors.
///
/// Below this the Loops figure is omitted for everyone but the owner: a small
/// headline number on a new creator's profile discourages the visitor and
/// tells them nothing useful. Owners always see their own total, since
/// correcting a creator's underestimate of their audience is what keeps them
/// posting.
///
/// A product call, not a technical one — the single value to change if the
/// bar sits wrong.
///
/// Lives here rather than beside one consumer because it now has two: the
/// profile header's Loops column, and the message-request preview's stats
/// line. On the preview the sender is never the viewer, so there is no
/// owner exemption there — the floor always applies.
///
/// The video feed card's lifetime-loops line is deliberately different: it
/// shows the author's total whenever it is known, with no floor, because the
/// line sits beside the author's name and reads as part of their identity
/// rather than as a headline figure about them.
const int profileLoopsVisibilityFloor = 10000;
