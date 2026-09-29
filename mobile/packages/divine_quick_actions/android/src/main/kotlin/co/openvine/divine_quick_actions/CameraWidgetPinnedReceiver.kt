package co.openvine.divine_quick_actions

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives the launcher's confirmation that the camera widget was pinned.
 *
 * Declared with `exported="false"`, so only the success callback this app
 * created can reach it, on every API level.
 */
class CameraWidgetPinnedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DivineQuickActionsPlugin.dispatchCameraWidgetPinned()
    }

    companion object {
        private const val REQUEST_CODE_WIDGET_PINNED = 4102

        fun successCallback(context: Context): PendingIntent {
            // Immutable: the launcher's widget-id fill-in is not needed.
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_WIDGET_PINNED,
                Intent(context, CameraWidgetPinnedReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
