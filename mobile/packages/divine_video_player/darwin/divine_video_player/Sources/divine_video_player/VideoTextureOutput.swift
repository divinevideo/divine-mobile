import AVFoundation
import os
import QuartzCore
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// Bridges an `AVPlayer` to Flutter's texture system.
///
/// Uses `AVPlayerItemVideoOutput` to pull `CVPixelBuffer` frames from
/// the player and exposes them via the `FlutterTexture` protocol.
/// A `CADisplayLink` (iOS) or a `Timer` (macOS) drives the frame
/// polling loop.
final class VideoTextureOutput: NSObject, FlutterTexture, AVPlayerItemOutputPullDelegate {

    private let registry: FlutterTextureRegistry
    private var onFirstFrame: (() -> Void)?

    /// The ID registered with Flutter's texture registry.
    private(set) var textureId: Int64 = 0

    private var videoOutput: AVPlayerItemVideoOutput?
    #if os(iOS)
    private var displayLink: CADisplayLink?
    #elseif os(macOS)
    private var pollTimer: Timer?
    #endif
    private var latestPixelBuffer: CVPixelBuffer?
    private var hasDeliveredFirstFrame = false
    private weak var player: AVPlayer?
    /// Item the output is currently attached to, so we can detach cleanly.
    private weak var attachedItem: AVPlayerItem?

    /// Every item that already carries one of our outputs, newest last.
    ///
    /// `AVPlayerLooper` does not replay one item — it cycles a small set of
    /// copies, so the current item changes at every loop restart. Building the
    /// output at that moment means `item.add` and the decoder's first frame
    /// both land on the seam, and until one arrives `copyPixelBuffer` keeps
    /// returning the previous lap's last frame: a visible freeze, once per
    /// loop, on any asset. Adding the output to each queued item ahead of time
    /// leaves nothing to do at the switch but adopt it.
    ///
    /// Items are held strongly, which is safe because the set only ever holds
    /// what [prewarm] was given — the looper's own items, which it retains for
    /// as long as it exists — and is dropped wholesale on [dispose].
    private var warmOutputs: [(item: AVPlayerItem, output: AVPlayerItemVideoOutput)] = []
    /// One-shot observation that triggers the initial frame pull as soon
    /// as the freshly attached item reports `.readyToPlay`. Without this,
    /// the first `copyPixelBuffer(forItemTime:)` can race the decoder
    /// initialisation on HEVC 10-bit / HDR clips and return `nil`
    /// indefinitely until something else (e.g. a loop restart) flushes
    /// the output sequence.
    private var itemStatusObservation: NSKeyValueObservation?
    /// Exact seek target from the most recent `forceRefresh`; preferred over
    /// `player.currentTime()` because a newer seek may already be in flight.
    private var pendingSeekTime: CMTime = .invalid

    /// Window during which the display link bypasses `hasNewPixelBuffer`
    /// and tries `copyPixelBuffer` on every tick. Covers the GOP-decode
    /// stall after an exact seek (up to ~500 ms on long-GOP clips).
    /// Uses `CACurrentMediaTime()` (monotonic) so NTP/TZ clock jumps
    /// can't collapse or extend the window.
    private var forceRefreshDeadline: CFTimeInterval = 0

    /// Failed `copyPixelBuffer` ticks within the current force window.
    /// Non-zero at expiry means the compositor is stuck at this time.
    private var forceWindowFailCount = 0

    /// Marks the current force window as a tolerant-seek retry. When
    /// `true`, expiry without a frame does NOT fire `onSeekStuck` again,
    /// preventing an infinite retry loop on persistently broken content.
    private var forceWindowIsRetry = false

    /// Consecutive `outputMediaDataWillChange` calls that returned `nil`
    /// from `copyPixelBuffer`. Reset on flush, forceRefresh, and successful
    /// frame delivery. Capped to prevent an infinite re-arm loop when a
    /// seek target is persistently un-decodable.
    private var mediaDataRearmCount = 0
    private static let maxMediaDataRearmCount = 10

