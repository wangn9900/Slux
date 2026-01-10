import 'dart:io';
import 'package:flutter/services.dart';

class VpnManager {
  static const MethodChannel _channel = MethodChannel('com.slux.slux/vpn');

  /// 检查是否有 VPN 权限
  static Future<bool> checkVpnPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod('checkVpnPermission');
      return result as bool;
    } catch (e) {
      print('Check VPN permission error: $e');
      return false;
    }
  }

  /// 启动 VPN
  static Future<bool> startVpn(String config) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('startVpn', config);
      return result as bool;
    } catch (e) {
      print('Start VPN error: $e');
      return false;
    }
  }

  /// 停止 VPN
  static Future<bool> stopVpn() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('stopVpn');
      return result as bool;
    } catch (e) {
      print('Stop VPN error: $e');
      return false;
    }
  }
}
