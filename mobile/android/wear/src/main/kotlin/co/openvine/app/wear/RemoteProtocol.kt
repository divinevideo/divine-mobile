// ABOUTME: What the watch and the phone send each other over the Data Layer
// ABOUTME: Paths, keys and capability names, matching WearRemoteProtocol on the phone

package co.openvine.app.wear

/**
 * The wire format between the watch remote and the recorder.
 *
 * Matches `WearRemoteProtocol` in the phone app's camera plugin
 * (`mobile/packages/divine_camera`). The two apps are built separately, so a
 * change here has to be made there too.
 */
internal object RemoteProtocol {
    /** Data item the phone keeps its recorder's latest state in. */
    const val RECORDER_PATH = "/divine/remote/recorder"

    /**
     * Watch to phone: a shutter press, with the action the watch showed and
     * the [REVISION] of the state it showed it on.
     */
    const val SHUTTER_PATH = "/divine/remote/shutter"

    /** Watch to phone: the remote came on screen and wants to know who answers. */
    const val HELLO_PATH = "/divine/remote/hello"

    /** Phone to watch: the recorder's state, as the answer to [HELLO_PATH]. */
    const val STATE_PATH = "/divine/remote/state"

    /** Declared by the phone app's camera plugin. */
    const val PHONE_CAPABILITY = "divine_recorder"

    /** What a press sends while the shutter shows Start. */
    const val START_RECORDING = "watchStart"

    /** What a press sends while the shutter shows Stop. */
    const val STOP_RECORDING = "watchStop"

    const val AVAILABLE = "available"
    const val RECORDED_MS = "recordedMs"
    const val ACTIVE_TAKE_STARTED_AT_MS = "activeTakeStartedAtMs"
    const val BUDGET_MS = "budgetMs"
    const val MODE_NAME = "modeName"
    const val SHUTTER_ACTIVE = "shutterActive"
    const val SHUTTER_ENABLED = "shutterEnabled"
    const val STILL_SHUTTER_COUNT = "stillShutterCount"

    /**
     * Numbers each state the phone publishes, higher for a newer one. A press
     * names the state it was made on, and the phone drops it once the
     * recorder has left that state.
     */
    const val REVISION = "revision"

    /** A hello's number, which the phone's answer repeats. */
    const val HELLO_ID = "helloId"

    /** The shutter action in a press. */
    const val ACTION = "action"

    /** Reads a state the phone sent, with the revision that orders it. */
    fun update(payload: Map<String, Any?>): RecorderUpdate = RecorderUpdate(
        recorder = snapshot(payload),
        revision = (payload[REVISION] as? Number)?.toLong() ?: 0L,
    )

    /** The hello an answer repeats, or `null` when it names none. */
    fun helloId(payload: Map<String, Any?>): Long? = (payload[HELLO_ID] as? Number)?.toLong()

    /**
     * Reads what the phone sent; `null` for a closed recorder.
     *
     * Takes the payload as plain values so it reads a data item and a state
     * message alike.
     */
    fun snapshot(payload: Map<String, Any?>): RecorderSnapshot? {
        if (payload[AVAILABLE] != true) return null
        val defaults = RecorderSnapshot()
        val activeTakeStartedAtMs = (payload[ACTIVE_TAKE_STARTED_AT_MS] as? Number)?.toLong()
        return RecorderSnapshot(
            recordedMs = (payload[RECORDED_MS] as? Number)?.toLong() ?: defaults.recordedMs,
            activeTakeStartedAtMs = activeTakeStartedAtMs,
            budgetMs = (payload[BUDGET_MS] as? Number)?.toLong()?.takeIf { it >= 0 }
                ?: defaults.budgetMs,
            modeName = payload[MODE_NAME] as? String ?: defaults.modeName,
            isShutterActive = payload[SHUTTER_ACTIVE] as? Boolean
                ?: (activeTakeStartedAtMs != null),
            isShutterEnabled = payload[SHUTTER_ENABLED] as? Boolean ?: true,
            stillShutterCount = (payload[STILL_SHUTTER_COUNT] as? Number)?.toInt()
                ?: defaults.stillShutterCount,
        )
    }
}
