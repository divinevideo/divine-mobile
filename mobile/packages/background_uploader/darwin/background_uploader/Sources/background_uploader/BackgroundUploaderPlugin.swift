// ABOUTME: Darwin (iOS + macOS) background uploader backed by a background
// ABOUTME: URLSession so transfers continue after the app is suspended.

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation

/// Owns the process-wide background `URLSession` and fans its delegate events
/// out to every attached Flutter engine's method channel.
///
/// A process can host more than one Flutter engine (e.g. the Firebase-messaging
/// background engine), and each one registers this plugin. iOS forbids creating
/// two `URLSession`s that share one background identifier — doing so is
/// undefined behavior and historically crashes — so the session must be a
/// single process-wide instance rather than one per plugin. Events are
/// delivered to every attached channel; only the engine whose Dart isolate set
/// an `onUploadEvent` handler acts on it, the rest ignore it (mirroring the
/// Android multi-engine handling).
private final class BackgroundUploadCoordinator: NSObject {
  static let shared = BackgroundUploadCoordinator()

  /// Identifier of the shared background session. Must be stable across
  /// launches so the OS can re-attach in-flight tasks after a relaunch.
  fileprivate static let sessionIdentifier =
    "co.openvine.background_uploader.session"

  /// Channels for every attached engine. Mutated and read only on the main
  /// queue.
  private var channels: [FlutterMethodChannel] = []

  /// Response bodies accumulated per task identifier. URLSession delivers
  /// delegate callbacks for one session serially, so this needs no locking.
  private var responseData: [Int: Data] = [:]

  #if os(iOS)
  /// Held while the OS relaunches us in the background to drain session
  /// events; called once those events and their Dart follow-up work have been
  /// delivered. iOS-only — macOS apps are not relaunched to finish background
  /// sessions.
  private var backgroundCompletionHandler: (() -> Void)?

  /// Maximum time to retain iOS's background-session wake for Dart follow-up
  /// work. The OS completion handler must always be balanced, even if Dart's
  /// publish future wedges.
  private static let backgroundCompletionWatchdogInterval: TimeInterval = 25

  private var backgroundCompletionWatchdog: Timer?

  /// Whether URLSession has finished delivering the current batch of native
  /// events. The app-delegate completion handler can be released only after
  /// this is true and every logical publish session has ended.
  private var backgroundEventsFinished = false

  /// Logical publish sessions that still have Dart follow-up work after the
  /// OS-owned upload (thumbnail, signing, relay broadcast). This is deliberately
  /// separate from `backgroundTasks`: iOS may expire a UIBackgroundTask before
  /// a large upload finishes, but the later URLSession wake must still remain
  /// open until Dart calls endForegroundSession.
  private var activeForegroundSessionIds: Set<String> = []

