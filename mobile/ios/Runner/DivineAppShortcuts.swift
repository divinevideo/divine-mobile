// ABOUTME: Offers the Divine camera to the Action Button, Siri, Spotlight and
// ABOUTME: the Shortcuts app, without the user building a shortcut.

import AppIntents

@available(iOS 17.0, *)
struct DivineAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenDivineCameraIntent(),
      phrases: [
        "Open the \(.applicationName) camera",
        "Record with \(.applicationName)",
      ],
      shortTitle: "divine_camera_name",
      systemImageName: "camera.fill"
    )
  }
}
