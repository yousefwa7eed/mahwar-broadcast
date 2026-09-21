package com.example.mahwar

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

/**
 * Creates the single high-importance notification channel used by every push.
 * Runs on process start (any component, including FCM delivery from a killed
 * app), so a fresh install is enough — no runtime Dart code required.
 */
class MahwarApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Mahwar",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { enableVibration(true) }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    companion object {
        const val CHANNEL_ID = "mahwar_alerts"
    }
}