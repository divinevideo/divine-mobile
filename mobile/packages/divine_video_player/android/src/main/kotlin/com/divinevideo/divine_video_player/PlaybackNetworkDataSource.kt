package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import java.util.UUID

/** Measures only the actual upstream boundary, never the cache's declared length. */
internal class PlaybackNetworkDataSource(
    private val delegate: DataSource,
    private val onSample: (Map<String, Any>) -> Unit,
    private val nowMs: () -> Long = { System.nanoTime() / 1_000_000 },
) : DataSource {
    private var loadId: String? = null
    private var requestId = ""
    private var started = 0L
    private var headersMs: Long? = null
    private var bytes = 0L
    private var finished = false

    override fun addTransferListener(listener: TransferListener) = delegate.addTransferListener(listener)
    override fun getUri(): Uri? = delegate.uri
    override fun getResponseHeaders(): Map<String, List<String>> = delegate.responseHeaders

    override fun open(spec: DataSpec): Long {
        loadId = spec.httpRequestHeaders.entries.firstOrNull {
            it.key.equals("X-Playback-Load-Id", ignoreCase = true)
        }?.value?.takeIf { it.matches(Regex("[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}")) }
        requestId = UUID.randomUUID().toString()
        started = nowMs()
        bytes = 0
        headersMs = null
        finished = false
        return try {
            val length = delegate.open(spec)
            headersMs = nowMs() - started
            emit("unavailable", terminal = false)
            length
        } catch (error: Exception) {
            finish("error")
            throw error
        }
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int = try {
        val read = delegate.read(buffer, offset, length)
        if (read == C.RESULT_END_OF_INPUT) finish("complete") else if (read > 0) bytes += read
        read
    } catch (error: Exception) {
        finish("error")
        throw error
    }

    override fun close() {
        try { delegate.close() } finally { finish("cancelled") }
    }

    private fun finish(outcome: String) {
        if (finished) return
        finished = true
        emit(outcome, terminal = true)
    }

    private fun emit(outcome: String, terminal: Boolean) {
        val id = loadId ?: return
        val sample = mutableMapOf<String, Any>(
            "type" to "playback_network", "load_id" to id,
            "request_id" to requestId, "network_outcome" to outcome,
        )
        headersMs?.takeIf { it in 0..600000 }?.let { sample["network_headers_ms"] = it }
        if (terminal) {
            (nowMs() - started).takeIf { it in 0..600000 }?.let { sample["network_duration_ms"] = it }
            bytes.takeIf { it in 0..1073741824 }?.let { sample["network_bytes"] = it }
        }
        try { onSample(sample) } catch (_: Exception) { /* Observability is fail-open. */ }
    }
}
