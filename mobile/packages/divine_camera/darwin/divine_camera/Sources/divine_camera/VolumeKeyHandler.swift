// ABOUTME: Handles volume button and media button events for remote recording (iOS)
// ABOUTME: Supports Bluetooth accessories via MPRemoteCommandCenter and volume buttons

// Volume keys and Bluetooth remote triggers exist only on iOS; the plugin
// answers false for them on macOS.
#if os(iOS)
import AVFoundation
import MediaPlayer
import UIKit

/// Handles volume button presses and Bluetooth media button events
/// for remote recording control on iOS.
///
/// Receiving AirPods/Bluetooth media-button presses requires becoming the iOS
/// "Now Playing" app (MPNowPlayingInfoCenter + MPRemoteCommandCenter), which
/// surfaces a media control (play/pause) on the Lock Screen / Control Center.
/// To stop that control lingering on the Lock Screen after the app is
/// backgrounded (#6090), the Now Playing session is scoped to the foreground:
/// it is released on `didEnterBackground` and re-claimed on `didBecomeActive`
/// while the handler is enabled. Camera capture is suspended in the background
/// anyway, so no remote trigger is lost.
class VolumeKeyHandler: NSObject {
    private var volumeKeysEnabled = true  // Can be toggled independently
    private var onTrigger: ((String) -> Void)?

    // Volume button detection
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    private var lastVolume: Float = 0.5
    private var isObservingVolume = false

    // Track volume changes to detect button presses
    private var volumeChangeTimer: Timer?
    private var isInternalVolumeChange = false

    // Cooldown after activation to ignore spurious Bluetooth events.
    // Must be long enough to cover delayed events from AirPods/Apple Watch
    // that arrive after audio route changes during camera initialization.
    private var enabledTimestamp: TimeInterval = 0
    private let activationCooldownSeconds: TimeInterval = 3.0

    // Debounce between Bluetooth triggers to prevent rapid-fire events
    private var lastBluetoothTriggerTimestamp: TimeInterval = 0
    private let bluetoothDebounceSeconds: TimeInterval = 1.0

    // Temporary suppression during camera switch / audio route changes
    private var isSuppressed = false

    // Foreground-scoping state machine for the Now Playing session (#6090). Owns
    // both the enabled flag and whether the MPRemoteCommandCenter session is
    // registered, extracted as pure logic so the transition table is
    // unit-testable. See MediaSessionScopePolicy.
    private var scope = MediaSessionScopePolicy()

    // Re-asserts the owning (UI) engine's diagnostics sink before emitting any
    // native-only diagnostic. iOS has no Activity-attachment lifecycle to bind
    // sink ownership to (unlike Android), so volume/Bluetooth callbacks — which
    // fire without a method call — reclaim the sink here so a background engine
    // that registered the plugin can't steal these UI-only events. See #5128.
    private let reclaimLogSink: (() -> Void)?

    init(reclaimLogSink: (() -> Void)? = nil, onTrigger: @escaping (String) -> Void) {
        self.reclaimLogSink = reclaimLogSink
        self.onTrigger = onTrigger
        super.init()
    }

    /// Enables volume button listening.
    /// Sets up MPRemoteCommandCenter for Bluetooth remotes and volume observation.
    /// Returns true if successfully enabled.
    func enable() -> Bool {
        if scope.isEnabled {
            return true
        }

        // NOTE: We intentionally do NOT configure the audio session here.
        // The camera already configures its own audio session for video recording.
        // Setting .playAndRecord with Bluetooth options causes iOS to trigger
        // "call start/end" sounds on Bluetooth headsets, which is undesirable.
        // MPRemoteCommandCenter and volume KVO work without specific audio session setup.

        setupVolumeObserver()

        volumeKeysEnabled = true

        registerAppLifecycleObservers()

        // Only claim the Now Playing session while the app is foreground-active.
        // Claiming it in the background would leave a persistent "Recording"
        // media control on the Lock Screen (#6090); it is (re)claimed on
        // foreground via appDidBecomeActive.
        let appActive = UIApplication.shared.applicationState == .active
        if scope.onEnable(appActive: appActive) {
            performActivateMediaSession()
        }

        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Enabled")
        return true
    }

    /// Disables volume button listening.
    func disable() {
        if !scope.isEnabled {
            return
        }

        unregisterAppLifecycleObservers()
        if scope.onDisable() {
            performDeactivateMediaSession()
        }
        teardownVolumeObserver()

        volumeKeysEnabled = true
        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Disabled")
    }

