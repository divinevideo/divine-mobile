// ABOUTME: iOS implementation for Divine quick actions.
// ABOUTME: Bridges UIApplicationShortcutItem events to Flutter.

import Flutter
import UIKit

public class DivineQuickActionsPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private static let quickActionURLScheme = "divine"
  private static let quickActionURLHost = "quick-action"
  private static let cameraActionType = "camera"

  private let channel: FlutterMethodChannel
  private var pendingLaunchAction: [String: Any]?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "divine_quick_actions",
      binaryMessenger: registrar.messenger()
    )
    let instance = DivineQuickActionsPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "setActions":
      guard let actions = call.arguments as? [[String: Any]] else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "setActions expects a list of quick action maps.",
            details: nil
          )
        )
        return
      }
      result(setActions(actions))
    case "getActions":
      result((UIApplication.shared.shortcutItems ?? []).map(encodeShortcutItem))
    case "clearActions":
      UIApplication.shared.shortcutItems = []
      result(true)
    case "consumeLaunchAction":
      result(pendingLaunchAction)
      pendingLaunchAction = nil
    case "isCameraWidgetPinSupported", "requestPinCameraWidget":
      // iOS has no API to add a widget on the user's behalf.
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
  ) -> Bool {
    if let shortcutItem = launchOptions[UIApplication.LaunchOptionsKey.shortcutItem]
      as? UIApplicationShortcutItem
    {
      pendingLaunchAction = encodeShortcutItem(shortcutItem)
    } else if let url = launchOptions[UIApplication.LaunchOptionsKey.url] as? URL {
      pendingLaunchAction = actionFromURL(url)
    }
    return true
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard let action = actionFromURL(url) else {
      return false
    }

    emitAction(action)
    return true
  }

  public func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) -> Bool {
    emitShortcutItem(shortcutItem)
    completionHandler(true)
    return true
  }

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let shortcutItem = connectionOptions?.shortcutItem {
      pendingLaunchAction = encodeShortcutItem(shortcutItem)
      return true
    }
    if let url = connectionOptions?.urlContexts.first?.url,
      let action = actionFromURL(url)
    {
      pendingLaunchAction = action
      return true
    }
    return false
  }

  public func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) -> Bool {
    guard let action = URLContexts.compactMap({ actionFromURL($0.url) }).first else {
      return false
    }

    emitAction(action)
    return true
  }

  public func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) -> Bool {
    emitShortcutItem(shortcutItem)
    completionHandler(true)
    return true
  }

  private func setActions(_ actions: [[String: Any]]) -> Bool {
    let shortcutItems = actions.compactMap(makeShortcutItem)
    guard shortcutItems.count == actions.count else {
      return false
    }

    UIApplication.shared.shortcutItems = shortcutItems
    return true
  }

  private func makeShortcutItem(_ action: [String: Any]) -> UIApplicationShortcutItem? {
    guard
      let type = action["type"] as? String,
      let title = action["title"] as? String,
      !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }

    return UIApplicationShortcutItem(
      type: type,
      localizedTitle: title,
      localizedSubtitle: action["subtitle"] as? String,
      icon: makeIcon(action),
      userInfo: userInfoFromAction(action)
    )
  }

  private func makeIcon(_ action: [String: Any]) -> UIApplicationShortcutIcon? {
    guard
      let iconName = action["iosIconName"] as? String,
      !iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }

    if action["iosIconStyle"] as? String == "system" {
      return UIApplicationShortcutIcon(systemImageName: iconName)
    }

    return UIApplicationShortcutIcon(templateImageName: iconName)
  }

  private func userInfoFromAction(_ action: [String: Any]) -> [String: NSSecureCoding]? {
    guard let payload = action["payload"] as? [String: String], !payload.isEmpty else {
      return nil
    }

    var userInfo = [String: NSSecureCoding]()
    for (key, value) in payload {
      userInfo[key] = value as NSString
    }
    return userInfo
  }

  private func emitShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
    emitAction(encodeShortcutItem(shortcutItem))
  }

  private func emitAction(_ action: [String: Any]) {
    channel.invokeMethod("onQuickAction", arguments: action)
  }

  private func actionFromURL(_ url: URL) -> [String: Any]? {
    guard
      url.scheme == Self.quickActionURLScheme,
      url.host == Self.quickActionURLHost
    else {
      return nil
    }

    let actionType = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard actionType == Self.cameraActionType else {
      return nil
    }

    return [
      "type": actionType,
      "title": "",
      "payload": [String: String](),
    ]
  }

  private func encodeShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> [String: Any] {
    var payload = [String: String]()
    shortcutItem.userInfo?.forEach { key, value in
      payload[key] = "\(value)"
    }

    var encoded: [String: Any] = [
      "type": shortcutItem.type,
      "title": shortcutItem.localizedTitle,
      "payload": payload,
    ]
    if let subtitle = shortcutItem.localizedSubtitle {
      encoded["subtitle"] = subtitle
    }
    return encoded
  }
}
