// ABOUTME: What the watch knows about the phone recorder it controls
// ABOUTME: Also turns recorded time into the segments of the budget strip

package co.openvine.app.wear

import java.util.Locale
import kotlin.math.max

/** What the watch knows about the recorder it controls. */
data class RecorderSnapshot(
    /**
     * Combined length of the clips already recorded. In Stop Motion, the clip
     * time the stills taken so far are held for.
     */
    val recordedMs: Long = 0,
    /** When the take in progress started, or `null` while none is running. */
    val activeTakeStartedAtMs: Long? = null,
    /**
     * Clip length the strip fills against. In Stop Motion, the clip time of
     * the most stills the session fits.
     */
    val budgetMs: Long = DEFAULT_BUDGET_MS,
    /**
     * The recorder mode in use, as the phone's mode wheel names it
     * (`VideoRecorderMode.label`, English in every locale).
     */
    val modeName: String = "Capture",
    /**
     * Whether a press stops what is running: a take, its countdown, or
     * stop-motion capturing on its interval. The last two add no recorded time.
     */
    val isShutterActive: Boolean = false,
    /** Whether the phone can act on a shutter press. */
    val isShutterEnabled: Boolean = true,
    /**
     * How many single-frame capture attempts have finished in Stop Motion. A
     * still leaves [isShutterActive] unchanged, so this confirms completion.
     */
    val stillShutterCount: Int = 0,
) {
    /** Whether recorded time is counting. */
    val isRecording: Boolean get() = activeTakeStartedAtMs != null

    /** Recorded time at [nowMs], counting the take in progress. */
    fun elapsedMs(nowMs: Long): Long {
        val startedAt = activeTakeStartedAtMs ?: return recordedMs
        return recordedMs + max(0, nowMs - startedAt)
    }

    /**
     * Recorded time at [nowMs] as `mm:ss`, the format of the phone recorder's
     * progress label.
     */
    fun durationLabel(nowMs: Long): String {
        val seconds = elapsedMs(nowMs) / 1000
        return String.format(Locale.ROOT, "%02d:%02d", seconds / 60, seconds % 60)
    }

    companion object {
        /** Mirrors `VideoEditorConstants.maxDuration` in the Flutter app. */
        const val DEFAULT_BUDGET_MS = 6300L
    }
}

/**
 * How much of the budget strip each segment takes, as fractions of its width.
 *
 * The same split as the phone recorder's progress bar: green grows until the
 * budget is used up, and time recorded past it squeezes the green back from
 * the right.
 */
data class RecordingBudgetFill(
    /** Recorded time within the budget. */
    val filled: Float,
    /** Recorded time past the budget. */
    val overflow: Float,
) {
    companion object {
        fun of(elapsedMs: Long, budgetMs: Long): RecordingBudgetFill {
            if (elapsedMs <= 0) return RecordingBudgetFill(filled = 0f, overflow = 0f)
            // With no shots left, every new still is past the budget.
            if (budgetMs <= 0) return RecordingBudgetFill(filled = 0f, overflow = 1f)
            if (elapsedMs <= budgetMs) {
                return RecordingBudgetFill(
                    filled = elapsedMs.toFloat() / budgetMs,
                    overflow = 0f,
                )
            }
            val filled = budgetMs.toFloat() / elapsedMs
            return RecordingBudgetFill(filled = filled, overflow = 1 - filled)
        }
    }
}
