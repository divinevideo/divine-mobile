// ABOUTME: Upper bounds on the system text scale for layouts whose size is
// ABOUTME: fixed by something other than the text they contain.

/// Caps applied via `MediaQuery.withClampedTextScaling` around subtrees that
/// cannot absorb unbounded growth.
///
/// A cap still honours the user's font-size preference — it just stops
/// where the layout breaks. Prefer one over `TextScaler.noScaling`, which
/// ignores the preference outright.
///
/// Icons are capped separately and globally by `DivineIcon.maxScaleFactor`;
/// the values here bound the *labels* those icons sit beside. Where both
/// apply the tighter of the two wins, so a subtree capped below the icon
/// bound scales its icons to the subtree's cap.
library;

/// Rows of fixed height whose width is shared between a label and
/// fixed-size chrome: the bottom nav, content-filter rows, the trending
/// hashtag strip, category tiles.
///
/// These have the least room — the height is set by the bar, not the text,
/// so growth spills rather than pushing the row taller.
const fixedRowTextScaleLimit = 1.25;

/// Columns of icon-with-caption buttons overlaid on video.
///
/// Matches `DivineIcon.maxScaleFactor` so the caption and the icon above it
/// stop growing together; past that the column starts overlapping the
/// video's own controls.
const overlayActionColumnTextScaleLimit = 1.3;

/// Display numerals drawn over the camera preview, such as the recorder's
/// countdown.
///
/// They start several times larger than body text. Growing further only covers
/// more of the preview, and at the largest sizes a two-digit count stretches
/// across a small phone and over the controls at its sides.
const overlayNumeralTextScaleLimit = 1.3;

/// Labels inside a pill or chip that can grow somewhat before the
/// surrounding controls collide.
const chipLabelTextScaleLimit = 1.4;

/// Numeric stats in a divided row.
///
/// The loosest bound here: the digits carry the meaning, each column is
/// `Expanded` so growth is shared, and the label below fades rather than
/// overflowing.
const statColumnTextScaleLimit = 1.5;
