// ABOUTME: Handles volume button and media button events for remote recording
// ABOUTME: Supports both physical volume buttons and Bluetooth accessories
// ABOUTME: Uses Window.Callback wrapper to intercept KeyEvents BEFORE system processes them

package co.openvine.divine_camera

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.view.KeyEvent
import android.view.Window
import androidx.annotation.VisibleForTesting

private const val TAG = "VolumeKeyHandler"

/**
 * Handles volume button presses and Bluetooth media button events
 * for remote recording control.
 *
 * Uses Window.Callback wrapper to intercept volume key events BEFORE
 * the system processes them, preventing volume UI from appearing.
 *
 * Android keeps sending headset and Bluetooth play/pause presses to the
 * media session that claimed them, even after its app is backgrounded. A
 * press meant for another app then started a recording nobody could see
 * (#10196), so the session is held only while the activity is in the
 * foreground: [onEnterBackground] releases it and [onBecomeActive] claims
 * it again. iOS scopes its Now Playing session the same way (#6090).
 */
class VolumeKeyHandler(
    private val context: Context,
    private val activity: Activity?,
    // Monotonic, so a wall-clock correction cannot cut the cooldown short or
    // stretch it out.
    private val clock: () -> Long = SystemClock::elapsedRealtime,
    private val onTrigger: (String) -> Unit
) {
    private var isEnabled = false
    private var volumeKeysEnabled = true  // Can be toggled independently
    private var mediaSession: MediaSessionCompat? = null
    private var originalCallback: Window.Callback? = null
    private var callbackWrapper: KeyInterceptingCallback? = null

    // Cooldown to ignore spurious Bluetooth events after the session is
    // claimed. A connected headset sends PAUSE when a new playing session
    // appears, which now happens on every return to the foreground; on a
    // Galaxy S26 it arrived 225-640 ms after the claim. 3 s matches iOS.
    private var sessionClaimedTimestamp: Long = 0
    private val activationCooldownMs: Long = 3000

    // Temporary suppression during camera switch / audio route changes
    @Volatile
    private var isSuppressed = false
    private val suppressHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var suppressRunnable: Runnable? = null

    // Debounce between Bluetooth triggers to prevent rapid-fire events
    private var lastBluetoothTriggerTimestamp: Long = 0
    private val bluetoothDebounceMs: Long = 1000

    /**
     * Enables volume button listening.
     * Sets up Window.Callback wrapper for physical buttons and, while the
     * activity is in the foreground ([appActive]), MediaSession for Bluetooth.
     */
    fun enable(appActive: Boolean): Boolean {
        if (isEnabled) {
            DivineCameraLog.d(TAG, "Volume key handler already enabled")
            return true
        }

        try {
            DivineCameraLog.d(TAG, "Enabling volume key handler...")
            setupWindowCallback()
            if (appActive) claimMediaSession()
            isEnabled = true
            volumeKeysEnabled = true
            DivineCameraLog.i(TAG, "Volume key handler enabled successfully")
            return true
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to enable volume key handler: ${e.message}", e)
            return false
        }
    }

    /**
     * Disables volume button listening.
     */
    fun disable() {
        if (!isEnabled) return
        
        try {
            // Restore original window callback
            activity?.window?.let { window ->
                originalCallback?.let { original ->
                    window.callback = original
                    DivineCameraLog.d(TAG, "Restored original window callback")
                }
            }
            originalCallback = null
            callbackWrapper = null

            releaseMediaSession()
            isEnabled = false
            volumeKeysEnabled = true
            DivineCameraLog.d(TAG, "Volume key handler disabled")
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to disable volume key handler: ${e.message}")
        }
    }

    /**
     * Enable or disable volume key interception.
     * When disabled, volume buttons will change system volume instead of triggering recording.
     * Bluetooth media buttons are NOT affected by this setting.
     */
    fun setVolumeKeysEnabled(enabled: Boolean) {
        volumeKeysEnabled = enabled
        DivineCameraLog.d(TAG, "Volume keys interception ${if (enabled) "enabled" else "disabled"}")
    }

    /**
     * The activity left the foreground. Releases the media session so a
     * headset press reaches the app in front instead of recording (#10196).
     */
    fun onEnterBackground() {
        if (mediaSession == null) return
        releaseMediaSession()
        DivineCameraLog.d(TAG, "MediaSession released - app in background")
    }

    /**
     * The activity is in the foreground again. Claims the media session back
     * while enabled, with a fresh activation cooldown.
     */
    fun onBecomeActive() {
        if (!isEnabled || mediaSession != null) return
        try {
            claimMediaSession()
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to claim MediaSession: ${e.message}", e)
        }
    }

    /**
     * Whether the media session receives Bluetooth and headset buttons.
     */
    @VisibleForTesting
    internal fun isMediaSessionClaimed(): Boolean = mediaSession != null

    /**
     * Sets up Window.Callback wrapper to intercept key events before system.
     */
    private fun setupWindowCallback() {
        val currentActivity = activity ?: run {
            DivineCameraLog.w(TAG, "No activity available, cannot intercept key events")
            return
        }
        
        val window = currentActivity.window ?: run {
            DivineCameraLog.w(TAG, "No window available, cannot intercept key events")
            return
        }
        
        originalCallback = window.callback
        callbackWrapper = KeyInterceptingCallback(originalCallback) { keyEvent ->
            handleKeyEvent(keyEvent)
        }
        window.callback = callbackWrapper
        
        DivineCameraLog.i(TAG, "Window.Callback wrapper installed for key event interception")
    }

    /**
     * Process a key event. Returns true if handled.
     * Volume keys are handled here (from Window.Callback).
     * Media keys are handled via MediaSession callbacks.
     */
    fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!isEnabled) return false
        
        // Only handle key down events to avoid double triggers
        if (event.action != KeyEvent.ACTION_DOWN) return false
        
        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                // Only intercept volume keys if enabled and not suppressed
                if (!volumeKeysEnabled) {
                    DivineCameraLog.d(TAG, "Volume up pressed but volume keys disabled - passing through")
                    return false
                }
                if (isSuppressed) {
                    DivineCameraLog.d(TAG, "Volume up pressed but suppressed (camera switch) - consuming")
                    return true  // Consume to prevent volume change, but don't trigger
                }
                DivineCameraLog.d(TAG, "Volume up button pressed")
                onTrigger("volumeUp")
                true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                // Only intercept volume keys if enabled and not suppressed
                if (!volumeKeysEnabled) {
                    DivineCameraLog.d(TAG, "Volume down pressed but volume keys disabled - passing through")
                    return false
                }
                if (isSuppressed) {
                    DivineCameraLog.d(TAG, "Volume down pressed but suppressed (camera switch) - consuming")
                    return true  // Consume to prevent volume change, but don't trigger
                }
                DivineCameraLog.d(TAG, "Volume down button pressed")
                onTrigger("volumeDown")
                true
            }
            // Media keys are handled by MediaSession, not here
            else -> false
        }
    }
    
    /**
     * Process a media button event from MediaSession.
     * Handles cooldown and repeat filtering.
     * Only intercepts play/pause type buttons - volume buttons pass through.
     */
    @VisibleForTesting
    internal fun handleMediaButtonEvent(event: KeyEvent): Boolean {
        // Disabled, or released in the background with this press still
        // queued.
        if (mediaSession == null) return false
        
        // Only handle key down events
        if (event.action != KeyEvent.ACTION_DOWN) return false
        
        // Only intercept media control buttons, NOT volume buttons
        val isMediaControlButton = when (event.keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_STOP,
            KeyEvent.KEYCODE_HEADSETHOOK -> true
            else -> false
        }
        
        if (!isMediaControlButton) {
            DivineCameraLog.d(TAG, "Media button not a control button (keyCode=${event.keyCode}) - passing through")
            return false  // Let system handle volume and other buttons
        }
        
        // Consume repeat events but don't trigger (long-press handling)
        if (event.repeatCount != 0) {
            DivineCameraLog.d(TAG, "Media button repeat ignored: ${event.keyCode}, repeatCount: ${event.repeatCount}")
            return true
        }
        
        // Check suppression (camera switch in progress)
        if (isSuppressed) {
            DivineCameraLog.d(TAG, "Media button ignored - suppressed (camera switch in progress)")
            return true
        }

        // Check cooldown after the session was claimed
        val now = clock()
        val timeSinceClaimed = now - sessionClaimedTimestamp
        if (timeSinceClaimed < activationCooldownMs) {
            DivineCameraLog.d(TAG, "Media button ignored - within ${activationCooldownMs}ms cooldown (${timeSinceClaimed}ms since claimed)")
            return true
        }

        // Check debounce between triggers
        val timeSinceLastTrigger = now - lastBluetoothTriggerTimestamp
        if (timeSinceLastTrigger < bluetoothDebounceMs) {
            DivineCameraLog.d(TAG, "Media button ignored - debounce (${timeSinceLastTrigger}ms since last)")
            return true
        }

        lastBluetoothTriggerTimestamp = now
        DivineCameraLog.d(TAG, "Media button triggered: ${event.keyCode}")
        onTrigger("bluetooth")
        return true
    }

    /**
     * Temporarily suppress all triggers for the given duration.
     *
     * Used during camera switch and other operations that cause
     * audio route changes, which can trigger spurious Bluetooth
     * play/pause events from connected devices.
     */
    fun suppressTemporarily(durationMs: Long = 3000) {
        isSuppressed = true
        DivineCameraLog.d(TAG, "Suppressed for ${durationMs}ms")

        // Cancel any pending unsuppress
        suppressRunnable?.let { suppressHandler.removeCallbacks(it) }
        suppressRunnable = Runnable {
            isSuppressed = false
            DivineCameraLog.d(TAG, "Suppression ended")
        }
        suppressHandler.postDelayed(suppressRunnable!!, durationMs)
    }

    /**
     * Whether volume key handling is currently enabled.
     */
    fun isEnabled(): Boolean = isEnabled

    /**
     * Claims a MediaSession to receive Bluetooth remote and headphone button events.
     */
    @Suppress("DEPRECATION")
    private fun claimMediaSession() {
        val session = MediaSessionCompat(context, "DivineCameraRemoteControl")
        try {
            session.apply {
                // Set flags to handle media buttons and transport controls
                setFlags(
                    MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
                )
            
                // Don't use a PendingIntent receiver - handle inline
                setMediaButtonReceiver(null)
            
                // Set playback state to allow receiving media button events
                setPlaybackState(
                    PlaybackStateCompat.Builder()
                        .setState(
                            PlaybackStateCompat.STATE_PLAYING,
                            PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN,
                            1.0f
                        )
                        .setActions(
                            PlaybackStateCompat.ACTION_PLAY or
                            PlaybackStateCompat.ACTION_PAUSE or
                            PlaybackStateCompat.ACTION_PLAY_PAUSE or
                            PlaybackStateCompat.ACTION_STOP
                        )
                        .build()
                )
            
                // Handle media button callbacks
                setCallback(object : MediaSessionCompat.Callback() {
                    override fun onMediaButtonEvent(mediaButtonEvent: Intent?): Boolean {
                        val keyEvent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            mediaButtonEvent?.getParcelableExtra(
                                Intent.EXTRA_KEY_EVENT,
                                KeyEvent::class.java
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            mediaButtonEvent?.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                        }
                    
                        if (keyEvent != null && handleMediaButtonEvent(keyEvent)) {
                            return true
                        }
                        return super.onMediaButtonEvent(mediaButtonEvent)
                    }

                    override fun onPlay() {
                        super.onPlay()
                        DivineCameraLog.d(TAG, "MediaSession onPlay callback")
                        triggerWithCooldownCheck()
                    }

                    override fun onPause() {
                        super.onPause()
                        DivineCameraLog.d(TAG, "MediaSession onPause callback")
                        triggerWithCooldownCheck()
                    }
                
                    override fun onStop() {
                        super.onStop()
                        DivineCameraLog.d(TAG, "MediaSession onStop callback")
                        triggerWithCooldownCheck()
                    }
                })
            
                isActive = true
            }
        } catch (e: Exception) {
            // Left unreleased, the platform session would stay registered
            // with nothing holding a reference that could release it.
            session.release()
            throw e
        }
        mediaSession = session
        sessionClaimedTimestamp = clock()
        
        DivineCameraLog.i(TAG, "MediaSession created and active for Bluetooth remote control")
    }

    private fun releaseMediaSession() {
        mediaSession?.release()
        mediaSession = null
    }
    
    /**
     * Trigger callback with cooldown, debounce and suppression check
     * for direct MediaSession callbacks.
     */
    private fun triggerWithCooldownCheck() {
        if (mediaSession == null) {
            DivineCameraLog.d(TAG, "MediaSession callback ignored - session released")
            return
        }
        if (isSuppressed) {
            DivineCameraLog.d(TAG, "MediaSession callback ignored - suppressed")
            return
        }
        val now = clock()
        if (now - sessionClaimedTimestamp < activationCooldownMs) {
            DivineCameraLog.d(TAG, "MediaSession callback ignored - within cooldown")
            return
        }
        val timeSinceLastTrigger = now - lastBluetoothTriggerTimestamp
        if (timeSinceLastTrigger < bluetoothDebounceMs) {
            DivineCameraLog.d(TAG, "MediaSession callback ignored - debounce")
            return
        }
        lastBluetoothTriggerTimestamp = now
        onTrigger("bluetooth")
    }

    /**
     * Cleanup resources.
     */
    fun release() {
        suppressRunnable?.let { suppressHandler.removeCallbacks(it) }
        suppressRunnable = null
        disable()
    }
}

