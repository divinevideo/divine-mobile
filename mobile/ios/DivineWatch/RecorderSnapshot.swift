// ABOUTME: What the Watch knows about the iPhone recorder it controls.
// ABOUTME: Also turns recorded time into the segments of the budget strip.

import Foundation

/// What the Watch knows about the recorder it controls.
struct RecorderSnapshot: Equatable {
  /// Mirrors `VideoEditorConstants.maxDuration` in the Flutter app.
  static let defaultBudget: TimeInterval = 6.3

  /// Combined length of the clips already recorded. In Stop Motion, the clip
  /// time the stills taken so far are held for.
  var recordedDuration: TimeInterval = 0

  /// When the take in progress started, or `nil` while none is running.
  var activeTakeStartedAt: Date?

  /// Clip length the strip fills against. In Stop Motion, the clip time of
  /// the most stills the session fits.
  var budget: TimeInterval = RecorderSnapshot.defaultBudget

  /// The recorder mode in use, as the iPhone's mode wheel names it
  /// (`VideoRecorderMode.label`, English in every locale).
  var modeName = "Capture"

  /// Whether a tap stops what is running: a take, its countdown, or
  /// stop-motion capturing on its interval. The last two add no recorded time.
  var isShutterActive = false

  /// Whether the phone can act on a shutter press.
  var isShutterEnabled = true

  /// How many single-frame capture attempts have finished in Stop Motion.
  /// A still leaves `isShutterActive` unchanged, so this confirms completion.
  var stillShutterCount = 0

  /// The iPhone's number for this state. A press names it, so the iPhone can
  /// drop a press made on a state it has since left.
  var revision: Int64?

  /// Whether recorded time is counting.
  var isRecording: Bool { activeTakeStartedAt != nil }

  /// Recorded time at `date` as `mm:ss`, the format of the iPhone recorder's
  /// progress label.
  func durationLabel(at date: Date) -> String {
    let seconds = Int(elapsed(at: date))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }

  /// Recorded time at `date`, counting the take in progress.
  func elapsed(at date: Date) -> TimeInterval {
    guard let activeTakeStartedAt else { return recordedDuration }
    return recordedDuration + max(0, date.timeIntervalSince(activeTakeStartedAt))
  }
}

/// How much of the budget strip each segment takes, as fractions of its width.
///
/// The same split as the iPhone recorder's progress bar: green grows until the
/// budget is used up, and time recorded past it squeezes the green back from
/// the right.
struct RecordingBudgetFill: Equatable {
  /// Recorded time within the budget.
  let filled: Double

  /// Recorded time past the budget.
  let overflow: Double

  init(elapsed: TimeInterval, budget: TimeInterval) {
    guard elapsed > 0 else {
      filled = 0
      overflow = 0
      return
    }
    // With no shots left, every new still is past the budget.
    guard budget > 0 else {
      filled = 0
      overflow = 1
      return
    }
    if elapsed <= budget {
      filled = elapsed / budget
      overflow = 0
    } else {
      filled = budget / elapsed
      overflow = 1 - filled
    }
  }
}
