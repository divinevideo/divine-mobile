// ABOUTME: The App Intent that opens the Divine camera, for the Action Button,
// ABOUTME: Siri, Spotlight and the Control Center control.

import AppIntents
import Foundation

/// The link the camera widget opens. The quick-actions plugin routes it to the
/// camera, on a cold start as well as a warm one.
let divineCameraQuickActionURL = URL(string: "divine://quick-action/camera")!

/// Opens the Divine camera.
///
/// Compiled into the app and the widget extension: the Control Center control
/// names it from the extension, and the system runs it in the app, because it
/// opens the app.
struct OpenDivineCameraIntent: AppIntent {
  static let title: LocalizedStringResource = "divine_camera_intent_title"
  static let description = IntentDescription("divine_camera_intent_description")
  static let openAppWhenRun = true

  /// Opens a link in the app. Set by the app at launch; the widget extension
  /// never runs this intent, so it stays `nil` there.
  @MainActor static var openURL: ((URL) async -> Void)?

  @MainActor
  func perform() async throws -> some IntentResult {
    await Self.openURL?(divineCameraQuickActionURL)
    return .result()
  }
}
