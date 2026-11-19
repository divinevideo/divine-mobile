// ABOUTME: Lets a feed in a wide landscape window show comments in a panel
// ABOUTME: beside the video; CommentsScreen.show opens it instead of the sheet

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;

/// What [CommentsPanelCubit.open] shows: the arguments `CommentsScreen.show`
/// was called with.
///
/// Compared by identity: each open is its own request, so reopening the same
/// video gives the panel fresh blocs.
@immutable
class CommentsPanelRequest {
  const CommentsPanelRequest({
    required this.video,
    this.initialCommentCount,
    this.onCommentCountChanged,
    this.focusCommentId,
  });

  final VideoEvent video;
  final int? initialCommentCount;
  final ValueChanged<int>? onCommentCountChanged;
  final String? focusCommentId;
}

/// Which video's comments the panel beside a feed shows; null while it is
/// closed.
class CommentsPanelCubit extends Cubit<CommentsPanelRequest?> {
  CommentsPanelCubit() : super(null);

  /// Shows [request] in the panel, replacing what it showed.
  ///
  /// Completes when the panel closes or shows something else, as the sheet's
  /// future completes when it is dismissed.
  Future<void> open(CommentsPanelRequest request) {
    if (isClosed) return Future<void>.value();
    final replaced = stream.firstWhere((shown) => !identical(shown, request));
    emit(request);
    // The cubit closing ends the stream without a match: the panel is gone,
    // which completes the request as well.
    return replaced.then<void>((_) {}, onError: (Object _) {});
  }

  /// Closes the panel.
  void dismiss() {
    if (isClosed || state == null) return;
    emit(null);
  }

  /// Closes the panel unless it shows the comments on the video [videoId].
  ///
  /// The feed calls this when another video becomes active: the panel was
  /// opened from one video's comment button, which keeps that video's comment
  /// count in step, and another video's count would go stale.
  void closeUnlessShowing(String videoId) {
    if (state?.video.id == videoId) return;
    dismiss();
  }
}

/// Publishes the [CommentsPanelCubit] of the feed below it.
class CommentsPanelScope extends InheritedWidget {
  const CommentsPanelScope({
    required this.cubit,
    required super.child,
    this.canOpen = true,
    super.key,
  });

  /// The panel's cubit.
  final CommentsPanelCubit cubit;

  /// Whether comments open in the panel now. False while the window is too
  /// narrow for it: comments then open in the sheet, and a panel already
  /// open waits, hidden, until the window is wide again.
  final bool canOpen;

  /// The cubit of the panel beside the feed above [context], or null when
  /// comments open in the sheet.
  ///
  /// Read without a dependency: callers are tap handlers, not builds.
  static CommentsPanelCubit? maybeOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CommentsPanelScope>();
    return scope != null && scope.canOpen ? scope.cubit : null;
  }

  /// Closes the panel beside the feed above [context] unless it shows the
  /// comments on the video [videoId], hidden or not (see
  /// [CommentsPanelCubit.closeUnlessShowing]).
  ///
  /// Read without a dependency, as [maybeOf] is.
  static void closeUnlessShowing(BuildContext context, String videoId) =>
      context
          .getInheritedWidgetOfExactType<CommentsPanelScope>()
          ?.cubit
          .closeUnlessShowing(videoId);

  @override
  bool updateShouldNotify(CommentsPanelScope oldWidget) =>
      cubit != oldWidget.cubit || canOpen != oldWidget.canOpen;
}