/**
 * Window.Callback wrapper that intercepts key events before the system processes them.
 * This prevents the volume UI from appearing when volume buttons are pressed.
 */
private class KeyInterceptingCallback(
    private val originalCallback: Window.Callback?,
    private val onKeyEvent: (KeyEvent) -> Boolean
) : Window.Callback {
    
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Only intercept volume keys here - media keys are handled by MediaSession
        val isVolumeKey = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || 
                          event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        
        if (isVolumeKey && onKeyEvent(event)) {
            DivineCameraLog.d(TAG, "Volume key event consumed: ${event.keyCode}")
            return true  // Event consumed, don't pass to system
        }
        // Pass unhandled events to the original callback
        return originalCallback?.dispatchKeyEvent(event) ?: false
    }
    
    // Delegate all other Window.Callback methods to original
    override fun dispatchKeyShortcutEvent(event: KeyEvent): Boolean =
        originalCallback?.dispatchKeyShortcutEvent(event) ?: false
    
    override fun dispatchTouchEvent(event: android.view.MotionEvent): Boolean =
        originalCallback?.dispatchTouchEvent(event) ?: false
    
    override fun dispatchTrackballEvent(event: android.view.MotionEvent): Boolean =
        originalCallback?.dispatchTrackballEvent(event) ?: false
    
    override fun dispatchGenericMotionEvent(event: android.view.MotionEvent): Boolean =
        originalCallback?.dispatchGenericMotionEvent(event) ?: false
    
    override fun dispatchPopulateAccessibilityEvent(event: android.view.accessibility.AccessibilityEvent): Boolean =
        originalCallback?.dispatchPopulateAccessibilityEvent(event) ?: false
    
    override fun onCreatePanelView(featureId: Int): android.view.View? =
        originalCallback?.onCreatePanelView(featureId)
    
    override fun onCreatePanelMenu(featureId: Int, menu: android.view.Menu): Boolean =
        originalCallback?.onCreatePanelMenu(featureId, menu) ?: false
    
    override fun onPreparePanel(featureId: Int, view: android.view.View?, menu: android.view.Menu): Boolean =
        originalCallback?.onPreparePanel(featureId, view, menu) ?: false
    
    override fun onMenuOpened(featureId: Int, menu: android.view.Menu): Boolean =
        originalCallback?.onMenuOpened(featureId, menu) ?: false
    
    override fun onMenuItemSelected(featureId: Int, item: android.view.MenuItem): Boolean =
        originalCallback?.onMenuItemSelected(featureId, item) ?: false
    
    override fun onWindowAttributesChanged(attrs: android.view.WindowManager.LayoutParams) {
        originalCallback?.onWindowAttributesChanged(attrs)
    }
    
    override fun onContentChanged() {
        originalCallback?.onContentChanged()
    }
    
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        originalCallback?.onWindowFocusChanged(hasFocus)
    }
    
    override fun onAttachedToWindow() {
        originalCallback?.onAttachedToWindow()
    }
    
    override fun onDetachedFromWindow() {
        originalCallback?.onDetachedFromWindow()
    }
    
    override fun onPanelClosed(featureId: Int, menu: android.view.Menu) {
        originalCallback?.onPanelClosed(featureId, menu)
    }
    
    override fun onSearchRequested(): Boolean =
        originalCallback?.onSearchRequested() ?: false
    
    override fun onSearchRequested(searchEvent: android.view.SearchEvent?): Boolean =
        originalCallback?.onSearchRequested(searchEvent) ?: false
    
    override fun onWindowStartingActionMode(callback: android.view.ActionMode.Callback?): android.view.ActionMode? =
        originalCallback?.onWindowStartingActionMode(callback)
    
    override fun onWindowStartingActionMode(callback: android.view.ActionMode.Callback?, type: Int): android.view.ActionMode? =
        originalCallback?.onWindowStartingActionMode(callback, type)
    
    override fun onActionModeStarted(mode: android.view.ActionMode?) {
        originalCallback?.onActionModeStarted(mode)
    }
    
    override fun onActionModeFinished(mode: android.view.ActionMode?) {
        originalCallback?.onActionModeFinished(mode)
    }
}
