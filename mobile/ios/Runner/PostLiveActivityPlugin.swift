import ActivityKit
import Flutter
import Foundation

// MARK: - Pure pieces (no ActivityKit, unit tested)

/// `start` arguments from Dart. Nil when a key is missing or mistyped.
struct PostActivityStartArguments {
    let ownerPubkey: String
    let thumbnailFileName: String?
    let showFirstRunNote: Bool

    init?(_ arguments: Any?) {
        guard
            let map = arguments as? [String: Any],
            let ownerPubkey = map["ownerPubkey"] as? String,
            let showFirstRunNote = map["showFirstRunNote"] as? Bool,
            let thumbnail = Self.optionalString(map["thumbnailFileName"])
        else { return nil }
        self.ownerPubkey = ownerPubkey
        self.thumbnailFileName = thumbnail.value
        self.showFirstRunNote = showFirstRunNote
    }

    /// Absent or null is fine; present with another type is not.
    fileprivate static func optionalString(_ value: Any?) -> (value: String?, Void)? {
        if value == nil || value is NSNull { return (nil, ()) }
        guard let string = value as? String else { return nil }
        return (string, ())
    }
}

/// `update` arguments from Dart. Nil when a key is missing or mistyped.
struct PostActivityUpdateArguments {
    let activityId: String
    let phase: PostActivityPhase
    let postCoordinate: String?
    let postEventId: String?
    let showFirstRunNote: Bool

    init?(_ arguments: Any?) {
        guard
            let map = arguments as? [String: Any],
            let activityId = map["activityId"] as? String,
            let phaseName = map["phase"] as? String,
            let phase = PostActivityPhase(rawValue: phaseName),
            let showFirstRunNote = map["showFirstRunNote"] as? Bool,
            let coordinate = PostActivityStartArguments.optionalString(map["postCoordinate"]),
            let eventId = PostActivityStartArguments.optionalString(map["postEventId"])
        else { return nil }
        self.activityId = activityId
        self.phase = phase
        self.postCoordinate = coordinate.value
        self.postEventId = eventId.value
        self.showFirstRunNote = showFirstRunNote
    }
}

enum PostActivityPushToken {
    /// Lowercase hex, which is what the push service registers.
    static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }
}

/// What the bridge reports about one existing activity.
struct PostActivitySnapshot {
    let activityId: String
    let ownerPubkey: String
    let startedAtMs: Int
    let postCoordinate: String?
    let postEventId: String?
    /// `active | ended | dismissed | stale`.
    let state: String
    let pushToken: Data?

    var listEntry: [String: Any] {
        var entry: [String: Any] = [
            "activityId": activityId,
            "ownerPubkey": ownerPubkey,
            "startedAtMs": startedAtMs,
            "state": state,
        ]
        if let postCoordinate { entry["postCoordinate"] = postCoordinate }
        if let postEventId { entry["postEventId"] = postEventId }
        return entry
    }
}

/// Where the stream handler reads the current activities from, so replay can
/// be tested without starting real ones.
protocol PostActivitySource {
    func snapshots() -> [PostActivitySnapshot]
    func isEnabled() -> Bool
}

enum PostActivityEvents {
    static func enablement(_ enabled: Bool) -> [String: Any] {
        ["type": "enablement", "enabled": enabled]
    }

    static func pushToken(activityId: String, token: Data) -> [String: Any] {
        [
            "type": "pushToken",
            "activityId": activityId,
            "token": PostActivityPushToken.hex(token),
        ]
    }

    static func state(activityId: String, state: String) -> [String: Any] {
        ["type": "state", "activityId": activityId, "state": state]
    }
}

/// Event channel handler. Observations that began before Dart listened
/// (launch time) emitted into nothing, so `onListen` replays the present
/// enablement, every existing token and every state.
final class PostActivityStreamHandler: NSObject, FlutterStreamHandler {
    private let source: PostActivitySource
    private var sink: FlutterEventSink?