  /// Short-lived UI background-task assertions keyed by publish session id.
  /// These bridge brief suspensions but are not the source of truth for whether
  /// a publish is complete.
  private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]

  /// The engine whose Dart opened each foreground session, so a torn-down
  /// engine's sessions can be closed on its behalf: its isolate is gone and
  /// will never send `endForegroundSession`.
  private var foregroundSessionOwners: [String: ObjectIdentifier] = [:]
  #endif

  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(
      withIdentifier: BackgroundUploadCoordinator.sessionIdentifier
    )
    #if os(iOS)
    configuration.sessionSendsLaunchEvents = true
    #endif
    configuration.isDiscretionary = false
    return URLSession(
      configuration: configuration,
      delegate: self,
      delegateQueue: nil
    )
  }()

  func attach(_ channel: FlutterMethodChannel) {
    dispatchPrecondition(condition: .onQueue(.main))
    channels.append(channel)
    // Touch the lazy session so its delegate is connected immediately. This
    // lets tasks that completed while the app was dead deliver their terminal
    // events as soon as an engine attaches.
    _ = session
  }

  /// Drops one engine's channel so upload events stop fanning out to it, and
  /// closes the foreground sessions its Dart opened, since that isolate can
  /// no longer end them and an open one holds every later background wake
  /// until the watchdog fires. Runs inside that engine's `dealloc`, so it
  /// must not touch the channel.
  func detach(_ channel: FlutterMethodChannel) {
    dispatchPrecondition(condition: .onQueue(.main))
    #if os(iOS)
    let owner = ObjectIdentifier(channel)
    for sessionId in foregroundSessionOwners.keys.sorted()
    where foregroundSessionOwners[sessionId] == owner {
      endForegroundSession(sessionId)
    }
    #endif
    channels.removeAll { $0 === channel }
  }

  /// Counters for tests and support: how many engines are attached, and on
  /// iOS how many publish sessions still hold the background wake open.
  func diagnostics() -> [String: Any] {
    var result: [String: Any] = ["attachedChannels": channels.count]
    #if os(iOS)
    result["activeForegroundSessions"] = activeForegroundSessionIds.count
    #endif
    return result
  }

  func enqueue(
    taskId: String,
    request: URLRequest,
    fileURL: URL,
    completion: @escaping () -> Void
  ) {
    // Dedupe: a retry/timeout can re-enqueue the same taskId while the first
    // transfer is still in flight (or was restored by the OS after a
    // relaunch). Skip starting a second parallel upload of the same file.
    session.getAllTasks { tasks in
      let alreadyRunning = tasks.contains { $0.taskDescription == taskId }
      if !alreadyRunning {
        let task = self.session.uploadTask(with: request, fromFile: fileURL)
        task.taskDescription = taskId
        task.resume()
      }
      DispatchQueue.main.async { completion() }
    }
  }

  func cancel(taskId: String, completion: @escaping () -> Void) {
    session.getAllTasks { tasks in
      for task in tasks where task.taskDescription == taskId {
        task.cancel()
      }
      DispatchQueue.main.async { completion() }
    }
  }

  func activeTaskIds(completion: @escaping ([String]) -> Void) {
    session.getAllTasks { tasks in
      let ids = tasks.compactMap { $0.taskDescription }
      DispatchQueue.main.async { completion(ids) }
    }
  }

  #if os(iOS)
  func beginForegroundSession(
    _ sessionId: String,
    owner channel: FlutterMethodChannel
  ) {
    expireBackgroundTaskAssertion(sessionId)
    activeForegroundSessionIds.insert(sessionId)
    foregroundSessionOwners[sessionId] = ObjectIdentifier(channel)
    let task = UIApplication.shared.beginBackgroundTask(
      withName: "co.openvine.background_uploader.\(sessionId)"
    ) { [weak self] in
      self?.expireBackgroundTaskAssertion(sessionId)
    }
    backgroundTasks[sessionId] = task
  }

  func endForegroundSession(_ sessionId: String) {
    activeForegroundSessionIds.remove(sessionId)
    foregroundSessionOwners.removeValue(forKey: sessionId)
    expireBackgroundTaskAssertion(sessionId)
    finishBackgroundEventsIfReady()
  }

  private func expireBackgroundTaskAssertion(_ sessionId: String) {
    guard let task = backgroundTasks.removeValue(forKey: sessionId),
      task != .invalid
    else { return }
    UIApplication.shared.endBackgroundTask(task)
  }

  func handleBackgroundEvents(completionHandler: @escaping () -> Void) {
    backgroundCompletionHandler = completionHandler
    backgroundCompletionWatchdog?.invalidate()
    backgroundCompletionWatchdog = Timer.scheduledTimer(
      withTimeInterval: Self.backgroundCompletionWatchdogInterval,
      repeats: false
    ) { [weak self] _ in
      DispatchQueue.main.async {
        self?.forceFinishBackgroundEvents()
      }
    }
    // The app-delegate callback starts a new delivery batch. Clear any
    // foreground-only finish marker left by a prior batch that never needed an
    // app-delegate completion handler.
    backgroundEventsFinished = false
    // Ensure the session (and its delegate) exists to drain pending events.
    _ = session
    finishBackgroundEventsIfReady()
  }

  /// Releases iOS's background-URLSession wake only after both sides of the
  /// handoff are finished: native delegate delivery and the publish work that
  /// the terminal event triggered in Dart.
  private func finishBackgroundEventsIfReady() {
    guard backgroundEventsFinished else { return }
    guard activeForegroundSessionIds.isEmpty else { return }
    completeBackgroundEvents()
  }

  /// Safety net for a Dart publish future that never resolves. This releases
  /// iOS's app-delegate completion handler but does not cancel Dart work; if
  /// the publish later ends, `endForegroundSession` becomes a no-op for the
  /// already-released handler.
  private func forceFinishBackgroundEvents() {
    completeBackgroundEvents()
  }

  private func completeBackgroundEvents() {
    guard let handler = backgroundCompletionHandler else { return }
    backgroundCompletionHandler = nil
    backgroundEventsFinished = false
    backgroundCompletionWatchdog?.invalidate()
    backgroundCompletionWatchdog = nil
    handler()
  }
  #endif

  private func sendEvent(_ payload: [String: Any?]) {
    DispatchQueue.main.async {
      for channel in self.channels {
        channel.invokeMethod("onUploadEvent", arguments: payload)
      }
    }
  }
}

