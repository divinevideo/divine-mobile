// ABOUTME: Lets exactly one stop finish a recording, Dart's or the time limit's
// ABOUTME: Owns the max-duration timer so a manual stop can cancel it (#10194)

package co.openvine.divine_camera

import android.os.Handler

/** Receives the finalized recording, or the reason there is none. */
internal typealias RecordingStopCallback = (Map<String, Any?>?, String?) -> Unit

/**
 * Lets exactly one stop finish a recording.
 *
 * A recording ends on a stop from Dart or on the max-duration timer, and
 * CameraX hands over the file ~100 ms after `Recording.stop()`, in
 * `VideoRecordEvent.Finalize`. When both stops waited for that one event, a
 * Stop tap just before the limit got the file and the timer got it again, and
 * Dart added the take twice (#10194). So the first stop owns the recording:
 * beginning it cancels the timer, and a stop that begins after it is refused,
 * as the iOS controller refuses a stop once `isRecording` is false.
 *
 * Not thread-safe: every call must come from [handler]'s thread, which is
 * where CameraX delivers the recording events and Flutter its method calls.
 */
internal class RecordingStopArbiter(private val handler: Handler) {
    private var maxDurationTimer: Runnable? = null
    private var pendingStop: RecordingStopCallback? = null

    /**
     * Whether a stop has begun and its recording has not finalized yet. A
     * finalize without one ended on its own; read it before [finish].
     */
    val isStopPending: Boolean
        get() = pendingStop != null

    /** Runs [onReached] after [delayMs], unless a stop begins first. */
    fun scheduleMaxDuration(delayMs: Long, onReached: () -> Unit) {
        cancelMaxDuration()
        val timer = Runnable {
            maxDurationTimer = null
            onReached()
        }
        maxDurationTimer = timer
        handler.postDelayed(timer, delayMs)
    }

    fun cancelMaxDuration() {
        maxDurationTimer?.let(handler::removeCallbacks)
        maxDurationTimer = null
    }

    /**
     * Claims the end of the recording for [callback] and cancels the
     * max-duration timer. Returns false, without calling [callback], when
     * another stop already owns the recording.
     */
    fun beginStop(callback: RecordingStopCallback): Boolean {
        if (pendingStop != null) return false
        cancelMaxDuration()
        pendingStop = callback
        return true
    }

    /**
     * Releases a stop whose `Recording.stop()` threw. The timer stays
     * cancelled: all it does is call `Recording.stop()` again.
     */
    fun abandonStop() {
        pendingStop = null
    }

    /** Hands the finalized recording to the stop that owns it, if any. */
    fun finish(result: Map<String, Any?>?, error: String?) {
        cancelMaxDuration()
        val callback = pendingStop ?: return
        pendingStop = null
        callback(result, error)
    }
}
