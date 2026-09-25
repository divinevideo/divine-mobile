// ABOUTME: Pure state machine deciding when the iOS "Now Playing" session is claimed
// ABOUTME: Extracted from VolumeKeyHandler so the #6090 foreground-scoping is unit-testable

import Foundation

/// Pure decision logic for scoping the iOS "Now Playing" session
/// (`MPRemoteCommandCenter` + `MPNowPlayingInfoCenter`) to the foreground.
///
/// `VolumeKeyHandler` must register the app as the "Now Playing" app to receive
/// AirPods/Bluetooth media-button presses, but that registration draws a media
/// control on the Lock Screen. To stop it lingering after the app is
/// backgrounded (#6090), the session is claimed only while the handler is
/// enabled AND the app is foreground-active: released on `didEnterBackground`,
/// re-claimed on `didBecomeActive`.
///
/// That policy is a two-flag state machine which, inside the handler, is
/// entangled with `UIApplication` and `MediaPlayer` singletons and cannot be
/// exercised from a unit test. It is extracted here as pure logic — no UIKit, no
/// MediaPlayer — so the transition table can be verified directly (mirrors
/// `NostrBridgeAttestationPolicy` in the Runner test target). Each mutating
/// method returns whether the caller must run the matching native side effect,
/// keeping the handler a thin performer over these decisions.
public struct MediaSessionScopePolicy {
    /// Whether the handler is listening (between `enable()` and `disable()`).
    public private(set) var isEnabled: Bool
    /// Whether the Now Playing session is currently claimed.
    public private(set) var isMediaSessionActive: Bool

    public init(isEnabled: Bool = false, isMediaSessionActive: Bool = false) {
        self.isEnabled = isEnabled
        self.isMediaSessionActive = isMediaSessionActive
    }

    /// The handler was enabled while the app is (`appActive == true`) or is not
    /// (`false`) foreground-active. Returns `true` if the caller should claim
    /// the Now Playing session now. Idempotent: a second `onEnable` while
    /// already enabled is a no-op.
    public mutating func onEnable(appActive: Bool) -> Bool {
        guard !isEnabled else { return false }
        isEnabled = true
        guard appActive, !isMediaSessionActive else { return false }
        isMediaSessionActive = true
        return true
    }

    /// The handler was disabled. Returns `true` if the caller should release the
    /// Now Playing session (i.e. it was claimed). No-op if already disabled.
    public mutating func onDisable() -> Bool {
        guard isEnabled else { return false }
        isEnabled = false
        guard isMediaSessionActive else { return false }
        isMediaSessionActive = false
        return true
    }

    /// The app entered the background. Returns `true` if the caller should
    /// release the Now Playing session so no control lingers on the Lock
    /// Screen (#6090).
    public mutating func onEnterBackground() -> Bool {
        guard isMediaSessionActive else { return false }
        isMediaSessionActive = false
        return true
    }

    /// The app became foreground-active. Returns `true` if the caller should
    /// (re)claim the Now Playing session — only while still enabled and not
    /// already claimed.
    public mutating func onBecomeActive() -> Bool {
        guard isEnabled, !isMediaSessionActive else { return false }
        isMediaSessionActive = true
        return true
    }
}
