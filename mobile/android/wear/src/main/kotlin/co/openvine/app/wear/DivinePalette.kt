// ABOUTME: Divine's colors for the Wear OS remote
// ABOUTME: Values match the VineTheme constants of the same name

package co.openvine.app.wear

import androidx.compose.ui.graphics.Color

/** Divine's colors, as `VineTheme` defines them in the Flutter app. */
internal object DivinePalette {
    val primary = Color(0xFF27C58B)
    val primaryContainer = Color(0xFFD0FBCB)
    val error = Color(0xFFF44336)
    val onSurfaceDisabled = Color.White.copy(alpha = 0.25f)
}
