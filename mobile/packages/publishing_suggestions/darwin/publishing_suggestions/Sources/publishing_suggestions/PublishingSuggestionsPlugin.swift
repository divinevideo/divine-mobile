#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import Foundation

public final class PublishingSuggestionsPlugin: NSObject, FlutterPlugin {
  private var generation: Task<Void, Never>?
  private let model: PublishingSuggestionsModel

  public override convenience init() {
    self.init(model: DevicePublishingSuggestionsModel())
  }

  init(model: PublishingSuggestionsModel) {
    self.model = model
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "publishing_suggestions", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(PublishingSuggestionsPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "cancel" {
      generation?.cancel()
      generation = nil
      result(nil)
      return
    }
    if model.isSupported {
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "capabilities":
        let language = args["language"] as? String ?? "en"
        let ready = model.isAvailable(language: language)
        result(["availability": ready ? "ready" : "unavailable", "images": ready])
      case "prepare":
        // Apple manages model installation in system settings.
        result(nil)
      case "generate":
        guard let prompt = args["prompt"] as? String else {
          result(FlutterError(code: "invalid_request", message: "Missing prompt", details: nil))
          return
        }
        generation?.cancel()
        let frames = (args["frames"] as? [FlutterStandardTypedData] ?? []).prefix(3).map { $0.data }
        generation = Task {
          do {
            let content = try await model.generate(prompt: prompt, frames: frames)
            try Task.checkCancellation()
            await MainActor.run { result(content) }
          } catch {
            await MainActor.run {
              result(FlutterError(code: "unavailable", message: "Local suggestions are unavailable", details: nil))
            }
          }
        }
      default: result(FlutterMethodNotImplemented)
      }
      return
    }
    if call.method == "capabilities" {
      result(["availability": "unavailable", "images": false])
    } else {
      result(FlutterError(code: "unavailable", message: "Local suggestions are unavailable", details: nil))
    }
  }
}
