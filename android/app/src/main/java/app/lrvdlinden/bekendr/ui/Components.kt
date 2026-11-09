@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.lrvdlinden.bekendr.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Article
import androidx.compose.material.icons.outlined.ConfirmationNumber
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.Park
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lrvdlinden.bekendr.data.Category
import app.lrvdlinden.bekendr.data.Fmt
import app.lrvdlinden.bekendr.data.Notice
import java.util.Calendar

val Category.icon: ImageVector
    get() = when (this) {
        Category.permit -> Icons.Outlined.Home
        Category.traffic -> Icons.Outlined.Warning
        Category.tree -> Icons.Outlined.Park
        Category.event -> Icons.Outlined.ConfirmationNumber
        Category.plan -> Icons.Outlined.Map
        Category.other -> Icons.Outlined.Article
    }

fun Context.openUrl(url: String) {
    runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

@Composable
fun Chip(text: String, selected: Boolean, onClick: () -> Unit, leading: ImageVector? = null) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(50),
        color = if (selected) Brand.ink else MaterialTheme.colorScheme.surfaceContainer,
        contentColor = if (selected) Color.White else MaterialTheme.colorScheme.onSurface,
        border = if (selected) null else BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
    ) {
        Row(Modifier.padding(horizontal = 14.dp).height(36.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            leading?.let { Icon(it, null, Modifier.size(16.dp)) }
            Text(text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
fun CategoryLabel(c: Category) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(c.icon, null, Modifier.size(14.dp), tint = c.colorValue)
        Text(c.label, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = c.textValue)
    }
}

/** Rond kaartpunt in de categoriekleur met een wit icoon. */
@Composable
fun CategoryDot(c: Category, size: Int = 32) {
    Box(Modifier.size(size.dp).background(c.colorValue, CircleShape).border(2.5.dp, Color.White, CircleShape),
        contentAlignment = Alignment.Center) {
        Icon(c.icon, null, Modifier.size((size * 0.48).dp), tint = Color.White)
    }
}

@Composable
fun NoticeRow(n: Notice, unread: Boolean, placeNames: Map<String, String>, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.padding(top = 6.dp).size(9.dp).background(if (unread) Brand.accent else Color.Transparent, CircleShape))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CategoryLabel(n.category)
                Spacer(Modifier.weight(1f))
                Text(Fmt.day(n.date), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(n.title, fontSize = 15.sp, fontWeight = if (unread) FontWeight.SemiBold else FontWeight.Normal,
                maxLines = 3, overflow = TextOverflow.Ellipsis)
            Text(meta(n, placeNames), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1,
                overflow = TextOverflow.Ellipsis)
        }
    }
}

fun meta(n: Notice, names: Map<String, String>): String {
    val parts = mutableListOf<String>()
    n.places.minByOrNull { kotlin.math.abs(it.value) }?.let { (k, d) ->
        names[k]?.let { parts += if (d >= 0) "$it · ${Fmt.distance(d)}" else it }
    }
    if (n.creator.isNotEmpty()) parts += n.creator
    return parts.joinToString(" · ")
}

/** Groepeert meldingen per dag: Vandaag, Gisteren, maandag 3 november… */
fun grouped(list: List<Notice>): List<Pair<String, List<Notice>>> =
    list.groupBy { Fmt.day(it.date) }.toList()

