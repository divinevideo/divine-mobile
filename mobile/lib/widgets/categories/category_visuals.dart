// ABOUTME: Shared visual metadata for featured and fallback category presentation.
// ABOUTME: Keeps the categories discovery list and gallery screens visually consistent.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoCategory;

/// A category's [DivineSticker] and where design placed it in the list tile.
///
/// The sticker is drawn in a [size] square that is larger than the tile's
/// sticker slot, turned by [rotationDegrees] clockwise, and moved by [offset]
/// from the slot's centre. It bleeds past the tile, which clips it.
class CategorySticker {
  const CategorySticker(
    this.name, {
    required this.size,
    this.rotationDegrees = 0,
    this.offset = Offset.zero,
  });

  final DivineStickerName name;
  final double size;
  final double rotationDegrees;

  /// Offset from the slot's centre in a left-to-right layout. The horizontal
  /// part is mirrored in right-to-left layouts.
  final Offset offset;
}

class CategoryVisuals {
  const CategoryVisuals({
    required this.backgroundColor,
    required this.foregroundColor,
    this.assetPath,
    this.sticker,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final String? assetPath;

  /// The sticker design chose for this category, or `null` when it has none
  /// and callers fall back to [assetPath] and then the category emoji.
  final CategorySticker? sticker;

  /// Resolves visuals for any category. Featured categories get custom colors;
  /// all others cycle through fallback colors. A category with a designed
  /// sticker also gets its [sticker]. Every asset path — featured or
  /// derived from the name — resolves through [bundledAssetBasenames], so it
  /// only points at an asset that is actually bundled.
  ///
  /// Backend category names are an open-ended, uncurated stream (#2547), so a
  /// name can arrive with no matching `assets/categories/<name>.svg`. In that
  /// case [assetPath] is `null` and callers degrade to the category emoji.
  /// Resolving to `null` here — rather than pointing at a missing file and
  /// relying on [CategoryGlyph]'s `errorBuilder` — is what keeps the load from
  /// ever being attempted: a missing-asset load surfaces the failure to the
  /// zone as a non-fatal even when `errorBuilder` handles the visual (#6116).
  factory CategoryVisuals.forCategory(VideoCategory category, int index) {
    final name = category.name.toLowerCase();
    final featured = _featuredCategoryVisuals[name];
    if (featured != null) {
      return CategoryVisuals(
        backgroundColor: featured.backgroundColor,
        foregroundColor: featured.foregroundColor,
        assetPath: _bundledAssetPathOrNull(featured.assetBasename),
        sticker: _categoryStickers[name],
      );
    }
    final fallback =
        _fallbackCategoryVisuals[index % _fallbackCategoryVisuals.length];
    return CategoryVisuals(
      backgroundColor: fallback.backgroundColor,
      foregroundColor: fallback.foregroundColor,
      assetPath: _bundledAssetPathOrNull(_assetNameAliases[name] ?? name),
      sticker: _categoryStickers[name],
    );
  }

  static String? _bundledAssetPathOrNull(String basename) =>
      bundledAssetBasenames.contains(basename)
      ? 'assets/categories/$basename.svg'
      : null;

  /// Names of the featured categories, exposed so tests can pin every curated
  /// asset basename to [bundledAssetBasenames].
  @visibleForTesting
  static List<String> get featuredCategoryNames =>
      _featuredCategoryVisuals.keys.toList();

  /// Basenames (without extension) of every SVG bundled under
  /// `assets/categories/`. Used to decide whether a derived asset path points
  /// at a real file before handing it to [CategoryGlyph]. Kept in sync with the
  /// directory by `category_visuals_test.dart`, which fails if the two diverge.
  ///
  /// Public only for that drift-guard test; production code goes through
  /// [forCategory].
  @visibleForTesting
  static const bundledAssetBasenames = <String>{
    'action',
    'adventure',
    'animals',
    'animation',
    'architecture',
    'art',
    'automotive',
    'award-show',
    'awards',
    'baseball',
    'basketball',
    'beauty',
    'beverage',
    'cars',
    'celebration',
    'celebrities',
    'celebrity',
    'cityscape',
    'comedy',
    'concert',
    'cooking',
    'costume',
    'crafts',
    'crime',
    'culture',
    'dance',
    'diy',
    'drama',
    'education',
    'emotional',
    'emotions',
    'entertainment',
    'event',
    'family',
    'fans',
    'fantasy',
    'fashion',
    'festival',
    'film',
    'fitness',
    'food',
    'football',
    'furniture',
    'gaming',
    'golf',
    'grooming',
    'guitar',
    'halloween',
    'health',
    'hockey',
    'holiday',
    'home',
    'home-improvement',
    'horror',
    'hospital',
    'humor',
    'interior-design',
    'interview',
    'kids',
    'lifestyle',
    'magic',
    'makeup',
    'medical',
    'music',
    'mystery',
    'nature',
    'news',
    'outdoor',
    'party',
    'people',
    'performance',
    'pets',
    'politics',
    'prank',
    'pranks',
    'reality-show',
    'relationship',
    'relationships',
    'romance',
    'school',
    'science-fiction',
    'selfie',
    'shopping',
    'skateboarding',
    'skincare',
    'soccer',
    'social-gathering',
    'social-media',
    'sports',
    'style',
    'talk-show',
    'technology',
    'television',
    'toys',
    'transportation',
    'travel',
    'urban',
    'violence',
    'vlog',
    'vlogging',
    'wrestling',
  };
}

/// The sticker placed on each category in the Explore category list, keyed by
/// backend slug, with its size, angle and offset for a 64 px slot. Most
/// placements are the Figma values. Food and dance keep the slot Figma gave
/// their earlier sticker; music, art, nature, fitness and the categories the
/// backend added later (animation, beauty, pets, automotive and pranks) carry
/// stickers the reference does not show, placed in the same style. The horse
/// turns less than in Figma so the cut edge of its neck stays below the tile.
/// A category missing here keeps its SVG or emoji glyph.
const _categoryStickers = <String, CategorySticker>{
  'animals': CategorySticker(
    DivineStickerName.horse,
    size: 115,
    rotationDegrees: 4,
    offset: Offset(7.5, 0),
  ),
  'food': CategorySticker(
    DivineStickerName.pizzaSlice,
    size: 116,
    offset: Offset(-0.5, 12),
  ),
  'sports': CategorySticker(
    DivineStickerName.foamFinger,
    size: 129,
    rotationDegrees: -17.5,
    offset: Offset(-2, -3),
  ),
  // The backend calls this category fashion and the app displays it as Style.
  'fashion': CategorySticker(
    DivineStickerName.sunglasses,
    size: 127,
    rotationDegrees: -3.83,
    offset: Offset(16.5, -1.5),
  ),
  'music': CategorySticker(
    DivineStickerName.djController,
    size: 147,
    rotationDegrees: -8,
    offset: Offset(8, -2),
  ),
  'art': CategorySticker(
    DivineStickerName.ceramicHands,
    size: 118,
    rotationDegrees: 6,
    offset: Offset(8, -2),
  ),
  'entertainment': CategorySticker(
    DivineStickerName.psychedelicTv,
    size: 120,
    rotationDegrees: 5.31,
    offset: Offset(9.5, -19.5),
  ),
  'family': CategorySticker(
    DivineStickerName.toaster,
    size: 117,
    offset: Offset(8, 0),
  ),
  'comedy': CategorySticker(
    DivineStickerName.chatteringTeeth,
    size: 114,
    rotationDegrees: -9.64,
    offset: Offset(14, -5.5),
  ),
  'dance': CategorySticker(
    DivineStickerName.discoBall,
    size: 112,
    rotationDegrees: 8,
    offset: Offset(7.5, -5),
  ),
  'travel': CategorySticker(
    DivineStickerName.luggage,
    size: 107,
    offset: Offset(8, -0.5),
  ),
  'education': CategorySticker(
    DivineStickerName.schoolBackpack,
    size: 108,
    rotationDegrees: -10.79,
    offset: Offset(7.5, -7),
  ),
  'gaming': CategorySticker(
    DivineStickerName.gameController,
    size: 124,
    rotationDegrees: -15,
    offset: Offset(7, -4),
  ),
  'news': CategorySticker(
    DivineStickerName.newsCamera,
    size: 122,
    offset: Offset(9.5, -1.5),
  ),
  'nature': CategorySticker(
    DivineStickerName.rainforest,
    size: 118,
    offset: Offset(8, 0),
  ),
  'fitness': CategorySticker(
    DivineStickerName.pinkDumbbells,
    size: 120,
    rotationDegrees: -12,
    offset: Offset(8, -2),
  ),
  'animation': CategorySticker(
    DivineStickerName.videoClapBoard,
    size: 118,
    rotationDegrees: -8,
    offset: Offset(8, -2),
  ),
  'beauty': CategorySticker(
    DivineStickerName.glitterLips,
    size: 128,
    rotationDegrees: 6,
    offset: Offset(10, 0),
  ),
  'pets': CategorySticker(
    DivineStickerName.cat,
    size: 116,
    offset: Offset(8, 0),
  ),
  'automotive': CategorySticker(
    DivineStickerName.flatTire,
    size: 116,
    rotationDegrees: -10,
    offset: Offset(8, -2),
  ),
  'pranks': CategorySticker(
    DivineStickerName.boom,
    size: 132,
    rotationDegrees: -6,
    offset: Offset(10, -2),
  ),
};

/// Maps backend category slugs onto the bundled SVG asset basename when the two
/// diverge. Keeps the asset path pointing at a file that exists (#4398); any
/// slug not covered here still degrades safely via [CategoryGlyph]'s emoji
/// fallback.
const _assetNameAliases = <String, String>{
  // Backend emits the plural; only beverage.svg is bundled.
  'beverages': 'beverage',
};

/// Curated colors plus the bundled-SVG basename for a featured category. The
/// basename resolves through the same [CategoryVisuals.bundledAssetBasenames]
/// gate as derived names, so a featured entry can never point at a missing
/// file (#6116).
typedef _FeaturedVisuals = ({
  Color backgroundColor,
  Color foregroundColor,
  String assetBasename,
});

const _featuredCategoryVisuals = <String, _FeaturedVisuals>{
  'animals': (
    backgroundColor: Color(0xFF3E0C1F),
    foregroundColor: Color(0xFFFF7FAF),
    assetBasename: 'animals',
  ),
  'food': (
    backgroundColor: Color(0xFF272F0E),
    foregroundColor: Color(0xFFD2FF40),
    assetBasename: 'food',
  ),
  'nature': (
    backgroundColor: Color(0xFF231557),
    foregroundColor: Color(0xFF8568FF),
    assetBasename: 'nature',
  ),
  'sports': (
    backgroundColor: Color(0xFF471F10),
    foregroundColor: Color(0xFFFF7640),
    assetBasename: 'sports',
  ),
  'fashion': (
    backgroundColor: Color(0xFF0A223C),
    foregroundColor: Color(0xFF34BBF1),
    assetBasename: 'style',
  ),
  'music': (
    backgroundColor: Color(0xFF363313),
    foregroundColor: Color(0xFFFFF140),
    assetBasename: 'music',
  ),
  'fitness': (
    backgroundColor: Color(0xFF2D214D),
    foregroundColor: Color(0xFFA3A9FF),
    assetBasename: 'fitness',
  ),
  'art': (
    backgroundColor: Color(0xFF471F10),
    foregroundColor: Color(0xFFFF7640),
    assetBasename: 'art',
  ),
};

const _fallbackCategoryVisuals = <CategoryVisuals>[
  CategoryVisuals(
    backgroundColor: Color(0xFF103023),
    foregroundColor: Color(0xFF7AF0B7),
  ),
  CategoryVisuals(
    backgroundColor: Color(0xFF251C41),
    foregroundColor: Color(0xFFB6A7FF),
  ),
  CategoryVisuals(
    backgroundColor: Color(0xFF1E2C10),
    foregroundColor: Color(0xFFE4FF70),
  ),
  CategoryVisuals(
    backgroundColor: Color(0xFF0E2942),
    foregroundColor: Color(0xFF62CFFF),
  ),
];
