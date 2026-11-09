package app.lrvdlinden.bekendr.data

import android.util.Xml
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.xmlpull.v1.XmlPullParser
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.cos

object Fmt {
    private val nl = Locale("nl", "NL")
    fun distance(m: Double): String = when {
        m < 0 -> "in het gebied"
        m < 1000 -> "${maxOf(10, (if (m < 100) Math.round(m / 10) * 10 else Math.round(m / 50) * 50).toInt())} m"
        else -> String.format(nl, if (m < 10_000) "%.1f km" else "%.0f km", m / 1000)
    }
    fun day(ms: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = ms }
        val now = Calendar.getInstance()
        val y = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }
        fun same(a: Calendar, b: Calendar) = a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
        return when {
            same(c, now) -> "Vandaag"
            same(c, y) -> "Gisteren"
            else -> SimpleDateFormat("EEEE d MMMM", nl).format(c.time)
        }
    }
    fun long(ms: Long): String = SimpleDateFormat("EEE d MMM yyyy", nl).format(ms)
    fun today(): String = SimpleDateFormat("EEEE d MMMM", nl).format(System.currentTimeMillis()).replaceFirstChar { it.uppercase() }
}

internal fun httpGet(url: String, accept: String): String {
    val c = URL(url).openConnection() as HttpURLConnection
    c.connectTimeout = 20_000
    c.readTimeout = 30_000
    c.setRequestProperty("Accept", accept)
    c.setRequestProperty("User-Agent", "Bekendr-Android/1.0 (app.lrvdlinden.bekendr)")
    try {
        if (c.responseCode !in 200..299) error("Server gaf fout ${c.responseCode}")
        return c.inputStream.bufferedReader().use { it.readText() }
    } finally {
        c.disconnect()
    }
}

private fun enc(s: String) = URLEncoder.encode(s, "UTF-8").replace("+", "%20")

/** Officiële bekendmakingen via KOOP (SRU 2.0). */
object Koop {
    private const val BASE = "https://repository.overheid.nl/sru"
    const val DAYS = 30

