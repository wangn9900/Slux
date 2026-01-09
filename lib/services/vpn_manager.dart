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
  static Future<bool> startVpn() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('startVpn');
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

  /// 获取 TUN 文件描述符
  static Future<int> getTunFd() async {
    if (!Platform.isAndroid) return -1;

    try {
      final result = await _channel.invokeMethod('getTunFd');
      return result as int;
    } catch (e) {
      print('Get TUN FD error: $e');
      return -1;
    }
  }
}
