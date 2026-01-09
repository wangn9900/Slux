package com.slux.slux

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class SluxVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    companion object {
        const val ACTION_CONNECT = "com.slux.slux.CONNECT"
        const val ACTION_DISCONNECT = "com.slux.slux.DISCONNECT"
        const val CHANNEL_ID = "SluxVpnChannel"
        private const val NOTIFICATION_ID = 1
        
        @Volatile
        private var tunFd: Int = -1
        
        fun getTunFd(): Int = tunFd
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                if (!isRunning) {
                    startVpn()
                }
            }
            ACTION_DISCONNECT -> {
                stopVpn()
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startVpn() {
        // 创建通知渠道
        createNotificationChannel()

        // 启动前台服务
        startForeground(NOTIFICATION_ID, createNotification())

        // 建立 VPN 连接
        val builder = Builder()
            .setSession("Slux VPN")
            .addAddress("10.0.0.2", 24)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
            .setMtu(1500)
            .setBlocking(false)

        try {
            vpnInterface = builder.establish()
            vpnInterface?.let {
                tunFd = it.fd
                isRunning = true
                
                // 通知 Flutter 层 VPN 已启动
                notifyFlutter("vpn_started", tunFd)
            } ?: run {
                notifyFlutter("vpn_failed", -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            notifyFlutter("vpn_failed", -1)
        }
    }

    private fun stopVpn() {
        isRunning = false
        tunFd = -1
        
        vpnInterface?.close()
        vpnInterface = null
        
        notifyFlutter("vpn_stopped", 0)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Slux VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Slux VPN 连接状态"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Slux VPN")
            .setContentText("VPN 连接已激活")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun notifyFlutter(event: String, data: Int) {
        // 这里需要通过 MethodChannel 通知 Flutter
        // 实际实现需要在 MainActivity 中设置
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
