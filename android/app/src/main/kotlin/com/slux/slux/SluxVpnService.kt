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

// Import Gomobile generated classes
// 注意：如果编译时找不到这些类，说明 AAR 生成失败或路径不对
import libbox.Libbox
import libbox.PlatformInterface
import libbox.Service
import libbox.TunOptions
import mobile.Mobile

class SluxVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var boxService: Service? = null
    private var isRunning = false

    companion object {
        const val ACTION_CONNECT = "com.slux.slux.CONNECT"
        const val ACTION_DISCONNECT = "com.slux.slux.DISCONNECT"
        const val EXTRA_CONFIG_CONTENT = "EXTRA_CONFIG_CONTENT" // Config string
        
        const val CHANNEL_ID = "SluxVpnChannel"
        private const val NOTIFICATION_ID = 1
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG_CONTENT)
                if (config != null && !isRunning) {
                    startBoxService(config)
                }
            }
            ACTION_DISCONNECT -> {
                stopBoxService()
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startBoxService(config: String) {
        // 创建通知并启动前台服务
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())

        try {
            if (boxService != null) {
                boxService?.close()
            }
            
            // 使用 Mobile.newService 创建实例
            // 这里的 PlatformImpl 是内部类，实现了 libbox.PlatformInterface
            boxService = Mobile.newService(config, PlatformImpl())
            
            // 启动
            boxService?.start()
            
            isRunning = true
            
        } catch (e: Exception) {
            e.printStackTrace()
            stopBoxService()
        }
    }

    private fun stopBoxService() {
        try {
            boxService?.close()
            boxService = null
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        isRunning = false
        stopForeground(true)
    }

    // 实现 Sing-box 的 Platform 接口
    // Sing-box 会回调这些方法来请求 TUN 接口
    private inner class PlatformImpl : PlatformInterface {
        override fun openTun(options: TunOptions): Int {
            val builder = Builder()
                .setSession("Slux VPN")
                .setMtu(options.mtu)
                .setBlocking(false) // 重要：非阻塞模式

            // Setup Routes
            // 这里为了简化，我们暂时把 Android 的流量全导进去，如果不全导，需要解析 options 之类的
            // Sing-box 1.12 通常会自动处理 Address 和 Route
            // 但如果 options 里有，我们应该用 options 的
            
            // 简单起见，配置默认路由 (0.0.0.0/0)
            // 更好的做法是读取 options.inet4Address 等
            builder.addAddress("172.19.0.1", 30)
            builder.addRoute("0.0.0.0", 0)
            
            // 如果是 ipv6
            // builder.addAddress("fdfe:dcba:9876::1", 126)
            // builder.addRoute("::", 0)

            builder.addDnsServer("1.1.1.1") // 也可以用 options.dnsServer

            // 建立连接
            val pfd = builder.establish() ?: throw Exception("Failed to establish VPN")
            vpnInterface = pfd
            
            return pfd.fd
        }
        
        override fun writeLog(message: String?) {
            println("[Libbox] $message")
        }

        override fun autoDetectInterfaceControl(fd: Int) {
            // Android 这里的保护通常由 VpnService 自动处理，或者需要在这里调用 protect(fd)
            // 如果 sing-box 打开了 socket，这里会被回调
            protect(fd)
        }

        override fun usePlatformAutoDetectInterfaceControl(): Boolean {
            return true // 告诉 sing-box 使用 AutoDetectInterfaceControl 来保护 socket
        }

        // 其他接口方法 (根据 Gomobile 生成的 Interface 可能需要实现)
        override fun useProcFS(): Boolean = false
        override fun findConnectionOwner(ipProtocol: Int, srcAddress: String?, srcPort: Int, destAddress: String?, destPort: Int): Int = 0
        override fun packageNameByUid(uid: Int): String = ""
        override fun uidByPackageName(packageName: String?): Int = 0
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Slux VPN", NotificationManager.IMPORTANCE_LOW)
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Slux VPN")
            .setContentText("Connected")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .build()
    }
    
    override fun onDestroy() {
        stopBoxService()
        super.onDestroy()
    }
}
