// ABOUTME: Model for remote record trigger events
// ABOUTME: Represents volume button or Bluetooth remote presses for recording

/// The type of remote trigger that initiated a recording action.
///
/// This enum represents the different ways a user can trigger recording
/// without touching the phone screen, such as physical volume buttons
/// or Bluetooth accessories.
enum RemoteRecordTrigger {
  /// Volume up button was pressed.
  volumeUp,

  /// Volume down button was pressed.
  volumeDown,

  /// A Bluetooth remote or headphone button was pressed.
  bluetooth,

  /// A legacy Watch toggle without an explicit action.
  watch,

  /// The Watch showed the Start action.
  watchStart,

  /// The Watch showed the Stop action.
  watchStop;

  /// Converts a native string to a [RemoteRecordTrigger].
  static RemoteRecordTrigger fromNativeString(String value) {
    return switch (value) {
      'volumeUp' => RemoteRecordTrigger.volumeUp,
      'volumeDown' => RemoteRecordTrigger.volumeDown,
      'bluetooth' => RemoteRecordTrigger.bluetooth,
      'watch' => RemoteRecordTrigger.watch,
      'watchStart' => RemoteRecordTrigger.watchStart,
      'watchStop' => RemoteRecordTrigger.watchStop,
      _ => RemoteRecordTrigger.volumeUp,
    };
  }

  /// Converts the trigger to a native string representation.
  String toNativeString() {
    return switch (this) {
      RemoteRecordTrigger.volumeUp => 'volumeUp',
      RemoteRecordTrigger.volumeDown => 'volumeDown',
      RemoteRecordTrigger.bluetooth => 'bluetooth',
      RemoteRecordTrigger.watch => 'watch',
      RemoteRecordTrigger.watchStart => 'watchStart',
      RemoteRecordTrigger.watchStop => 'watchStop',
    };
  }
}
