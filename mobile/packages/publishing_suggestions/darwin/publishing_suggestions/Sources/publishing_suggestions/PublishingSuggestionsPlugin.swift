#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import Foundation
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

public final class PublishingSuggestionsPlugin: NSObject, FlutterPlugin {
  private var generation: Task<Void, Never>?

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
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let args = call.arguments as? [String: Any] ?? [:]
      let model = SystemLanguageModel.default
      switch call.method {
      case "capabilities":
        let language = args["language"] as? String ?? "en"
        let ready = model.availability == .available && model.supportsLocale(Locale(identifier: language))
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
            let content = try await PublishingIdeasEngine.generate(prompt: prompt, frames: frames)
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
    #endif
    if call.method == "capabilities" {
      result(["availability": "unavailable", "images": false])
    } else {
      result(FlutterError(code: "unavailable", message: "Local suggestions are unavailable", details: nil))
    }
  }
}
