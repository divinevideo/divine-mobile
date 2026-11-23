// ABOUTME: The watch's connection to the recorder on the phone
// ABOUTME: Receives the recorder's state and sends shutter presses back

package co.openvine.app.wear

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable

/** How long a press waits for the phone's answer before the shutter is released. */
private const val PRESS_TIMEOUT_MS = 4_000L

/** How long the phone has to answer the hello before it counts as unreachable. */
private const val HELLO_TIMEOUT_MS = 3_000L

/**
 * The recorder on the paired phone, as the watch sees it.
 *
 * [recorder] is `null` while the phone has no recorder on screen. The phone
 * keeps its latest state in a data item, so that state is shown as soon as
 * the remote opens. Whether a press can reach it is a separate question: the
 * data item outlives the phone app, so the remote says hello and counts the
 * phone as reachable once the app answers.
 *
 * Only touched on the main thread.
 */
internal class PhoneRecorderLink(context: Context) {
    private val appContext = context.applicationContext
    private val dataClient = Wearable.getDataClient(appContext)
    private val messageClient = Wearable.getMessageClient(appContext)
    private val capabilityClient = Wearable.getCapabilityClient(appContext)
    private val mainHandler = Handler(Looper.getMainLooper())

    /** The phone's recorder, or `null` while it has none on screen. */
    var recorder by mutableStateOf<RecorderSnapshot?>(null)
        private set

    /**
     * Whether a press can reach the phone now. While it cannot, [recorder] is
     * the last state received and may be out of date.
     */
    var isPhoneReachable by mutableStateOf(false)
        private set

    /** Whether a press is waiting for the phone's answer. */
    var isShutterPending by mutableStateOf(false)
        private set

    /** Called each time a press could not be delivered. */
    var onDeliveryFailure: () -> Unit = {}

    private var isStarted = false
    private var phoneNodeId: String? = null
    private var pending: ShutterRequest? = null
    private var pendingTimeout: Runnable? = null
    private var helloTimeout: Runnable? = null

    private val dataListener = DataClient.OnDataChangedListener { events ->
        // The buffer is only valid inside this callback.
        val latest = events
            .filter { it.dataItem.uri.path == RemoteProtocol.RECORDER_PATH }
            .map { event ->
                val values = if (event.type == DataEvent.TYPE_DELETED) {
                    emptyMap()
                } else {
                    DataMapItem.fromDataItem(event.dataItem).dataMap.toValues()
                }
                event.dataItem.uri.host to values
            }
            .lastOrNull() ?: return@OnDataChangedListener
        // The phone app only writes while it runs, so a change proves it is there.
        mainHandler.post { receive(latest.second, fromNode = latest.first, isLive = true) }
    }

    private val messageListener = MessageClient.OnMessageReceivedListener { event ->
        if (event.path != RemoteProtocol.STATE_PATH) return@OnMessageReceivedListener
        val values = DataMap.fromByteArray(event.data).toValues()
        mainHandler.post { receive(values, fromNode = event.sourceNodeId, isLive = true) }
    }

    private val capabilityListener = CapabilityClient.OnCapabilityChangedListener {
        mainHandler.post { sayHello() }
    }

    /** Starts listening, shows the last state the phone left, and says hello. */
    fun start() {
        if (isStarted) return
        isStarted = true
        dataClient.addListener(dataListener)
        messageClient.addListener(messageListener)
        capabilityClient.addListener(capabilityListener, RemoteProtocol.PHONE_CAPABILITY)
        readStoredState()
        sayHello()
    }

    /** Stops listening; the remote is off screen. */
    fun stop() {
        if (!isStarted) return
        isStarted = false
        dataClient.removeListener(dataListener)
        messageClient.removeListener(messageListener)
        capabilityClient.removeListener(capabilityListener, RemoteProtocol.PHONE_CAPABILITY)
        cancelHelloTimeout()
        setReachable(false)
    }

