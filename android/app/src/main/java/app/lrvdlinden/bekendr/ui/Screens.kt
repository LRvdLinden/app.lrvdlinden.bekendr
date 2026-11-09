@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.lrvdlinden.bekendr.ui

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import android.location.LocationManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.runtime.key
import androidx.compose.runtime.SideEffect
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.AlertDialog
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.Streetview
import androidx.compose.material.icons.outlined.DeleteSweep
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.DoneAll
import androidx.compose.material.icons.outlined.MyLocation
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Restore
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lrvdlinden.bekendr.BuildConfig
import app.lrvdlinden.bekendr.MainActivity
import app.lrvdlinden.bekendr.data.AreaRef
import app.lrvdlinden.bekendr.data.Bounds
import app.lrvdlinden.bekendr.data.Category
import app.lrvdlinden.bekendr.data.Fmt
import app.lrvdlinden.bekendr.data.Notice
import app.lrvdlinden.bekendr.data.Pdok
import app.lrvdlinden.bekendr.data.Place
import app.lrvdlinden.bekendr.data.PlaceMode
import app.lrvdlinden.bekendr.data.Repository
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon

// MARK: - Algemene opbouw

@Composable
fun Header(title: String, onBack: (() -> Unit)? = null, actions: @Composable () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().statusBarsPadding().padding(start = if (onBack == null) 20.dp else 4.dp, end = 8.dp, top = 8.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically) {
        onBack?.let { IconButton(onClick = it) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Terug") } }
        Text(title, Modifier.weight(1f), fontSize = if (onBack == null) 30.sp else 20.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1)
        actions()
    }
}

@Composable
private fun Segmented(options: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        options.forEachIndexed { i, label ->
            SegmentedButton(selected = i == selected, onClick = { onSelect(i) }, shape = SegmentedButtonDefaults.itemShape(i, options.size)) { Text(label) }
        }
    }
}

// MARK: - Locatie zoeken

@Composable
fun LocationSearch(mode: PlaceMode, selection: Pdok.Location?, initial: String = "", clearOnPick: Boolean = false, placeholder: String? = null, onSelect: (Pdok.Location?) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var query by remember(mode) { mutableStateOf(selection?.label ?: initial) }
    var suggestions by remember { mutableStateOf<List<Pdok.Suggestion>>(emptyList()) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) scope.launch { useLocation(context, { busy = it }, { message = it }) { loc -> onSelect(loc); query = loc.label; suggestions = emptyList() } }
        else message = "Bekendr heeft geen toegang tot je locatie. Zoek zelf een adres."
    }

    LaunchedEffect(query, mode) {
        if (query.length < 2 || query == selection?.label) { suggestions = emptyList(); return@LaunchedEffect }
        delay(280)
        busy = true
        runCatching { Pdok.suggest(query, if (mode == PlaceMode.radius) listOf("adres") else listOf("woonplaats", "wijk", "buurt", "gemeente")) }
            .onSuccess { suggestions = it; message = if (it.isEmpty()) "Niets gevonden. Probeer het anders te schrijven." else null }
            .onFailure { message = "Zoeken lukt nu niet. Controleer je verbinding." }
        busy = false
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(query, { query = it; if (selection != null && !clearOnPick) onSelect(null) }, Modifier.fillMaxWidth(),
            placeholder = { Text(placeholder ?: if (mode == PlaceMode.radius) "Zoek een adres" else "Zoek een wijk, buurt, woonplaats of gemeente") },
            leadingIcon = { Icon(Icons.Outlined.Search, null) },
            trailingIcon = { if (busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) },
            singleLine = true, shape = RoundedCornerShape(14.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search))
        if (suggestions.isNotEmpty()) Card {
            suggestions.forEachIndexed { i, s ->
                Text(s.label + if (s.type != "adres") "  ·  ${s.type}" else "",
                    Modifier.fillMaxWidth().clickable {
                        scope.launch {
                            busy = true
                            runCatching { Pdok.lookup(s.id) }
                                .onSuccess { onSelect(it); query = if (clearOnPick) "" else it.label; suggestions = emptyList(); message = null }
                                .onFailure { message = "Deze locatie kon niet worden geladen." }
                            busy = false
                        }
                    }.padding(horizontal = 16.dp, vertical = 12.dp))
                if (i < suggestions.lastIndex) HorizontalDivider()
            }
        }
        if (mode == PlaceMode.radius) TextButton(onClick = {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                scope.launch { useLocation(context, { busy = it }, { message = it }) { loc -> onSelect(loc); query = loc.label; suggestions = emptyList() } }
            } else permission.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
        }) {
            Icon(Icons.Outlined.MyLocation, null, Modifier.size(18.dp))
            Text("  Gebruik huidige locatie", fontWeight = FontWeight.SemiBold)
        }
        message?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@SuppressLint("MissingPermission")
private suspend fun useLocation(context: Context, setBusy: (Boolean) -> Unit, setMessage: (String?) -> Unit, done: (Pdok.Location) -> Unit) {
    setBusy(true)
    try {
        val lm = context.getSystemService(LocationManager::class.java)
        val loc = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER, LocationManager.PASSIVE_PROVIDER)
            .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
        if (loc == null) { setMessage("Je locatie kon niet worden bepaald. Zoek een adres."); return }
        done(Pdok.reverse(loc.latitude, loc.longitude))
        setMessage(null)
    } catch (e: Exception) {
        setMessage(e.message ?: "Je locatie kon niet worden bepaald.")
    } finally {
        setBusy(false)
    }
}

