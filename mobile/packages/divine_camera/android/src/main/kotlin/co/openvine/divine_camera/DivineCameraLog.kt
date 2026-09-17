// ABOUTME: Forwards curated native camera diagnostics to Dart's UnifiedLogger
// ABOUTME: so recording issues (e.g. missing audio) appear in user bug reports

package co.openvine.divine_camera

import android.util.Log

/**
 * Bridges relevant native diagnostics to the Dart side so they are captured by
 * the app's `UnifiedLogger` and included in bug-report log dumps.
 *
 * Native recording code calls these methods (instead of bare [Log]) for the
 * handful of events worth surfacing to support: audio-permission denial,
 * recording finalize errors, encoder-fallback retries, and audio-source state
 * transitions. Per-frame / verbose logging must stay on [Log] so it does not
 * flood the captured buffer.
 *
 * `DivineCameraPlugin` installs [sink] when attached to the engine to forward
 * each entry over the method channel. Before that is wired (or in unit-test
 * contexts) entries fall back to logcat only.
 */
object DivineCameraLog {
    /**
     * Forwards `(level, message, name, timestampMs)` to Dart. `level` is one
     * of `debug`, `info`, `warning`, `error`. `timestampMs` is epoch
     * milliseconds stamped at the call site. Set by the plugin; `null` until
     * then.
     */
    @Volatile
    var sink: ((String, String, String, Double) -> Unit)? = null

    fun debug(message: String, name: String = "DivineCamera") = emit("debug", message, name)

    fun info(message: String, name: String = "DivineCamera") = emit("info", message, name)

    fun warning(message: String, name: String = "DivineCamera") = emit("warning", message, name)

    fun error(message: String, name: String = "DivineCamera") = emit("error", message, name)

    // android.util.Log-shaped overloads so existing `Log.x(TAG, ...)` call
    // sites forward to the bridge with a mechanical rename. The tag becomes
    // the entry name. Logcat keeps the full throwable stack trace; Dart gets a
    // concise throwable summary because MethodChannel payloads stay structured.
    fun d(tag: String, message: String, tr: Throwable? = null) =
        emit("debug", message, tag, tr)

    fun i(tag: String, message: String, tr: Throwable? = null) =
        emit("info", message, tag, tr)

    fun w(tag: String, message: String, tr: Throwable? = null) =
        emit("warning", message, tag, tr)

    fun e(tag: String, message: String, tr: Throwable? = null) =
        emit("error", message, tag, tr)

    private fun emit(level: String, message: String, name: String, tr: Throwable? = null) {
        // Stamp here, on whichever thread raised the event. The sink hops to
        // the main looper before it reaches Dart, and Dart stamps on arrival,
        // so without this a line held up by a busy main thread reads exactly
        // like native work that ran late. See #9291.
        val timestampMs = System.currentTimeMillis().toDouble()
        // Keep the logcat fallback so on-device debugging is unchanged.
        when (level) {
            "error" -> if (tr != null) Log.e(name, message, tr) else Log.e(name, message)
            "warning" -> if (tr != null) Log.w(name, message, tr) else Log.w(name, message)
            "info" -> if (tr != null) Log.i(name, message, tr) else Log.i(name, message)
            else -> if (tr != null) Log.d(name, message, tr) else Log.d(name, message)
        }
        sink?.invoke(level, tr?.let { "$message: $it" } ?: message, name, timestampMs)
    }
}
