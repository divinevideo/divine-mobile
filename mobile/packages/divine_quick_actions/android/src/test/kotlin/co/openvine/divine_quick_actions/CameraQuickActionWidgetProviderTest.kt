package co.openvine.divine_quick_actions

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Looper
import android.widget.FrameLayout
import android.widget.LinearLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers
import java.time.Duration
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CameraQuickActionWidgetProviderTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val appWidgetManager = AppWidgetManager.getInstance(context)
    private val queuedUpdates = ArrayDeque<Runnable>()
    private val broadcast = Mockito.mock(BroadcastReceiver.PendingResult::class.java)
    private val provider = CameraQuickActionWidgetProvider(Executor(queuedUpdates::addLast))

    // goAsync() documents 10 s for a receiver to finish its broadcast in.
    private val receiverBudget = Duration.ofSeconds(10)

    @Before
    fun registerLauncherActivity() {
        // The widget opens the app's launcher activity, which a library has none of.
        val launcher = ComponentName(context, "co.openvine.app.MainActivity")
        val filter = IntentFilter(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        shadowOf(context.packageManager).apply {
            addActivityIfNotPresent(launcher)
            addIntentFilterForActivity(launcher, filter)
        }
    }

    @Test
    fun holdsTheBroadcastUntilTheQueuedUpdateRuns() {
        val widgetId = bindWidget(AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN)

        deliverUpdate(widgetId)

        assertNull(shadowOf(appWidgetManager).getViewFor(widgetId))
        Mockito.verify(broadcast, Mockito.never()).finish()

        runQueuedUpdates()

        Mockito.verify(broadcast).finish()
        val view = shadowOf(appWidgetManager).getViewFor(widgetId)
        assertEquals(LinearLayout::class.java, view.javaClass)

        view.performClick()

        val opened = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity
        assertEquals(
            QuickActionContract.TYPE_CAMERA,
            opened.getStringExtra(QuickActionContract.EXTRA_ACTION_TYPE)
        )
    }

    @Test
    fun runsTheUpdateOnABackgroundThreadByDefault() {
        val widgetId = bindWidget(AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN)
        val finishedOn = CompletableFuture<Thread>()
        Mockito.doAnswer {
            finishedOn.complete(Thread.currentThread())
            null
        }.`when`(broadcast).finish()

        deliverUpdate(widgetId, receiver = CameraQuickActionWidgetProvider())

        // The main looper stays paused, so only the update can finish the broadcast.
        val updateThread = finishedOn.get(5, TimeUnit.SECONDS)
        assertNotSame(Looper.getMainLooper().thread, updateThread)
        assertEquals(
            LinearLayout::class.java,
            shadowOf(appWidgetManager).getViewFor(widgetId)?.javaClass
        )
    }

    @Test
    fun releasesTheBroadcastBeforeAStalledUpdateTimesOut() {
        val widgetId = bindWidget(AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN)

        deliverUpdate(widgetId)
        shadowOf(Looper.getMainLooper()).idleFor(receiverBudget)

        Mockito.verify(broadcast).finish()

        runQueuedUpdates()

        Mockito.verify(broadcast).finish()
        assertEquals(
            LinearLayout::class.java,
            shadowOf(appWidgetManager).getViewFor(widgetId).javaClass
        )
    }

    @Test
    fun givesALockScreenHostTheKeyguardLayout() {
        val widgetId = bindWidget(AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD)

        deliverUpdate(widgetId)
        runQueuedUpdates()

        val view = shadowOf(appWidgetManager).getViewFor(widgetId)
        assertEquals(FrameLayout::class.java, view.javaClass)
    }

    private fun bindWidget(hostCategory: Int): Int {
        val widgetId = 7
        shadowOf(appWidgetManager).bindAppWidgetId(
            widgetId,
            ComponentName(context, CameraQuickActionWidgetProvider::class.java)
        )
        appWidgetManager.updateAppWidgetOptions(
            widgetId,
            Bundle().apply {
                putInt(AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY, hostCategory)
            }
        )
        return widgetId
    }

    private fun deliverUpdate(
        widgetId: Int,
        receiver: CameraQuickActionWidgetProvider = provider
    ) {
        // The system hands each broadcast a pending result for goAsync().
        ReflectionHelpers.callInstanceMethod<Any?>(
            receiver,
            "setPendingResult",
            ReflectionHelpers.ClassParameter.from(
                BroadcastReceiver.PendingResult::class.java,
                broadcast
            )
        )
        receiver.onReceive(
            context,
            Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
        )
    }

    private fun runQueuedUpdates() {
        while (queuedUpdates.isNotEmpty()) {
            queuedUpdates.removeFirst().run()
        }
    }
}
