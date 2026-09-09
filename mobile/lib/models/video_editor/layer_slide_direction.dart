// ABOUTME: The eight slide directions the layer-animation picker offers, and
// ABOUTME: how each decomposes into pro_video_editor's axis-aligned directions.

import 'package:pro_video_editor/pro_video_editor.dart' show SlideDirection;

/// A direction a layer can slide from (enter) or toward (leave), including the
/// four diagonals that pro_video_editor's [SlideDirection] cannot name.
///
/// pro_video_editor models a slide as a single canvas edge, so a diagonal has
/// no single-animation spelling. It does not need one: every renderer *sums*
/// the offsets of all slide animations on a layer, so one horizontal plus one
/// vertical slide — same phase, duration and curve — composes into a corner
/// slide. The three implementations that have to agree all do:
///
/// * the in-editor preview accumulates into `slideAbsolute` / `slideFractional`
///   (pro_image_editor `layer_timeline_visibility.dart`),
/// * the Android export accumulates into `offsetX` / `offsetY`
///   (pro_video_editor `ApplyAnimation.kt`),
/// * the iOS export chains `CGAffineTransform.translatedBy`
///   (pro_video_editor `ApplyAnimation.swift`).
///
/// The iOS chaining is order-sensitive — a translation applied after a scale is
/// scaled with it — so a slide's components must be emitted before any scale
/// animation of the same phase, which is what the picker's fixed
/// fade → slide → scale emission order guarantees.
enum LayerSlideDirection {
  /// Enters from / leaves toward the left edge.
  left(horizontal: SlideDirection.left),

  /// Enters from / leaves toward the right edge.
  right(horizontal: SlideDirection.right),

  /// Enters from / leaves toward the top edge.
  up(vertical: SlideDirection.top),

  /// Enters from / leaves toward the bottom edge.
  down(vertical: SlideDirection.bottom),

  /// Enters from / leaves toward the top-left corner.
  upLeft(horizontal: SlideDirection.left, vertical: SlideDirection.top),

  /// Enters from / leaves toward the top-right corner.
  upRight(horizontal: SlideDirection.right, vertical: SlideDirection.top),

  /// Enters from / leaves toward the bottom-left corner.
  downLeft(horizontal: SlideDirection.left, vertical: SlideDirection.bottom),

  /// Enters from / leaves toward the bottom-right corner.
  downRight(horizontal: SlideDirection.right, vertical: SlideDirection.bottom);

  const LayerSlideDirection({this.horizontal, this.vertical});

  /// The horizontal component, or `null` for a purely vertical direction.
  final SlideDirection? horizontal;

  /// The vertical component, or `null` for a purely horizontal direction.
  final SlideDirection? vertical;

  /// Whether this direction travels on both axes at once.
  bool get isDiagonal => horizontal != null && vertical != null;

  /// The plugin directions to emit for this direction: one slide animation for
  /// an edge, two (horizontal first) for a corner.
  ///
  /// Horizontal first only so the emitted order is deterministic; the renderers
  /// sum the components, so the order between them carries no meaning.
  List<SlideDirection> get components => <SlideDirection>[
    ?horizontal,
    ?vertical,
  ];

  /// Rebuilds the direction from the [SlideDirection]s of a phase's slide
  /// animations, or `null` when [components] carries no direction.
  ///
  /// The first entry per axis wins, so a list that names one axis twice (or
  /// contradicts itself with `left` and `right`) still resolves rather than
  /// throwing — the picker edits a single direction per phase, and animations
  /// composed elsewhere must survive a round-trip through it.
  static LayerSlideDirection? fromComponents(
    Iterable<SlideDirection> components,
  ) {
    SlideDirection? horizontal;
    SlideDirection? vertical;
    for (final component in components) {
      switch (component) {
        case SlideDirection.left:
        case SlideDirection.right:
          horizontal ??= component;
        case SlideDirection.top:
        case SlideDirection.bottom:
          vertical ??= component;
      }
    }
    if (horizontal == null && vertical == null) return null;
    return values.firstWhere(
      (direction) =>
          direction.horizontal == horizontal && direction.vertical == vertical,
    );
  }
}
