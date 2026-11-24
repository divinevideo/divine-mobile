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
import kotlin.random.Random

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
 * phone as reachable once the app answers. [RecorderMirror] decides both.
 *
 * Only touched on the main thread.
 */
internal class PhoneRecorderLink(context: Context) {
    private val appContext = context.applicationContext
    private val dataClient = Wearable.getDataClient(appContext)
    private val messageClient = Wearable.getMessageClient(appContext)
    private val capabilityClient = Wearable.getCapabilityClient(appContext)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mirror = RecorderMirror()

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

    // Random, so an answer to a hello from an earlier run of the remote does
    // not match one from this run.
    private var lastHelloId = Random.nextLong()
    private var pendingTimeout: Runnable? = null
    private var helloTimeout: Runnable? = null

    private val dataListener = DataClient.OnDataChangedListener { events ->
        // The buffer is only valid inside this callback.
        val event = events.lastOrNull { it.dataItem.uri.path == RemoteProtocol.RECORDER_PATH }
            ?: return@OnDataChangedListener
        val latest = if (event.type == DataEvent.TYPE_DELETED) {
            null
        } else {
            DataMapItem.fromDataItem(event.dataItem).dataMap.toValues()
        }
        mainHandler.post {
            if (!isStarted) return@post
            if (latest == null) mirror.recorderRemoved() else mirror.show(RemoteProtocol.update(latest))
            // A data item can arrive long after the phone app wrote it, so it
            // does not say the app is there; its answer to a hello does.
            if (!mirror.isPhoneReachable && !mirror.isAwaitingHello) sayHello()
            sync()
        }
    }

    private val messageListener = MessageClient.OnMessageReceivedListener { event ->
        if (event.path != RemoteProtocol.STATE_PATH) return@OnMessageReceivedListener
        val values = DataMap.fromByteArray(event.data).toValues()
        mainHandler.post {
            if (!isStarted) return@post
            mirror.answered(
                RemoteProtocol.update(values),
                helloId = RemoteProtocol.helloId(values),
                fromNode = event.sourceNodeId,
            )
            if (!mirror.isAwaitingHello) cancelHelloTimeout()
            sync()
        }
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
        mirror.unreachable()
        sync()
    }

    /**
     * Asks the phone to start or stop a take. What the recorder then does
     * comes back as a new [recorder].
     */
    fun toggleRecording() {
        val request = mirror.tap() ?: return
        val node = mirror.phoneNodeId
        if (!mirror.isPhoneReachable || node == null) {
            onDeliveryFailure()
            sayHello()
            return
        }
        mirror.sent(request)
        sync()
        val payload = DataMap().apply {
            putString(RemoteProtocol.ACTION, request.command)
            putLong(RemoteProtocol.REVISION, request.revision)
        }.toByteArray()
        messageClient
            .sendMessage(node, RemoteProtocol.SHUTTER_PATH, payload)
            .addOnFailureListener {
                mainHandler.post {
                    if (!mirror.release(request)) return@post
                    sync()
                    onDeliveryFailure()
                    sayHello()
                }
            }
        // A press the phone ignores changes nothing it publishes, and so does
        // one it drops because the recorder left the state it was made on.
        // The timeout releases the shutter then, and checks the phone app is
        // still there.
        val timeout = Runnable {
            if (!mirror.release(request)) return@Runnable
            sync()
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
            val stored = items.firstOrNull()?.let { DataMapItem.fromDataItem(it).dataMap.toValues() }
            items.release()
            if (stored == null || !isStarted) return@addOnSuccessListener
            // Shown only if nothing newer came in while it was read.
            mirror.show(RemoteProtocol.update(stored))
            sync()
        }
    }

    /** Asks the phone app to answer, which tells whether a press would reach it. */
    private fun sayHello() {
        if (!isStarted) return
        val id = ++lastHelloId
        mirror.helloStarted(id)
        capabilityClient
            .getCapability(RemoteProtocol.PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { info ->
                if (!isStarted) return@addOnSuccessListener
                if (info.nodes.isEmpty()) {
                    // Out of reach; the phone may still be recording.
                    if (mirror.helloUnanswered(id)) cancelHelloTimeout()
                    sync()
                    return@addOnSuccessListener
                }
                mirror.helloSent(id, info.nodes.map { it.id }.toSet())
                val payload = DataMap().apply { putLong(RemoteProtocol.HELLO_ID, id) }.toByteArray()
                info.nodes.forEach { node ->
                    messageClient.sendMessage(node.id, RemoteProtocol.HELLO_PATH, payload)
                }
                scheduleHelloTimeout(id)
            }
            .addOnFailureListener {
                mirror.helloUnanswered(id)
                sync()
            }
    }

    private fun scheduleHelloTimeout(id: Long) {
        cancelHelloTimeout()
        val timeout = Runnable {
            helloTimeout = null
            if (!mirror.helloUnanswered(id)) return@Runnable
            sync()
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

    /** Hands what [mirror] decided to the screen. */
    private fun sync() {
        recorder = mirror.recorder
        isPhoneReachable = mirror.isPhoneReachable
        isShutterPending = mirror.pending != null
        if (mirror.pending == null) {
            pendingTimeout?.let(mainHandler::removeCallbacks)
            pendingTimeout = null
        }
    }
}

private fun DataMap.toValues(): Map<String, Any?> = keySet().associateWith { get<Any>(it) }
