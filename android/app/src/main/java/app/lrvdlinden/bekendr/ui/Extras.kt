package app.lrvdlinden.bekendr.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material.icons.outlined.Cloud
import androidx.compose.material.icons.outlined.Thunderstorm
import androidx.compose.material.icons.outlined.AcUnit
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material.icons.outlined.Foggy
import androidx.compose.material.icons.outlined.NightsStay
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lrvdlinden.bekendr.BuildConfig
import app.lrvdlinden.bekendr.data.Fmt
import app.lrvdlinden.bekendr.data.Notice
import app.lrvdlinden.bekendr.data.Place
import app.lrvdlinden.bekendr.data.Repository
import app.lrvdlinden.bekendr.data.httpGet
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

// MARK: - Vorige en volgende

/** De lijst die het laatst getoond is, voor vorige/volgende in een melding. */
object NoticeNavigator {
    var sequence: List<String> = emptyList()
    fun neighbours(id: String): Pair<String?, String?> {
        val i = sequence.indexOf(id)
        if (i < 0) return null to null
        return sequence.getOrNull(i - 1) to sequence.getOrNull(i + 1)
    }
    fun position(id: String): Pair<Int, Int>? = sequence.indexOf(id).takeIf { it >= 0 }?.let { it + 1 to sequence.size }
}

// MARK: - Feedback

enum class FeedbackReason(val key: String, val label: String) {
    Locatie("locatie", "Locatie klopt niet"),
    Categorie("categorie", "Verkeerde categorie"),
    Gemeente("gemeente", "Verkeerde gemeente"),
    Link("link", "Link naar de publicatie werkt niet"),
    Anders("anders", "Anders"),
}

object FeedbackClient {
    private const val ENDPOINT = "https://vbhkewgyujzgbukkbtml.supabase.co/functions/v1/lrbeheer"

    fun deviceId(context: Context): String {
        val prefs = context.getSharedPreferences("bekendr", Context.MODE_PRIVATE)
        return prefs.getString("feedback.device", null) ?: UUID.randomUUID().toString().also {
            prefs.edit().putString("feedback.device", it).apply()
        }
    }

    /** Geeft null bij succes, anders een foutmelding voor de gebruiker. */
    suspend fun send(context: Context, n: Notice, reason: FeedbackReason, message: String): String? = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("action", "bekendr_feedback").put("notice_id", n.id).put("notice_title", n.title).put("notice_url", n.url)
            .put("reason", reason.key).put("message", message).put("platform", "android")
            .put("app_version", "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})").put("device", deviceId(context))
        runCatching {
            val c = URL(ENDPOINT).openConnection() as HttpURLConnection
            c.requestMethod = "POST"
            c.connectTimeout = 20_000
            c.readTimeout = 30_000
            c.doOutput = true
            c.setRequestProperty("Content-Type", "application/json")
            c.outputStream.use { it.write(body.toString().toByteArray()) }
            val code = c.responseCode
            c.disconnect()
            when (code) {
                in 200..299 -> null
                429 -> "Je hebt net al een paar keer feedback gestuurd. Probeer het later opnieuw."
                400 -> "Vul een toelichting in."
                else -> "Versturen lukte niet. Probeer het opnieuw."
            }
        }.getOrElse { "Versturen lukte niet. Controleer je verbinding en probeer het opnieuw." }
    }
}

