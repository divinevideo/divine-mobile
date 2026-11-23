// ABOUTME: Connects the recorder to the Wear OS remote over the Wearable Data Layer
// ABOUTME: Publishes the recorder's state to the watch and receives its shutter presses

package co.openvine.divine_camera

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailabilityLight
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

private const val LOG_NAME = "DivineCamera.WearRemote"

/**
 * Keeps the Wear OS remote in step with the recorder.
 *
 * The latest state is a data item, which the watch reads whenever its app
 * opens and which wakes the watch app's listener service so it can offer the
 * remote while the camera is open. A watch app that comes on screen also says
 * hello, and the answer tells it the phone app is there to act on a press.
 *
 * The Data Layer is part of Google Play services, so [create] returns `null`
 * on a device without them and the recorder works as before.
 */
internal class WearRemoteLink private constructor(
    context: Context,
    private val onShutterAction: (String) -> Unit,
    private val onWatchRemoteChanged: (Boolean) -> Unit,
) {
    private val dataClient = Wearable.getDataClient(context)
    private val messageClient = Wearable.getMessageClient(context)
    private val capabilityClient = Wearable.getCapabilityClient(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Whether a reachable watch has the remote. Only touched on the main
     * thread.
     */
    var hasWatchRemote = false
        private set

    /** What the watch should show. Only touched on the main thread. */
    private var state: DataMap = WearRemoteProtocol.recorderDataMap(null)

    private var isStarted = false

    // Registration fails while the phone has no Wear OS companion app; the
    // next return to the app tries again. Only touched on the main thread.
    private var isListeningToMessages = false
    private var isListeningToCapability = false

    // Phones without the Wear OS app fail every call; say so once.
    private var hasLoggedUnavailable = false

    private val messageListener = MessageClient.OnMessageReceivedListener { event ->
        mainHandler.post { handle(event) }
    }

    private val capabilityListener = CapabilityClient.OnCapabilityChangedListener {
        // Re-read with the reachable filter: the event's own node set may
        // still list a watch that just disconnected.
        mainHandler.post { refreshWatchRemote() }
    }

    /**
     * Starts listening for the watch, and tells a watch still showing a
     * recorder from an earlier run that it is gone.
     */
    fun start() {
        if (isStarted) return
        isStarted = true
        listen()
        refreshWatchRemote()
        publish()
    }

    /**
     * The app is in the foreground again. Picks up a watch paired, or a Wear
     * OS companion app installed, while the user was away: listening failed
     * without one.
     */
    fun onResume() {
        if (!isStarted) return
        listen()
        refreshWatchRemote()
    }

    /** Stops listening and tells the watch the recorder is gone. */
    fun stop() {
        if (!isStarted) return
        isStarted = false
        messageClient.removeListener(messageListener)
        capabilityClient.removeListener(capabilityListener, WearRemoteProtocol.WATCH_CAPABILITY)
        isListeningToMessages = false
        isListeningToCapability = false
        update(null)
        setWatchRemote(false)
    }

    private fun listen() {
        if (!isListeningToMessages) {
            isListeningToMessages = true
            messageClient.addListener(messageListener).addOnFailureListener {
                isListeningToMessages = false
                logUnavailable(it)
            }
        }
        if (!isListeningToCapability) {
            isListeningToCapability = true
            capabilityClient
                .addListener(capabilityListener, WearRemoteProtocol.WATCH_CAPABILITY)
                .addOnFailureListener {
                    isListeningToCapability = false
                    logUnavailable(it)
                }
        }
    }

    /**
     * Publishes the recorder's state, or that the recorder closed when
     * [recorder] is `null`. Call on the main thread.
     */
    fun update(recorder: Map<*, *>?) {
        state = WearRemoteProtocol.recorderDataMap(recorder)
        publish()
    }

    private fun publish() {
        val request = PutDataMapRequest.create(WearRemoteProtocol.RECORDER_PATH)
            .apply { dataMap.putAll(state) }
            .asPutDataRequest()
            // The watch is on screen waiting for it; don't batch it.
            .setUrgent()
        dataClient.putDataItem(request).addOnFailureListener { logUnavailable(it) }
    }

    private fun handle(event: MessageEvent) {
        when (event.path) {
            WearRemoteProtocol.SHUTTER_PATH -> {
                val action = WearRemoteProtocol.shutterAction(event.data) ?: return
                DivineCameraLog.debug("Watch shutter: $action", name = LOG_NAME)
                onShutterAction(action)
            }
            WearRemoteProtocol.HELLO_PATH -> {
                messageClient.sendMessage(
                    event.sourceNodeId,
                    WearRemoteProtocol.STATE_PATH,
                    state.toByteArray()
                ).addOnFailureListener {
                    DivineCameraLog.debug(
                        "Watch hello not answered: ${it.message}",
                        name = LOG_NAME
                    )
                }
            }
        }
    }

    private fun refreshWatchRemote() {
        capabilityClient
            .getCapability(WearRemoteProtocol.WATCH_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { info ->
                if (isStarted) setWatchRemote(info.nodes.isNotEmpty())
            }
            .addOnFailureListener { logUnavailable(it) }
    }

    private fun setWatchRemote(available: Boolean) {
        if (hasWatchRemote == available) return
        hasWatchRemote = available
        DivineCameraLog.info(
            if (available) "Wear OS remote reachable" else "Wear OS remote gone",
            name = LOG_NAME
        )
        onWatchRemoteChanged(available)
    }

    private fun logUnavailable(error: Exception) {
        if (hasLoggedUnavailable) return
        hasLoggedUnavailable = true
        DivineCameraLog.debug("Wear OS Data Layer unavailable: ${error.message}", name = LOG_NAME)
    }

    companion object {
        /**
         * A link to the Wear OS remote, or `null` without Google Play
         * services, where no watch can be paired.
         *
         * @param onShutterAction Called on the main thread with `watchStart`
         *   or `watchStop` when the watch's shutter is pressed.
         * @param onWatchRemoteChanged Called on the main thread when a
         *   reachable watch gains or loses the remote.
         */
        fun create(
            context: Context,
            onShutterAction: (String) -> Unit,
            onWatchRemoteChanged: (Boolean) -> Unit,
        ): WearRemoteLink? {
            // The check throws when the app's manifest lacks the Play services
            // version entry, or for a context without a package manager. The
            // camera must attach regardless, so that counts as unavailable.
            val availability = try {
                GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(context)
            } catch (e: Exception) {
                DivineCameraLog.debug(
                    "No Wear OS remote: Play services check failed: ${e.message}",
                    name = LOG_NAME
                )
                return null
            }
            if (availability != ConnectionResult.SUCCESS) {
                DivineCameraLog.debug(
                    "No Wear OS remote: Google Play services unavailable ($availability)",
                    name = LOG_NAME
                )
                return null
            }
            return WearRemoteLink(context, onShutterAction, onWatchRemoteChanged)
        }
    }
}