    private fun date(daysAgo: Int): String {
        val c = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -daysAgo) }
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(c.time)
    }
    private fun base() = "(c.product-area==\"officielepublicaties\" AND dt.modified>=${date(DAYS)})"
    private fun n(v: Double) = String.format(Locale.US, "%.7f", v)
    private const val SORT = " sortBy dt.modified /sort.descending"

    fun radiusQuery(lat: Double, lon: Double, radius: Double): String {
        val geo = "within/etrs89 \"${n(lat)} ${n(lon)} ${String.format(Locale.US, "%.3f", radius / 1000)}\""
        return "${base()} AND (w.locatiepunt $geo OR cd.afgeleideLocatiegebied $geo)$SORT"
    }

    fun boxQuery(b: Bounds): String {
        val geo = "within/nwse.etrs89 \"${n(b.maxLat)} ${n(b.minLon)} ${n(b.minLat)} ${n(b.maxLon)}\""
        return "${base()} AND (w.locatiepunt $geo OR cd.afgeleideLocatiegebied $geo)$SORT"
    }

    private fun quoted(v: String): String? {
        val t = v.trim()
        return if (t.isEmpty() || t.length > 120 || t.contains('"') || t.contains('\\')) null else "\"$t\""
    }

    fun nameQuery(area: String): String? = if (area.length < 3) null else quoted(area)?.let {
        "${base()} AND (dt.spatial=$it OR dt.title=$it)$SORT"
    }

    fun creatorQuery(municipality: String): String? = quoted(municipality)?.let { "${base()} AND dt.creator=$it$SORT" }

    /** Grote gebieden opdelen in vakken die KOOP accepteert (± 350 km² maximaal). */
    fun tiles(b: Bounds): List<Bounds> {
        val latKm = (b.maxLat - b.minLat) * 111.32
        val lonKm = (b.maxLon - b.minLon) * 111.32 * cos(Math.toRadians(b.minLat))
        var nLat = 1; var nLon = 1
        while (latKm * lonKm / (nLat * nLon) > 230 && nLat * nLon < 24) {
            if (latKm / nLat >= lonKm / nLon) nLat++ else nLon++
        }
        val out = mutableListOf<Bounds>()
        for (y in 0 until nLat) for (x in 0 until nLon) {
            out += Bounds(
                b.minLat + (b.maxLat - b.minLat) * y / nLat, b.minLat + (b.maxLat - b.minLat) * (y + 1) / nLat,
                b.minLon + (b.maxLon - b.minLon) * x / nLon, b.minLon + (b.maxLon - b.minLon) * (x + 1) / nLon)
        }
        return out
    }

    suspend fun fetch(query: String, maxPages: Int = 2): List<Notice> = withContext(Dispatchers.IO) {
        val out = mutableListOf<Notice>()
        for (page in 0 until maxPages) {
            val url = "$BASE?version=2.0&operation=searchRetrieve&recordSchema=gzd&maximumRecords=250" +
                "&startRecord=${page * 250 + 1}&query=${enc(query)}"
            val (records, total) = parse(httpGet(url, "application/xml"))
            out += records
            if (out.size >= total || records.size < 250) break
        }
        out
    }

    private fun parse(xml: String): Pair<List<Notice>, Int> {
        val p = Xml.newPullParser()
        p.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, true)
        p.setInput(xml.reader())
        val out = mutableListOf<Notice>()
        var total = 0
        var inRecord = 0
        var inDiag = false
        var diag: String? = null
        var f = mutableMapOf<String, String>()
        val subjects = mutableListOf<String>()
        val spatials = mutableListOf<String>()
        var text = StringBuilder()
        while (p.next() != XmlPullParser.END_DOCUMENT) {
            when (p.eventType) {
                XmlPullParser.START_TAG -> {
                    text = StringBuilder()
                    when (p.name) {
                        "diagnostics" -> inDiag = true
                        "record" -> { inRecord++; if (inRecord == 1) { f = mutableMapOf(); subjects.clear(); spatials.clear() } }
                    }
                }
                XmlPullParser.TEXT -> text.append(p.text)
                XmlPullParser.END_TAG -> {
                    val name = p.name
                    val v = text.toString().trim()
                    text = StringBuilder()
                    if (inDiag) {
                        if ((name == "message" || name == "details") && diag == null && v.isNotEmpty()) diag = v.take(180)
                        if (name == "diagnostics") inDiag = false
                        continue
                    }
                    if (name == "numberOfRecords" && inRecord == 0) { total = v.toIntOrNull() ?: 0; continue }
                    if (name == "record") {
                        inRecord--
                        if (inRecord == 0) toNotice(f, subjects, spatials)?.let { out += it }
                        continue
                    }
                    if (inRecord == 0 || v.isEmpty()) continue
                    when (name) {
                        "subject" -> subjects += v
                        "spatial" -> spatials += v
                        "issued", "available", "date" -> f.putIfAbsent("modified", v)
                        "authority" -> f.putIfAbsent("creator", v)
                        "description" -> f.putIfAbsent("abstract", v)
                        "prefferedUrl" -> f.putIfAbsent("preferredUrl", v)
                        else -> f.putIfAbsent(name, v)
                    }
                }
            }
        }
        diag?.let { error("De bekendmakingen konden niet worden opgehaald: $it") }
        return out to total
    }

    private fun toNotice(f: Map<String, String>, subjects: List<String>, spatials: List<String>): Notice? {
        val identifier = f["identifier"].orEmpty()
        val preferred = f["preferredUrl"].orEmpty()
        val id = identifier.ifEmpty { preferred }
        if (id.isEmpty()) return null
        val title = f["title"].orEmpty().ifEmpty { "Officiële bekendmaking" }
        val subject = subjects.joinToString(" · ")
        val point = parsePoint(f["locatiepunt"].orEmpty())
        val summary = f["abstract"].orEmpty()
        val type = f["type"].orEmpty()
        return Notice(
            id = id, title = title, date = parseDate(f["modified"].orEmpty()) ?: System.currentTimeMillis(),
            creator = f["creator"].orEmpty(), type = type, subject = subject, spatial = spatials.joinToString(" · "),
            summary = summary, url = officialUrl(identifier, preferred), lat = point?.first, lon = point?.second,
            category = Category.classify(listOf(title, type, subject, summary)))
    }

    fun officialUrl(identifier: String, preferred: String): String {
        if (preferred.startsWith("http")) return preferred
        Regex("[a-z]+-\\d{4}-\\d+", RegexOption.IGNORE_CASE).find(identifier)?.let {
            return "https://zoek.officielebekendmakingen.nl/${it.value}.html"
        }
        return if (identifier.startsWith("http")) identifier else "https://zoek.officielebekendmakingen.nl/"
    }

    private fun parseDate(s: String): Long? {
        val tz = TimeZone.getTimeZone("Europe/Amsterdam")
        for ((fmt, len) in listOf("yyyy-MM-dd'T'HH:mm:ss" to 19, "yyyy-MM-dd" to 10)) {
            if (s.length < len) continue
            runCatching { SimpleDateFormat(fmt, Locale.US).apply { timeZone = tz }.parse(s.take(len))?.time }.getOrNull()?.let { return it }
        }
        return null
    }

    /** "POINT(lon lat)" of twee getallen; geeft (lat, lon). */
    fun parsePoint(s: String): Pair<Double, Double>? {
        val nums = Regex("-?\\d+(?:\\.\\d+)?").findAll(s).mapNotNull { it.value.toDoubleOrNull() }.toList()
        if (nums.size < 2) return null
        val (a, b) = nums
        fun lat(v: Double) = v in 50.0..54.0
        fun lon(v: Double) = v in 2.5..8.0
        return when {
            s.uppercase().contains("POINT") && lon(a) && lat(b) -> b to a
            lat(a) && lon(b) -> a to b
            lon(a) && lat(b) -> b to a
            else -> null
        }
    }
}

