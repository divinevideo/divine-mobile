// ABOUTME: A text-overlay look saved under a name of the user's choosing, so
// ABOUTME: it can be applied to titles in later videos (#7742).

import 'package:equatable/equatable.dart';
import 'package:openvine/models/video_editor/saved_style_name.dart';
import 'package:openvine/models/video_editor/title_style.dart';

/// A [TitleStyle] the user saved for reuse across drafts.
///
/// A saved style is a copy of the look, not a reference: applying it writes
/// the style onto the layer, so deleting the saved style later leaves every
/// title that was styled from it untouched.
class SavedTitleStyle extends Equatable {
  /// Creates a saved style.
  const SavedTitleStyle({
    required this.id,
    required this.name,
    required this.style,
    required this.createdAt,
    this.orderIndex = 0,
  });

  /// Unique style identifier.
  final String id;

  /// The user's own display name for this style. Never localized.
  final String name;

  /// The look itself.
  final TitleStyle style;

  /// When the user saved the style.
  final DateTime createdAt;

  /// Position in the picker, ascending.
  final int orderIndex;

  /// Longest name a style may carry; see [savedStyleMaxNameLength].
  static const int maxNameLength = savedStyleMaxNameLength;

  /// Trims [rawName] and returns it, or `null` when it holds no usable text;
  /// see [sanitizeSavedStyleName].
  static String? sanitizeName(String rawName) =>
      sanitizeSavedStyleName(rawName);

  /// Copy with the given fields replaced.
  SavedTitleStyle copyWith({String? name, int? orderIndex}) => SavedTitleStyle(
    id: id,
    name: name ?? this.name,
    style: style,
    createdAt: createdAt,
    orderIndex: orderIndex ?? this.orderIndex,
  );

  @override
  List<Object?> get props => [id, name, style, createdAt, orderIndex];
}
