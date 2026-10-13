// ABOUTME: Metadata of a combined sticker layer: the stickers (or earlier
// ABOUTME: combinations) it holds and where each one sits inside it.

import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show StickerData;

/// Key under which a combined sticker layer's meta stores its group.
const stickerGroupMetaKey = 'stickerGroup';

/// Whether [meta] belongs to a sticker layer: a single sticker, whose meta is
/// its `StickerData` json, or a combined one.
bool isStickerLayerMeta(Map<String, dynamic>? meta) =>
    StickerGroupData.isStickerGroupMeta(meta) ||
    meta?['networkUrl'] is String ||
    meta?['assetPath'] is String;

/// Several stickers combined into one `WidgetLayer`.
///
/// Stored in the layer's `exportConfigs.meta` (and `Layer.meta`) as
/// `{stickerGroupMetaKey: toJson()}`, so the editor's widget loader can
/// rebuild it after a draft round-trip the same way it rebuilds a single
/// sticker.
class StickerGroupData extends Equatable {
  const StickerGroupData({required this.size, required this.children});

  /// Reads a group from [json], as written by [toJson].
  ///
  /// Throws a [TypeError] or [FormatException] when [json] is not a group.
  factory StickerGroupData.fromJson(Map<String, dynamic> json) {
    final children = json['children'];
    if (children is! List || children.isEmpty) {
      throw const FormatException('A sticker group needs children');
    }
    return StickerGroupData(
      size: Size(_double(json['width']), _double(json['height'])),
      children: [
        for (final child in children)
          StickerGroupChild.fromJson(_jsonMap(child)),
      ],
    );
  }

  /// The group's box at layer scale 1, in the canvas units the layers are
  /// laid out in. Every child is placed inside it.
  final Size size;

  /// The combined stickers, bottom-most first.
  final List<StickerGroupChild> children;

  /// Whether [meta] describes a combined sticker layer.
  static bool isStickerGroupMeta(Map<String, dynamic>? meta) =>
      meta?[stickerGroupMetaKey] is Map;

  /// The group stored in [meta], or `null` when [meta] holds none or cannot
  /// be read.
  static StickerGroupData? fromMeta(Map<String, dynamic>? meta) {
    if (!isStickerGroupMeta(meta)) return null;
    try {
      return StickerGroupData.fromJson(_jsonMap(meta![stickerGroupMetaKey]));
    } on Object {
      // A damaged group renders as nothing rather than breaking the editor,
      // the same way a widget layer without meta does.
      return null;
    }
  }

  /// The map stored in a combined sticker layer's meta.
  Map<String, dynamic> toMeta() => {stickerGroupMetaKey: toJson()};

  Map<String, dynamic> toJson() => {
    'width': size.width,
    'height': size.height,
    'children': [for (final child in children) child.toJson()],
  };

  /// Every sticker in the group, nested groups included, in paint order.
  List<StickerData> get stickers => [
    for (final child in children)
      if (child.group case final group?) ...group.stickers else child.sticker!,
  ];

  /// How many single stickers the group shows, nested groups included.
  int get stickerCount => children.fold(
    0,
    (count, child) => count + (child.group?.stickerCount ?? 1),
  );

  @override
  List<Object?> get props => [size, children];
}

/// One entry of a [StickerGroupData]: a sticker, or an earlier combination,
/// placed the way its layer was on the canvas when it was combined.
class StickerGroupChild extends Equatable {
  const StickerGroupChild({
    required this.center,
    required this.size,
    this.sticker,
    this.group,
    this.rotation = 0,
    this.flipX = false,
    this.flipY = false,
    this.opacity = 1,
  }) : assert(
         (sticker == null) != (group == null),
         'A child is either a sticker or a group',
       );

  factory StickerGroupChild.fromJson(Map<String, dynamic> json) {
    final sticker = json['sticker'];
    final group = json['group'];
    return StickerGroupChild(
      sticker: sticker == null ? null : StickerData.fromJson(_jsonMap(sticker)),
      group: group == null ? null : StickerGroupData.fromJson(_jsonMap(group)),
      center: Offset(_double(json['x']), _double(json['y'])),
      size: Size(_double(json['width']), _double(json['height'])),
      rotation: _double(json['rotation']),
      flipX: json['flipX'] == true,
      flipY: json['flipY'] == true,
      opacity: json['opacity'] == null ? 1 : _double(json['opacity']),
    );
  }

  /// The single sticker this child shows, or `null` for a nested [group].
  final StickerData? sticker;

  /// The earlier combination this child shows, or `null` for a [sticker].
  final StickerGroupData? group;

  /// Centre of the child, measured from the group box's top-left corner.
  final Offset center;

  /// The child's size before [rotation], with its layer scale applied.
  final Size size;

  /// Rotation around [center], in radians.
  final double rotation;

  /// Whether the child is mirrored horizontally.
  final bool flipX;

  /// Whether the child is mirrored vertically.
  final bool flipY;

  /// The child's opacity, between 0 and 1.
  final double opacity;

  Map<String, dynamic> toJson() => {
    if (sticker case final sticker?) 'sticker': sticker.toJson(),
    if (group case final group?) 'group': group.toJson(),
    'x': center.dx,
    'y': center.dy,
    'width': size.width,
    'height': size.height,
    if (rotation != 0) 'rotation': rotation,
    if (flipX) 'flipX': true,
    if (flipY) 'flipY': true,
    if (opacity != 1) 'opacity': opacity,
  };

  @override
  List<Object?> get props => [
    sticker,
    group,
    center,
    size,
    rotation,
    flipX,
    flipY,
    opacity,
  ];
}

double _double(Object? value) => switch (value) {
  final num number => number.toDouble(),
  null => 0,
  _ => throw FormatException('Expected a number, got $value'),
};

Map<String, dynamic> _jsonMap(Object? value) => switch (value) {
  final Map<String, dynamic> map => map,
  _ => throw FormatException('Expected a JSON object, got $value'),
};
