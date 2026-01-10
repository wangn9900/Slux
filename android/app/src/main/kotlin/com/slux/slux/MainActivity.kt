package com.slux.slux

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.slux.slux/vpn"
    private val VPN_REQUEST_CODE = 0x0F

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val config = call.arguments as? String
                    if (config != null) {
                        startVpn(config, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Config content is required", null)
                    }
                }
                "stopVpn" -> {
                    stopVpn(result)
                }
                "checkVpnPermission" -> {
                    val intent = VpnService.prepare(this)
                    result.success(intent == null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startVpn(config: String, result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            // 需要请求 VPN 权限
            pendingResult = result
            // 暂时保存 config 以便在 onActivityResult 中使用 (可以用成员变量)
            pendingConfig = config
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            // 已有权限，直接启动
            launchVpnService(config)
            result.success(true)
        }
    }

    // 临时存储 config
    private var pendingConfig: String? = null

    private fun stopVpn(result: MethodChannel.Result) {
        val intent = Intent(this, SluxVpnService::class.java).apply {
            action = SluxVpnService.ACTION_DISCONNECT
        }
        startService(intent)
        result.success(true)
    }

    private fun launchVpnService(config: String) {
        val intent = Intent(this, SluxVpnService::class.java).apply {
            action = SluxVpnService.ACTION_CONNECT
            putExtra(SluxVpnService.EXTRA_CONFIG_CONTENT, config)
        }
        // 在 Android O+ 需要 startForegroundService，但在 Service 内部我们调了 startForeground，startService 也可以
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingConfig?.let { launchVpnService(it) }
                pendingResult?.success(true)
            } else {
                pendingResult?.error("VPN_PERMISSION_DENIED", "用户拒绝了 VPN 权限", null)
            }
            pendingResult = null
            pendingConfig = null
        }
    }
}
