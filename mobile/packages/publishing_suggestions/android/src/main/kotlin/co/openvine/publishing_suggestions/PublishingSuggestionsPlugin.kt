package co.openvine.publishing_suggestions

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.Content
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** Each instance owns its cancellable on-device model session. */
class PublishingSuggestionsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var generation: Job? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "publishing_suggestions")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope.cancel()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") {
            generation?.cancel()
            generation = null
            result.success(null)
            return
        }
        if (call.method !in setOf("capabilities", "prepare", "generate")) {
            result.notImplemented()
            return
        }
        if (call.method == "generate" || call.method == "prepare") generation?.cancel()
        val job = scope.launch {
            val model = try {
                Generation.getClient()
            } catch (_: Exception) {
                result.error("unavailable", "Local suggestions are unavailable", null)
                return@launch
            }
            try {
                when (call.method) {
                    "capabilities" -> {
                        val status = when (model.checkStatus()) {
                            FeatureStatus.AVAILABLE -> "ready"
                            FeatureStatus.DOWNLOADABLE -> "downloadable"
                            FeatureStatus.DOWNLOADING -> "preparing"
                            else -> "unavailable"
                        }
                        result.success(mapOf("availability" to status, "images" to (status == "ready")))
                    }
                    "prepare" -> {
                        model.download().collect { }
                        check(model.checkStatus() == FeatureStatus.AVAILABLE)
                        result.success(null)
                    }
                    "generate" -> {
                        val prompt = call.argument<String>("prompt") ?: error("Missing prompt")
                        val images = call.argument<List<ByteArray>>("frames").orEmpty().take(3)
                        val bitmaps = mutableListOf<Bitmap>()
                        try {
                            images.forEach { bytes ->
                                bitmaps.add(BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                                    ?: error("Invalid frame"))
                            }
                            val content = Content.Builder().text(prompt)
                            bitmaps.forEach { content.image(it) }
                            val request = generateContentRequest(content.build()) {
                                maxOutputTokens = 1024
                            }
                            result.success(model.generateContent(request).candidates.firstOrNull()?.text)
                        } finally {
                            bitmaps.forEach { it.recycle() }
                        }
                    }
                }
            } catch (_: Exception) {
                // Never forward model errors: they can contain private source text.
                result.error("unavailable", "Local suggestions are unavailable", null)
            } finally {
                model.close()
            }
        }
        if (call.method == "generate" || call.method == "prepare") generation = job
    }
}
