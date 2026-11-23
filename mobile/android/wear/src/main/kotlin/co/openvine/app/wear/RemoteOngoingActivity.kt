// ABOUTME: Offers the remote on the watch face while the phone's camera is open
// ABOUTME: An ongoing activity whose tap opens the remote shutter

package co.openvine.app.wear

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status

/**
 * The phone's camera, offered on the watch face and in the app launcher's
 * recents while it is open, the way the Apple Watch offers the remote in its
 * Smart Stack.
 *
 * A watch app cannot be opened from the phone without the user asking, so
 * this is how the remote turns up when the camera opens.
 */
internal object RemoteOngoingActivity {
    private const val CHANNEL_ID = "camera_remote"
    private const val NOTIFICATION_ID = 1

    /** Shows the activity while [recorder] is open, and hides it once it closes. */
    fun update(context: Context, recorder: RecorderSnapshot?) {
        if (recorder == null) hide(context) else show(context, recorder)
    }

    fun hide(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun show(context: Context, recorder: RecorderSnapshot) {
        val notifications = NotificationManagerCompat.from(context)
        // Without them the activity cannot be posted; the remote is still in
        // the app list.
        if (!notifications.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        notifications.createNotificationChannel(
            NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
                .setName(context.getString(R.string.divine_watch_notification_channel))
                .setShowBadge(false)
                .build()
        )
        val openRemote = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val appName = context.getString(R.string.app_name)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_remote_shutter)
            .setContentTitle(appName)
            .setContentText(recorder.modeName)
            .setContentIntent(openRemote)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setLocalOnly(true)
        OngoingActivity.Builder(context, NOTIFICATION_ID, notification)
            .setStaticIcon(R.drawable.ic_remote_shutter)
            .setTouchIntent(openRemote)
            .setTitle(appName)
            .setStatus(Status.forPart(Status.TextPart(recorder.modeName)))
            .build()
            .apply(context)
        notifications.notify(NOTIFICATION_ID, notification.build())
    }
}