extension BackgroundUploadCoordinator: URLSessionDataDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    guard
      let taskId = task.taskDescription,
      totalBytesExpectedToSend > 0
    else { return }
    let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
    sendEvent([
      "taskId": taskId,
      "status": "running",
      "progress": min(max(progress, 0), 1),
    ])
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    responseData[dataTask.taskIdentifier, default: Data()].append(data)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    let taskId = task.taskDescription ?? ""
    let body = responseData.removeValue(forKey: task.taskIdentifier)
    let responseBody = body.flatMap { String(data: $0, encoding: .utf8) }

    if let error = error {
      let isCancelled = (error as NSError).code == NSURLErrorCancelled
      sendEvent([
        "taskId": taskId,
        "status": isCancelled ? "cancelled" : "failed",
        "progress": 0,
        "error": error.localizedDescription,
      ])
      return
    }

    let statusCode = (task.response as? HTTPURLResponse)?.statusCode
    let isSuccess = statusCode.map { (200..<300).contains($0) } ?? false
    sendEvent([
      "taskId": taskId,
      "status": isSuccess ? "completed" : "failed",
      "progress": isSuccess ? 1 : 0,
      "httpStatusCode": statusCode,
      "responseBody": responseBody,
    ])
  }

  #if os(iOS)
  func urlSessionDidFinishEvents(
    forBackgroundURLSession session: URLSession
  ) {
    DispatchQueue.main.async {
      self.backgroundEventsFinished = true
      self.finishBackgroundEventsIfReady()
    }
  }
  #endif
}

