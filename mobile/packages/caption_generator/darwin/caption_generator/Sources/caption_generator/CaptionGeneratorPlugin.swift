// ABOUTME: Darwin (iOS + macOS) caption generator using SFSpeechRecognizer.
// ABOUTME: Transcribes audio files into word-level segments with timestamps.

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation
import Speech

public final class CaptionGeneratorPlugin: NSObject, FlutterPlugin {
  /// Sessions currently running, keyed by id, so each recognizer and task
  /// stay alive until their completion handler fires. Main-queue only.
  private var activeSessions: [UUID: TranscriptionSession] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "caption_generator", binaryMessenger: messenger)
    let instance = CaptionGeneratorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "transcribe" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
      let audioPath = args["audioPath"] as? String, !audioPath.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_arguments", message: "audioPath is required",
          details: nil))
      return
    }
    guard FileManager.default.fileExists(atPath: audioPath) else {
      result(
        FlutterError(
          code: "audio_not_found",
          message: "Audio file not found: \(audioPath)", details: nil))
      return
    }
    let localeIdentifier = args["localeIdentifier"] as? String
    let preferOnDevice = args["preferOnDeviceRecognition"] as? Bool ?? true
    let requireOnDevice = args["requireOnDeviceRecognition"] as? Bool ?? false

    ensureAuthorization { [weak self] authorized in
      DispatchQueue.main.async {
        guard let self else { return }
        guard authorized else {
          result(
            FlutterError(
              code: "not_authorized",
              message: "Speech recognition is not authorized", details: nil))
          return
        }
        self.startTranscription(
          audioPath: audioPath, localeIdentifier: localeIdentifier,
          preferOnDevice: preferOnDevice, requireOnDevice: requireOnDevice,
          result: result)
      }
    }
  }

  private func ensureAuthorization(completion: @escaping (Bool) -> Void) {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      completion(true)
    case .notDetermined:
      SFSpeechRecognizer.requestAuthorization { status in
        completion(status == .authorized)
      }
    default:
      completion(false)
    }
  }

  /// Must be called on the main queue.
  private func startTranscription(
    audioPath: String, localeIdentifier: String?, preferOnDevice: Bool,
    requireOnDevice: Bool,
    result: @escaping FlutterResult
  ) {
    let locale = localeIdentifier.map { Locale(identifier: $0) } ?? Locale.current
    guard let recognizer = SFSpeechRecognizer(locale: locale),
      recognizer.isAvailable
    else {
      result(
        FlutterError(
          code: "recognizer_unavailable",
          message:
            "No speech recognizer available for locale \(locale.identifier)",
          details: nil))
      return
    }
    guard !requireOnDevice || recognizer.supportsOnDeviceRecognition else {
      result(
        FlutterError(
          code: "recognizer_unavailable",
          message: "On-device speech recognition is unavailable for this locale",
          details: nil))
      return
    }
    let request = SFSpeechURLRecognitionRequest(
      url: URL(fileURLWithPath: audioPath))
    request.shouldReportPartialResults = false
    request.taskHint = .dictation
    if requireOnDevice || (preferOnDevice && recognizer.supportsOnDeviceRecognition) {
      request.requiresOnDeviceRecognition = true
    }
    if #available(iOS 16.0, macOS 13.0, *) {
      request.addsPunctuation = true
    }

    let sessionId = UUID()
    let session = TranscriptionSession(recognizer: recognizer)
    activeSessions[sessionId] = session

    session.task = recognizer.recognitionTask(with: request) {
      [weak self] recognitionResult, error in
      DispatchQueue.main.async {
        guard let self, self.activeSessions[sessionId] != nil else { return }
        if let recognitionResult, recognitionResult.isFinal {
          self.activeSessions[sessionId] = nil
          let segments = recognitionResult.bestTranscription.segments.map {
            segment -> [String: Any] in
            [
              "text": segment.substring,
              "startMs": Int((segment.timestamp * 1000).rounded()),
              "endMs": Int(
                ((segment.timestamp + segment.duration) * 1000).rounded()),
            ]
          }
          result(segments)
          return
        }
        guard let error else { return }
        self.activeSessions[sessionId] = nil
        let nsError = error as NSError
        // "No speech detected" is a valid empty transcription, not a failure.
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 1110 {
          result([[String: Any]]())
        } else {
          result(
            FlutterError(
              code: "transcription_failed",
              message: nsError.localizedDescription, details: nil))
        }
      }
    }
  }
}

/// Keeps one recognizer and its task alive for the duration of one request.
private final class TranscriptionSession {
  let recognizer: SFSpeechRecognizer
  var task: SFSpeechRecognitionTask?

  init(recognizer: SFSpeechRecognizer) {
    self.recognizer = recognizer
  }
}