/** Kaartje (osmdroid) met de straal of het gebied, of met meldingen. */
@Composable
fun OsmMap(
    modifier: Modifier,
    center: GeoPoint,
    radius: Double? = null,
    polygons: List<List<Pair<Double, Double>>> = emptyList(),
    homes: List<Place> = emptyList(),
    notices: List<Notice> = emptyList(),
    interactive: Boolean = false,
    onSelect: (Notice) -> Unit = {},
) {
    val accent = Brand.accent.toArgb()
    AndroidView(modifier = modifier, factory = { ctx ->
        MapView(ctx).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(interactive)
            zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
            if (!interactive) setOnTouchListener { _, _ -> true }
            controller.setZoom(16.0)
        }
    }, update = { map ->
        map.overlays.clear()
        radius?.let { r ->
            map.overlays += Polygon(map).apply {
                points = Polygon.pointsAsCircle(center, r)
                fillPaint.color = (accent and 0x00FFFFFF) or 0x1F000000
                outlinePaint.color = accent; outlinePaint.strokeWidth = 4f
            }
        }
        polygons.forEach { ring ->
            map.overlays += Polygon(map).apply {
                points = ring.map { GeoPoint(it.first, it.second) }
                fillPaint.color = (accent and 0x00FFFFFF) or 0x1F000000
                outlinePaint.color = accent; outlinePaint.strokeWidth = 4f
            }
        }
        (homes.ifEmpty { if (notices.isEmpty()) listOf(Place(lat = center.latitude, lon = center.longitude)) else emptyList() }).forEach { p ->
            map.overlays += Marker(map).apply {
                position = GeoPoint(p.lat, p.lon); title = p.name
                icon = dot(map.context, Brand.ink.toArgb(), 26)
                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
            }
        }
        notices.filter { it.lat != null && it.lon != null }.forEach { n ->
            map.overlays += Marker(map).apply {
                position = GeoPoint(n.lat!!, n.lon!!); title = n.title
                icon = dot(map.context, n.category.colorValue.toArgb(), 30)
                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                setOnMarkerClickListener { _, _ -> onSelect(n); true }
            }
        }
        val pts = polygons.flatten()
        if (pts.size > 2) {
            map.post { runCatching { map.zoomToBoundingBox(BoundingBox(pts.maxOf { it.first }, pts.maxOf { it.second }, pts.minOf { it.first }, pts.minOf { it.second }), false, 40) } }
        } else {
            map.controller.setCenter(center)
            radius?.let { map.controller.setZoom(when { it <= 250 -> 17.0; it <= 600 -> 16.0; it <= 1200 -> 15.0; else -> 14.0 }) }
        }
        map.invalidate()
    })
}

private fun dot(context: Context, color: Int, sizeDp: Int): BitmapDrawable {
    val px = (sizeDp * context.resources.displayMetrics.density).toInt()
    val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val c = android.graphics.Canvas(bmp)
    val p = Paint(Paint.ANTI_ALIAS_FLAG)
    p.color = 0x40000000; c.drawCircle(px / 2f, px / 2f + 2, px / 2f - 1, p)
    p.color = android.graphics.Color.WHITE; c.drawCircle(px / 2f, px / 2f, px / 2f - 2, p)
    p.color = color; c.drawCircle(px / 2f, px / 2f, px / 2f - 2 - px * 0.09f, p)
    p.color = android.graphics.Color.WHITE; c.drawCircle(px / 2f, px / 2f, px * 0.12f, p)
    return BitmapDrawable(context.resources, bmp)
}

// MARK: - Welkom

