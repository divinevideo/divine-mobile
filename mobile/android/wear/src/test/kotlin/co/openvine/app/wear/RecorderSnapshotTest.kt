package co.openvine.app.wear

import org.junit.Test
import kotlin.test.assertEquals

class RecorderSnapshotTest {
    @Test
    fun elapsed_countsTheTakeInProgress() {
        val recorder = RecorderSnapshot(recordedMs = 2_000, activeTakeStartedAtMs = 10_000)

        assertEquals(3_500, recorder.elapsedMs(nowMs = 11_500))
        // A watch clock slightly behind the phone's never counts backwards.
        assertEquals(2_000, recorder.elapsedMs(nowMs = 9_000))
    }

    @Test
    fun durationLabel_usesThePhonesMinutesAndSeconds() {
        val recorder = RecorderSnapshot(recordedMs = 64_900)

        assertEquals("01:04", recorder.durationLabel(nowMs = 0))
    }

    @Test
    fun budgetFill_growsUntilTheBudgetIsUsedUp() {
        assertEquals(RecordingBudgetFill(0f, 0f), RecordingBudgetFill.of(0, 6_300))
        assertEquals(RecordingBudgetFill(0.5f, 0f), RecordingBudgetFill.of(3_150, 6_300))
        assertEquals(RecordingBudgetFill(1f, 0f), RecordingBudgetFill.of(6_300, 6_300))
    }

    @Test
    fun budgetFill_pastTheBudget_squeezesTheGreenBack() {
        val fill = RecordingBudgetFill.of(elapsedMs = 8_000, budgetMs = 6_000)

        assertEquals(0.75f, fill.filled)
        assertEquals(0.25f, fill.overflow)
    }

    // A Stop Motion composition that is already full has no shots left, so
    // every still counts as past the budget.
    @Test
    fun budgetFill_withNoBudgetLeft_isAllOverflow() {
        assertEquals(RecordingBudgetFill(0f, 1f), RecordingBudgetFill.of(500, 0))
        assertEquals(RecordingBudgetFill(0f, 0f), RecordingBudgetFill.of(0, 0))
    }
}
