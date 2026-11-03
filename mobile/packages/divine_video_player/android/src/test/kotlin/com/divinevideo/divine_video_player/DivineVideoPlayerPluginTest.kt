package com.divinevideo.divine_video_player

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformViewRegistry
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the activity-teardown contract: when the Activity detaches, every live
 * player is stopped (no new frames produced into the renderer) but NOT released —
 * full release stays on engine detach so configuration-free destroys can fall
 * through to `onDetachedFromEngine`.
 *
 * Also pins engine ownership: every engine gets a channel handler, and only the
 * engine attached to the Activity owns the process-wide state.
 */
class DivineVideoPlayerPluginTest {

    private val attached = mutableListOf<Pair<DivineVideoPlayerPlugin, FlutterPlugin.FlutterPluginBinding>>()

    @After
    fun tearDown() {
        attached.reversed().forEach { (plugin, binding) -> plugin.onDetachedFromEngine(binding) }
        // PlayerRegistry is an internal singleton; reset between tests.
        // dispose() on relaxed mocks is a no-op.
        PlayerRegistry.disposeAll()
        DivineVideoPlayerLog.sink = null
    }

    private fun attachEngine(
        plugin: DivineVideoPlayerPlugin,
        messenger: BinaryMessenger = mockk(relaxed = true),
        views: PlatformViewRegistry = mockk(relaxed = true),
    ): FlutterPlugin.FlutterPluginBinding {
        val binding = mockk<FlutterPlugin.FlutterPluginBinding>(relaxed = true)
        every { binding.binaryMessenger } returns messenger
        every { binding.platformViewRegistry } returns views
        plugin.onAttachedToEngine(binding)
        attached += plugin to binding
        return binding
    }

    private fun detachEngine(plugin: DivineVideoPlayerPlugin) {
        val entry = attached.first { it.first === plugin }
        attached.remove(entry)
        plugin.onDetachedFromEngine(entry.second)
    }

    private fun attachActivity(plugin: DivineVideoPlayerPlugin) {
        plugin.onAttachedToActivity(mockk<ActivityPluginBinding>(relaxed = true))
    }

    @Test
    fun `onDetachedFromActivity invokes stopForActivityDetach on every registered player`() {
        val plugin = DivineVideoPlayerPlugin()
        val instanceA = mockk<DivineVideoPlayerInstance>(relaxed = true)
        val instanceB = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, instanceA)
        PlayerRegistry.put(2, instanceB)

        plugin.onDetachedFromActivity()

        verify { instanceA.stopForActivityDetach() }
        verify { instanceB.stopForActivityDetach() }
    }

    @Test
    fun `onDetachedFromActivity does not release any player`() {
        val plugin = DivineVideoPlayerPlugin()
        val instanceA = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, instanceA)

        plugin.onDetachedFromActivity()

        verify(exactly = 0) { instanceA.dispose() }
    }

    @Test
    fun `onDetachedFromActivity is a no-op when no players are registered`() {
        val plugin = DivineVideoPlayerPlugin()

        // Should not throw.
        plugin.onDetachedFromActivity()
    }

    @Test
    fun `UI engine gets a channel handler when a background engine attached first`() {
        // A push that starts the process attaches the Firebase engine first.
        attachEngine(DivineVideoPlayerPlugin())
        val uiMessenger = mockk<BinaryMessenger>(relaxed = true)

        attachEngine(DivineVideoPlayerPlugin(), uiMessenger)

        verify {
            uiMessenger.setMessageHandler("divine_video_player", isNull(inverse = true))
        }
    }

    @Test
    fun `UI engine gets the player view when a background engine attached first`() {
        attachEngine(DivineVideoPlayerPlugin())
        val uiViews = mockk<PlatformViewRegistry>(relaxed = true)

        attachEngine(DivineVideoPlayerPlugin(), views = uiViews)

        verify { uiViews.registerViewFactory("divine_video_player_view", any()) }
    }

    @Test
    fun `log sink belongs to the engine attached to the activity`() {
        attachEngine(DivineVideoPlayerPlugin())
        assertNull(DivineVideoPlayerLog.sink)

        val ui = DivineVideoPlayerPlugin()
        attachEngine(ui)
        attachActivity(ui)

        assertNotNull(DivineVideoPlayerLog.sink)
    }

    @Test
    fun `background engine detaching keeps the UI engine's players and sink`() {
        val background = DivineVideoPlayerPlugin()
        attachEngine(background)
        val ui = DivineVideoPlayerPlugin()
        attachEngine(ui)
        attachActivity(ui)
        val player = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, player)

        detachEngine(background)

        verify(exactly = 0) { player.dispose() }
        assertNotNull(DivineVideoPlayerLog.sink)
    }

    @Test
    fun `background engine attaching keeps the UI engine's players`() {
        val ui = DivineVideoPlayerPlugin()
        attachEngine(ui)
        attachActivity(ui)
        val player = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, player)

        attachEngine(DivineVideoPlayerPlugin())

        verify(exactly = 0) { player.dispose() }
    }

    @Test
    fun `UI engine detaching disposes its players and clears the sink`() {
        val ui = DivineVideoPlayerPlugin()
        attachEngine(ui)
        attachActivity(ui)
        val player = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, player)

        detachEngine(ui)

        verify { player.dispose() }
        assertNull(DivineVideoPlayerLog.sink)
    }

    @Test
    fun `UI engine detaching after a background engine attached disposes its players`() {
        // A push can start the Firebase engine while the app is open.
        val ui = DivineVideoPlayerPlugin()
        attachEngine(ui)
        attachActivity(ui)
        attachEngine(DivineVideoPlayerPlugin())
        val player = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, player)

        detachEngine(ui)

        verify { player.dispose() }
        assertNull(DivineVideoPlayerLog.sink)
    }

    @Test
    fun `UI engine reattaching after hot restart disposes zombie players`() {
        val ui = DivineVideoPlayerPlugin()
        val binding = attachEngine(ui)
        attachActivity(ui)
        val zombie = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, zombie)

        ui.onAttachedToEngine(binding)

        verify { zombie.dispose() }
    }
}
