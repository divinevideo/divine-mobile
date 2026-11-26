// ABOUTME: The part of the budget strip a round watch screen leaves visible
// ABOUTME: So the green starts and ends where the strip can be seen

package co.openvine.app.wear

import kotlin.math.sqrt

/** Where the strip fills, as a start and a width across its own width. */
internal data class BudgetStripSpan(val start: Float, val width: Float) {
    /** Where a fill of [fraction] of the span ends. */
    fun endOf(fraction: Float): Float = start + width * fraction

    companion object {
        /**
         * The span of a strip [width] wide and [height] tall along the bottom
         * of the screen.
         *
         * A round screen hides the strip's corners, so the strip fills across
         * the chord along its top edge, where it is widest: the green then
         * appears at the first moment recorded and covers the strip at the
         * budget.
         */
        fun of(width: Float, height: Float, isRound: Boolean): BudgetStripSpan {
            if (!isRound || height <= 0f || width <= 0f) return BudgetStripSpan(0f, width)
            val radius = width / 2
            val rise = height.coerceAtMost(radius)
            val halfChord = sqrt(2 * radius * rise - rise * rise)
            return BudgetStripSpan(start = radius - halfChord, width = 2 * halfChord)
        }
    }
}
