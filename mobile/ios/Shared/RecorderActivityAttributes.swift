// ABOUTME: The data behind the camera's Live Activity.
// ABOUTME: Compiled into the app, which starts it, and the widget, which draws it.

import ActivityKit
import Foundation

/// The Divine camera, open on this iPhone.
///
/// The Apple Watch app names this type in
/// `WKSupportsLiveActivityLaunchAttributeTypes`, so renaming it stops a tap on
/// the Live Activity from opening the Watch remote.
@available(iOS 16.2, *)
struct RecorderActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// Combined length of the clips already recorded, in seconds.
    var recordedDuration: TimeInterval

    /// When the take in progress started, or `nil` while none is running.
    var activeTakeStartedAt: Date?

    /// Whether a shutter press stops what is running: a take, its countdown,
    /// or stop-motion capturing on its interval.
    var isShutterActive = false

    /// Whether recorded time is counting.
    var isRecording: Bool { activeTakeStartedAt != nil }

    /// The moment a clock that has counted `recordedDuration` would have
    /// started, so a timer from it shows the total while a take runs.
    var timerStart: Date? {
      activeTakeStartedAt?.addingTimeInterval(-recordedDuration)
    }

    /// Recorded time as `mm:ss`, the format of the recorder's progress label.
    var durationLabel: String {
      let seconds = Int(recordedDuration)
      return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
  }
}

@available(iOS 16.2, *)
extension RecorderActivityAttributes.ContentState {
  /// Reads the state the recorder publishes for remote controls
  /// (`RemoteRecorderState.toMap` in `divine_camera`).
  init(recorderState: [String: Any]) {
    let recordedMs = (recorderState["recordedMs"] as? NSNumber)?.doubleValue ?? 0
    let startedAtMs = (recorderState["activeTakeStartedAtMs"] as? NSNumber)?.doubleValue
    self.init(
      recordedDuration: recordedMs / 1000,
      activeTakeStartedAt: startedAtMs.map { Date(timeIntervalSince1970: $0 / 1000) },
      isShutterActive: recorderState["shutterActive"] as? Bool ?? (startedAtMs != nil)
    )
  }
}