@Composable
fun Onboarding(repo: Repository, activity: MainActivity) {
    var step by rememberSaveable { mutableStateOf(0) }
    var mode by remember { mutableStateOf(PlaceMode.radius) }
    var location by remember { mutableStateOf<Pdok.Location?>(null) }
    var areas by remember { mutableStateOf<List<Pdok.Location>>(emptyList()) }
    var radius by remember { mutableStateOf(500.0) }
    var categories by remember { mutableStateOf(Category.entries.toSet()) }
    var notify by remember { mutableStateOf(true) }
    val hasPlaces = repo.places.value.isNotEmpty()
    val valid = categories.isNotEmpty() && if (mode == PlaceMode.radius) location?.type == "adres" else areas.isNotEmpty()
    val notifyPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        repo.updateSettings { it.copy(notify = ok) }
    }

    fun finish() {
        saveDraft(repo, null, if (mode == PlaceMode.area) areas.first().name else "Thuis", mode, location, areas, radius, categories)
        if (notify) {
            if (Build.VERSION.SDK_INT >= 33) notifyPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
            else repo.updateSettings { it.copy(notify = true) }
        }
        repo.updateSettings { it.copy(onboardingDone = true) }
    }

    Column(Modifier.fillMaxSize().background(if (step == 0) Brand.ink else MaterialTheme.colorScheme.background).navigationBarsPadding().imePadding()) {
        Box(Modifier.weight(1f)) {
            when (step) {
                0 -> Column(Modifier.fillMaxSize().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center) {
                    Box(Modifier.size(220.dp), contentAlignment = Alignment.Center) {
                        Box(Modifier.size(150.dp).background(Brand.accent.copy(alpha = 0.22f), CircleShape))
                        BekendrMark(72)
                        Row(Modifier.align(Alignment.TopStart)) { CategoryDot(Category.permit, 38) }
                        Row(Modifier.align(Alignment.TopEnd)) { CategoryDot(Category.traffic, 38) }
                        Row(Modifier.align(Alignment.BottomEnd)) { CategoryDot(Category.tree, 38) }
                        Row(Modifier.align(Alignment.BottomStart)) { CategoryDot(Category.event, 38) }
                    }
                    Spacer(Modifier.height(32.dp))
                    Text("Weet wat er in je buurt gebeurt", color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.ExtraBold,
                        textAlign = TextAlign.Center, lineHeight = 34.sp)
                    Spacer(Modifier.height(14.dp))
                    Text("Vergunningen, verkeersbesluiten, kap en evenementen: alle officiële bekendmakingen rond je adres, op één plek.",
                        color = Color(0xFFC4CAE0), textAlign = TextAlign.Center)
                }
                1 -> Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Kies je eerste locatie", fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Text("Ieder adres in Nederland kan. Later voeg je er meer toe, zoals je werk of een wijk.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Segmented(PlaceMode.entries.map { it.label }, mode.ordinal) { mode = PlaceMode.entries[it] }
                    if (mode == PlaceMode.area) AreaPicker(areas) { areas = it }
                    else LocationSearch(mode, location) { location = it }
                    if (valid) PlacePreview(mode, location, areas, radius)
                }
                else -> Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Wat wil je volgen?", fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Text("Stel in hoe ver om je heen je wilt kijken en welke soorten bekendmakingen je wilt zien.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    PlaceOptions(mode, radius, { radius = it }, categories, { categories = it })
                    Card {
                        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("Stuur een melding bij iets nieuws", Modifier.weight(1f))
                            Switch(notify, { notify = it })
                        }
                    }
                    Text("Bekendr kijkt zelf ongeveer elk uur of er iets nieuws is. Tussen 22:00 en 07:00 komen meldingen stil binnen.",
                        fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                repeat(3) { i ->
                    Box(Modifier.height(8.dp).size(if (i == step) 22.dp else 8.dp, 8.dp)
                        .background(if (i == step) Brand.accentDark else if (step == 0) Color(0xFF3A4060) else MaterialTheme.colorScheme.outline, RoundedCornerShape(4.dp)))
                }
            }
            Button(
                onClick = { if (step == 0 && hasPlaces) repo.updateSettings { it.copy(onboardingDone = true) } else if (step < 2) step++ else finish() },
                enabled = step == 0 || valid,
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Brand.accent, contentColor = Color.White),
            ) { Text(when { step == 2 -> "Aan de slag"; step == 0 && hasPlaces -> "Sluiten"; else -> "Volgende" }, fontWeight = FontWeight.Bold, fontSize = 17.sp) }
            if (step == 0) Text("Gegevens van officielebekendmakingen.nl (KOOP) en PDOK", fontSize = 12.sp, color = Color(0xFFA3AAC4))
            else TextButton({ step-- }) { Text("Terug", fontWeight = FontWeight.SemiBold) }
        }
    }
}