    init(source: PostActivitySource) {
        self.source = source
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        sink = events
        events(PostActivityEvents.enablement(source.isEnabled()))
        for snapshot in source.snapshots() {
            if let token = snapshot.pushToken {
                events(PostActivityEvents.pushToken(activityId: snapshot.activityId, token: token))
            }
            events(PostActivityEvents.state(activityId: snapshot.activityId, state: snapshot.state))
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    /// Delivers a live event, dropped while nobody listens (the next
    /// `onListen` replays current values).
    func emit(_ event: [String: Any]) {
        sink?(event)
    }
}

// MARK: - ActivityKit-backed source and plugin

@available(iOS 16.2, *)
private enum PostActivityKit {
    static func stateName(_ state: ActivityState) -> String {
        switch state {
        case .active: return "active"
        case .ended: return "ended"
        case .dismissed: return "dismissed"
        case .stale: return "stale"
        @unknown default: return "ended"
        }
    }

    static func snapshot(_ activity: Activity<PostActivityAttributes>) -> PostActivitySnapshot {
        PostActivitySnapshot(
            activityId: activity.id,
            ownerPubkey: activity.attributes.ownerPubkey,
            startedAtMs: Int(activity.attributes.startedAt.timeIntervalSince1970 * 1000),
            postCoordinate: activity.content.state.postCoordinate,
            postEventId: activity.content.state.postEventId,
            state: stateName(activity.activityState),
            pushToken: activity.pushToken
        )
    }

    static func activity(withId id: String) -> Activity<PostActivityAttributes>? {
        Activity<PostActivityAttributes>.activities.first { $0.id == id }
    }
}

@available(iOS 16.2, *)
private struct LivePostActivitySource: PostActivitySource {
    func snapshots() -> [PostActivitySnapshot] {
        Activity<PostActivityAttributes>.activities.map(PostActivityKit.snapshot)
    }

    func isEnabled() -> Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}

/// Method and event channels for the post Live Activity. The only code that
/// touches ActivityKit; the repository in Dart owns every decision.
final class PostLiveActivityPlugin: NSObject {
    static let methodChannelName = "divine/post_live_activity"
    static let eventChannelName = "divine/post_live_activity/events"
    /// How long an activity may go without an update before it is stale.
    static let staleInterval: TimeInterval = 10 * 60

    // Process-lifetime, like NostrBridgeAttestationPlugin.
    private static var shared: PostLiveActivityPlugin?

    private let streamHandler: PostActivityStreamHandler
    private var observed = Set<String>()

    private override init() {
        if #available(iOS 16.2, *) {
            streamHandler = PostActivityStreamHandler(source: LivePostActivitySource())
        } else {
            streamHandler = PostActivityStreamHandler(source: UnsupportedSource())
        }
        super.init()
    }

    private struct UnsupportedSource: PostActivitySource {
        func snapshots() -> [PostActivitySnapshot] { [] }
        func isEnabled() -> Bool { false }
    }

    static func setup(messenger: FlutterBinaryMessenger) {
        let plugin = PostLiveActivityPlugin()
        shared = plugin

        let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        methodChannel.setMethodCallHandler { [weak plugin] call, result in
            plugin?.handle(call, result: result)
        }
        FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
            .setStreamHandler(plugin.streamHandler)

        if #available(iOS 16.2, *) {
            plugin.observeEnablement()
            for activity in Activity<PostActivityAttributes>.activities {
                plugin.observe(activity)
            }
        }
    }

