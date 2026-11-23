// ABOUTME: A shutter press sent to the phone and not yet answered
// ABOUTME: Knows which recorder state counts as the phone's answer

package co.openvine.app.wear

/**
 * A press the phone has not answered yet.
 *
 * The phone has no reply for a press; its answer is the recorder state it
 * publishes next. A video press flips the shutter. A still leaves the shutter
 * as it was and counts up the finished stills instead.
 */
internal data class ShutterRequest(
    /** Whether the press stops what is running rather than starting it. */
    val stops: Boolean,
    /** Finished stills when the press was sent. */
    val stillShutterCount: Int,
) {
    /** What the press tells the phone. */
    val command: String
        get() = if (stops) RemoteProtocol.STOP_RECORDING else RemoteProtocol.START_RECORDING

    /** Whether [recorder], the phone's latest state, answers this press. */
    fun isAnsweredBy(recorder: RecorderSnapshot?): Boolean =
        recorder == null ||
            recorder.isShutterActive != stops ||
            recorder.stillShutterCount != stillShutterCount

    companion object {
        /** The press a tap sends for what [recorder] shows. */
        fun forTap(recorder: RecorderSnapshot) = ShutterRequest(
            stops = recorder.isShutterActive,
            stillShutterCount = recorder.stillShutterCount,
        )
    }
}
