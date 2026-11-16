// ABOUTME: The Watch remote for the recorder.
// ABOUTME: A shutter button over a strip that fills with the clip budget.

import SwiftUI
import WatchKit

/// The remote shutter: the record button, and below it the clip budget filling
/// from the left while a take runs.
///
/// With no recorder open on the iPhone the shutter is dimmed and inert, and
/// nothing but the empty strip is shown around it.
struct RemoteShutterView: View {
  /// The iPhone's recorder, or `nil` while it has none on screen.
  let recorder: RecorderSnapshot?
  let onToggleRecording: () -> Void

  /// What to draw: the open recorder, or an empty one.
  private var shown: RecorderSnapshot { recorder ?? RecorderSnapshot() }

  /// Share of the screen height the budget strip takes.
  private static let stripHeightFraction: CGFloat = 0.22

  /// Share of the space above the strip the shutter button takes.
  private static let buttonFraction: CGFloat = 0.72

  var body: some View {
    GeometryReader { safeArea in
      GeometryReader { screen in
        VStack(spacing: 0) {
          GeometryReader { region in
            RecordButton(
              isRecording: shown.isRecording,
              isEnabled: recorder != nil,
              diameter: min(region.size.width, region.size.height) * Self.buttonFraction,
              action: onToggleRecording
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          TimelineView(.animation(paused: !shown.isRecording)) { timeline in
            VStack(spacing: 4) {
              Text(verbatim: shown.durationLabel(at: timeline.date))
                .font(.system(.footnote, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundColor(.white)
                .opacity(recorder == nil ? 0 : 1)
              RecordingBudgetStrip(
                fill: RecordingBudgetFill(
                  elapsed: shown.elapsed(at: timeline.date),
                  budget: shown.budget
                )
              )
              .frame(height: (screen.size.height * Self.stripHeightFraction).rounded())
            }
          }
        }
      }
      // The strip runs to the screen's own edges; the button stays clear of the clock.
      .ignoresSafeArea(edges: [.horizontal, .bottom])
      .background(Color.black.ignoresSafeArea())
      .overlay(alignment: .topLeading) {
        if let recorder {
          RecorderModeLabel(name: recorder.modeName, clockBandHeight: safeArea.safeAreaInsets.top)
        }
      }
    }
    .onChange(of: shown.isRecording) { isRecording in
      WKInterfaceDevice.current().play(isRecording ? .start : .stop)
    }
  }
}

/// The recorder mode, on the system clock's line at the opposite edge.
private struct RecorderModeLabel: View {
  let name: String

  /// Height of the band the system draws the clock in.
  let clockBandHeight: CGFloat

  /// Matches the clock's inset from the screen edge.
  private static let edgeInset: CGFloat = 14

  var body: some View {
    Text(verbatim: name)
      .font(.system(size: 16, weight: .medium))
      .foregroundColor(.gray)
      .frame(height: clockBandHeight)
      .padding(.leading, Self.edgeInset)
      .ignoresSafeArea(edges: [.top, .horizontal])
  }
}

struct RemoteShutterView_Previews: PreviewProvider {
  static var previews: some View {
    RemoteShutterView(
      recorder: RecorderSnapshot(recordedDuration: 2.5),
      onToggleRecording: {}
    )
  }
}
