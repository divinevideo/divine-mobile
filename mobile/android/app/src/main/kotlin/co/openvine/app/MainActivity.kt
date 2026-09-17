package co.openvine.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Log
import android.window.OnBackInvokedCallback
import co.openvine.app.proofmode.HardwareAttestationNotarizationProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.witness.proofmode.ProofMode
import java.io.File
import zendesk.core.Zendesk
import zendesk.core.Identity
import zendesk.core.AnonymousIdentity
import zendesk.core.JwtIdentity
import zendesk.support.Support
import zendesk.support.requestlist.RequestListActivity
import zendesk.support.request.RequestActivity
import zendesk.support.RequestProvider
import zendesk.support.UploadProvider
import zendesk.support.UploadResponse
import zendesk.support.CreateRequest
import zendesk.support.Request
import zendesk.support.CustomField
import com.zendesk.service.ZendeskCallback
import com.zendesk.service.ErrorResponse
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException
import org.witness.proofmode.notarization.NotarizationProvider
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.cert.X509Certificate

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val NAVIGATION_CHANNEL = "org.openvine/navigation"
        private const val NAV_TAG = "OpenVineNavigation"
        private const val INSTALL_SOURCE_CHANNEL = "divine/install_source"
        private const val INSTALL_SOURCE_TAG = "OpenVineInstallSource"
    }

    private var navigationChannel: MethodChannel? = null
    private var backCallback: OnBackInvokedCallback? = null
    @Volatile private var isActivityDestroyed = false
    private val PROOFMODE_CHANNEL = "org.openvine/proofmode"
    private val ZENDESK_CHANNEL = "com.openvine/zendesk_support"
    private val PROOFMODE_TAG = "OpenVineProofMode"
    private val ZENDESK_TAG = "OpenVineZendesk"

    // Lifecycle-aware scope: cancelled in onDestroy to prevent post-detach crashes
    private val activityScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // NIP-55 Android Signer plugin
    private var nostrSignerPlugin: NostrSignerPlugin? = null

    // Nostr bridge per-frame origin attestation plugin (#4105)
    private var nostrBridgeAttestationPlugin: NostrBridgeAttestationPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up ProofMode platform channel
        setupProofModeChannel(flutterEngine)

        // Set up Zendesk platform channel
        setupZendeskChannel(flutterEngine)

        // Set up navigation channel for back button handling
        setupNavigationChannel(flutterEngine)

        // Set up install-source channel (Play Store / Zapstore / sideload).
        // Drives the in-app review prompt's store-install gate and the
        // AppUpdateRepository's download-URL resolution (#6296).
        setupInstallSourceChannel(flutterEngine)

        // Set up NIP-55 Android Signer plugin
        nostrSignerPlugin = NostrSignerPlugin(this, flutterEngine)

        // Set up Nostr bridge frame attestation channel. Must run after
        // super.configureFlutterEngine (which registers WebViewFlutterPlugin via
        // GeneratedPluginRegistrant) — WebViewFlutterAndroidExternalApi.getWebView
        // returns null until that plugin is registered.
        nostrBridgeAttestationPlugin = NostrBridgeAttestationPlugin(flutterEngine)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Forward activity result to NIP-55 signer plugin
        if (nostrSignerPlugin?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onBackPressed() {
        Log.d(NAV_TAG, "onBackPressed() called")

        // Guard against platform channel calls after activity destruction
        if (isActivityDestroyed || isFinishing) {
            super.onBackPressed()
            return
        }

        dispatchBackPressToFlutter(
            channelProvider = { navigationChannel },
            isActivityDestroyed = { isActivityDestroyed },
            isFinishing = { isFinishing },
            onFallback = {
                Log.d(NAV_TAG, "Back handling fell through to default behavior")
                super@MainActivity.onBackPressed()
            },
        )
    }

    private fun setupNavigationChannel(flutterEngine: FlutterEngine) {
        navigationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)

        // Register OnBackInvokedCallback for Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback = OnBackInvokedCallback {
                handleBackPress()
            }
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backCallback!!
            )
        }
    }

    private fun handleBackPress() {
        // Guard against platform channel calls after activity destruction.
        // FlutterJNI may not be attached to native after onDestroy.
        if (isActivityDestroyed || isFinishing) {
            finish()
            return
        }

        dispatchBackPressToFlutter(
            channelProvider = { navigationChannel },
            isActivityDestroyed = { isActivityDestroyed },
            isFinishing = { isFinishing },
            onFallback = { finish() },
        )
    }

    /**
     * Resolves the installer package name (e.g. "com.android.vending" for Play
     * Store, "com.zapstore.app" for Zapstore) so the Dart side can classify
     * the install source. Returns null for sideloaded APKs or on older Android
     * versions where the installer cannot be determined.
     */
    @Suppress("DEPRECATION")
    private fun resolveInstallerPackageName(): String? {
        return try {
            // Prefer getInstallSourceInfo (Play's documented API) on Tiramisu+.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager
                    .getInstallSourceInfo(packageName)
                    .installingPackageName
            } else {
                packageManager.getInstallerPackageName(packageName)
            }
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d(INSTALL_SOURCE_TAG, "No installer package name available", e)
            null
        } catch (e: IllegalArgumentException) {
            Log.d(INSTALL_SOURCE_TAG, "Installer lookup failed", e)
            null
        }
    }

    private fun setupInstallSourceChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALL_SOURCE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallerPackageName" -> result.success(resolveInstallerPackageName())
                else -> result.notImplemented()
            }
        }
        Log.d(INSTALL_SOURCE_TAG, "Install source channel registered")
    }

    override fun onDestroy() {
        isActivityDestroyed = true
        activityScope.cancel()
        navigationChannel = null
        nostrSignerPlugin = null
        nostrBridgeAttestationPlugin = null
        // Unregister callback when activity is destroyed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && backCallback != null) {
            onBackInvokedDispatcher.unregisterOnBackInvokedCallback(backCallback!!)
        }
        super.onDestroy()
    }

    private fun setupProofModeChannel(flutterEngine: FlutterEngine) {

        //add custom notarization for Android Hardware Attestation
        ProofMode.addNotarizationProvider(this, HardwareAttestationNotarizationProvider(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROOFMODE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateProof" -> {
                    val mediaPath = call.argument<String>("mediaPath")
                    if (mediaPath == null) {
                        result.error("INVALID_ARGUMENT", "Media path is required", null)
                        return@setMethodCallHandler
                    }

                    val mediaFile = File(mediaPath)
                    if (!mediaFile.exists()) {
                        result.error("FILE_NOT_FOUND", "Media file does not exist: $mediaPath", null)
                        return@setMethodCallHandler
                    }

                    // Run proof generation on a background thread to avoid ANR.
                    // RSA key generation (BouncyCastle BN_primality_test) is CPU-heavy.
                    val mainHandler = Handler(Looper.getMainLooper())
                    val context = this
                    Thread {
                        try {
                            Log.d(PROOFMODE_TAG, "Generating proof for: $mediaPath")
                            val mediaUri = Uri.fromFile(mediaFile)
                            val proofHash = ProofMode.generateProof(context, mediaUri)

                            mainHandler.post {
                                if (isActivityDestroyed || isFinishing) {
                                    Log.w(PROOFMODE_TAG, "Dropped proof result: activity destroyed")
                                    return@post
                                }
                                if (proofHash.isNullOrEmpty()) {
                                    Log.e(PROOFMODE_TAG, "ProofMode did not generate hash")
                                    result.error("PROOF_HASH_MISSING", "ProofMode did not generate video hash", null)
                                } else {
                                    Log.d(PROOFMODE_TAG, "Proof generated successfully: $proofHash")
                                    result.success(proofHash)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(PROOFMODE_TAG, "Failed to generate proof", e)
                            mainHandler.post {
                                if (isActivityDestroyed || isFinishing) {
                                    Log.w(PROOFMODE_TAG, "Dropped proof error: activity destroyed")
                                    return@post
                                }
                                result.error("PROOF_GENERATION_FAILED", e.message, null)
                            }
                        }
                    }.start()
                }

                "getProofDir" -> {
                    val proofHash = call.argument<String>("proofHash")
                    if (proofHash == null) {
                        result.error("INVALID_ARGUMENT", "Proof hash is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val proofDir = ProofMode.getProofDir(this, proofHash)
                        if (proofDir != null && proofDir.exists()) {
                            result.success(proofDir.absolutePath)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        Log.e(PROOFMODE_TAG, "Failed to get proof directory", e)
                        result.error("GET_PROOF_DIR_FAILED", e.message, null)
                    }
                }

                "isAvailable" -> {
                    // ProofMode is always available on Android when library is included
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }



    private fun setupZendeskChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ZENDESK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val args = call.arguments as? Map<*, *>
                    val appId = args?.get("appId") as? String
                    val clientId = args?.get("clientId") as? String
                    val zendeskUrl = args?.get("zendeskUrl") as? String

                    if (appId == null || clientId == null || zendeskUrl == null) {
                        result.error("INVALID_ARGUMENT", "appId, clientId, and zendeskUrl are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(ZENDESK_TAG, "Initializing Zendesk with URL: $zendeskUrl")

                        // Initialize Zendesk Core SDK
                        Zendesk.INSTANCE.init(this, zendeskUrl, appId, clientId)

                        // Initialize Support SDK
                        Support.INSTANCE.init(Zendesk.INSTANCE)

                        // No identity set at init — JWT identity will be set when the user
                        // accesses support. Setting anonymous here would lock the SDK into
                        // anonymous auth mode and prevent switching to JWT later.

                        Log.d(ZENDESK_TAG, "Zendesk initialized (identity deferred to JWT)")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to initialize Zendesk", e)
                        result.error("INITIALIZATION_FAILED", e.message, null)
                    }
                }

                "showNewTicket" -> {
                    try {
                        // Guard against launching when activity is finishing/destroyed
                        // which causes Theme.AppCompat crashes
                        if (isFinishing || isDestroyed) {
                            result.error("ACTIVITY_DESTROYED", "Activity is not available", null)
                            return@setMethodCallHandler
                        }

                        // Guard: Zendesk SDK requires an identity before showing UI.
                        // Without one the Activity crashes on launch, killing the app
                        // process (reported on Samsung Note 20 Ultra, issue #2365).
                        if (Zendesk.INSTANCE.identity == null) {
                            Log.w(ZENDESK_TAG, "No identity set — cannot show ticket screen")
                            result.error("NO_IDENTITY", "Set an identity before showing Zendesk UI", null)
                            return@setMethodCallHandler
                        }

                        // Note: Zendesk Android SDK v5.1.2 does not support pre-filling
                        // subject/tags in RequestActivity. Users must fill these in the UI.
                        // This is a known limitation of the Android SDK vs iOS SDK.
                        Log.d(ZENDESK_TAG, "Showing new ticket screen")

                        // Launch Zendesk request activity
                        RequestActivity.builder()
                            .show(this)

                        Log.d(ZENDESK_TAG, "Ticket screen shown successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to show ticket screen", e)
                        result.error("SHOW_TICKET_FAILED", e.message, null)
                    }
                }

                "showTicketList" -> {
                    try {
                        // Guard against launching when activity is finishing/destroyed
                        if (isFinishing || isDestroyed) {
                            result.error("ACTIVITY_DESTROYED", "Activity is not available", null)
                            return@setMethodCallHandler
                        }

                        // Guard: Zendesk SDK requires an identity before showing UI.
                        // Without one the Activity crashes on launch, killing the app
                        // process (reported on Samsung Note 20 Ultra, issue #2365).
                        if (Zendesk.INSTANCE.identity == null) {
                            Log.w(ZENDESK_TAG, "No identity set — cannot show ticket list")
                            result.error("NO_IDENTITY", "Set an identity before showing Zendesk UI", null)
                            return@setMethodCallHandler
                        }

                        Log.d(ZENDESK_TAG, "Showing ticket list screen")

                        // Launch Zendesk request list activity
                        RequestListActivity.builder()
                            .show(this)

                        Log.d(ZENDESK_TAG, "Ticket list shown successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to show ticket list", e)
                        result.error("SHOW_LIST_FAILED", e.message, null)
                    }
                }

                "setUserIdentity" -> {
                    val args = call.arguments as? Map<*, *>
                    val name = args?.get("name") as? String
                    val email = args?.get("email") as? String

                    if (name == null || email == null) {
                        result.error("INVALID_ARGUMENT", "name and email are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(ZENDESK_TAG, "Setting user identity")

                        // Create anonymous identity with name and email identifiers
                        val identity: Identity = AnonymousIdentity.Builder()
                            .withNameIdentifier(name)
                            .withEmailIdentifier(email)
                            .build()
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "User identity set successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to set user identity", e)
                        result.error("SET_IDENTITY_FAILED", e.message, null)
                    }
                }

                "clearUserIdentity" -> {
                    try {
                        Log.d(ZENDESK_TAG, "Clearing user identity")

                        // Reset to plain anonymous identity
                        val identity: Identity = AnonymousIdentity()
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "User identity cleared")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to clear user identity", e)
                        result.error("CLEAR_IDENTITY_FAILED", e.message, null)
                    }
                }

                "setJwtIdentity" -> {
                    val args = call.arguments as? Map<*, *>
                    val userToken = args?.get("userToken") as? String

                    if (userToken == null) {
                        result.error("INVALID_ARGUMENT", "userToken is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(ZENDESK_TAG, "Setting JWT identity with user token")

                        // Pass user token (npub) to SDK - Zendesk will call our JWT endpoint to get the actual JWT
                        val identity: Identity = JwtIdentity(userToken)
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "JWT identity set - Zendesk will callback to get JWT")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to set JWT identity", e)
                        result.error("SET_JWT_IDENTITY_FAILED", e.message, null)
                    }
                }

                "setAnonymousIdentity" -> {
                    try {
                        Log.d(ZENDESK_TAG, "Setting anonymous identity")

                        // Set plain anonymous identity (for non-logged-in users)
                        val identity: Identity = AnonymousIdentity()
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "Anonymous identity set")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to set anonymous identity", e)
                        result.error("SET_ANONYMOUS_IDENTITY_FAILED", e.message, null)
                    }
                }

                "createTicket" -> {
                    val args = call.arguments as? Map<*, *>
                    val subject = args?.get("subject") as? String
                    val description = args?.get("description") as? String
                    val tags = (args?.get("tags") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    val ticketFormId = (args?.get("ticketFormId") as? Number)?.toLong()
                    val customFieldsData = (args?.get("customFields") as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()
                    val attachmentPaths = (args?.get("attachmentPaths") as? List<*>)?.filterIsInstance<String>() ?: emptyList()

                    if (subject == null || description == null) {
                        result.error("INVALID_ARGUMENT", "subject and description are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(ZENDESK_TAG, "Creating ticket programmatically - subject: $subject")

                        // Get RequestProvider from Support SDK
                        val providerStore = Support.INSTANCE.provider()
                        if (providerStore == null) {
                            result.error("SDK_NOT_INITIALIZED", "Zendesk Support SDK not initialized", null)
                            return@setMethodCallHandler
                        }
                        val provider: RequestProvider = providerStore.requestProvider()
                        val createRequest = CreateRequest()
                        createRequest.subject = subject
                        createRequest.description = description
                        createRequest.tags = tags

                        // Set ticket form ID if provided
                        if (ticketFormId != null) {
                            createRequest.ticketFormId = ticketFormId
                            Log.d(ZENDESK_TAG, "Using ticket form ID: $ticketFormId")
                        }

                        // Set custom fields if provided
                        if (customFieldsData.isNotEmpty()) {
                            val customFields = customFieldsData.mapNotNull { fieldData ->
                                val fieldId = (fieldData["id"] as? Number)?.toLong()
                                val fieldValue = fieldData["value"]
                                if (fieldId != null && fieldValue != null) {
                                    Log.d(ZENDESK_TAG, "Custom field $fieldId = $fieldValue")
                                    CustomField(fieldId, fieldValue.toString())
                                } else null
                            }
                            createRequest.customFields = customFields
                        }

                        // Zendesk SDK fires callbacks on a background thread,
                        // but Flutter platform channels require the main thread.
                        // Without this dispatch the app crashes (issue #1679).
                        val mainHandler = Handler(Looper.getMainLooper())

                        val submitRequest = {
                            provider.createRequest(createRequest, object : ZendeskCallback<Request>() {
                                override fun onSuccess(request: Request?) {
                                    mainHandler.post {
                                        if (isActivityDestroyed || isFinishing) {
                                            Log.w(ZENDESK_TAG, "Dropped ticket result: activity destroyed")
                                            return@post
                                        }
                                        Log.d(ZENDESK_TAG, "Ticket created successfully - ID: ${request?.id}")
                                        result.success(true)
                                    }
                                }

                                override fun onError(error: ErrorResponse?) {
                                    mainHandler.post {
                                        if (isActivityDestroyed || isFinishing) {
                                            Log.w(ZENDESK_TAG, "Dropped ticket error: activity destroyed")
                                            return@post
                                        }
                                        Log.e(ZENDESK_TAG, "Failed to create ticket: ${error?.reason}")
                                        result.success(false)
                                    }
                                }
                            })
                        }

                        if (attachmentPaths.isEmpty()) {
                            submitRequest()
                        } else {
                            Log.d(ZENDESK_TAG, "Uploading ${attachmentPaths.size} attachments before ticket creation")
                            val uploadProvider: UploadProvider = providerStore.uploadProvider()
                            uploadAttachments(uploadProvider, attachmentPaths, mainHandler) { uploadResult ->
                                uploadResult.fold(
                                    onSuccess = { tokens ->
                                        createRequest.attachments = tokens
                                        Log.d(ZENDESK_TAG, "All ${tokens.size} attachments uploaded, creating ticket")
                                        submitRequest()
                                    },
                                    onFailure = { error ->
                                        mainHandler.post {
                                            if (isActivityDestroyed || isFinishing) {
                                                Log.w(ZENDESK_TAG, "Dropped upload error: activity destroyed")
                                                return@post
                                            }
                                            Log.e(ZENDESK_TAG, "Attachment upload failed: ${error.message}")
                                            result.error("UPLOAD_FAILED", error.message, null)
                                        }
                                    }
                                )
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to create ticket", e)
                        result.error("CREATE_TICKET_FAILED", e.message, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        Log.d(ZENDESK_TAG, "Zendesk platform channel registered")
    }

    private fun uploadAttachments(
        uploadProvider: UploadProvider,
        paths: List<String>,
        mainHandler: Handler,
        onComplete: (Result<List<String>>) -> Unit
    ) {
        val tokens = mutableListOf<String>()

        fun uploadNext(index: Int) {
            if (index >= paths.size) {
                mainHandler.post {
                    onComplete(Result.success(tokens))
                }
                return
            }

            val path = paths[index]
            val file = File(path)
            if (!file.exists()) {
                mainHandler.post {
                    onComplete(Result.failure(Exception("Could not read the selected image")))
                }
                return
            }

            val filename = file.name
            val contentType = attachmentContentType(filename)

            uploadProvider.uploadAttachment(filename, file, contentType, object : ZendeskCallback<UploadResponse>() {
                override fun onSuccess(response: UploadResponse?) {
                    val token = response?.token
                    if (token != null) {
                        // Do not log uploadToken: short-lived Zendesk secure-download credential.
                        Log.d(ZENDESK_TAG, "Uploaded $filename successfully")
                        tokens.add(token)
                        uploadNext(index + 1)
                    } else {
                        mainHandler.post {
                            onComplete(Result.failure(Exception("Attachment upload did not return a token")))
                        }
                    }
                }

                override fun onError(error: ErrorResponse?) {
                    Log.e(ZENDESK_TAG, "Upload failed for $filename: ${error?.reason}")
                    mainHandler.post {
                        onComplete(Result.failure(Exception("Failed to upload selected image")))
                    }
                }
            })
        }

        uploadNext(0)
    }

    private fun attachmentContentType(filename: String): String {
        return when (filename.substringAfterLast('.', "").lowercase()) {
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "heic" -> "image/heic"
            "heif" -> "image/heif"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "image/jpeg"
        }
    }
}

internal fun dispatchBackPressToFlutter(
    channelProvider: () -> MethodChannel?,
    isActivityDestroyed: () -> Boolean,
    isFinishing: () -> Boolean,
    onFallback: () -> Unit,
) {
    if (isActivityDestroyed() || isFinishing()) {
        onFallback()
        return
    }

    val channel = channelProvider() ?: run {
        onFallback()
        return
    }

    // Re-check immediately before invoking Flutter so we degrade safely if the
    // engine detaches between the initial back-navigation pre-check and the call.
    if (isActivityDestroyed() || isFinishing()) {
        onFallback()
        return
    }

    try {
        channel.invokeMethod("onBackPressed", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val handled = result as? Boolean ?: false
                if (!handled) {
                    onFallback()
                }
            }

            override fun error(error: String, message: String?, details: Any?) {
                onFallback()
            }

            override fun notImplemented() {
                onFallback()
            }
        })
    } catch (e: RuntimeException) {
        runCatching {
            Log.w("OpenVineNavigation", "Back navigation invokeMethod failed after detach", e)
        }
        onFallback()
    }
}
