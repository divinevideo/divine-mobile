// ABOUTME: A user-defined caption style saved under a name of the user's
// ABOUTME: choosing, so it can be applied to captions in later videos (#7742).

import 'package:equatable/equatable.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/saved_style_name.dart';

/// A [CaptionCustomStyle] the user saved for reuse across drafts.
///
/// A custom style otherwise lives inside its draft's caption track; a saved
/// one is a copy with its own name, so deleting it later leaves every caption
/// track that was styled from it untouched.
class SavedCaptionStyle extends Equatable {
  /// Creates a saved style.
  const SavedCaptionStyle({
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
  final CaptionCustomStyle style;

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
  SavedCaptionStyle copyWith({String? name, int? orderIndex}) =>
      SavedCaptionStyle(
        id: id,
        name: name ?? this.name,
        style: style,
        createdAt: createdAt,
        orderIndex: orderIndex ?? this.orderIndex,
      );

  @override
  List<Object?> get props => [id, name, style, createdAt, orderIndex];
}