public class BackgroundUploaderPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    BackgroundUploadCoordinator.shared.attach(channel)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #elseif os(macOS)
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "background_uploader",
      binaryMessenger: messenger
    )
    let instance = BackgroundUploaderPlugin(channel: channel)
    // Flutter delivers `detachFromEngine(for:)` only to a plugin that
    // published itself (FlutterPlugin.h). Without this line the hook below
    // never ran, and the coordinator kept every torn-down engine's channel
    // for the life of the process. Only iOS delivers it: the macOS
    // `FlutterPlugin` protocol declares no detach hook, and a macOS engine
    // lives as long as the process anyway. See #9342.
    registrar.publish(instance)
    registrar.addMethodCallDelegate(instance, channel: channel)
    #if os(iOS)
    registrar.addApplicationDelegate(instance)
    #endif
  }

  /// Runs inside `-[FlutterEngine dealloc]` (iOS only, see `register`). The
  /// coordinator outlives every engine, so without this its channel list
  /// grows by one entry per engine, each upload event keeps fanning out to
  /// the dead ones — a "Communicating on a dead channel" warning per
  /// progress tick, forever — and a publish session the dead engine's Dart
  /// opened holds every later background wake until the watchdog fires.
  ///
  /// Nothing here may go through `registrar`: every weak reference to a
  /// deallocating object already reads nil, so `registrar.messenger()` hands
  /// Swift a nil where it expects a `FlutterBinaryMessenger`. The channel
  /// captured at init is all the coordinator needs. This hook does not cover
  /// the window between `destroyContext` and dealloc, in which the engine
  /// object is alive but its shell is gone; a send there still trips the
  /// shell assert in `sendOnChannel:`.
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    // The coordinator's state is main-queue-confined and dealloc runs on
    // whichever thread dropped the engine's last reference.
    let channel = self.channel
    if Thread.isMainThread {
      BackgroundUploadCoordinator.shared.detach(channel)
    } else {
      DispatchQueue.main.async {
        BackgroundUploadCoordinator.shared.detach(channel)
      }
    }
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isSupported":
      result(true)
    case "enqueue":
      enqueue(call.arguments, result: result)
    case "cancel":
      cancel(call.arguments, result: result)
    case "activeTaskIds":
      activeTaskIds(result: result)
    case "beginForegroundSession":
      beginForegroundSession(call.arguments, result: result)
    case "endForegroundSession":
      endForegroundSession(call.arguments, result: result)
    case "diagnostics":
      result(BackgroundUploadCoordinator.shared.diagnostics())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Begins a background-task assertion on iOS so in-process work survives a
  /// brief suspension; a no-op on macOS, which does not background-restrict
  /// network the way iOS does.
  private func beginForegroundSession(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    #if os(iOS)
    guard
      let args = arguments as? [String: Any],
      let sessionId = args["sessionId"] as? String, !sessionId.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "beginForegroundSession requires a sessionId",
          details: nil
        )
      )
      return
    }
    BackgroundUploadCoordinator.shared.beginForegroundSession(
      sessionId,
      owner: channel
    )
    #endif
    result(nil)
  }

  private func endForegroundSession(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    #if os(iOS)
    if let args = arguments as? [String: Any],
      let sessionId = args["sessionId"] as? String {
      BackgroundUploadCoordinator.shared.endForegroundSession(sessionId)
    }
    #endif
    result(nil)
  }

  private func enqueue(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let taskId = args["taskId"] as? String, !taskId.isEmpty,
      let urlString = args["url"] as? String,
      let url = URL(string: urlString),
      let filePath = args["filePath"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "enqueue requires taskId, url, and filePath",
          details: nil
        )
      )
      return
    }

    let fileURL = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: filePath) else {
      result(
        FlutterError(
          code: "file_not_found",
          message: "No file at \(filePath)",
          details: nil
        )
      )
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = (args["method"] as? String) ?? "PUT"
    if let headers = args["headers"] as? [String: Any] {
      for (key, value) in headers {
        request.setValue(String(describing: value), forHTTPHeaderField: key)
      }
    }

    BackgroundUploadCoordinator.shared.enqueue(
      taskId: taskId,
      request: request,
      fileURL: fileURL
    ) {
      result(nil)
    }
  }

  private func cancel(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let taskId = args["taskId"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "cancel requires a taskId",
          details: nil
        )
      )
      return
    }

    BackgroundUploadCoordinator.shared.cancel(taskId: taskId) {
      result(nil)
    }
  }

  private func activeTaskIds(result: @escaping FlutterResult) {
    BackgroundUploadCoordinator.shared.activeTaskIds { ids in
      result(ids)
    }
  }
}

#if os(iOS)
extension BackgroundUploaderPlugin {
  public func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) -> Bool {
    guard identifier == BackgroundUploadCoordinator.sessionIdentifier else {
      return false
    }
    BackgroundUploadCoordinator.shared.handleBackgroundEvents(
      completionHandler: completionHandler
    )
    return true
  }
}
#endif
