package co.openvine.divine_quick_actions

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetProviderInfo
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import java.util.concurrent.Executor
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class CameraQuickActionWidgetProvider internal constructor(
    private val updateExecutor: Executor
) : AppWidgetProvider() {
    /** The constructor the system uses for the manifest receiver. */
    constructor() : this(defaultUpdateExecutor)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // An update calls into the widget service, the package manager and the
        // activity manager. When the system server is slow, those calls hold
        // the broadcast past its timeout and the system reports an ANR.
        val pendingResult = goAsync()
        val finished = AtomicBoolean(false)
        val finishBroadcast = Runnable {
            if (finished.compareAndSet(false, true)) pendingResult.finish()
        }
        // The timeout still runs while the broadcast is held, so release it in
        // time. A stalled update keeps running, but once the broadcast is
        // released the process can be frozen or killed before it lands.
        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.postDelayed(finishBroadcast, BROADCAST_DEADLINE_MILLIS)
        updateExecutor.execute {
            try {
                appWidgetIds.forEach { appWidgetId ->
                    updateWidget(context, appWidgetManager, appWidgetId)
                }
            } finally {
                mainHandler.removeCallbacks(finishBroadcast)
                finishBroadcast.run()
            }
        }
    }

    companion object {
        private const val REQUEST_CODE_OPEN_CAMERA = 4101
        private const val UPDATE_THREAD_IDLE_SECONDS = 10L

        // Half the 10 s goAsync() documents for a receiver. The update is a
        // background broadcast, which the system allows 60 s before an ANR.
        private const val BROADCAST_DEADLINE_MILLIS = 5_000L

        // One thread keeps updates in the order they were sent. It exits when
        // idle: with no update period, the widget updates only now and then.
        private val defaultUpdateExecutor: Executor by lazy {
            ThreadPoolExecutor(
                1,
                1,
                UPDATE_THREAD_IDLE_SECONDS,
                TimeUnit.SECONDS,
                LinkedBlockingQueue()
            ) { runnable -> Thread(runnable, "DivineCameraWidgetUpdate") }
                .apply { allowCoreThreadTimeOut(true) }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(
                context.packageName,
                widgetLayout(appWidgetManager, appWidgetId)
            )
            buildOpenCameraPendingIntent(context)?.let { pendingIntent ->
                views.setOnClickPendingIntent(
                    R.id.divine_quick_actions_camera_widget_button,
                    pendingIntent
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun widgetLayout(
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ): Int {
            val hostCategory = appWidgetManager
                .getAppWidgetOptions(appWidgetId)
                .getInt(
                    AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY,
                    AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN
                )
            return if (hostCategory == AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD) {
                R.layout.divine_quick_actions_camera_widget_keyguard
            } else {
                R.layout.divine_quick_actions_camera_widget
            }
        }

        private fun buildOpenCameraPendingIntent(context: Context): PendingIntent? {
            val intent = QuickActionContract.buildLaunchIntent(
                context,
                QuickActionContract.TYPE_CAMERA,
                mapOf("source" to "widget")
            ) ?: return null
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            return PendingIntent.getActivity(
                context,
                REQUEST_CODE_OPEN_CAMERA,
                intent,
                flags
            )
        }

        private fun immutableFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        }
    }
}