    /// Enable or disable volume key interception.
    /// When disabled, volume buttons will change system volume instead of triggering recording.
    /// Bluetooth media buttons are NOT affected by this setting.
    func setVolumeKeysEnabled(_ enabled: Bool) {
        volumeKeysEnabled = enabled
        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Volume keys \(enabled ? "enabled" : "disabled")")
    }

    /// Whether volume key handling is currently enabled.
    func isHandlerEnabled() -> Bool {
        return scope.isEnabled
    }

    /// Temporarily suppress all triggers for the given duration.
    ///
    /// Used during camera switch and other operations that cause
    /// iOS audio route changes, which can trigger spurious Bluetooth
    /// play/pause events from connected devices (e.g. Apple Watch).
    func suppressTemporarily(forSeconds duration: TimeInterval = 1.0) {
        isSuppressed = true
        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Suppressed for \(duration)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isSuppressed = false
            // Native-only event (timer callback, no method call): reclaim the
            // UI engine's diagnostics sink first.
            self?.reclaimLogSink?()
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Suppression ended")
        }
    }

    /// Cleanup resources.
    func release() {
        disable()
        onTrigger = nil
    }

    // MARK: - App Lifecycle & Media Session Scoping

    /// Claims the iOS "Now Playing" session (MPRemoteCommandCenter +
    /// MPNowPlayingInfoCenter) so Bluetooth/AirPods media buttons route to us.
    /// Scoped to the foreground camera session so the media control never
    /// lingers on the Lock Screen (#6090). Callers gate this on `scope`; the
    /// performer itself is unconditional.
    private func performActivateMediaSession() {
        setupRemoteCommandCenter()
        enabledTimestamp = ProcessInfo.processInfo.systemUptime

        // Suppress triggers briefly to absorb spurious Bluetooth events that
        // fire when MPRemoteCommandCenter handlers are (re)registered. Connected
        // AirPods/Apple Watch may send play/pause when they detect a new
        // "now playing" app.
        isSuppressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + activationCooldownSeconds) { [weak self] in
            self?.isSuppressed = false
            // Native-only event (timer callback, no method call): reclaim the
            // UI engine's diagnostics sink first.
            self?.reclaimLogSink?()
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Initial suppression ended")
        }
        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Media session activated (suppressed for \(activationCooldownSeconds)s)")
    }

    /// Releases the Now Playing session. Callers gate this on `scope`; the
    /// performer itself is unconditional.
    private func performDeactivateMediaSession() {
        teardownRemoteCommandCenter()
        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Media session deactivated")
    }

    /// Assumes a single enabled handler per process: AppDelegate registers the
    /// plugin on both the UI engine and the background notification-action
    /// engine, so two instances exist and a second `enable()` would add a
    /// duplicate set of observers here. Dormant while only the UI engine drives
    /// the camera; revisit if the background isolate ever enables remote record.
    private func registerAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func unregisterAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// Releases the Now Playing session when the app backgrounds so no media
    /// control lingers on the Lock Screen (#6090). Camera capture is suspended
    /// in the background anyway, so no remote trigger is lost.
    @objc private func appDidEnterBackground() {
        if scope.onEnterBackground() {
            performDeactivateMediaSession()
        }
    }

    /// Re-claims the Now Playing session on return to the foreground so
    /// Bluetooth/AirPods media buttons keep controlling recording.
    @objc private func appDidBecomeActive() {
        // Native-only event (notification, no method call): reclaim the UI
        // engine's diagnostics sink first.
        reclaimLogSink?()
        if scope.onBecomeActive() {
            performActivateMediaSession()
        }
    }

    // MARK: - Remote Command Center (Bluetooth remotes/earbuds)

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play/Pause toggle (most common on Bluetooth headphones)
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.reclaimLogSink?()
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Bluetooth toggle play/pause")
            self?.handleBluetoothTrigger()
            return .success
        }

        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.reclaimLogSink?()
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Bluetooth play")
            self?.handleBluetoothTrigger()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.reclaimLogSink?()
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Bluetooth pause")
            self?.handleBluetoothTrigger()
            return .success
        }

        // Enable the commands
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true

        // Set up now playing info to make remote commands work
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Recording"
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Remote command center configured")
    }

    private func teardownRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Bluetooth Trigger Handling

    /// Handles a Bluetooth remote trigger with cooldown and debounce protection.
    ///
    /// Filters out:
    /// - Events during activation cooldown (spurious events when enabling)
    /// - Events during temporary suppression (camera switch / route changes)
    /// - Rapid-fire duplicate events (debounce)
    private func handleBluetoothTrigger() {
        let now = ProcessInfo.processInfo.systemUptime

        // Check suppression (camera switch in progress)
        if isSuppressed {
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Bluetooth trigger ignored - suppressed")
            return
        }

        // Check activation cooldown
        let timeSinceEnabled = now - enabledTimestamp
        if timeSinceEnabled < activationCooldownSeconds {
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Bluetooth trigger ignored - within \(String(format: "%.0f", activationCooldownSeconds * 1000))ms activation cooldown (\(String(format: "%.0f", timeSinceEnabled * 1000))ms since enabled)")
            return
        }

        // Check debounce between triggers
        let timeSinceLastTrigger = now - lastBluetoothTriggerTimestamp
        if timeSinceLastTrigger < bluetoothDebounceSeconds {
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Bluetooth trigger ignored - debounce (\(String(format: "%.0f", timeSinceLastTrigger * 1000))ms since last)")
            return
        }

        lastBluetoothTriggerTimestamp = now
        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Bluetooth trigger accepted")

        // Refresh now playing info so iOS keeps routing remote events to us.
        // Without this, audio session changes during recording start/stop can
        // cause iOS to disassociate our app from MPNowPlayingInfoCenter,
        // making AirPods stop sending events to our command handlers.
        refreshNowPlayingInfo()

        onTrigger?("bluetooth")
    }

    /// Refreshes MPNowPlayingInfoCenter to keep our app as the active
    /// "now playing" app. Without this, iOS may stop routing AirPods/Apple
    /// Watch button presses to our MPRemoteCommandCenter handlers after
    /// audio session changes (e.g. recording start/stop).
    private func refreshNowPlayingInfo() {
        // Only meaningful while the media session is active (foreground). If a
        // stray trigger arrives while backgrounded, don't re-create the Now
        // Playing entry — that would resurrect the Lock Screen control (#6090).
        guard scope.isMediaSessionActive else { return }
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Recording"
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Volume Button Detection

    private func setupVolumeObserver() {
        // Get current volume
        lastVolume = AVAudioSession.sharedInstance().outputVolume

        // Create a hidden MPVolumeView to prevent the system volume HUD from appearing
        let volumeView = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        volumeView.showsRouteButton = false
        volumeView.showsVolumeSlider = true

        // Find the volume slider within the view
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                self.volumeSlider = slider
                break
            }
        }

        // Add to window to receive events
        if let window = UIApplication.shared.windows.first {
            window.addSubview(volumeView)
            self.volumeView = volumeView
        }

        // Observe volume changes via KVO
        AVAudioSession.sharedInstance().addObserver(
            self,
            forKeyPath: "outputVolume",
            options: [.new, .old],
            context: nil
        )
        isObservingVolume = true

        DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Volume observer configured")
    }

    private func teardownVolumeObserver() {
        if isObservingVolume {
            AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
            isObservingVolume = false
        }

        volumeView?.removeFromSuperview()
        volumeView = nil
        volumeSlider = nil
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "outputVolume",
              let newValue = change?[.newKey] as? Float,
              let oldValue = change?[.oldKey] as? Float else {
            return
        }

        // Native-only event: reclaim the UI engine's diagnostics sink before
        // any logging below.
        reclaimLogSink?()

        // Only trigger if volume keys are enabled, not suppressed,
        // and this is an external change.
        // The isSuppressed check prevents audio route changes during camera
        // switch from being misinterpreted as volume button presses.
        if !isInternalVolumeChange && scope.isEnabled && volumeKeysEnabled && !isSuppressed {
            if newValue > oldValue {
                DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Volume up button pressed")
                onTrigger?("volumeUp")

                // Restore volume to prevent actual volume change
                restoreVolume(to: oldValue)
            } else if newValue < oldValue {
                DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Volume down button pressed")
                onTrigger?("volumeDown")

                // Restore volume to prevent actual volume change
                restoreVolume(to: oldValue)
            }
        } else if isSuppressed && !isInternalVolumeChange && newValue != oldValue {
            DivineCameraLog.shared.debug("DivineCameraVolumeKeyHandler: Volume change ignored - suppressed (camera switch in progress)")
            // Still restore volume during suppression to prevent drift
            restoreVolume(to: oldValue)
        }
        // If volume keys are disabled, let the volume change through (don't restore)
    }

    /// Restores the volume to the previous level to prevent actual volume changes
    private func restoreVolume(to level: Float) {
        isInternalVolumeChange = true

        // Use the hidden slider to set volume without showing the HUD
        DispatchQueue.main.async { [weak self] in
            self?.volumeSlider?.setValue(level, animated: false)

            // Reset the flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.isInternalVolumeChange = false
            }
        }
    }
}
#endif
