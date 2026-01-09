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
                    startVpn(result)
                }
                "stopVpn" -> {
                    stopVpn(result)
                }
                "getTunFd" -> {
                    result.success(SluxVpnService.getTunFd())
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

    private fun startVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            // 需要请求 VPN 权限
            pendingResult = result
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            // 已有权限，直接启动
            launchVpnService()
            result.success(true)
        }
    }

    private fun stopVpn(result: MethodChannel.Result) {
        val intent = Intent(this, SluxVpnService::class.java).apply {
            action = SluxVpnService.ACTION_DISCONNECT
        }
        startService(intent)
        result.success(true)
    }

    private fun launchVpnService() {
        val intent = Intent(this, SluxVpnService::class.java).apply {
            action = SluxVpnService.ACTION_CONNECT
        }
        startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                launchVpnService()
                pendingResult?.success(true)
            } else {
                pendingResult?.error("VPN_PERMISSION_DENIED", "用户拒绝了 VPN 权限", null)
            }
            pendingResult = null
        }
    }
}
