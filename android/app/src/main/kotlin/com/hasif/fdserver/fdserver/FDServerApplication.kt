package com.hasif.fdserver.fdserver

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

class FDServerApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels(this)
    }

    companion object {
        const val AUTO_TRAIL_CHANNEL_ID = "auto_trail_service"
        const val VPN_CHANNEL_ID = "fdserver_vpn_channel"
        const val DEFAULT_BG_CHANNEL_ID = "my_foreground"

        fun createNotificationChannels(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

                // 1. Auto Trail Passive Location Tracking Channel
                val autoTrailChannel = NotificationChannel(
                    AUTO_TRAIL_CHANNEL_ID,
                    "Auto Trail Background Service",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Passive background location memory tracking"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(autoTrailChannel)

                // 2. Default flutter_background_service fallback channel
                val defaultBgChannel = NotificationChannel(
                    DEFAULT_BG_CHANNEL_ID,
                    "FDServer Background Service",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Background task execution channel"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(defaultBgChannel)

                // 3. Proxy VPN Diverter Tunnel Channel
                val vpnChannel = NotificationChannel(
                    VPN_CHANNEL_ID,
                    "FDServer Proxy Diverter",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Active VPN tunnel forwarding device traffic to proxy"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(vpnChannel)
            }
        }
    }
}
