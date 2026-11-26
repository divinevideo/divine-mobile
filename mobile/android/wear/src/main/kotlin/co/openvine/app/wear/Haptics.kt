// ABOUTME: Wrist feedback for the remote shutter
// ABOUTME: Distinct buzzes for a take starting, stopping, and a press that failed

package co.openvine.app.wear

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** Tells the wrist what the phone did, since the user may not be looking. */
internal class Haptics(context: Context) {
    private val vibrator: Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }

    fun recordingStarted() = play(VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK))

    fun recordingStopped() = play(VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK))

    fun pressFailed() = play(VibrationEffect.createWaveform(longArrayOf(0, 60, 90, 60, 90, 60), -1))

    private fun play(effect: VibrationEffect) {
        vibrator?.takeIf { it.hasVibrator() }?.vibrate(effect)
    }
}
