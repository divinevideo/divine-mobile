// ABOUTME: The Wear OS remote for the phone's recorder
// ABOUTME: A shutter button over a strip that fills with the clip budget

package co.openvine.app.wear

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.CurvedTextStyle
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.TimeText
import androidx.wear.compose.material3.timeTextCurvedText
import androidx.wear.compose.material3.timeTextSeparator

/** Share of the screen height the budget strip takes. */
private const val STRIP_HEIGHT_FRACTION = 0.22f

/** Share of the space above the strip the shutter button takes. */
private const val BUTTON_FRACTION = 0.72f

/** Keeps the shutter clear of the time along the top edge. */
private val TimeTextBand = 20.dp

/**
 * The remote shutter: the record button, and below it the clip budget filling
 * from the left while a take runs.
 *
 * With no recorder open on the phone the shutter is dimmed and inert, and
 * nothing but the empty strip is shown around it. It is dimmed and inert too
 * while the phone is out of reach, over the last state it sent.
 *
 * @param recorder The phone's recorder, or `null` while it has none on screen.
 * @param isPhoneReachable Whether a press can reach the phone now.
 * @param onShutterActiveChanged Called when the shutter turns from Start to
 *   Stop or back, but not for the state it shows first.
 */
@Composable
fun RemoteShutterScreen(
    recorder: RecorderSnapshot?,
    isPhoneReachable: Boolean,
    onToggleRecording: () -> Unit,
    onShutterActiveChanged: (Boolean) -> Unit = {},
) {
    val shown = recorder ?: RecorderSnapshot()
    val onChanged by rememberUpdatedState(onShutterActiveChanged)
    var lastShutterActive by remember { mutableStateOf(shown.isShutterActive) }
    LaunchedEffect(shown.isShutterActive) {
        if (shown.isShutterActive == lastShutterActive) return@LaunchedEffect
        lastShutterActive = shown.isShutterActive
        onChanged(shown.isShutterActive)
    }
    // Counts on every frame while a take runs, and stands still otherwise.
    val nowMs by produceState(System.currentTimeMillis(), shown.isRecording) {
        value = System.currentTimeMillis()
        while (shown.isRecording) {
            withFrameMillis { }
            value = System.currentTimeMillis()
        }
    }

    MaterialTheme {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
        ) {
            val stripHeight = maxHeight * STRIP_HEIGHT_FRACTION
            Column(modifier = Modifier.fillMaxSize()) {
                BoxWithConstraints(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(top = TimeTextBand),
                    contentAlignment = Alignment.Center,
                ) {
                    RecordButton(
                        isRecording = shown.isShutterActive,
                        isEnabled = recorder?.isShutterEnabled == true && isPhoneReachable,
                        diameter = min(maxWidth, maxHeight) * BUTTON_FRACTION,
                        onClick = onToggleRecording,
                    )
                }
                Text(
                    text = shown.durationLabel(nowMs),
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .alpha(if (recorder == null) 0f else 1f),
                    style = MaterialTheme.typography.labelMedium.copy(fontFeatureSettings = "tnum"),
                )
                Spacer(modifier = Modifier.height(4.dp))
                RecordingBudgetStrip(
                    fill = RecordingBudgetFill.of(shown.elapsedMs(nowMs), shown.budgetMs),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(stripHeight),
                )
            }
            RecorderTimeText(modeName = recorder?.modeName)
        }
    }
}

/** The time along the top edge, after the recorder mode while one is open. */
@Composable
private fun RecorderTimeText(modeName: String?) {
    TimeText { time ->
        if (modeName != null) {
            timeTextCurvedText(modeName, style = CurvedTextStyle(color = Color.Gray))
            timeTextSeparator()
        }
        timeTextCurvedText(time)
    }
}

/**
 * The shutter: a ring whose inner shape morphs between the idle dot and the
 * recording square.
 *
 * Every measure is the phone record button's, scaled from its 96 dp ring.
 */
@Composable
private fun RecordButton(
    isRecording: Boolean,
    isEnabled: Boolean,
    diameter: Dp,
    onClick: () -> Unit,
) {
    val scale = diameter.value / 96f
    val animation = tween<Dp>(durationMillis = 300, easing = FastOutSlowInEasing)
    val innerSize by animateDpAsState(
        targetValue = ((if (isRecording) 32 else 64) * scale).dp,
        animationSpec = animation,
        label = "innerSize",
    )
    val innerCorner by animateDpAsState(
        targetValue = ((if (isRecording) 6 else 20) * scale).dp,
        animationSpec = animation,
        label = "innerCorner",
    )
    val ringColor by animateColorAsState(
        targetValue = if (isRecording) DivinePalette.error else Color.White,
        animationSpec = tween(durationMillis = 300, easing = FastOutSlowInEasing),
        label = "ringColor",
    )
    val label = stringResource(
        if (isRecording) R.string.divine_watch_stop_recording else R.string.divine_watch_start_recording
    )
    val ring = RoundedCornerShape((36 * scale).dp)
    Box(
        modifier = Modifier
            .size(diameter)
            .alpha(if (isEnabled) 1f else 0.5f)
            .border(width = (4 * scale).dp, color = ringColor, shape = ring)
            .clickable(
                enabled = isEnabled,
                role = Role.Button,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(innerSize)
                .background(DivinePalette.error, RoundedCornerShape(innerCorner)),
        )
    }
}

/**
 * The clip budget, filling from the left as it is recorded.
 *
 * Says nothing to TalkBack: the shutter button carries the recorder's state.
 */
@Composable
private fun RecordingBudgetStrip(fill: RecordingBudgetFill, modifier: Modifier = Modifier) {
    val isRound = LocalConfiguration.current.isScreenRound
    Canvas(modifier = modifier.clearAndSetSemantics { }) {
        val span = BudgetStripSpan.of(size.width, size.height, isRound)
        drawRect(DivinePalette.onSurfaceDisabled)
        if (fill.filled > 0f) {
            drawRect(
                color = DivinePalette.primary,
                size = Size(span.endOf(fill.filled), size.height),
            )
        }
        if (fill.overflow > 0f) {
            val start = span.endOf(1f - fill.overflow)
            drawRect(
                color = DivinePalette.primaryContainer,
                topLeft = Offset(start, 0f),
                size = Size(size.width - start, size.height),
            )
        }
    }
}
