// ABOUTME: Holds the Add yours a video is recorded to answer while the camera
// ABOUTME: and editor run; cleared when the flow is left.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/add_yours_context.dart';

/// The Add yours the camera was opened to answer, or `null` when it was
/// opened for anything else.
final addYoursContextProvider =
    NotifierProvider<AddYoursContextNotifier, AddYoursContext?>(
      AddYoursContextNotifier.new,
    );

/// Sets and clears [addYoursContextProvider].
class AddYoursContextNotifier extends Notifier<AddYoursContext?> {
  @override
  AddYoursContext? build() => null;

  /// Answers [context] with the video recorded next.
  void set(AddYoursContext context) => state = context;

  /// Answers nothing any more.
  void clear() => state = null;
}
