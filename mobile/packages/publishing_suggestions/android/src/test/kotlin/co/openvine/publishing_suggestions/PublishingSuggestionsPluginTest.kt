package co.openvine.publishing_suggestions

import android.graphics.Bitmap
import com.google.mlkit.genai.common.FeatureStatus
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.ByteArrayOutputStream

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PublishingSuggestionsPluginTest {
    private val dispatcher = StandardTestDispatcher()
    @Before fun setUp() { Dispatchers.setMain(dispatcher) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test fun unsupportedLanguageNeverOpensTheModel() = runTest(dispatcher) {
        val plugin = PublishingSuggestionsPlugin()
        val reply = Reply()
        plugin.onMethodCall(MethodCall("capabilities", mapOf("language" to "fr")), reply)
        runCurrent()
        assertEquals(mapOf("availability" to "unavailable", "images" to false), reply.value)
        assertEquals(1, reply.count)
    }

    @Test fun cancellationBeforeCoroutineStartsCompletesOriginalReply() = runTest(dispatcher) {
        val plugin = PublishingSuggestionsPlugin()
        val original = Reply()
        val cancelled = Reply()
        plugin.onMethodCall(MethodCall("generate", mapOf("prompt" to "sample", "language" to "en")), original)
        plugin.onMethodCall(MethodCall("cancel", null), cancelled)
        runCurrent()
        assertEquals(1, cancelled.count)
        assertEquals(1, original.count)
        assertEquals("unavailable", original.error)
    }

    @Test fun mapsDeviceStatusesAndRegionalEnglish() = runTest(dispatcher) {
        for ((status, expected) in listOf(
            FeatureStatus.AVAILABLE to "ready",
            FeatureStatus.DOWNLOADABLE to "downloadable",
            FeatureStatus.DOWNLOADING to "preparing",
            FeatureStatus.UNAVAILABLE to "unavailable",
            -1 to "unavailable",
        )) {
            val model = FakeModel(status)
            val plugin = PublishingSuggestionsPlugin { model }
            val reply = Reply()
            plugin.onMethodCall(MethodCall("capabilities", mapOf("language" to "en_NZ")), reply)
            runCurrent()
            assertEquals(mapOf("availability" to expected, "images" to (expected == "ready")), reply.value)
            assertEquals(1, reply.count)
            assertTrue(model.closed)
        }
    }

    @Test fun unsupportedGenerationDoesNotOpenDeviceModel() = runTest(dispatcher) {
        val plugin = PublishingSuggestionsPlugin { error("Must not open model") }
        val reply = Reply()
        plugin.onMethodCall(MethodCall("generate", mapOf("language" to "ja", "prompt" to "sample")), reply)
        runCurrent()
        assertEquals("unavailable", reply.error)
        assertEquals(1, reply.count)
    }

    @Test fun decodesAtMostThreeFramesAndRecyclesAfterGeneration() = runTest(dispatcher) {
        val model = FakeModel()
        val plugin = PublishingSuggestionsPlugin { model }
        val reply = Reply()
        plugin.onMethodCall(MethodCall("generate", mapOf("prompt" to "sample", "frames" to listOf(png(), png(), png(), byteArrayOf(0)))), reply)
        runCurrent()
        assertEquals("generated", reply.value)
        assertEquals(3, model.frames.size)
        assertTrue(model.frames.all { it.isRecycled })
        assertTrue(model.closed)
        assertEquals(1, reply.count)
    }

    @Test fun malformedFrameFailsAndReleasesModel() = runTest(dispatcher) {
        val model = FakeModel()
        val plugin = PublishingSuggestionsPlugin { model }
        val reply = Reply()
        plugin.onMethodCall(MethodCall("generate", mapOf("prompt" to "sample", "frames" to listOf(png(), byteArrayOf(0)))), reply)
        runCurrent()
        assertEquals("unavailable", reply.error)
        assertTrue(model.frames.isEmpty())
        assertTrue(model.closed)
        assertEquals(1, reply.count)
    }

    @Test fun cancellationCompletesInFlightReplyAndClosesModel() = runTest(dispatcher) {
        val model = FakeModel(wait = CompletableDeferred())
        val plugin = PublishingSuggestionsPlugin { model }
        val reply = Reply()
        plugin.onMethodCall(MethodCall("generate", mapOf("prompt" to "private sample")), reply)
        runCurrent()
        assertEquals(0, reply.count)
        plugin.onMethodCall(MethodCall("cancel", null), Reply())
        runCurrent()
        assertEquals("unavailable", reply.error)
        assertEquals(1, reply.count)
        assertTrue(model.closed)
    }

    @Test fun replacementCompletesCancelledReplyAndNewGeneration() = runTest(dispatcher) {
        val first = FakeModel(wait = CompletableDeferred())
        val second = FakeModel()
        val models = ArrayDeque(listOf(first, second))
        val plugin = PublishingSuggestionsPlugin { models.removeFirst() }
        val oldReply = Reply()
        val newReply = Reply()
        plugin.onMethodCall(MethodCall("generate", mapOf("prompt" to "first")), oldReply)
        runCurrent()
        plugin.onMethodCall(MethodCall("generate", mapOf("prompt" to "second")), newReply)
        runCurrent()
        assertEquals("unavailable", oldReply.error)
        assertEquals(1, oldReply.count)
        assertEquals("generated", newReply.value)
        assertEquals(1, newReply.count)
        assertTrue(first.closed && second.closed)
    }

    @Test fun modelFailureReturnsOnlySanitizedError() = runTest(dispatcher) {
        val plugin = PublishingSuggestionsPlugin { error("private transcript") }
        val reply = Reply()
        plugin.onMethodCall(MethodCall("generate", mapOf("prompt" to "sample")), reply)
        runCurrent()
        assertEquals("unavailable", reply.error)
        assertEquals("Local suggestions are unavailable", reply.message)
        assertNull(reply.details)
        assertEquals(1, reply.count)
    }

    @Test fun preparationClosesModelAndRepliesOnce() = runTest(dispatcher) {
        val model = FakeModel()
        val reply = Reply()
        PublishingSuggestionsPlugin { model }.onMethodCall(MethodCall("prepare", null), reply)
        runCurrent()
        assertTrue(model.prepared && model.closed)
        assertEquals(1, reply.count)
        assertNull(reply.error)
    }

    private fun png(): ByteArray {
        val bitmap = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        return ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            bitmap.recycle()
            it.toByteArray()
        }
    }

    private class FakeModel(
        private val availability: Int = FeatureStatus.AVAILABLE,
        private val wait: CompletableDeferred<String>? = null,
    ) : PublishingModel {
        var closed = false
        var prepared = false
        var frames = listOf<Bitmap>()
        override suspend fun status() = availability
        override suspend fun prepare() { prepared = true }
        override suspend fun generate(prompt: String, frames: List<Bitmap>): String {
            this.frames = frames.toList()
            return wait?.await() ?: "generated"
        }
        override fun close() { closed = true }
    }

    private class Reply : MethodChannel.Result {
        var count = 0
        var value: Any? = null
        var error: String? = null
        var message: String? = null
        var details: Any? = null
        override fun success(result: Any?) { count++; value = result }
        override fun error(code: String, message: String?, details: Any?) { count++; error = code; this.message = message; this.details = details }
        override fun notImplemented() { count++; error = "notImplemented" }
    }
}
