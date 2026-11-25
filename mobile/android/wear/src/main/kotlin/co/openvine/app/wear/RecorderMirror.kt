// ABOUTME: Decides which recorder state the watch shows and whether a press can reach the phone
// ABOUTME: Orders the phone's states by revision; only a current hello answer counts as live

package co.openvine.app.wear

/** A recorder state the phone published, with the revision that orders it. */
internal data class RecorderUpdate(
    /** The phone's recorder, or `null` while it has none on screen. */
    val recorder: RecorderSnapshot?,
    /** Higher for a newer state; see `RemoteProtocol.REVISION`. */
    val revision: Long,
)

/**
 * The watch's view of the phone's recorder, apart from the Data Layer that
 * carries it.
 *
 * The stored data item, its changes and the answers to hello reach the watch
 * in any order, so a state replaces the shown one only when it is newer. None
 * of them proves on its own that the phone app is running: the data item
 * outlives it. Only the answer to the hello in flight, from a phone it went
 * to, makes the phone reachable.
 */
internal class RecorderMirror {
    /** The phone's recorder, or `null` while it has none on screen. */
    var recorder: RecorderSnapshot? = null
        private set

    /** Revision of [recorder], or `null` before the phone sent a state. */
    private var revision: Long? = null

    /** Whether a press can reach the phone now. */
    var isPhoneReachable = false
        private set

    /** The phone that answered the last hello; presses go to it. */
    var phoneNodeId: String? = null
        private set

    /** The press waiting for the phone's answer. */
    var pending: ShutterRequest? = null
        private set

    private var hello: HelloRound? = null

    /** Whether a hello is out and neither answered nor given up yet. */
    val isAwaitingHello: Boolean
        get() = hello != null

    /** Shows [update] unless the state shown is as new. */
    fun show(update: RecorderUpdate) {
        val shown = revision
        if (shown != null && update.revision <= shown) return
        recorder = update.recorder
        revision = update.revision
        if (pending?.isAnsweredBy(update.recorder) == true) pending = null
    }

    /** The phone's data item is gone, as when the phone app was removed. */
    fun recorderRemoved() {
        recorder = null
        pending = null
    }

    /** Hello [id] is about to go out; until it is settled, no other is needed. */
    fun helloStarted(id: Long) {
        hello = HelloRound(id, emptySet())
    }

    /**
     * Hello [id] goes out to [nodes]; only their answers count. Returns
     * `false` when a later hello replaced it while the phones were looked
     * up, and then it is not sent and has no timeout to wait for.
     */
    fun helloSent(id: Long, nodes: Set<String>): Boolean {
        if (hello?.id != id) return false
        hello = HelloRound(id, nodes)
        return true
    }

    /**
     * Hello [id] was not answered: no phone was in reach, it could not be
     * sent, or no answer came in time. Returns whether it was the hello in
     * flight, so the phone now counts as unreachable.
     */
    fun helloUnanswered(id: Long): Boolean {
        if (hello?.id != id) return false
        unreachable()
        return true
    }

    /**
     * The phone answered a hello [helloId] from [fromNode] with [update].
     * The state is shown either way; an earlier hello's answer only does not
     * make the phone reachable.
     */
    fun answered(update: RecorderUpdate, helloId: Long?, fromNode: String) {
        show(update)
        val round = hello ?: return
        if (helloId != round.id || fromNode !in round.nodes) return
        hello = null
        phoneNodeId = fromNode
        isPhoneReachable = true
    }

    /** Presses cannot reach the phone; the one waiting is given up. */
    fun unreachable() {
        hello = null
        isPhoneReachable = false
        pending = null
    }

    /**
     * The press a tap makes on the state shown, or `null` while the shutter
     * cannot act. It still has to be sent with [sent].
     */
    fun tap(): ShutterRequest? {
        val recorder = recorder ?: return null
        val revision = revision ?: return null
        if (!recorder.isShutterEnabled || pending != null) return null
        return ShutterRequest.forTap(recorder, revision)
    }

    /** [request] went out and waits for the phone's answer. */
    fun sent(request: ShutterRequest) {
        pending = request
    }

    /** Gives up on [request]. Returns whether it was still waiting. */
    fun release(request: ShutterRequest): Boolean {
        if (pending !== request) return false
        pending = null
        return true
    }

    private class HelloRound(val id: Long, val nodes: Set<String>)
}
