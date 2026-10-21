// ABOUTME: The pro_video_editor plugin the test harness installs as its default,
// ABOUTME: so no test subscribes to the plugin's native event channels.

// Not exported from pro_video_editor's barrel; imported by path so the
// harness can subclass the method-channel plugin.
import 'package:pro_video_editor/core/platform/native_method_channel.dart';

/// A [MethodChannelProVideoEditor] that never subscribes to native streams.
///
/// The real plugin listens on its progress and log event channels when it is
/// constructed, except on Linux and Windows. Nothing in a test answers those
/// channels, so on macOS the first read of `ProVideoEditor.instance` failed
/// whichever test was running when the reply arrived (#10352).
/// `flutter_test_config.dart` installs this before any test runs, so every
/// host behaves as the Linux CI runners do. Method calls still go to the
/// `pro_video_editor` method channel, which tests mock as before.
class StreamlessProVideoEditor extends MethodChannelProVideoEditor {
  @override
  void initializeStream() {
    // Intentional no-op: nothing in a test answers the native event channels.
  }
}