    /// Item time of the most recently delivered frame, or `.invalid` until
    /// the first frame and after every attach / flush. Used to detect a
    /// "playing but frozen" texture: when the player clock advances past this
    /// while `copyPixelBuffer` keeps returning `nil`, the output pull is
    /// wedged and needs an explicit re-prime (see `pullAndDeliverFrame`).
    private var lastDeliveredItemTime: CMTime = .invalid

    /// Throttle (monotonic `CACurrentMediaTime()`) gating how often the
    /// stalled-texture recovery may re-arm the output, so a persistently
    /// wedged frame can't spam `requestNotificationOfMediaDataChange` on
    /// every display-link tick.
    private var nextStallRecoveryTime: CFTimeInterval = 0

    /// How far the player clock must advance past `lastDeliveredItemTime`
    /// with no new frame before the texture counts as stalled. Comfortably
    /// above a normal between-tick frame gap so brief decode hiccups and the
    /// loop-boundary time reset don't trip it.
    private static let stalledTextureAdvanceSeconds = 0.25

    /// Minimum spacing between stalled-texture recovery re-arms.
    private static let stallRecoveryIntervalSeconds: CFTimeInterval = 0.3

    /// Serialises access to `latestPixelBuffer`, which is written on the
    /// display-link callback (main thread) and read on Flutter's render
    /// thread via `copyPixelBuffer()`.
    private var pixelBufferLock = os_unfair_lock()

    /// Gates every path that calls `registry.textureFrameAvailable`.
    /// Flipped to `false` while the app is backgrounded (and on
    /// `dispose`) so the display-link / AVFoundation-notification / preroll
    /// paths stop pushing frames into the Flutter engine during the
    /// resign-active → suspend window. Delivering a frame in that window
    /// dereferences a torn-down `Shell` inside
    /// `-[FlutterEngine textureFrameAvailable:]` and crashes with
    /// EXC_BAD_ACCESS. Read/written on the main thread only.
    private var isFrameDeliveryEnabled = true

    /// Set once `dispose()` has run. Guards `resumeFrameDelivery()` so a
    /// foreground notification that races a teardown-driven dispose can never
    /// re-arm delivery on an output whose texture is already unregistered.
    /// Read/written on the main thread only.
    private var isDisposed = false

    /// Fired when the force window expires without a frame; caller should
    /// retry the seek with tolerance. Suppressed for retry windows.
    var onSeekStuck: ((CMTime) -> Void)?

    init(
        registry: FlutterTextureRegistry,
        onFirstFrame: (() -> Void)? = nil
    ) {
        self.registry = registry
        self.onFirstFrame = onFirstFrame

        super.init()

        // Register after super.init() so `self` is fully initialised
        // and `copyPixelBuffer()` can be called immediately.
        textureId = registry.register(self)
    }

    // MARK: - Public API

    /// Builds an output configured for Flutter's external-texture path.
    ///
    /// Request 32BGRA: Flutter's external-texture upload path expects a BGRA
    /// `CVPixelBuffer` and renders garbage / black on YpCbCr buffers.
    /// AVFoundation will color-convert 10-bit / HDR sources into BGRA for us —
    /// at the cost of HDR range, but that's the same tradeoff the official
    /// video_player plugin makes when it doesn't pass an explicit Metal
    /// renderer.
    private func makeVideoOutput() -> AVPlayerItemVideoOutput {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA,
            // Force IOSurface backing so the buffer can be uploaded to
            // the GPU as a Flutter texture without an extra copy.
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
        output.setDelegate(self, queue: .main)
        return output
    }

