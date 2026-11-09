package app.lrvdlinden.bekendr.data

import androidx.compose.ui.graphics.Color
import kotlinx.serialization.Serializable
import java.util.UUID

/** Indeling van bekendmakingen, gelijk aan de Apple-app. */
@Serializable
enum class Category(val title: String, val label: String, val color: Long, val tint: Long, val text: Long) {
    permit("Vergunningen", "Vergunning", 0xFF2747E8, 0xFFE4E9FD, 0xFF1B34B0),
    traffic("Verkeer", "Verkeer", 0xFFE8743B, 0xFFFDEBE1, 0xFFA4461A),
    tree("Bomen en kap", "Bomen en kap", 0xFF2E8B57, 0xFFE0F2E8, 0xFF1E6B40),
    event("Evenementen", "Evenement", 0xFF7B4BD6, 0xFFEEE7FB, 0xFF5A30AE),
    plan("Ruimtelijke plannen", "Ruimtelijk plan", 0xFF0F8A8A, 0xFFDDF2F2, 0xFF0B6767),
    other("Regels en overig", "Overig", 0xFF5B6275, 0xFFECEEF3, 0xFF4A5168);

    val colorValue get() = Color(color)
    val tintValue get() = Color(tint)
    val textValue get() = Color(text)

    companion object {
        fun classify(parts: List<String>): Category {
            val t = parts.joinToString(" ").lowercase()
            fun has(vararg words: String) = words.any { t.contains(it) }
            return when {
                has("kapvergunning", "kappen", "kapmelding", "boom", "bomen", "houtopstand", "herplant") -> tree
                has("verkeersbesluit", "verkeersmaatregel", "wegafsluiting", "afsluiting van", "parkeerverbod",
                    "parkeerplaats", "gehandicaptenparkeer", "laadpaal", "oplaadpunt", "verkeer", "wegwerk") -> traffic
                has("evenement", "festival", "kermis", "markt", "braderie", "optocht") -> event
                has("omgevingsplan", "bestemmingsplan", "ruimtelijk", "wijzigingsplan", "projectbesluit",
                    "voorbereidingsbesluit", "structuurvisie", "omgevingsvisie", "ter inzage") -> plan
                has("vergunning", "ontheffing", "aanvraag", "melding activiteitenbesluit") -> permit
                else -> other
            }
        }
    }
}

@Serializable
enum class PlaceMode(val label: String) { radius("Straal rond adres"), area("Wijk of gemeente") }

@Serializable
data class Bounds(val minLat: Double, val maxLat: Double, val minLon: Double, val maxLon: Double)

/** Eén gebied binnen een (samengevoegde) locatie. */
@Serializable
data class AreaRef(
    val id: String,
    val name: String,
    val type: String,
    val municipality: String = "",
    val lat: Double,
    val lon: Double,
    val bounds: Bounds? = null,
)

/** Een gevolgde locatie. Op Android alleen lokaal bewaard. */
@Serializable
data class Place(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "Thuis",
    val mode: PlaceMode = PlaceMode.radius,
    val address: String = "",
    val pdokId: String = "",
    val type: String = "adres",
    val lat: Double = 0.0,
    val lon: Double = 0.0,
    val radius: Double = 500.0,
    val municipality: String = "",
    val bounds: Bounds? = null,
    val categories: Set<Category> = Category.entries.toSet(),
    val createdAt: Long = System.currentTimeMillis(),
    /** Samengevoegde gebieden; leeg bij een adres met straal. */
    val areas: List<AreaRef> = emptyList(),
) {
    /** De gebieden van deze locatie, ook voor oudere locaties met één gebied. */
    val allAreas: List<AreaRef>
        get() = areas.ifEmpty {
            if (mode == PlaceMode.area && pdokId.isNotEmpty())
                listOf(AreaRef(pdokId, address.substringBefore(",").trim(), type, municipality, lat, lon, bounds))
            else emptyList()
        }
    val shortAddress get() = if (mode == PlaceMode.area && areas.size > 1) areas.joinToString(" + ") { it.name } else address.substringBefore(",").trim()
    val detail get() = when {
        mode == PlaceMode.radius -> "$shortAddress · ${Fmt.distance(radius)}"
        areas.size > 1 -> "${areas.size} gebieden samengevoegd"
        else -> "$shortAddress · heel gebied"
    }
}

@Serializable
data class Notice(
    val id: String,
    val title: String,
    val date: Long,
    val creator: String = "",
    val type: String = "",
    val subject: String = "",
    val spatial: String = "",
    val summary: String = "",
    val url: String,
    val lat: Double? = null,
    val lon: Double? = null,
    val category: Category,
    /** Locatie-id → afstand in meters (of -1 in een gebied). */
    val places: Map<String, Double> = emptyMap(),
    val firstSeen: Long = System.currentTimeMillis(),
    val initial: Boolean = false,
)

/** Gelezen, bewaard of in de prullenbak. */
@Serializable
data class Mark(
    val read: Boolean = false,
    val saved: Boolean = false,
    val trashedAt: Long? = null,
    val deleted: Boolean = false,
    val snapshot: Notice? = null,
)

@Serializable
data class Settings(
    val onboardingDone: Boolean = false,
    val notify: Boolean = false,
    val quiet: Boolean = true,
    val quietStart: Int = 22,
    val quietEnd: Int = 7,
    val lock: Boolean = false,
    val appearance: String = "system",
)