/** Het LR-logo, getekend zoals op lrvdlinden.app. */
@Composable
fun LRLogo(size: Int = 56) {
    Canvas(Modifier.size(size.dp)) {
        val s = this.size.width / 512f
        drawRoundRect(Brand.ink, cornerRadius = CornerRadius(116 * s))
        val stroke = Stroke(width = 46 * s, cap = StrokeCap.Round)
        fun p(x: Float, y: Float) = Offset(x * s, y * s)
        drawLine(Color.White, p(132f, 146f), p(132f, 370f), 46 * s, StrokeCap.Round)
        drawLine(Color.White, p(132f, 370f), p(232f, 370f), 46 * s, StrokeCap.Round)
        drawLine(Color.White, p(292f, 370f), p(292f, 146f), 46 * s, StrokeCap.Round)
        drawLine(Color.White, p(292f, 146f), p(340f, 146f), 46 * s, StrokeCap.Round)
        drawArc(Color.White, -90f, 180f, false, topLeft = p(278f, 146f), size = Size(124 * s, 124 * s), style = stroke)
        drawLine(Color.White, p(340f, 270f), p(292f, 270f), 46 * s, StrokeCap.Round)
        drawLine(Color.White, p(338f, 270f), p(390f, 370f), 46 * s, StrokeCap.Round)
        drawCircle(Brand.ink, 41 * s, p(404f, 126f))
        drawCircle(Brand.logoDot, 34 * s, p(404f, 126f))
    }
}

/** "Meer apps van de ontwikkelaar", gelijk aan de kaart in de Apple-apps. */
@Composable
fun MoreAppsCard() {
    val context = LocalContext.current
    Surface(
        onClick = { context.openUrl("https://lrvdlinden.app") },
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            LRLogo(56)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text("Meer apps van de ontwikkelaar", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
                Text("Apps voor iPhone, iPad, Apple TV en Homey", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text("Bekijk", Modifier.background(MaterialTheme.colorScheme.primary, RoundedCornerShape(50)).padding(horizontal = 14.dp, vertical = 6.dp),
                color = MaterialTheme.colorScheme.onPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
    }
}

/** Icoon, versie en copyright onderaan Instellingen. */
@Composable
fun AppInfoFooter(versionName: String, versionCode: Long) {
    Column(Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        BekendrMark(64)
        Spacer(Modifier.height(4.dp))
        Text("Versie: $versionName ($versionCode)", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("© ${Calendar.getInstance().get(Calendar.YEAR)} Bekendr", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center)
    }
}

/** Het beeldmerk: blauwe tegel met een witte speld en een document. */
@Composable
fun BekendrMark(size: Int = 64) {
    Canvas(Modifier.size(size.dp)) {
        val w = this.size.width
        drawRoundRect(Brand.accent, cornerRadius = CornerRadius(w * 0.2237f))
        val r = w * 0.27f
        val c = Offset(w / 2, w * 0.42f)
        drawCircle(Color.White, r, c)
        val path = androidx.compose.ui.graphics.Path().apply {
            moveTo(c.x - r * 0.82f, c.y + r * 0.57f); lineTo(c.x + r * 0.82f, c.y + r * 0.57f); lineTo(c.x, w * 0.84f); close()
        }
        drawPath(path, Color.White)
        val dw = r * 0.95f; val dh = r * 1.15f
        drawRoundRect(Brand.accent, topLeft = Offset(c.x - dw / 2, c.y - dh / 2), size = Size(dw, dh), cornerRadius = CornerRadius(r * 0.12f))
        listOf(0.28f to 0.8f, 0.5f to 0.8f, 0.72f to 0.6f).forEach { (f, e) ->
            val y = c.y - dh / 2 + dh * f
            drawLine(Color.White, Offset(c.x - dw / 2 + dw * 0.2f, y), Offset(c.x - dw / 2 + dw * e, y), r * 0.1f, StrokeCap.Round)
        }
        drawCircle(Brand.accent, w * 0.1f, Offset(c.x + r * 0.78f, c.y - r * 0.78f))
        drawCircle(Color(0xFFE8743B), w * 0.075f, Offset(c.x + r * 0.78f, c.y - r * 0.78f))
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(text.uppercase(), Modifier.padding(start = 16.dp, top = 20.dp, bottom = 6.dp), fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
fun Card(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Surface(modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainer) {
        Column { content() }
    }
}

@Composable
fun EmptyState(title: String, text: String) {
    Column(Modifier.fillMaxWidth().padding(40.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp, textAlign = TextAlign.Center)
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
    }
}

@Suppress("unused")
private val unusedWidth = Modifier.width(0.dp)
