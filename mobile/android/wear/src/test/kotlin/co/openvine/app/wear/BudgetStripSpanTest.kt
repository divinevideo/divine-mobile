package co.openvine.app.wear

import org.junit.Test
import kotlin.test.assertEquals

class BudgetStripSpanTest {
    @Test
    fun aSquareScreen_fillsTheWholeStrip() {
        assertEquals(BudgetStripSpan(0f, 200f), BudgetStripSpan.of(200f, 44f, isRound = false))
    }

    // On a 200 px round screen a 40 px strip is visible from x = 20 to 180
    // along its top edge: the chord 40 px above the bottom.
    @Test
    fun aRoundScreen_fillsAlongTheVisibleTopEdge() {
        val span = BudgetStripSpan.of(200f, 40f, isRound = true)

        assertEquals(20f, span.start)
        assertEquals(160f, span.width)
        assertEquals(20f, span.endOf(0f))
        assertEquals(180f, span.endOf(1f))
    }
}