@Composable
fun FeedbackScreen(repo: Repository, id: String, pop: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val n = remember(id) { repo.find(id) }
    var reason by remember { mutableStateOf(FeedbackReason.Locatie) }
    var message by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var sent by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize()) {
        Header("Feedback", pop)
        if (n == null) { EmptyState("Niet meer beschikbaar", "Deze bekendmaking staat niet meer in de lijst."); return }
        if (sent) {
            Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Spacer(Modifier.size(40.dp))
                Icon(Icons.Outlined.CheckCircle, null, Modifier.size(56.dp), tint = Brand.accent)
                Text("Bedankt!", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
                Text("Je feedback is ontvangen. Daarmee maken we de indeling van Bekendr beter. Je krijgt geen persoonlijk antwoord.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(pop) { Text("Sluiten") }
            }
            return
        }
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            SectionTitle("Bekendmaking")
            Card { Text(n.title, Modifier.padding(16.dp), fontWeight = FontWeight.SemiBold, maxLines = 3) }
            SectionTitle("Wat klopt er niet?")
            Card {
                FeedbackReason.entries.forEachIndexed { i, r ->
                    Row(Modifier.fillMaxWidth().selectable(reason == r, role = Role.RadioButton) { reason = r }.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(reason == r, null)
                        Text(r.label, Modifier.padding(start = 8.dp))
                    }
                    if (i < FeedbackReason.entries.lastIndex) HorizontalDivider()
                }
            }
            SectionTitle("Toelichting")
            OutlinedTextField(message, { message = it.take(2000) }, Modifier.fillMaxWidth().heightIn(min = 120.dp),
                placeholder = { Text(if (reason == FeedbackReason.Anders) "Omschrijf wat er niet klopt (verplicht)" else "Toelichting (optioneel)") })
            Text("Wil je bezwaar maken of een zienswijze indienen? Dat doe je bij de instantie zelf; hoe dat gaat, staat in de officiële publicatie.",
                Modifier.padding(vertical = 10.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Button(
                onClick = {
                    sending = true; error = null
                    scope.launch {
                        val e = FeedbackClient.send(context, n, reason, message.trim())
                        sending = false
                        if (e == null) sent = true else error = e
                    }
                },
                enabled = !sending && !(reason == FeedbackReason.Anders && message.trim().length < 3),
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp).heightIn(min = 52.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Brand.accent, contentColor = Color.White),
            ) {
                if (sending) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                else Text("Verstuur", fontWeight = FontWeight.Bold)
            }
        }
    }
}

// MARK: - Weer (Open-Meteo, gratis, CC BY 4.0)

data class Weather(val temp: Double, val code: Int, val day: Boolean) {
    val text: String get() = when (code) {
        0 -> "Onbewolkt"; 1 -> "Licht bewolkt"; 2 -> "Half bewolkt"; 3 -> "Bewolkt"
        45, 48 -> "Mist"; in 51..57 -> "Motregen"; in 61..65 -> "Regen"; 66, 67 -> "IJzel"
        in 71..77 -> "Sneeuw"; in 80..82 -> "Buien"; 85, 86 -> "Sneeuwbuien"; in 95..99 -> "Onweer"
        else -> "Wisselend"
    }
    val icon: ImageVector get() = when (code) {
        0, 1 -> if (day) Icons.Outlined.WbSunny else Icons.Outlined.NightsStay
        45, 48 -> Icons.Outlined.Foggy
        in 51..67, in 80..82 -> Icons.Outlined.WaterDrop
        in 71..77, 85, 86 -> Icons.Outlined.AcUnit
        in 95..99 -> Icons.Outlined.Thunderstorm
        else -> Icons.Outlined.Cloud
    }
    val tempText: String get() = "${Math.round(temp)}°"
}

object WeatherCache {
    val byPlace = mutableStateMapOf<String, Weather>()
    private val fetched = mutableMapOf<String, Long>()

    suspend fun load(p: Place) {
        if (p.lat == 0.0) return
        val at = fetched[p.id]
        if (at != null && System.currentTimeMillis() - at < 30 * 60_000) return
        fetched[p.id] = System.currentTimeMillis()
        val url = "https://api.open-meteo.com/v1/forecast?latitude=${"%.3f".format(java.util.Locale.US, p.lat)}" +
            "&longitude=${"%.3f".format(java.util.Locale.US, p.lon)}&current=temperature_2m,weather_code,is_day&timezone=Europe%2FAmsterdam"
        val w = withContext(Dispatchers.IO) {
            runCatching {
                val cur = JSONObject(httpGet(url, "application/json")).getJSONObject("current")
                Weather(cur.getDouble("temperature_2m"), cur.getInt("weather_code"), cur.optInt("is_day", 1) == 1)
            }.getOrNull()
        }
        if (w != null) byPlace[p.id] = w else fetched.remove(p.id)
    }
}

