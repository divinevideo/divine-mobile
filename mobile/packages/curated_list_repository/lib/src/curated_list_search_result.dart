import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// One video list a list search found.
///
/// A list found in FunnelCake's list index first arrives as a summary: [list]
/// carries its owner, `d` tag, name and description, but none of its video
/// references, and [itemCount] says how many videos it holds. Such a result is
/// not [isComplete], and a screen that shows the list's videos must load the
/// list itself instead of trusting [list].
class CuratedListSearchResult extends Equatable {
  /// A result holding the whole [list], its video references included.
  CuratedListSearchResult(this.list)
    : itemCount = list.videoEventIds.length,
      isComplete = true;

  /// A summary of a list from the search index, which holds [itemCount]
  /// videos that [list] does not reference.
  const CuratedListSearchResult.summary({
    required this.list,
    required this.itemCount,
  }) : isComplete = false;

  /// The list found. When the result is not [isComplete], it has no video
  /// references or thumbnails.
  final CuratedList list;

  /// How many videos the list holds.
  final int itemCount;

  /// Whether [list] carries the list's video references.
  final bool isComplete;

  @override
  List<Object?> get props => [list, itemCount, isComplete];
}