@Composable
fun PlaceOptions(mode: PlaceMode, radius: Double, setRadius: (Double) -> Unit, categories: Set<Category>, setCategories: (Set<Category>) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (mode == PlaceMode.radius) Card {
            Column(Modifier.padding(16.dp)) {
                Row {
                    Text("Straal", Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                    Text(Fmt.distance(radius), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                }
                Slider(radius.toFloat(), { setRadius((Math.round(it / 50f) * 50).toDouble()) }, valueRange = 100f..2000f)
                Row { Text("100 m", Modifier.weight(1f), fontSize = 12.sp); Text("2 km", fontSize = 12.sp) }
            }
        }
        SectionTitle("Categorieën voor deze locatie")
        Card {
            Category.entries.forEachIndexed { i, c ->
                Row(Modifier.padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(c.icon, null, tint = c.colorValue)
                    Text(c.title, Modifier.weight(1f))
                    Switch(c in categories, { on -> setCategories(if (on) categories + c else categories - c) })
                }
                if (i < Category.entries.lastIndex) HorizontalDivider(Modifier.padding(start = 52.dp))
            }
        }
    }
}

fun saveDraft(repo: Repository, existing: Place?, name: String, mode: PlaceMode, loc: Pdok.Location?, areas: List<Pdok.Location>,
              radius: Double, categories: Set<Category>) {
    val base = existing ?: Place()
    val place = if (mode == PlaceMode.radius) {
        val l = loc ?: return
        base.copy(name = name.trim().ifEmpty { "Thuis" }, mode = mode, address = l.label, pdokId = l.id, type = l.type,
            lat = l.lat, lon = l.lon, radius = radius, municipality = l.municipality, bounds = null, categories = categories, areas = emptyList())
    } else {
        if (areas.isEmpty()) return
        val all = areas.mapNotNull { it.bounds }
        val bounds = if (all.isEmpty()) null else Bounds(all.minOf { it.minLat }, all.maxOf { it.maxLat }, all.minOf { it.minLon }, all.maxOf { it.maxLon })
        val first = areas.first()
        base.copy(
            name = name.trim().ifEmpty { first.name }, mode = mode, address = areas.joinToString(" + ") { it.name },
            pdokId = first.id, type = first.type, municipality = first.municipality,
            lat = bounds?.let { (it.minLat + it.maxLat) / 2 } ?: areas.map { it.lat }.average(),
            lon = bounds?.let { (it.minLon + it.maxLon) / 2 } ?: areas.map { it.lon }.average(),
            radius = radius, bounds = bounds, categories = categories,
            areas = areas.map { AreaRef(it.id, it.name, it.type, it.municipality, it.lat, it.lon, it.bounds) })
    }
    repo.savePlace(place)
}

fun AreaRef.toLocation() = Pdok.Location(id, name, type, name, lat, lon, municipality, bounds, emptyList())

/** Kies één of meer gebieden die samen één locatie vormen. */
@Composable
fun AreaPicker(areas: List<Pdok.Location>, onChange: (List<Pdok.Location>) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (areas.isNotEmpty()) Card {
            areas.forEachIndexed { i, a ->
                Row(Modifier.padding(start = 16.dp, end = 4.dp, top = 4.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(a.name, fontWeight = FontWeight.SemiBold)
                        Text(a.type.replaceFirstChar { it.uppercase() }, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    IconButton(onClick = { onChange(areas.filterNot { it.id == a.id }) }) { Icon(Icons.Outlined.Close, "Haal ${a.name} weg") }
                }
                if (i < areas.lastIndex) HorizontalDivider()
            }
        }
        LocationSearch(PlaceMode.area, null, clearOnPick = true,
            placeholder = if (areas.isEmpty()) null else "Voeg nog een buurt, wijk of gemeente toe") { picked ->
            if (picked != null && areas.none { it.id == picked.id }) onChange(areas + picked)
        }
        Text(if (areas.size > 1) "Deze ${areas.size} gebieden worden samen één locatie, met één lijst meldingen."
             else "Je kunt meerdere buurten of wijken kiezen; ze worden samen één locatie.",
            fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Kaartje met de straal of met alle gekozen gebieden; ontbrekende grenzen worden opgehaald. */
@Composable
fun PlacePreview(mode: PlaceMode, location: Pdok.Location?, areas: List<Pdok.Location>, radius: Double) {
    var polygons by remember { mutableStateOf<Map<String, List<List<Pair<Double, Double>>>>>(emptyMap()) }
    LaunchedEffect(areas.map { it.id }) {
        if (mode != PlaceMode.area) return@LaunchedEffect
        for (a in areas) if (a.polygons.isEmpty() && a.id !in polygons && a.id.isNotEmpty()) {
            runCatching { Pdok.lookup(a.id).polygons }.onSuccess { polygons = polygons + (a.id to it) }
        }
    }
    val modifier = Modifier.fillMaxWidth().height(190.dp).background(Color.LightGray, RoundedCornerShape(18.dp))
    if (mode == PlaceMode.radius) {
        location?.let { OsmMap(modifier, GeoPoint(it.lat, it.lon), radius) }
    } else if (areas.isNotEmpty()) {
        val rings = areas.flatMap { a -> a.polygons.ifEmpty { polygons[a.id] ?: emptyList() } }
        OsmMap(modifier, GeoPoint(areas.map { it.lat }.average(), areas.map { it.lon }.average()), null, rings,
            homes = areas.map { Place(name = it.name, lat = it.lat, lon = it.lon) })
    }
}

// MARK: - Jouw buurt

@Composable
fun HomeScreen(repo: Repository, push: (Screen) -> Unit) {
    val places by repo.places.collectAsStateWithLifecycle()
    val notices by repo.notices.collectAsStateWithLifecycle()
    val marks by repo.marks.collectAsStateWithLifecycle()
    val loading by repo.loading.collectAsStateWithLifecycle()
    val error by repo.error.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    val place = places.firstOrNull { it.id == selectedId } ?: places.firstOrNull()

    Column(Modifier.fillMaxSize()) {
        Header("Jouw buurt") {
            IconButton(onClick = { scope.launch { runCatching { repo.refresh() } } }, enabled = !loading) {
                if (loading) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp) else Icon(Icons.Outlined.Refresh, "Nu controleren")
            }
        }
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(Fmt.today(), color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold)
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                places.forEach { p -> Chip(p.name, p.id == place?.id, { selectedId = p.id }) }
                Chip("+", false, { push(Screen.Editor(null)) })
            }
            if (place == null) {
                EmptyState("Nog geen locaties", "Voeg een adres of wijk toe om bekendmakingen in de buurt te zien.")
            } else {
                val list = remember(notices, marks, place.id) { notices.filter { place.id in it.places && !repo.isTrashed(it) } }
                val newCount = list.count { repo.isUnread(it) }
                val today = list.count { Fmt.day(it.date) == "Vandaag" }
                val week = list.count { it.date >= System.currentTimeMillis() - 7 * 86_400_000L }
                Surface(onClick = { push(Screen.Listing(place.id, null, if (newCount > 0) Scope.unread else Scope.all)) },
                    shape = RoundedCornerShape(22.dp), color = Brand.accent, contentColor = Color.White) {
                    Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Text("$newCount nieuwe", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold)
                        Text(if (place.mode == PlaceMode.radius) "binnen ${Fmt.distance(place.radius)} van ${place.shortAddress}" else "in ${place.shortAddress}",
                            color = Color.White.copy(alpha = 0.85f))
                        Text("$today vandaag   ·   $week afgelopen 7 dagen", color = Color.White.copy(alpha = 0.85f), fontSize = 14.sp)
                    }
                }
                TodayCard(repo, place, list, push)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Categorieën", Modifier.weight(1f), fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
                    TextButton({ push(Screen.Editor(place)) }) { Text("Beheren") }
                }
                Category.entries.filter { it in place.categories }.chunked(2).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { c ->
                            val count = list.count { it.category == c }
                            Surface(onClick = { push(Screen.Listing(place.id, c, Scope.all)) }, Modifier.weight(1f),
                                shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surfaceContainer) {
                                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Box(Modifier.size(38.dp).background(c.tintValue, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                                            Icon(c.icon, null, tint = c.colorValue)
                                        }
                                        Spacer(Modifier.weight(1f))
                                        Text("$count", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
                                    }
                                    Text(c.title, fontWeight = FontWeight.SemiBold, maxLines = 1)
                                }
                            }
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
                error?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

// MARK: - Meldingen

private fun filterNotices(repo: Repository, notices: List<Notice>, placeId: String?, category: Category?, scope: Scope): List<Notice> {
    var list = when (scope) {
        Scope.saved -> repo.saved()
        Scope.trash -> notices.filter { repo.isInTrash(it) }
        Scope.unread -> notices.filter { repo.isUnread(it) }
        Scope.all -> notices.filter { !repo.isTrashed(it) }
    }
    if (placeId != null && scope != Scope.saved) list = list.filter { placeId in it.places }
    if (category != null) list = list.filter { it.category == category }
    return list
}

@Composable
private fun NoticeList(repo: Repository, list: List<Notice>, scope: Scope, push: (Screen) -> Unit) {
    val names = repo.places.value.associate { it.id to it.name }
    if (list.isEmpty()) {
        when (scope) {
            Scope.saved -> EmptyState("Nog niets bewaard", "Bewaar een melding om hem hier terug te vinden.")
            Scope.trash -> EmptyState("De prullenbak is leeg", "Meldingen die je weggooit, staan hier nog 30 dagen.")
            else -> EmptyState("Niets nieuws in je buurt", repo.error.value ?: "Er zijn geen bekendmakingen die bij je filters passen.")
        }
        return
    }
    SideEffect { NoticeNavigator.sequence = list.map { it.id } }
    LazyColumn(Modifier.fillMaxSize()) {
        grouped(list).forEach { (day, items) ->
            item(key = "h-$day") { SectionTitle(day) }
            items(items, key = { it.id }) { n ->
                Surface(color = MaterialTheme.colorScheme.surfaceContainer) {
                    NoticeRow(n, repo.isUnread(n), names) { push(Screen.Detail(n.id)) }
                }
                HorizontalDivider()
            }
        }
        if (scope == Scope.trash) item {
            Text("Na 30 dagen worden meldingen in de prullenbak verwijderd. Tot die tijd kun je ze terugzetten.",
                Modifier.padding(16.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun InboxScreen(repo: Repository, push: (Screen) -> Unit) {
    val notices by repo.notices.collectAsStateWithLifecycle()
    val marks by repo.marks.collectAsStateWithLifecycle()
    val places by repo.places.collectAsStateWithLifecycle()
    var showMap by rememberSaveable { mutableStateOf(false) }
    var placeId by rememberSaveable { mutableStateOf<String?>(null) }
    var scope by rememberSaveable { mutableStateOf(Scope.all) }
    var selected by remember { mutableStateOf<Notice?>(null) }
    val list = remember(notices, marks, placeId, scope) { filterNotices(repo, notices, placeId, null, scope) }
    var confirmBulk by remember { mutableStateOf(false) }
    val bulkTitle = when (scope) { Scope.saved -> "Alles niet meer bewaren"; Scope.trash -> "Prullenbak legen"; else -> "Verwijder alle meldingen" }

    if (confirmBulk) AlertDialog(
        onDismissRequest = { confirmBulk = false },
        title = { Text(bulkTitle) },
        text = { Text(when (scope) {
            Scope.saved -> "${list.size} bewaarde meldingen terugzetten naar de inbox?"
            Scope.trash -> "${list.size} meldingen definitief verwijderen?"
            else -> "${list.size} meldingen naar de prullenbak? Ze staan daar nog 30 dagen."
        }) },
        confirmButton = { TextButton({
            when (scope) { Scope.saved -> repo.unsaveAll(list); Scope.trash -> repo.deleteForeverAll(list); else -> repo.trashAll(list) }
            confirmBulk = false
        }) { Text(bulkTitle, color = MaterialTheme.colorScheme.error) } },
        dismissButton = { TextButton({ confirmBulk = false }) { Text("Annuleer") } },
    )

    Column(Modifier.fillMaxSize()) {
        Header("Meldingen") {
            if (list.isNotEmpty()) IconButton(onClick = { confirmBulk = true }) { Icon(Icons.Outlined.DeleteSweep, bulkTitle) }
            IconButton(onClick = { repo.markAllRead() }) { Icon(Icons.Outlined.DoneAll, "Markeer alles als gelezen") }
        }
        Column(Modifier.padding(horizontal = 16.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Segmented(listOf("Lijst", "Kaart"), if (showMap) 1 else 0) { showMap = it == 1 }
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Chip("Alle locaties", placeId == null, { placeId = null })
                places.forEach { p -> Chip(p.name, placeId == p.id, { placeId = p.id }) }
                listOf(Scope.unread, Scope.saved, Scope.trash).forEach { s -> Chip(s.label, scope == s, { scope = if (scope == s) Scope.all else s }) }
            }
        }
        if (showMap) {
            val shown = places.filter { placeId == null || it.id == placeId }
            val first = shown.firstOrNull()
            Box(Modifier.fillMaxSize()) {
                if (first != null) OsmMap(Modifier.fillMaxSize(), GeoPoint(first.lat, first.lon),
                    radius = if (first.mode == PlaceMode.radius) first.radius else null, homes = shown,
                    notices = list, interactive = true, onSelect = { selected = it; NoticeNavigator.sequence = list.filter { n -> n.lat != null }.map { n -> n.id } })
                selected?.let { n ->
                    Surface(onClick = { push(Screen.Detail(n.id)) }, Modifier.align(Alignment.BottomCenter).padding(12.dp),
                        shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainer, shadowElevation = 8.dp) {
                        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            CategoryDot(n.category, 42)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text("${n.category.label} · ${Fmt.day(n.date)}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = n.category.textValue)
                                Text(n.title, fontWeight = FontWeight.SemiBold, maxLines = 3)
                                Text(meta(n, places.associate { it.id to it.name }), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                val hidden = list.count { it.lat == null }
                if (hidden > 0) Text("$hidden meldingen zonder punt op de kaart staan in de lijst.",
                    Modifier.align(Alignment.TopCenter).padding(8.dp).background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(50))
                        .padding(horizontal = 12.dp, vertical = 6.dp), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        } else NoticeList(repo, list, scope, push)
    }
}

@Composable
fun ListScreen(repo: Repository, s: Screen.Listing, push: (Screen) -> Unit, pop: () -> Unit) {
    val notices by repo.notices.collectAsStateWithLifecycle()
    val marks by repo.marks.collectAsStateWithLifecycle()
    val list = remember(notices, marks) { filterNotices(repo, notices, s.placeId, s.category, s.scope) }
    Column(Modifier.fillMaxSize()) {
        Header(s.category?.title ?: when (s.scope) { Scope.unread -> "Nieuw"; Scope.saved -> "Bewaard"; Scope.trash -> "Prullenbak"; else -> "Meldingen" }, pop)
        NoticeList(repo, list, s.scope, push)
    }
}

// MARK: - Bekendmaking

@Composable
fun DetailScreen(repo: Repository, startId: String, push: (Screen) -> Unit, pop: () -> Unit) {
    val context = LocalContext.current
    val marks by repo.marks.collectAsStateWithLifecycle()
    val places by repo.places.collectAsStateWithLifecycle()
    var id by remember(startId) { mutableStateOf(startId) }
    val n = remember(id) { repo.find(id) }
    if (n == null) { Column { Header("Bekendmaking", pop); EmptyState("Niet meer beschikbaar", "Deze bekendmaking staat niet meer in de lijst.") }; return }
    LaunchedEffect(id) { repo.setRead(n) }
    val saved = marks[n.id]?.saved == true
    val trashed = repo.isInTrash(n)

    Column(Modifier.fillMaxSize()) {
        Header(n.category.label, pop) {
            IconButton({ repo.toggleSaved(n) }) { Icon(if (saved) Icons.Outlined.Bookmark else Icons.Outlined.BookmarkBorder, if (saved) "Niet meer bewaren" else "Bewaren") }
            if (trashed) IconButton({ repo.restore(n) }) { Icon(Icons.Outlined.Restore, "Zet terug") }
            else IconButton({ repo.trash(n); pop() }) { Icon(Icons.Outlined.Delete, "Naar prullenbak") }
            IconButton({
                context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_SUBJECT, n.title).putExtra(Intent.EXTRA_TEXT, "${n.title}\n${n.url}"), "Deel"))
            }) { Icon(Icons.Outlined.Share, "Delen") }
        }
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Box(Modifier.background(n.category.tintValue, RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 5.dp)) { CategoryLabel(n.category) }
            Text(n.title, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
            Card {
                val rows = buildList {
                    if (n.creator.isNotEmpty()) add("Instantie" to n.creator)
                    add("Gepubliceerd" to Fmt.long(n.date))
                    places.forEach { p -> n.places[p.id]?.takeIf { it >= 0 }?.let { add("Afstand" to "${Fmt.distance(it)} van ${p.name}") } }
                    if (n.spatial.isNotEmpty()) add("Locatie" to n.spatial)
                }
                rows.forEachIndexed { i, (k, v) ->
                    Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                        Text(k, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.weight(1f).size(12.dp))
                        Text(v, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.End)
                    }
                    if (i < rows.lastIndex) HorizontalDivider(Modifier.padding(start = 16.dp))
                }
            }
            if (n.lat != null && n.lon != null) {
                val home = places.firstOrNull { it.id in n.places }
                key(n.id) { OsmMap(Modifier.fillMaxWidth().height(170.dp), GeoPoint(n.lat, n.lon), homes = listOfNotNull(home), notices = listOf(n)) }
                streetViewIntent(context, n.lat, n.lon)?.let { sv ->
                    OutlinedButton({ context.startActivity(sv) }, Modifier.fillMaxWidth()) {
                        Icon(Icons.Outlined.Streetview, null, Modifier.size(18.dp))
                        Text("  Bekijk in Street View")
                    }
                }
            }
            val text = n.summary.ifEmpty { n.subject }
            if (text.isNotEmpty()) {
                Text("SAMENVATTING", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(text)
            }
            Card {
                Text("Een zienswijze of bezwaar dien je in bij de instantie zelf. Hoe dat gaat, staat in de officiële publicatie.",
                    Modifier.padding(14.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Button(onClick = { context.openUrl(n.url) }, Modifier.fillMaxWidth().height(54.dp), shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Brand.accent, contentColor = Color.White)) {
                Text("Bekijk officiële publicatie  ", fontWeight = FontWeight.Bold)
                Icon(Icons.Outlined.OpenInNew, null, Modifier.size(18.dp))
            }
            TextButton(onClick = { push(Screen.Feedback(n.id)) }, Modifier.fillMaxWidth()) {
                Text("Klopt er iets niet? Laat het weten", fontWeight = FontWeight.SemiBold)
            }
            val (prev, next) = NoticeNavigator.neighbours(n.id)
            if (prev != null || next != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedButton({ prev?.let { id = it } }, Modifier.weight(1f), enabled = prev != null) {
                        Icon(Icons.Outlined.ChevronLeft, null); Text("Vorige")
                    }
                    NoticeNavigator.position(n.id)?.let { (a, b) ->
                        Text("$a van $b", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    OutlinedButton({ next?.let { id = it } }, Modifier.weight(1f), enabled = next != null) {
                        Text("Volgende"); Icon(Icons.Outlined.ChevronRight, null)
                    }
                }
            }
        }
    }
}

// MARK: - Locatie bewerken

@Composable
fun EditorScreen(repo: Repository, place: Place?, initialQuery: String, pop: () -> Unit) {
    var name by remember { mutableStateOf(place?.name ?: if (repo.places.value.isEmpty()) "Thuis" else "Locatie ${repo.places.value.size + 1}") }
    var mode by remember { mutableStateOf(place?.mode ?: PlaceMode.radius) }
    var location by remember {
        mutableStateOf(place?.takeIf { it.lat != 0.0 && it.mode == PlaceMode.radius }?.let { Pdok.Location(it.pdokId, it.address, it.type, it.shortAddress, it.lat, it.lon, it.municipality, it.bounds, emptyList()) })
    }
    var areas by remember { mutableStateOf<List<Pdok.Location>>(place?.allAreas?.map { it.toLocation() } ?: emptyList()) }
    var radius by remember { mutableStateOf(place?.radius ?: 500.0) }
    var categories by remember { mutableStateOf(place?.categories ?: Category.entries.toSet()) }
    var confirmDelete by remember { mutableStateOf(false) }
    val valid = categories.isNotEmpty() && name.isNotBlank() && if (mode == PlaceMode.radius) location?.type == "adres" else areas.isNotEmpty()

    Column(Modifier.fillMaxSize().imePadding()) {
        Header(if (place == null) "Nieuwe locatie" else "Locatie", pop) {
            TextButton(onClick = { saveDraft(repo, place, name, mode, location, areas, radius, categories); pop() }, enabled = valid) {
                Text("Bewaar", fontWeight = FontWeight.Bold)
            }
        }
        Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Naam") }, singleLine = true, shape = RoundedCornerShape(14.dp))
            Segmented(PlaceMode.entries.map { it.label }, mode.ordinal) {
                val m = PlaceMode.entries[it]
                if (m != mode) mode = m
            }
            if (mode == PlaceMode.area) AreaPicker(areas) { list ->
                // Eerste gebied bij een nieuwe locatie: neem de naam over als die nog standaard is.
                if (place == null && areas.isEmpty() && list.isNotEmpty() && (name == "Thuis" || name.startsWith("Locatie "))) name = list.first().name
                areas = list
            } else LocationSearch(mode, location, initialQuery) { location = it }
            if (valid) PlacePreview(mode, location, areas, radius)
            PlaceOptions(mode, radius, { radius = it }, categories, { categories = it })
            if (place != null) {
                if (confirmDelete) {
                    Text("Weet je het zeker? De locatie en de bijbehorende instellingen worden verwijderd.", fontSize = 14.sp)
                    Button(onClick = { repo.deletePlace(place.id); pop() }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFC62F3A))) {
                        Text("Verwijder ${place.name}")
                    }
                } else TextButton({ confirmDelete = true }) { Text("Locatie verwijderen", color = Color(0xFFC62F3A)) }
            }
        }
    }
}

// MARK: - Instellingen

@Composable
fun SettingsScreen(repo: Repository, activity: MainActivity, push: (Screen) -> Unit) {
    val context = LocalContext.current
    val places by repo.places.collectAsStateWithLifecycle()
    val settings by repo.settings.collectAsStateWithLifecycle()
    val notifyPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        repo.updateSettings { it.copy(notify = ok) }
    }
    Column(Modifier.fillMaxSize()) {
        Header("Instellingen")
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            SectionTitle("Mijn locaties")
            Card {
                places.forEach { p ->
                    Row(Modifier.fillMaxWidth().clickable { push(Screen.Editor(p)) }.padding(16.dp)) {
                        Column(Modifier.weight(1f)) {
                            Text(p.name)
                            Text("${p.detail} · ${p.categories.size} categorieën", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    HorizontalDivider()
                }
                Row(Modifier.fillMaxWidth().clickable { push(Screen.Editor(null)) }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Outlined.Add, null, tint = MaterialTheme.colorScheme.primary)
                    Text("  Locatie toevoegen", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                }
            }

            SectionTitle("Meldingen en beveiliging")
            Card {
                SwitchRow("Melding bij nieuwe bekendmaking", settings.notify) { on ->
                    if (on && Build.VERSION.SDK_INT >= 33) notifyPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    else repo.updateSettings { it.copy(notify = on) }
                }
                if (settings.notify) {
                    HorizontalDivider()
                    SwitchRow("Stille uren (${"%02d".format(settings.quietStart)}:00 – ${"%02d".format(settings.quietEnd)}:00)", settings.quiet) { on ->
                        repo.updateSettings { it.copy(quiet = on) }
                    }
                }
                if (activity.canUseBiometrics()) {
                    HorizontalDivider()
                    SwitchRow("Vergrendel met vingerafdruk of gezicht", settings.lock) { on ->
                        if (on) activity.authenticate("Zet vergrendeling aan") { ok -> if (ok) repo.updateSettings { it.copy(lock = true) } }
                        else repo.updateSettings { it.copy(lock = false) }
                    }
                }
            }

            SectionTitle("Meldingen")
            Card {
                LinkRow("Bewaarde meldingen (${repo.saved().size})") { push(Screen.Listing(null, null, Scope.saved)) }
                HorizontalDivider()
                LinkRow("Prullenbak · na 30 dagen definitief verwijderd") { push(Screen.Listing(null, null, Scope.trash)) }
            }

            SectionTitle("Weergave")
            Segmented(listOf("Automatisch", "Licht", "Donker"), listOf("system", "light", "dark").indexOf(settings.appearance).coerceAtLeast(0)) { i ->
                repo.updateSettings { it.copy(appearance = listOf("system", "light", "dark")[i]) }
            }

            Spacer(Modifier.height(12.dp))
            Card {
                LinkRow("Over Bekendr") { push(Screen.About) }
                HorizontalDivider()
                LinkRow("Privacyverklaring") { context.openUrl("https://github.com/LRvdLinden/app.lrvdlinden.bekendr/blob/main/PRIVACY.md") }
                HorizontalDivider()
                LinkRow("Support en contact") { context.openUrl("https://github.com/LRvdLinden/app.lrvdlinden.bekendr/issues") }
                HorizontalDivider()
                LinkRow("Wat is nieuw") { push(Screen.WhatsNew) }
                HorizontalDivider()
                LinkRow("Toon het welkomstscherm") { repo.updateSettings { it.copy(onboardingDone = false) } }
                HorizontalDivider()
                LinkRow("Bron: officielebekendmakingen.nl") { context.openUrl("https://www.officielebekendmakingen.nl") }
            }
            Text("Bekendr is geen app van de overheid. De gegevens komen van KOOP en PDOK, het weer van Open-Meteo, en worden rechtstreeks op je toestel opgehaald. Op Android blijft alles op dit toestel.",
                Modifier.padding(16.dp), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

            SectionTitle("Ontdekken")
            MoreAppsCard()
            AppInfoFooter(BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE.toLong())
        }
    }
}

@Composable
private fun SwitchRow(text: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, Modifier.weight(1f))
        Switch(checked, onChange)
    }
}

@Composable
private fun LinkRow(text: String, onClick: () -> Unit) {
    Text(text, Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp))
}

@Composable
fun WhatsNewScreen(pop: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Header("Wat is nieuw", pop)
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Versie 1.0", fontWeight = FontWeight.Bold, fontSize = 18.sp)
            listOf(
                "Officiële bekendmakingen rond je adres, wijk of gemeente",
                "Buurten en wijken samenvoegen tot één locatie",
                "Meldingen als lijst of op de kaart",
                "Bewaren, prullenbak en gelezen",
                "Melding bij iets nieuws, met stille uren",
                "Vandaag: wat er vandaag is bekendgemaakt, met het weer",
                "Vorige en volgende melding zonder terug naar de lijst",
                "Feedback met een reden als er iets niet klopt",
                "Straatbeeld bij een melding (Google Street View)",
                "Alles in één keer weggooien, terugzetten of de prullenbak legen",
                "Over Bekendr met bronnen en disclaimer",
            ).forEach { Text("•  $it") }
        }
    }
}
