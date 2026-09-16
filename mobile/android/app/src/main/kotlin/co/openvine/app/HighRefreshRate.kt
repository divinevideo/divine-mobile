package co.openvine.app

import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.Display
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup

/**
 * Asks the panel for its fastest refresh rate at the current resolution so
 * feed scrolling animates at 120 Hz where the hardware offers it.
 *
 * Flutter draws at whatever cadence Android's Choreographer delivers, and a
 * window that states no preference is served the panel's default — 60 Hz on
 * a Samsung set to "Adaptive" until something votes higher. Android has two
 * refresh-rate models, so this votes twice: [Display.Mode] selection through
 * `preferredDisplayModeId` for panels with discrete modes, and a
 * [Surface.setFrameRate] vote on Flutter's own surface, which is what the
 * adaptive refresh rate on Android 15+ reads within a mode. Both are
 * requests: a panel pinned to "Standard" (60 Hz) in system settings ignores
 * them, and that is the user's choice to keep.
 */
object HighRefreshRate {
    private const val TAG = "OpenVineRefreshRate"

    /**
     * The fastest mode at [current]'s resolution, which may be [current]
     * itself, or `null` when the panel reports no modes.
     */
    fun fastestMode(modes: Array<Display.Mode>, current: Display.Mode): Display.Mode? =
        modes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate }

    /**
     * Requests the fastest rate for [activity]: switches the window to the
     * fastest mode when a faster one exists, and votes that rate on the
     * Flutter surface either way — on an adaptive panel the 120 Hz mode can
     * already be active while frames are still delivered at 60.
     */
    fun apply(activity: Activity, flutterView: ViewGroup?) {
        val display =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                activity.display
            } else {
                @Suppress("DEPRECATION")
                activity.windowManager.defaultDisplay
            } ?: return
        val current = display.mode
        val fastest = fastestMode(display.supportedModes, current) ?: return
        if (fastest.modeId != current.modeId) {
            val attributes = activity.window.attributes
            attributes.preferredDisplayModeId = fastest.modeId
            activity.window.attributes = attributes
            Log.d(TAG, "Requested display mode ${fastest.modeId} at ${fastest.refreshRate} Hz")
        }
        voteFrameRate(flutterView, fastest.refreshRate)
    }

    /**
     * Votes [hz] on the surface Flutter renders into, now and on every
     * re-creation of that surface (each return from the background makes a
     * new one). No-op below Android 11, where the API does not exist, and
     * when [flutterView] holds no [SurfaceView] (texture render mode).
     */
    fun voteFrameRate(flutterView: ViewGroup?, hz: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val surfaceView = flutterView?.let(::findSurfaceView) ?: return
        val holder = surfaceView.holder
        holder.addCallback(
            object : SurfaceHolder.Callback {
                override fun surfaceCreated(holder: SurfaceHolder) = vote(holder.surface, hz)

                override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = Unit

                override fun surfaceDestroyed(holder: SurfaceHolder) = Unit
            },
        )
        if (holder.surface?.isValid == true) vote(holder.surface, hz)
    }

    private fun vote(surface: Surface, hz: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        surface.setFrameRate(
            hz,
            Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
            Surface.CHANGE_FRAME_RATE_ALWAYS,
        )
        Log.d(TAG, "Voted $hz Hz on the Flutter surface")
    }

    private fun findSurfaceView(root: View): SurfaceView? {
        if (root is SurfaceView) return root
        if (root !is ViewGroup) return null
        for (i in 0 until root.childCount) {
            findSurfaceView(root.getChildAt(i))?.let { return it }
        }
        return null
    }
}