    /**
     * Asks the phone to start or stop a take. What the recorder then does
     * comes back as a new [recorder].
     */
    fun toggleRecording() {
        val recorder = recorder ?: return
        if (!recorder.isShutterEnabled || pending != null) return
        val node = phoneNodeId
        if (!isPhoneReachable || node == null) {
            onDeliveryFailure()
            sayHello()
            return
        }
        val request = ShutterRequest.forTap(recorder)
        pending = request
        isShutterPending = true
        messageClient
            .sendMessage(node, RemoteProtocol.SHUTTER_PATH, request.command.toByteArray())
            .addOnFailureListener {
                mainHandler.post {
                    if (pending !== request) return@post
                    clearPending()
                    onDeliveryFailure()
                    sayHello()
                }
            }
        // A press the phone ignores changes nothing it publishes. The timeout
        // releases the shutter then, and checks the phone app is still there.
        val timeout = Runnable {
            if (pending !== request) return@Runnable
            clearPending()
            sayHello()
        }
        pendingTimeout = timeout
        mainHandler.postDelayed(timeout, PRESS_TIMEOUT_MS)
    }

    private fun readStoredState() {
        val uri = Uri.Builder()
            .scheme(PutDataRequest.WEAR_URI_SCHEME)
            .path(RemoteProtocol.RECORDER_PATH)
            .build()
        dataClient.getDataItems(uri).addOnSuccessListener { items ->
            val stored = items.firstOrNull()?.let { item ->
                item.uri.host to DataMapItem.fromDataItem(item).dataMap.toValues()
            }
            items.release()
            // A live update may already have arrived; it is newer.
            if (stored != null && isStarted && recorder == null) {
                receive(stored.second, fromNode = stored.first, isLive = false)
            }
        }
    }

    /** Asks the phone app to answer, which tells whether a press would reach it. */
    private fun sayHello() {
        if (!isStarted) return
        capabilityClient
            .getCapability(RemoteProtocol.PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { info ->
                if (!isStarted) return@addOnSuccessListener
                if (info.nodes.isEmpty()) {
                    // Out of reach; the phone may still be recording.
                    cancelHelloTimeout()
                    setReachable(false)
                    return@addOnSuccessListener
                }
                info.nodes.forEach { node ->
                    messageClient.sendMessage(node.id, RemoteProtocol.HELLO_PATH, ByteArray(0))
                }
                scheduleHelloTimeout()
            }
            .addOnFailureListener { setReachable(false) }
    }

    private fun scheduleHelloTimeout() {
        cancelHelloTimeout()
        val timeout = Runnable {
            helloTimeout = null
            setReachable(false)
            // The phone is in reach but its app did not answer, so it is not
            // running and no recorder is open.
            RemoteOngoingActivity.hide(appContext)
        }
        helloTimeout = timeout
        mainHandler.postDelayed(timeout, HELLO_TIMEOUT_MS)
    }

    private fun cancelHelloTimeout() {
        helloTimeout?.let(mainHandler::removeCallbacks)
        helloTimeout = null
    }

    private fun receive(values: Map<String, Any?>, fromNode: String?, isLive: Boolean) {
        if (!isStarted) return
        val snapshot = RemoteProtocol.snapshot(values)
        recorder = snapshot
        if (fromNode != null) phoneNodeId = fromNode
        if (isLive) {
            cancelHelloTimeout()
            setReachable(true)
        }
        if (pending?.isAnsweredBy(snapshot) == true) clearPending()
    }

    private fun setReachable(reachable: Boolean) {
        isPhoneReachable = reachable
        if (!reachable) clearPending()
    }

    private fun clearPending() {
        pendingTimeout?.let(mainHandler::removeCallbacks)
        pendingTimeout = null
        pending = null
        isShutterPending = false
    }
}

private fun DataMap.toValues(): Map<String, Any?> = keySet().associateWith { get<Any>(it) }
