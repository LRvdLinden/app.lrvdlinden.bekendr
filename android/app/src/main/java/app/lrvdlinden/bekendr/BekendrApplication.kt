package app.lrvdlinden.bekendr

import android.app.Application
import app.lrvdlinden.bekendr.work.Notifications
import app.lrvdlinden.bekendr.work.RefreshWorker
import org.osmdroid.config.Configuration

class BekendrApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Configuration.getInstance().userAgentValue = "Bekendr-Android/1.0 (app.lrvdlinden.bekendr)"
        Configuration.getInstance().osmdroidBasePath = cacheDir
        Configuration.getInstance().osmdroidTileCache = cacheDir.resolve("tiles")
        Notifications.createChannel(this)
        RefreshWorker.schedule(this)
    }
}