/** Vandaag: het weer en wat er vandaag is bekendgemaakt bij deze locatie. */
@Composable
fun TodayCard(repo: Repository, place: Place, list: List<Notice>, push: (Screen) -> Unit) {
    LaunchedEffect(place.id) { WeatherCache.load(place) }
    val today = list.filter { Fmt.day(it.date) == "Vandaag" }
    val names = repo.places.value.associate { it.id to it.name }
    val w = WeatherCache.byPlace[place.id]
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Vandaag", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
            Spacer(Modifier.weight(1f))
            if (w != null) {
                Icon(w.icon, null, Modifier.size(18.dp), tint = Brand.accent)
                Text("  ${w.tempText} · ${w.text}", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            }
        }
        Card {
            if (today.isEmpty()) {
                Text("Vandaag nog niets bekendgemaakt bij ${place.name}.", Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                today.take(4).forEachIndexed { i, n ->
                    NoticeRow(n, repo.isUnread(n), names) { NoticeNavigator.sequence = today.map { it.id }; push(Screen.Detail(n.id)) }
                    if (i < minOf(3, today.lastIndex)) HorizontalDivider()
                }
                if (today.size > 4) {
                    HorizontalDivider()
                    TextButton({ push(Screen.Listing(place.id, null, Scope.all)) }, Modifier.fillMaxWidth()) {
                        Text("Bekijk alle ${today.size} van vandaag", fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
        if (w != null) Text("Weer: Open-Meteo", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// MARK: - Straatbeeld

/** Opent Street View in Google Maps als die app er is; anders null. */
fun streetViewIntent(context: Context, lat: Double, lon: Double): Intent? {
    val i = Intent(Intent.ACTION_VIEW, Uri.parse("google.streetview:cbll=$lat,$lon")).setPackage("com.google.android.apps.maps")
    val ok = if (Build.VERSION.SDK_INT >= 33)
        context.packageManager.resolveActivity(i, android.content.pm.PackageManager.ResolveInfoFlags.of(0)) != null
    else @Suppress("DEPRECATION") context.packageManager.resolveActivity(i, 0) != null
    return if (ok) i else null
}

// MARK: - Over Bekendr

@Composable
fun AboutScreen(pop: () -> Unit) {
    val context = LocalContext.current
    Column(Modifier.fillMaxSize()) {
        Header("Over Bekendr", pop)
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            Spacer(Modifier.size(8.dp))
            Card {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Bekendr", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
                    Text("Versie ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Bekendr laat je de officiële bekendmakingen zien die over jouw buurt gaan: vergunningen, verkeersbesluiten, kap, evenementen en ruimtelijke plannen. Zonder account en zonder eigen server: de app haalt de gegevens zelf op bij de openbare bronnen van de overheid.")
                }
            }
            SectionTitle("Bronnen")
            Card {
                listOf(
                    "Bekendmakingen: KOOP, officielebekendmakingen.nl" to "https://www.officielebekendmakingen.nl",
                    "Adressen en gebieden: PDOK" to "https://www.pdok.nl",
                    "Weer: Open-Meteo (CC BY 4.0)" to "https://open-meteo.com",
                    "Kaart: © OpenStreetMap-bijdragers" to "https://www.openstreetmap.org/copyright",
                ).forEachIndexed { i, (t, u) ->
                    Text(t, Modifier.fillMaxWidth().clickable { context.openUrl(u) }.padding(16.dp))
                    if (i < 3) HorizontalDivider()
                }
            }
            SectionTitle("Disclaimer")
            Card {
                Text("Bekendr is geen app van de overheid en is niet verbonden aan een gemeente, provincie, waterschap of het Rijk. De app toont openbare gegevens zoals de bronnen die aanleveren. Een bekendmaking kan op de verkeerde plek staan, in een andere categorie vallen of ontbreken. Alleen de officiële publicatie is geldig; daar staat ook hoe en tot wanneer je een zienswijze of bezwaar kunt indienen. Aan de inhoud van Bekendr kun je geen rechten ontlenen.",
                    Modifier.padding(16.dp), fontSize = 14.sp)
            }
            Spacer(Modifier.size(24.dp))
        }
    }
}
