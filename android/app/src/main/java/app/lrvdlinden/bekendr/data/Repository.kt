package app.lrvdlinden.bekendr.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/** Alle gegevens van de app, lokaal bewaard als JSON. */
class Repository private constructor(private val dir: File) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val mutex = Mutex()

    private val _places = MutableStateFlow(read<List<Place>>("places.json") ?: emptyList())
    private val _notices = MutableStateFlow(read<List<Notice>>("notices.json") ?: emptyList())
    private val _marks = MutableStateFlow(read<Map<String, Mark>>("marks.json") ?: emptyMap())
    private val _settings = MutableStateFlow(read<Settings>("settings.json") ?: Settings())
    private val _loading = MutableStateFlow(false)
    private val _error = MutableStateFlow<String?>(null)
    private var checked = read<Set<String>>("checked.json") ?: emptySet()
    private val polygonCache = mutableMapOf<String, List<List<Pair<Double, Double>>>>()

    val places: StateFlow<List<Place>> = _places.asStateFlow()
    val notices: StateFlow<List<Notice>> = _notices.asStateFlow()
    val marks: StateFlow<Map<String, Mark>> = _marks.asStateFlow()
    val settings: StateFlow<Settings> = _settings.asStateFlow()
    val loading: StateFlow<Boolean> = _loading.asStateFlow()
    val error: StateFlow<String?> = _error.asStateFlow()

    private inline fun <reified T> read(name: String): T? =
        runCatching { json.decodeFromString<T>(File(dir, name).readText()) }.getOrNull()

    private inline fun <reified T> write(name: String, value: T) {
        runCatching {
            val tmp = File(dir, "$name.tmp")
            tmp.writeText(json.encodeToString(value))
            tmp.renameTo(File(dir, name))
        }
    }

    // MARK: Locaties en instellingen

    fun savePlace(place: Place) {
        val list = _places.value.toMutableList()
        val i = list.indexOfFirst { it.id == place.id }
        if (i >= 0) list[i] = place else list += place
        _places.value = list
        write("places.json", list)
    }

    fun deletePlace(id: String) {
        _places.value = _places.value.filterNot { it.id == id }
        write("places.json", _places.value)
        _notices.value = _notices.value.mapNotNull { n -> (n.places - id).takeIf { it.isNotEmpty() }?.let { n.copy(places = it) } }
        write("notices.json", _notices.value)
    }

    fun updateSettings(change: (Settings) -> Settings) {
        _settings.value = change(_settings.value)
        write("settings.json", _settings.value)
    }

    // MARK: Gelezen, bewaard, prullenbak

    private fun mark(id: String, change: (Mark) -> Mark) {
        val m = _marks.value.toMutableMap()
        m[id] = change(m[id] ?: Mark())
        _marks.value = m
        write("marks.json", m)
    }

    fun isUnread(n: Notice) = !n.initial && _marks.value[n.id]?.read != true && _marks.value[n.id]?.trashedAt == null
    fun setRead(n: Notice, read: Boolean = true) = mark(n.id) { it.copy(read = read) }
    fun markAllRead() {
        val m = _marks.value.toMutableMap()
        _notices.value.forEach { n -> m[n.id] = (m[n.id] ?: Mark()).copy(read = true) }
        _marks.value = m
        write("marks.json", m)
    }
    fun toggleSaved(n: Notice) = mark(n.id) { it.copy(saved = !it.saved, snapshot = if (!it.saved) n else null) }
    fun trash(n: Notice) = mark(n.id) { it.copy(trashedAt = System.currentTimeMillis(), read = true) }
    fun restore(n: Notice) = mark(n.id) { it.copy(trashedAt = null) }
    fun deleteForever(n: Notice) = mark(n.id) { it.copy(deleted = true, saved = false, snapshot = null, trashedAt = 0) }

    fun isTrashed(n: Notice) = _marks.value[n.id]?.trashedAt != null
    fun isInTrash(n: Notice): Boolean {
        val m = _marks.value[n.id] ?: return false
        val t = m.trashedAt ?: return false
        return !m.deleted && System.currentTimeMillis() - t < 30L * 86_400_000
    }
    fun saved(): List<Notice> {
        val byId = _notices.value.associateBy { it.id }
        return _marks.value.filter { it.value.saved }.mapNotNull { (id, m) -> byId[id] ?: m.snapshot }.sortedByDescending { it.date }
    }
    fun find(id: String) = _notices.value.firstOrNull { it.id == id } ?: _marks.value[id]?.snapshot

    // MARK: Ophalen

    /** Haalt bekendmakingen op voor alle locaties; geeft de nieuwe terug. */
    suspend fun refresh(): List<Notice> = mutex.withLock {
        val places = _places.value.filter { it.lat != 0.0 }
        if (places.isEmpty()) return emptyList()
        _loading.value = true
        _error.value = null
        try {
            val now = System.currentTimeMillis()
            val known = _notices.value.associateBy { it.id }.toMutableMap()
            val found = mutableMapOf<String, MutableMap<String, Double>>()
            val fresh = mutableListOf<String>()
            var failures = 0
            val newlyChecked = checked.toMutableSet()
            for (place in places) {
                try {
                    val first = place.id !in checked
                    for (n in fetch(place)) {
                        found.getOrPut(n.id) { mutableMapOf() }[place.id] = n.places[place.id] ?: -1.0
                        if (known[n.id] == null) {
                            known[n.id] = n.copy(places = emptyMap(), firstSeen = now, initial = first)
                            if (!first) fresh += n.id
                        }
                    }
                    newlyChecked += place.id
                } catch (e: Exception) {
                    failures++
                    _error.value = e.message ?: "Ophalen lukte niet. Controleer je verbinding."
                }
            }
            val active = places.map { it.id }.toSet()
            val cutoff = now - Koop.DAYS * 86_400_000L
            val merged = known.values.mapNotNull { n ->
                val p = found[n.id] ?: n.places.filterKeys { it in active }
                if (p.isEmpty() || n.date < cutoff) null else n.copy(places = p)
            }.sortedWith(compareByDescending<Notice> { it.date }.thenByDescending { it.firstSeen })
            _notices.value = merged
            write("notices.json", merged)
            if (failures < places.size) {
                if (failures == 0) _error.value = null
                checked = newlyChecked
                write("checked.json", checked)
            }
            return merged.filter { it.id in fresh }
        } finally {
            _loading.value = false
        }
    }

    private suspend fun fetch(place: Place): List<Notice> {
        val queries = mutableListOf<String>()
        if (place.mode == PlaceMode.radius) {
            queries += Koop.radiusQuery(place.lat, place.lon, place.radius)
        } else {
            place.bounds?.let { b -> queries += Koop.tiles(b).map(Koop::boxQuery) } ?: run { queries += Koop.radiusQuery(place.lat, place.lon, 1500.0) }
            Koop.nameQuery(place.shortAddress)?.let { queries += it }
            if (place.type == "gemeente") Koop.creatorQuery(place.municipality.ifEmpty { place.shortAddress })?.let { queries += it }
        }
        val polygons = if (place.mode == PlaceMode.area && place.pdokId.isNotEmpty()) {
            polygonCache[place.pdokId] ?: runCatching { Pdok.lookup(place.pdokId).polygons }.getOrDefault(emptyList()).also { polygonCache[place.pdokId] = it }
        } else emptyList()

        val result = mutableMapOf<String, Notice>()
        for (q in queries) {
            for (n in Koop.fetch(q)) {
                if (n.category !in place.categories) continue
                val d: Double = if (n.lat != null && n.lon != null) {
                    if (place.mode == PlaceMode.radius) {
                        val dist = distance(place.lat, place.lon, n.lat, n.lon)
                        if (dist > place.radius * 1.15) continue
                        dist
                    } else {
                        if (polygons.isNotEmpty() && !Pdok.contains(polygons, n.lat, n.lon)) continue
                        -1.0
                    }
                } else -1.0
                result[n.id] = n.copy(places = mapOf(place.id to d))
            }
        }
        return result.values.toList()
    }

    companion object {
        @Volatile private var instance: Repository? = null
        fun get(context: Context): Repository = instance ?: synchronized(this) {
            instance ?: Repository(context.applicationContext.filesDir).also { instance = it }
        }

        fun distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
            val r = 6_371_000.0
            val dLat = Math.toRadians(lat2 - lat1)
            val dLon = Math.toRadians(lon2 - lon1)
            val a = Math.sin(dLat / 2).let { it * it } +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLon / 2).let { it * it }
            return 2 * r * Math.asin(Math.sqrt(a))
        }
    }
}

suspend fun <T> io(block: suspend () -> T): T = withContext(Dispatchers.IO) { block() }
