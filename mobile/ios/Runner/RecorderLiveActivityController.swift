// ABOUTME: Shows a Live Activity while the camera is open and a Watch can control it.
// ABOUTME: The Activity is what puts the Watch remote in the Watch's Smart Stack.

import ActivityKit
import Foundation

/// Keeps one Live Activity in step with the recorder.
///
/// An iPhone app cannot open its Watch app. A Live Activity is the nearest
/// thing: the Watch shows it in the Smart Stack, and a tap on it there opens
/// the Watch remote.
@available(iOS 16.2, *)
final class RecorderLiveActivityController {
  private var activity: Activity<RecorderActivityAttributes>?

  /// The newest state asked for, so updates sent in a burst land in order.
  private var pending: Task<Void, Never>?

  init() {
    // The app was killed with the camera open: nothing ended that Activity.
    enqueue { _ in
      for stale in Activity<RecorderActivityAttributes>.activities {
        await stale.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  /// Shows `recorderState`, or ends the Activity when it is `nil`.
  ///
  /// Call on the main queue.
  func show(recorderState: [String: Any]?) {
    let state = recorderState.map(RecorderActivityAttributes.ContentState.init(recorderState:))
    enqueue { controller in
      await controller.apply(state)
    }
  }

  private func enqueue(_ work: @escaping @MainActor (RecorderLiveActivityController) async -> Void) {
    let previous = pending
    pending = Task { @MainActor [weak self] in
      await previous?.value
      guard let self else { return }
      await work(self)
    }
  }

  @MainActor
  private func apply(_ state: RecorderActivityAttributes.ContentState?) async {
    guard let state else {
      await activity?.end(nil, dismissalPolicy: .immediate)
      activity = nil
      return
    }
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity {
      await activity.update(content)
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    do {
      activity = try Activity.request(
        attributes: RecorderActivityAttributes(),
        content: content
      )
    } catch {
      // Live Activities are off, or the system is showing too many: the
      // Watch remote still works when opened by hand.
    }
  }
}