    /// Gives every item in [items] an output before it becomes current.
    ///
    /// Pass `AVPlayerLooper.loopingPlayerItems`. The looper cycles that same
    /// small set, so after the first pass every lap finds its output already
    /// attached and [attach] has nothing to build at the seam. Items the
    /// looper no longer owns are dropped, so rebuilding the queue cannot pin
    /// an old item's decoder for the life of the player.
    func prewarm(items: [AVPlayerItem]) {
        for entry in warmOutputs
        where !items.contains(where: { $0 === entry.item }) && entry.item !== attachedItem {
            entry.item.remove(entry.output)
        }
        warmOutputs.removeAll { entry in
            !items.contains(where: { $0 === entry.item })
        }

        for item in items where !warmOutputs.contains(where: { $0.item === item }) {
            // The current item already has one; adopt it rather than adding a
            // second output to the same item.
            if item === attachedItem, let existing = videoOutput {
                warmOutputs.append((item: item, output: existing))
                continue
            }
            let output = makeVideoOutput()
            item.add(output)
            warmOutputs.append((item: item, output: output))
        }
    }

    /// Attaches the video output to a player item so frames can be
    /// pulled from it.
    func attach(to item: AVPlayerItem) {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        // Already warmed by [prewarm] — adopt it. Nothing is torn down: the
        // outgoing item keeps its own output so it is warm again when the
        // looper comes back around to it.
        if let warm = warmOutputs.first(where: { $0.item === item })?.output {
            videoOutput = warm
            attachedItem = item
            pendingSeekTime = .invalid
            mediaDataRearmCount = 0
            lastDeliveredItemTime = .invalid
            nextStallRecoveryTime = 0
            warm.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
            return
        }

        // Remove the old output from the item it was actually added to.
        if let old = videoOutput,
           let prev = attachedItem,
           !warmOutputs.contains(where: { $0.item === prev }) {
            prev.remove(old)
        }

        let output = makeVideoOutput()
        item.add(output)
        videoOutput = output
        attachedItem = item
        hasDeliveredFirstFrame = false
        pendingSeekTime = .invalid
        mediaDataRearmCount = 0
        lastDeliveredItemTime = .invalid
        nextStallRecoveryTime = 0

        // The first `copyPixelBuffer` attempt right after attach often
        // races decoder init (especially on HEVC 10-bit / HDR), and
        // returns `nil` until something flushes the output sequence —
        // which normally only happens on the next loop or seek. Watch
        // for `.readyToPlay` and explicitly request a media-data-change
        // notification so the decoder is forced to hand over the first
        // frame as soon as it's available.
        if item.status == .readyToPlay {
            output.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
        } else {
            itemStatusObservation = item.observe(
                \.status,
                options: [.new]
            ) { [weak self, weak output] item, _ in
                guard let self, let output, item.status == .readyToPlay else {
                    return
                }
                output.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
                self.itemStatusObservation?.invalidate()
                self.itemStatusObservation = nil
            }
        }
    }

    /// Attaches the frame-driver polling loop to the player.
    /// Call once after the player is created.
    func attachPlayer(_ player: AVPlayer) {
        self.player = player
        startFrameDriver()
    }

    /// Opens a 600 ms force window after a seek and requests a delegate
    /// notification, so the texture updates even while paused. Pass the
    /// exact seek target — used directly in `outputMediaDataWillChange`.
    /// Pass `isRetry: true` for a tolerant-seek retry; suppresses
    /// `onSeekStuck` on expiry to break recovery loops.
    func forceRefresh(for seekTime: CMTime, isRetry: Bool = false) {
        mediaDataRearmCount = 0
        pendingSeekTime = seekTime
        forceRefreshDeadline = CACurrentMediaTime() + 0.6
        forceWindowFailCount = 0
        forceWindowIsRetry = isRetry
        videoOutput?.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }

    /// Synchronously attempts to pull a frame at `time` and push it into
    /// the Flutter texture. Returns `true` if a real `CVPixelBuffer` was
    /// delivered (which fires `onFirstFrame` on the first successful
    /// call) and resets the output's retry/refresh bookkeeping like a
    /// regular delivery would. Used by `safePreroll` to flip
    /// `DivineVideoPlayerInstance.firstFrameRendered` only when the
    /// texture actually has a buffer — otherwise Flutter would render
    /// the texture's initial empty state (black) until the async
    /// display-link path delivers one.
    @discardableResult
    func tryPullFrameNow(at time: CMTime) -> Bool {
        guard let output = videoOutput else { return false }
        guard let pixelBuffer = output.copyPixelBuffer(
            forItemTime: time,
            itemTimeForDisplay: nil
        ) else {
            return false
        }
        pendingSeekTime = .invalid
        forceRefreshDeadline = 0
        forceWindowFailCount = 0
        mediaDataRearmCount = 0
        deliverFrame(pixelBuffer, at: time)
        return true
    }

