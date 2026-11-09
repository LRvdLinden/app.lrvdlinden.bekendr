package app.lrvdlinden.bekendr

import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lrvdlinden.bekendr.data.Repository
import app.lrvdlinden.bekendr.ui.BekendrApp
import app.lrvdlinden.bekendr.ui.BekendrTheme

class MainActivity : FragmentActivity() {
    var openNoticeId by mutableStateOf<String?>(null)
    var sharedText by mutableStateOf<String?>(null)
    var locked by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val repo = Repository.get(this)
        locked = repo.settings.value.lock
        handle(intent)
        setContent {
            val settings by repo.settings.collectAsStateWithLifecycle()
            BekendrTheme(settings.appearance) {
                BekendrApp(this)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    override fun onStop() {
        super.onStop()
        if (Repository.get(this).settings.value.lock) locked = true
    }

    private fun handle(intent: Intent?) {
        intent?.getStringExtra("noticeId")?.let { openNoticeId = it }
        if (intent?.action == Intent.ACTION_SEND) {
            intent.getStringExtra(Intent.EXTRA_TEXT)?.let { text ->
                val uri = runCatching { android.net.Uri.parse(text.trim()) }.getOrNull()
                val fromLink = uri?.takeIf { it.scheme?.startsWith("http") == true }?.let {
                    listOf("q", "address", "daddr", "query").firstNotNullOfOrNull { k -> it.getQueryParameter(k) }
                }
                sharedText = (fromLink ?: text.lines().take(3).joinToString(", ")).take(140)
            }
        }
    }

    fun canUseBiometrics(): Boolean =
        BiometricManager.from(this).canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL
        ) == BiometricManager.BIOMETRIC_SUCCESS

    fun authenticate(reason: String, onResult: (Boolean) -> Unit) {
        val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onResult(true)
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) = onResult(false)
        })
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Bekendr")
            .setSubtitle(reason)
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
            .build()
        prompt.authenticate(info)
    }
}
