@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.lrvdlinden.bekendr.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lrvdlinden.bekendr.MainActivity
import app.lrvdlinden.bekendr.data.Category
import app.lrvdlinden.bekendr.data.Place
import app.lrvdlinden.bekendr.data.Repository
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class Tab { home, inbox, settings }
enum class Scope(val label: String) { all("Alles"), unread("Ongelezen"), saved("Bewaard"), trash("Prullenbak") }

/** Schermen boven op de tabbladen. */
sealed interface Screen {
    data class Detail(val id: String) : Screen
    data class Editor(val place: Place?, val query: String = "") : Screen
    data class Listing(val placeId: String?, val category: Category?, val scope: Scope) : Screen
    data object WhatsNew : Screen
}

@Composable
fun BekendrApp(activity: MainActivity) {
    val repo = remember { Repository.get(activity) }
    val settings by repo.settings.collectAsStateWithLifecycle()
    val places by repo.places.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var splash by remember { mutableStateOf(true) }
    var tab by rememberSaveable { mutableStateOf(Tab.home) }
    val stack = remember { mutableStateListOf<Screen>() }

    LaunchedEffect(Unit) { delay(900); splash = false }
    LaunchedEffect(settings.onboardingDone, places.size) {
        if (settings.onboardingDone) runCatching { repo.refresh() }
    }
    LaunchedEffect(activity.openNoticeId) {
        activity.openNoticeId?.let { tab = Tab.inbox; stack.add(Screen.Detail(it)); activity.openNoticeId = null }
    }
    LaunchedEffect(activity.sharedText, settings.onboardingDone) {
        val text = activity.sharedText
        if (text != null && settings.onboardingDone) { stack.add(Screen.Editor(null, text)); activity.sharedText = null }
    }

    val push: (Screen) -> Unit = { stack.add(it) }
    val pop: () -> Unit = { if (stack.isNotEmpty()) stack.removeAt(stack.lastIndex) }
    BackHandler(enabled = stack.isNotEmpty()) { pop() }

    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        when {
            !settings.onboardingDone -> Onboarding(repo, activity)
            stack.isNotEmpty() -> when (val top = stack.last()) {
                is Screen.Detail -> DetailScreen(repo, top.id, pop)
                is Screen.Editor -> EditorScreen(repo, top.place, top.query, pop)
                is Screen.Listing -> ListScreen(repo, top, push, pop)
                Screen.WhatsNew -> WhatsNewScreen(pop)
            }
            else -> Tabs(repo, activity, tab, { tab = it }, push)
        }
        if (activity.locked && settings.lock && settings.onboardingDone) LockScreen(activity)
        AnimatedVisibility(splash, enter = fadeIn(), exit = fadeOut()) { Splash() }
    }

    // Opnieuw ophalen bij terugkomst als het langer dan een kwartier geleden is.
    LaunchedEffect(activity.locked) {
        if (!activity.locked && settings.onboardingDone) scope.launch { runCatching { repo.refresh() } }
    }
}

@Composable
private fun Tabs(repo: Repository, activity: MainActivity, tab: Tab, setTab: (Tab) -> Unit, push: (Screen) -> Unit) {
    val notices by repo.notices.collectAsStateWithLifecycle()
    val marks by repo.marks.collectAsStateWithLifecycle()
    val unread = remember(notices, marks) { notices.count { repo.isUnread(it) } }
    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainer) {
                NavigationBarItem(tab == Tab.home, { setTab(Tab.home) }, { Icon(Icons.Outlined.Home, null) }, label = { Text("Jouw buurt") })
                NavigationBarItem(tab == Tab.inbox, { setTab(Tab.inbox) }, {
                    BadgedBox(badge = { if (unread > 0) Badge { Text("$unread") } }) { Icon(Icons.Outlined.Inbox, null) }
                }, label = { Text("Meldingen") })
                NavigationBarItem(tab == Tab.settings, { setTab(Tab.settings) }, { Icon(Icons.Outlined.Settings, null) }, label = { Text("Instellingen") })
            }
        },
    ) { padding ->
        Box(Modifier.padding(bottom = padding.calculateBottomPadding())) {
            when (tab) {
                Tab.home -> HomeScreen(repo, push)
                Tab.inbox -> InboxScreen(repo, push)
                Tab.settings -> SettingsScreen(repo, activity, push)
            }
        }
    }
}

@Composable
private fun Splash() {
    Box(Modifier.fillMaxSize().background(Brand.accent), contentAlignment = Alignment.Center) {
        BekendrMark(112)
    }
}

@Composable
private fun LockScreen(activity: MainActivity) {
    fun unlock() = activity.authenticate("Ontgrendel Bekendr") { ok -> if (ok) activity.locked = false }
    LaunchedEffect(Unit) { unlock() }
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
            BekendrMark(84)
            Text("Bekendr is vergrendeld", fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
            Button(onClick = { unlock() }) {
                Icon(Icons.Outlined.LockOpen, null)
                Text("  Ontgrendel")
            }
        }
    }
}
