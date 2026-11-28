// ABOUTME: What the phone and the Wear OS remote send each other over the Data Layer
// ABOUTME: Paths, keys and the recorder state payload, shared in meaning with the watch app

package co.openvine.divine_camera

import com.google.android.gms.wearable.DataMap

/**
 * The wire format between the recorder and the Wear OS remote.
 *
 * Paths, keys and capability names match `RemoteProtocol` in the watch app
 * (`mobile/android/wear`), and the keys match the map Dart sends with
 * `updateRemoteRecorderState`. The watch app is built separately, so a change
 * here has to be made there too.
 */
internal object WearRemoteProtocol {
    /** Data item holding the recorder's latest state. */
    const val RECORDER_PATH = "/divine/remote/recorder"

    /**
     * Watch to phone: a shutter press, with the action the watch showed and
     * the [REVISION] of the state it showed it on.
     */
    const val SHUTTER_PATH = "/divine/remote/shutter"

    /** Watch to phone: the watch app came on screen and wants to know who answers. */
    const val HELLO_PATH = "/divine/remote/hello"

    /** Phone to watch: the recorder's state, as the answer to [HELLO_PATH]. */
    const val STATE_PATH = "/divine/remote/state"

    /** Declared by the watch app; a reachable node with it shows the remote. */
    const val WATCH_CAPABILITY = "divine_remote_shutter"

    /**
     * Declared by this plugin in `res/values/wear.xml`, so the watch finds the
     * phone that runs the recorder.
     */
    const val PHONE_CAPABILITY = "divine_recorder"

    const val AVAILABLE = "available"
    const val RECORDED_MS = "recordedMs"
    const val ACTIVE_TAKE_STARTED_AT_MS = "activeTakeStartedAtMs"
    const val BUDGET_MS = "budgetMs"
    const val MODE_NAME = "modeName"
    const val SHUTTER_ACTIVE = "shutterActive"
    const val SHUTTER_ENABLED = "shutterEnabled"
    const val STILL_SHUTTER_COUNT = "stillShutterCount"

    /**
     * Numbers each state the phone publishes, higher for a newer one, also
     * across restarts of the app. The watch shows only a state newer than the
     * one it has, and a press names the state it was made on.
     */
    const val REVISION = "revision"

    /**
     * Dart's number for the state it sent. The watch never sees it: a press
     * the phone forwards repeats the number of the state it matched, and Dart
     * drops one made on a state it has since replaced.
     */
    const val STATE_ID = "stateId"

    /** A hello's number, which the answer repeats so the watch can match it. */
    const val HELLO_ID = "helloId"

    /** The shutter action in a press. */
    const val ACTION = "action"

    /** The shutter actions a watch can send, as `RemoteRecordTrigger` names them. */
    private val shutterActions = setOf("watchStart", "watchStop")

    /** A press from the watch: [action] on the state with [revision]. */
    data class ShutterPress(val action: String, val revision: Long)

    /**
     * The recorder [state] Dart sent as a data map with its [revision], or a
     * closed recorder when it is `null`.
     *
     * A take that is not running leaves out its start time: a data map cannot
     * hold `null`.
     */
    fun recorderDataMap(state: Map<*, *>?, revision: Long): DataMap {
        val map = DataMap()
        map.putLong(REVISION, revision)
        if (state == null) {
            map.putBoolean(AVAILABLE, false)
            return map
        }
        map.putBoolean(AVAILABLE, true)
        (state[RECORDED_MS] as? Number)?.let { map.putLong(RECORDED_MS, it.toLong()) }
        (state[ACTIVE_TAKE_STARTED_AT_MS] as? Number)?.let {
            map.putLong(ACTIVE_TAKE_STARTED_AT_MS, it.toLong())
        }
        (state[BUDGET_MS] as? Number)?.let { map.putLong(BUDGET_MS, it.toLong()) }
        (state[MODE_NAME] as? String)?.let { map.putString(MODE_NAME, it) }
        (state[SHUTTER_ACTIVE] as? Boolean)?.let { map.putBoolean(SHUTTER_ACTIVE, it) }
        (state[SHUTTER_ENABLED] as? Boolean)?.let { map.putBoolean(SHUTTER_ENABLED, it) }
        (state[STILL_SHUTTER_COUNT] as? Number)?.let {
            map.putInt(STILL_SHUTTER_COUNT, it.toInt())
        }
        return map
    }

    /** Dart's number for [state], or `null` for a closed recorder. */
    fun stateId(state: Map<*, *>?): Long? = (state?.get(STATE_ID) as? Number)?.toLong()

    /**
     * The revision after [previous]. Starting from the clock keeps it above
     * what an earlier run of the app published.
     */
    fun nextRevision(previous: Long, nowMs: Long): Long = maxOf(previous + 1, nowMs)

    /** The press a [SHUTTER_PATH] message carries, or `null` for anything else. */
    fun shutterPress(payload: ByteArray): ShutterPress? {
        val map = dataMapOf(payload) ?: return null
        val action = map.getString(ACTION)?.takeIf { it in shutterActions } ?: return null
        if (!map.containsKey(REVISION)) return null
        return ShutterPress(action, map.getLong(REVISION))
    }

    /** The answer to a [HELLO_PATH] message: [state], and the hello's number. */
    fun helloAnswer(state: DataMap, hello: ByteArray): DataMap {
        val answer = DataMap()
        answer.putAll(state)
        val helloMap = dataMapOf(hello)
        if (helloMap != null && helloMap.containsKey(HELLO_ID)) {
            answer.putLong(HELLO_ID, helloMap.getLong(HELLO_ID))
        }
        return answer
    }

    private fun dataMapOf(payload: ByteArray): DataMap? =
        // Anything a watch sends is untrusted; malformed bytes throw.
        try {
            DataMap.fromByteArray(payload)
        } catch (e: RuntimeException) {
            null
        }
}