    // MARK: - AVPlayerItemOutputPullDelegate

    /// Called after a seek flushes the output queue.
    func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
        mediaDataRearmCount = 0
        lastDeliveredItemTime = .invalid
        (output as? AVPlayerItemVideoOutput)?
            .requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }

    /// Fires even on a paused player — most reliable frame path after an
    /// exact seek on an `AVMutableComposition` with `AVVideoComposition`.
    func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        guard let videoOutput = sender as? AVPlayerItemVideoOutput else {
            return
        }
        // Prefer the stored seek target; fall back to currentTime only when
        // there's no pending seek (e.g. notification from a flush).
        let targetTime: CMTime
        if pendingSeekTime.isValid {
            targetTime = pendingSeekTime
        } else if let p = player {
            targetTime = p.currentTime()
        } else {
            return
        }
        let pb = videoOutput.copyPixelBuffer(
            forItemTime: targetTime,
            itemTimeForDisplay: nil
        )
        guard let pixelBuffer = pb else {
            mediaDataRearmCount += 1
            if mediaDataRearmCount < VideoTextureOutput.maxMediaDataRearmCount {
                videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
            }
            return
        }
        mediaDataRearmCount = 0
        pendingSeekTime = .invalid
        forceRefreshDeadline = 0
        forceWindowFailCount = 0
        deliverFrame(pixelBuffer, at: targetTime)
    }

    // MARK: - App lifecycle

    /// Pauses frame delivery into the Flutter texture while the app is
    /// backgrounded. The display link is paused so it stops polling, and
    /// `isFrameDeliveryEnabled` gates the AVFoundation-notification and
    /// preroll paths too — together they guarantee no `textureFrameAvailable`
    /// call reaches the engine while it may be tearing down its shell during
    /// suspension. Must be called on the main thread.
    func suspendFrameDelivery() {
        isFrameDeliveryEnabled = false
        #if os(iOS)
        displayLink?.isPaused = true
        #endif
    }

    /// Re-enables frame delivery when the app returns to the foreground.
    /// The retained `latestPixelBuffer` keeps the texture populated across
    /// the background period, so resuming does not flash black. Must be
    /// called on the main thread.
    func resumeFrameDelivery() {
        guard !isDisposed else { return }
        isFrameDeliveryEnabled = true
        #if os(iOS)
        displayLink?.isPaused = false
        #endif
    }

    /// Cleans up the frame driver and unregisters the texture.
    func dispose() {
        isDisposed = true
        isFrameDeliveryEnabled = false
        stopFrameDriver()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        registry.unregisterTexture(textureId)
        warmOutputs.removeAll()
        videoOutput = nil
        latestPixelBuffer = nil
        onFirstFrame = nil
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        os_unfair_lock_lock(&pixelBufferLock)
        let pixelBuffer = latestPixelBuffer
        os_unfair_lock_unlock(&pixelBufferLock)
        guard let pixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }

    // MARK: - Frame driver

    #if os(iOS)
    private func startFrameDriver() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(
            target: self,
            selector: #selector(onDisplayLink)
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopFrameDriver() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onDisplayLink() {
        pullAndDeliverFrame()
    }
    #elseif os(macOS)
    private func startFrameDriver() {
        guard pollTimer == nil else { return }
        // macOS < 14 has no CADisplayLink; poll at ~60 fps to match a
        // typical display refresh rate.
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.pullAndDeliverFrame()
        }
    }

    private func stopFrameDriver() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    #endif

    private func deliverFrame(_ pixelBuffer: CVPixelBuffer, at itemTime: CMTime) {
        lastDeliveredItemTime = itemTime
        nextStallRecoveryTime = 0
        os_unfair_lock_lock(&pixelBufferLock)
        latestPixelBuffer = pixelBuffer
        os_unfair_lock_unlock(&pixelBufferLock)
        guard isFrameDeliveryEnabled else { return }
        registry.textureFrameAvailable(textureId)
        if !hasDeliveredFirstFrame {
            hasDeliveredFirstFrame = true
            onFirstFrame?()
        }
    }

    /// Pulls the current frame and pushes it into the Flutter texture.
    /// Driven by `CADisplayLink` on iOS and a `Timer` on macOS.
    private func pullAndDeliverFrame() {
        guard isFrameDeliveryEnabled,
              let output = videoOutput,
              let player else { return }

        let itemTime = player.currentTime()

        if CACurrentMediaTime() < forceRefreshDeadline {
            if let pixelBuffer = output.copyPixelBuffer(
                forItemTime: itemTime,
                itemTimeForDisplay: nil
            ) {
                pendingSeekTime = .invalid
                forceRefreshDeadline = 0
                forceWindowFailCount = 0
                deliverFrame(pixelBuffer, at: itemTime)
            } else {
                forceWindowFailCount += 1
            }
            return
        }

        if forceWindowFailCount > 0 {
            let stuckTime = itemTime
            let wasRetry = forceWindowIsRetry
            forceWindowFailCount = 0
            forceWindowIsRetry = false
            if !wasRetry {
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekStuck?(stuckTime)
                }
            }
        }

        // Skip `hasNewPixelBuffer(forItemTime:)` and just attempt the
        // copy. The predicate returns `false` indefinitely on some
        // sources (HEVC over `AVMutableComposition`, and progressive
        // MP4 under decode pressure) even while the player is actively
        // decoding — audio continues and time advances, but the texture
        // wedges on the last frame. `copyPixelBuffer(forItemTime:)` is
        // cheap when no new frame is ready (returns `nil`), so polling
        // it on every display-link tick costs only the call itself; a
        // sustained `nil` streak while playing triggers an explicit
        // re-prime via `recoverStalledTextureIfNeeded`.
        if let pixelBuffer = output.copyPixelBuffer(
            forItemTime: itemTime,
            itemTimeForDisplay: nil
        ) {
            deliverFrame(pixelBuffer, at: itemTime)
        } else {
            recoverStalledTextureIfNeeded(output, itemTime: itemTime)
        }
    }

    /// Breaks the "playing but frozen" deadlock where `AVPlayerItemVideoOutput`
    /// keeps returning `nil` from `copyPixelBuffer` while the player clock
    /// keeps advancing — audio plays on, but the texture stays on the last
    /// delivered frame until the next flush (loop restart) clears it. Re-arms
    /// the output's media-data notification — the same unstick the loop flush
    /// performs in `outputSequenceWasFlushed` — as soon as the clock has
    /// demonstrably moved past `lastDeliveredItemTime`, so playback recovers
    /// mid-clip instead of only on the next loop.
    ///
    /// Gated so it can't fire spuriously: a paused player legitimately holds
    /// its last frame (`rate <= 0`), and a genuine buffer underrun freezes the
    /// player clock too (`itemTime` stops advancing), so neither trips it.
    /// Throttled to one re-arm per `stallRecoveryIntervalSeconds`.
    private func recoverStalledTextureIfNeeded(
        _ output: AVPlayerItemVideoOutput,
        itemTime: CMTime
    ) {
        guard let player, player.rate > 0, lastDeliveredItemTime.isValid
        else { return }
        let advanced = CMTimeGetSeconds(itemTime)
            - CMTimeGetSeconds(lastDeliveredItemTime)
        guard advanced > VideoTextureOutput.stalledTextureAdvanceSeconds
        else { return }
        let now = CACurrentMediaTime()
        guard now >= nextStallRecoveryTime else { return }
        nextStallRecoveryTime =
            now + VideoTextureOutput.stallRecoveryIntervalSeconds
        mediaDataRearmCount = 0
        output.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }
}