/** Adressen en gebieden via de PDOK Locatieserver. */
object Pdok {
    private const val BASE = "https://api.pdok.nl/bzk/locatieserver/search/v3_1"

    data class Suggestion(val id: String, val label: String, val type: String)
    data class Location(
        val id: String, val label: String, val type: String, val name: String,
        val lat: Double, val lon: Double, val municipality: String,
        val bounds: Bounds?, val polygons: List<List<Pair<Double, Double>>>,
    )

    suspend fun suggest(q: String, types: List<String>): List<Suggestion> = withContext(Dispatchers.IO) {
        if (q.trim().length < 2) return@withContext emptyList()
        val fq = enc("type:(" + types.joinToString(" OR ") + ")")
        val json = JSONObject(httpGet("$BASE/suggest?q=${enc(q.trim())}&fq=$fq&rows=8", "application/json"))
        val docs = json.optJSONObject("response")?.optJSONArray("docs") ?: return@withContext emptyList()
        (0 until docs.length()).mapNotNull { i ->
            val d = docs.getJSONObject(i)
            val id = d.optString("id"); val label = d.optString("weergavenaam")
            if (id.isEmpty() || label.isEmpty()) null else Suggestion(id, label, d.optString("type"))
        }
    }

    suspend fun lookup(id: String): Location = withContext(Dispatchers.IO) {
        val fl = enc("id,type,weergavenaam,centroide_ll,gemeentenaam,woonplaatsnaam,wijknaam,buurtnaam,geometrie_ll")
        val json = JSONObject(httpGet("$BASE/lookup?id=${enc(id)}&fl=$fl", "application/json"))
        val d = json.optJSONObject("response")?.optJSONArray("docs")?.optJSONObject(0) ?: error("Deze locatie is niet gevonden.")
        val c = numbers(d.optString("centroide_ll"))
        if (c.size < 2) error("Deze locatie is niet gevonden.")
        val type = d.optString("type")
        val label = d.optString("weergavenaam")
        val key = when (type) { "woonplaats" -> "woonplaatsnaam"; "wijk" -> "wijknaam"; "buurt" -> "buurtnaam"; "gemeente" -> "gemeentenaam"; else -> "" }
        val name = (if (key.isEmpty()) label else d.optString(key, label)).substringBefore(",").trim()
        val polygons = parsePolygons(d.optString("geometrie_ll"))
        val all = polygons.flatten()
        val bounds = if (all.isEmpty()) null else Bounds(all.minOf { it.first }, all.maxOf { it.first }, all.minOf { it.second }, all.maxOf { it.second })
        Location(d.optString("id", id), label, type, name, c[1], c[0], d.optString("gemeentenaam"), bounds, polygons)
    }

    suspend fun reverse(lat: Double, lon: Double): Location {
        val id = withContext(Dispatchers.IO) {
            val json = JSONObject(httpGet("$BASE/reverse?lat=$lat&lon=$lon&type=adres&rows=1", "application/json"))
            json.optJSONObject("response")?.optJSONArray("docs")?.optJSONObject(0)?.optString("id")
        }
        return lookup(id ?: error("Geen adres gevonden op deze plek."))
    }

    private fun numbers(s: String) = Regex("-?\\d+(?:\\.\\d+)?(?:[eE][-+]?\\d+)?").findAll(s).mapNotNull { it.value.toDoubleOrNull() }.toList()

    /** Buitenste ring van elk vlak, als (lat, lon). */
    fun parsePolygons(wkt: String): List<List<Pair<Double, Double>>> {
        if (!wkt.uppercase().contains("POLYGON")) return emptyList()
        val ringDepth = if (wkt.uppercase().startsWith("MULTIPOLYGON")) 3 else 2
        val out = mutableListOf<List<Pair<Double, Double>>>()
        var depth = 0; var ring = 0; val buf = StringBuilder()
        for (ch in wkt) when (ch) {
            '(' -> { depth++; if (depth == ringDepth - 1) ring = 0; if (depth == ringDepth) buf.setLength(0) }
            ')' -> {
                if (depth == ringDepth) {
                    if (ring == 0) {
                        val n = numbers(buf.toString())
                        val pts = (0 until n.size / 2).map { n[it * 2 + 1] to n[it * 2] }
                        if (pts.size >= 3) out += pts
                    }
                    ring++
                }
                depth--
            }
            else -> if (depth == ringDepth) buf.append(ch)
        }
        return out
    }

    fun contains(polygons: List<List<Pair<Double, Double>>>, lat: Double, lon: Double): Boolean = polygons.any { r ->
        var inside = false
        var j = r.size - 1
        for (i in r.indices) {
            val a = r[i]; val b = r[j]
            if ((a.first > lat) != (b.first > lat) &&
                lon < (b.second - a.second) * (lat - a.first) / (b.first - a.first) + a.second) inside = !inside
            j = i
        }
        inside
    }

    @Suppress("unused")
    private fun close(a: Double, b: Double) = abs(a - b) < 1e-9
}
