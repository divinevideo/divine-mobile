// ABOUTME: Android Studio previews of the remote shutter
// ABOUTME: The states the watch shows: no camera, ready, recording past the budget, a full composition

package co.openvine.app.wear

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Preview(device = "id:wearos_small_round", showSystemUi = true, name = "Camera closed")
@Composable
private fun CameraClosedPreview() {
    RemoteShutterScreen(recorder = null, isPhoneReachable = true, onToggleRecording = {})
}

@Preview(device = "id:wearos_small_round", showSystemUi = true, name = "Ready")
@Composable
private fun ReadyPreview() {
    RemoteShutterScreen(
        recorder = RecorderSnapshot(recordedMs = 2_500),
        isPhoneReachable = true,
        onToggleRecording = {},
    )
}

@Preview(device = "id:wearos_large_round", showSystemUi = true, name = "Past the budget")
@Composable
private fun OverflowPreview() {
    RemoteShutterScreen(
        recorder = RecorderSnapshot(recordedMs = 8_400, isShutterActive = true),
        isPhoneReachable = true,
        onToggleRecording = {},
    )
}

@Preview(device = "id:wearos_square", showSystemUi = true, name = "Full composition")
@Composable
private fun FullCompositionPreview() {
    RemoteShutterScreen(
        recorder = RecorderSnapshot(recordedMs = 400, budgetMs = 0, modeName = "Stop Motion"),
        isPhoneReachable = true,
        onToggleRecording = {},
    )
}
