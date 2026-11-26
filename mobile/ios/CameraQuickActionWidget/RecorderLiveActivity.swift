// ABOUTME: Draws the camera's Live Activity on the Lock Screen and Dynamic Island.
// ABOUTME: The Apple Watch shows its compact views in the Smart Stack.

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct RecorderLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecorderActivityAttributes.self) { context in
      HStack(spacing: 12) {
        RecorderActivityIndicator(isRecording: context.state.isShutterActive)
        Text(verbatim: "Divine")
          .font(.system(.headline, design: .rounded))
          .foregroundStyle(.white)
        Spacer()
        RecorderActivityDuration(state: context.state)
          .font(.system(.title2, design: .rounded).weight(.semibold))
          .foregroundStyle(.white)
      }
      .padding()
      .activityBackgroundTint(recorderActivityBackground)
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          RecorderActivityIndicator(isRecording: context.state.isShutterActive)
        }
        DynamicIslandExpandedRegion(.trailing) {
          RecorderActivityDuration(state: context.state)
            .font(.system(.title3, design: .rounded).weight(.semibold))
        }
      } compactLeading: {
        RecorderActivityIndicator(isRecording: context.state.isShutterActive)
      } compactTrailing: {
        RecorderActivityDuration(state: context.state)
          .font(.system(.body, design: .rounded).weight(.semibold))
      } minimal: {
        RecorderActivityIndicator(isRecording: context.state.isShutterActive)
      }
    }
  }
}

private let recorderActivityBackground = Color(red: 0, green: 21 / 255, blue: 13 / 255)
private let recorderActivityGreen = Color(red: 39 / 255, green: 197 / 255, blue: 139 / 255)
private let recorderActivityRed = Color(red: 244 / 255, green: 67 / 255, blue: 54 / 255)

/// A camera while the recorder waits, a red dot while a take runs.
@available(iOS 16.2, *)
private struct RecorderActivityIndicator: View {
  let isRecording: Bool

  var body: some View {
    if isRecording {
      Image(systemName: "record.circle.fill")
        .foregroundStyle(recorderActivityRed)
    } else {
      Image(systemName: "camera.fill")
        .foregroundStyle(recorderActivityGreen)
    }
  }
}

/// The recorded time, counting by itself while a take runs.
@available(iOS 16.2, *)
private struct RecorderActivityDuration: View {
  let state: RecorderActivityAttributes.ContentState

  var body: some View {
    if let timerStart = state.timerStart {
      // The far end only bounds the timer; the recorder ends the take long
      // before it.
      Text(timerInterval: timerStart...timerStart.addingTimeInterval(3600), countsDown: false)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 56)
    } else {
      Text(verbatim: state.durationLabel)
        .monospacedDigit()
    }
  }
}
