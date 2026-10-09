import Cocoa
import FlutterMacOS
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    NativeCameraPlugin.register(with: controller.registrar(forPlugin: "NativeCameraPlugin"))
    // Divine's own video effects, for the editor preview and the export (#9708).
    // The source is shared with the iOS runner.
    EchoVideoEffect.register()
    // CameraMacOSPlugin removed - Flutter now has native macOS camera support
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(
    _ application: NSApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void
  ) -> Bool {
    if let url = AppLinks.shared.getUniversalLink(userActivity) {
      AppLinks.shared.handleLink(link: url.absoluteString)
      return true
    }

    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }
}