    // MARK: Method channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            handleUnsupported(call, result: result)
            return
        }
        switch call.method {
        case "isEnabled":
            result(ActivityAuthorizationInfo().areActivitiesEnabled)
        case "writeThumbnail":
            writeThumbnail(call, result: result)
        case "start":
            start(call, result: result)
        case "update":
            update(call, result: result)
        case "end":
            end(call, result: result)
        case "list":
            result(Activity<PostActivityAttributes>.activities.map { PostActivityKit.snapshot($0).listEntry })
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Below iOS 16.2 everything answers "not enabled".
    private func handleUnsupported(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "isEnabled": result(false)
        case "list": result([])
        case "start": result(FlutterError(code: "activity_failed", message: "unsupported", details: nil))
        case "writeThumbnail", "update", "end": result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func badArgs(_ result: FlutterResult, _ method: String) {
        result(FlutterError(code: "bad_args", message: "Invalid arguments for \(method)", details: nil))
    }

    private func writeThumbnail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let map = call.arguments as? [String: Any],
            let bytes = map["bytes"] as? FlutterStandardTypedData
        else { return badArgs(result, call.method) }
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PostActivityThumbnail.appGroup
        ) else {
            return result(FlutterError(code: "activity_failed", message: "no app group container", details: nil))
        }
        do {
            result(try PostActivityThumbnailWriter.write(bytes.data, containerURL: container))
        } catch {
            result(FlutterError(code: "activity_failed", message: "\(error)", details: nil))
        }
    }

    @available(iOS 16.2, *)
    private func start(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = PostActivityStartArguments(call.arguments) else {
            return badArgs(result, call.method)
        }
        let now = Date()
        let attributes = PostActivityAttributes(
            ownerPubkey: args.ownerPubkey,
            thumbnailFileName: args.thumbnailFileName,
            startedAt: now
        )
        let state = PostActivityContentState(
            phase: .posting,
            views: nil,
            likes: nil,
            comments: nil,
            updatedAt: now,
            showFirstRunNote: args.showFirstRunNote,
            postCoordinate: nil,
            postEventId: nil
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: now.addingTimeInterval(Self.staleInterval)
                ),
                pushType: .token
            )
            observe(activity)
            result(activity.id)
        } catch {
            result(FlutterError(code: "activity_failed", message: "\(error)", details: nil))
        }
    }

    @available(iOS 16.2, *)
    private func update(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = PostActivityUpdateArguments(call.arguments) else {
            return badArgs(result, call.method)
        }
        // An unknown id is a no-op: the activity may already have ended.
        guard let activity = PostActivityKit.activity(withId: args.activityId) else {
            return result(nil)
        }
        // Counts are carried over untouched; only the push service sets them.
        var state = activity.content.state
        state.phase = args.phase
        state.postCoordinate = args.postCoordinate
        state.postEventId = args.postEventId
        state.showFirstRunNote = args.showFirstRunNote
        state.updatedAt = Date()
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(Self.staleInterval)
        )
        Task {
            await activity.update(content)
            result(nil)
        }
    }

    @available(iOS 16.2, *)
    private func end(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let map = call.arguments as? [String: Any],
            let activityId = map["activityId"] as? String,
            let immediate = map["immediate"] as? Bool
        else { return badArgs(result, call.method) }
        guard let activity = PostActivityKit.activity(withId: activityId) else {
            return result(nil)
        }
        Task {
            await activity.end(nil, dismissalPolicy: immediate ? .immediate : .default)
            result(nil)
        }
    }

    // MARK: Observation

    @available(iOS 16.2, *)
    private func observeEnablement() {
        Task { [weak self] in
            for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                self?.streamHandler.emit(PostActivityEvents.enablement(enabled))
            }
        }
    }

    /// Streams this activity's token and state changes to Dart, once.
    @available(iOS 16.2, *)
    private func observe(_ activity: Activity<PostActivityAttributes>) {
        guard observed.insert(activity.id).inserted else { return }
        let id = activity.id
        Task { [weak self] in
            for await token in activity.pushTokenUpdates {
                self?.streamHandler.emit(PostActivityEvents.pushToken(activityId: id, token: token))
            }
        }
        Task { [weak self] in
            for await state in activity.activityStateUpdates {
                self?.streamHandler.emit(
                    PostActivityEvents.state(activityId: id, state: PostActivityKit.stateName(state))
                )
            }
        }
    }
}
