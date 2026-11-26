// ABOUTME: Entry point of the Divine Wear OS app
// ABOUTME: Shows the remote shutter for the phone's recorder

package co.openvine.app.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

class MainActivity : ComponentActivity() {
    private lateinit var phone: PhoneRecorderLink

    private val requestNotifications =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            // The listener service posts it on the phone's next change; show
            // it now for a camera that is already open.
            if (granted) RemoteOngoingActivity.update(this, phone.recorder)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val haptics = Haptics(this)
        phone = PhoneRecorderLink(this).apply { onDeliveryFailure = haptics::pressFailed }
        setContent {
            RemoteShutterScreen(
                recorder = phone.recorder,
                isPhoneReachable = phone.isPhoneReachable && !phone.isShutterPending,
                onToggleRecording = phone::toggleRecording,
                onShutterActiveChanged = { isActive ->
                    if (isActive) haptics.recordingStarted() else haptics.recordingStopped()
                },
            )
        }
        if (savedInstanceState == null) requestNotificationPermission()
    }

    override fun onStart() {
        super.onStart()
        phone.start()
    }

    override fun onStop() {
        phone.stop()
        super.onStop()
    }

    /** Asks once for what the ongoing activity that offers the remote needs. */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) {
            return
        }
        if (shouldShowRequestPermissionRationale(permission)) return
        requestNotifications.launch(permission)
    }
}
