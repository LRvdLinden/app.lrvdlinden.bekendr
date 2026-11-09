package app.lrvdlinden.bekendr.work

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import app.lrvdlinden.bekendr.MainActivity
import app.lrvdlinden.bekendr.R
import app.lrvdlinden.bekendr.data.Notice
import app.lrvdlinden.bekendr.data.Repository
import java.util.Calendar
import java.util.concurrent.TimeUnit

/** Kijkt elk uur op de achtergrond of er nieuwe bekendmakingen zijn. */
class RefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val repo = Repository.get(applicationContext)
        return try {
            val fresh = repo.refresh()
            Notifications.announce(applicationContext, fresh, repo)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    companion object {
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<RefreshWorker>(1, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork("bekendr-refresh", ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}

object Notifications {
    private const val CHANNEL = "nieuw"
    private const val CHANNEL_QUIET = "nieuw-stil"

    fun createChannel(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, context.getString(R.string.channel_name), NotificationManager.IMPORTANCE_DEFAULT))
        nm.createNotificationChannel(NotificationChannel(CHANNEL_QUIET, "Nieuwe bekendmakingen (stille uren)", NotificationManager.IMPORTANCE_LOW))
    }

    @SuppressLint("MissingPermission")
    fun announce(context: Context, fresh: List<Notice>, repo: Repository) {
        val s = repo.settings.value
        if (!s.notify || fresh.isEmpty()) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val quiet = s.quiet && s.quietStart != s.quietEnd &&
            (if (s.quietStart < s.quietEnd) hour in s.quietStart until s.quietEnd else hour >= s.quietStart || hour < s.quietEnd)
        val names = repo.places.value.associate { it.id to it.name }
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (fresh.size == 1) putExtra("noticeId", fresh.first().id)
        }
        val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val builder = NotificationCompat.Builder(context, if (quiet) CHANNEL_QUIET else CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setColor(0xFF2747E8.toInt())
            .setAutoCancel(true)
            .setContentIntent(pending)
        if (fresh.size == 1) {
            val n = fresh.first()
            val place = n.places.keys.firstNotNullOfOrNull { names[it] }
            builder.setContentTitle(n.category.label + (place?.let { " · $it" } ?: "")).setContentText(n.title)
                .setStyle(NotificationCompat.BigTextStyle().bigText(n.title))
        } else {
            builder.setContentTitle("${fresh.size} nieuwe bekendmakingen")
                .setContentText(fresh.first().title)
                .setStyle(NotificationCompat.InboxStyle().also { st -> fresh.take(5).forEach { st.addLine(it.title) } })
        }
        runCatching { NotificationManagerCompat.from(context).notify((System.currentTimeMillis() / 1000).toInt(), builder.build()) }
    }
}
