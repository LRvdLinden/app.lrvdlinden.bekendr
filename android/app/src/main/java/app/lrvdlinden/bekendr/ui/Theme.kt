package app.lrvdlinden.bekendr.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object Brand {
    val accent = Color(0xFF2747E8)
    val accentDark = Color(0xFF8A9DFF)
    val ink = Color(0xFF121726)
    val logoDot = Color(0xFF4C6BFF)
}

private val Light = lightColorScheme(
    primary = Brand.accent,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFE4E9FD),
    onPrimaryContainer = Color(0xFF1B34B0),
    background = Color(0xFFF4F5F8),
    surface = Color(0xFFF4F5F8),
    surfaceContainer = Color.White,
    surfaceContainerLow = Color.White,
    surfaceContainerHigh = Color.White,
    onSurfaceVariant = Color(0xFF5B6275),
    outline = Color(0xFFDDE1EA),
    outlineVariant = Color(0xFFE3E5EC),
)

private val Dark = darkColorScheme(
    primary = Brand.accentDark,
    onPrimary = Color(0xFF0D1018),
    primaryContainer = Color(0xFF1D2547),
    onPrimaryContainer = Color(0xFF9DB0FF),
    background = Color(0xFF0E111A),
    surface = Color(0xFF0E111A),
    surfaceContainer = Color(0xFF1A1F2C),
    surfaceContainerLow = Color(0xFF1A1F2C),
    surfaceContainerHigh = Color(0xFF1A1F2C),
    onSurfaceVariant = Color(0xFF9AA2B8),
    outline = Color(0xFF2A3040),
    outlineVariant = Color(0xFF2A3040),
)

@Composable
fun BekendrTheme(appearance: String, content: @Composable () -> Unit) {
    val dark = when (appearance) { "light" -> false; "dark" -> true; else -> isSystemInDarkTheme() }
    MaterialTheme(colorScheme = if (dark) Dark else Light, content = content)
}
