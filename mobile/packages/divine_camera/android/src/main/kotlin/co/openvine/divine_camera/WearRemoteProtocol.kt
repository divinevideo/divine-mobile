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

    /** Watch to phone: a shutter press, with the action the watch showed. */
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

    /** The shutter actions a watch can send, as `RemoteRecordTrigger` names them. */
    private val shutterActions = setOf("watchStart", "watchStop")

    /**
     * The recorder [state] Dart sent as a data map, or a closed recorder when
     * it is `null`.
     *
     * A take that is not running leaves out its start time: a data map cannot
     * hold `null`.
     */
    fun recorderDataMap(state: Map<*, *>?): DataMap {
        val map = DataMap()
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

    /** The shutter action a [SHUTTER_PATH] message carries, or `null` for anything else. */
    fun shutterAction(payload: ByteArray): String? =
        payload.toString(Charsets.UTF_8).takeIf { it in shutterActions }
}
