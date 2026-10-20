package com.divinevideo.divine_video_player

import android.media.AudioTrack
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.audio.AudioOutputProvider
import androidx.media3.exoplayer.audio.AudioTrackAudioOutput
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * Guards the start threshold that keeps the editor preview from freezing at a
 * clip boundary when the clip has less audio left than the track's buffer
 * holds (a sped-up body after a transition seam, or a seek close to a cut).
 */
@UnstableApi
class EarlyStartAudioOutputProviderTest {

    private val audioTrack = mockk<AudioTrack>(relaxed = true)

    private val output = mockk<AudioTrackAudioOutput> {
        every { audioTrack } returns this@EarlyStartAudioOutputProviderTest.audioTrack
    }

    private val delegate = mockk<AudioOutputProvider> {
        every { getAudioOutput(any()) } returns output
    }

    private val config = AudioOutputProvider.OutputConfig.Builder().build()

    @Test
    fun `starts each track on its first frame`() {
        val provider = EarlyStartAudioOutputProvider(delegate, sdkInt = 31)

        assertSame(output, provider.getAudioOutput(config))
        val threshold = EarlyStartAudioOutputProvider.START_THRESHOLD_FRAMES
        verify(exactly = 1) { audioTrack.setStartThresholdInFrames(threshold) }
    }

    @Test
    fun `leaves the threshold alone before API 31, which has no setter for it`() {
        val provider = EarlyStartAudioOutputProvider(delegate, sdkInt = 30)

        assertSame(output, provider.getAudioOutput(config))
        verify(exactly = 0) { audioTrack.setStartThresholdInFrames(any()) }
    }
}
