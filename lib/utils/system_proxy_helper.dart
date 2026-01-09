import 'dart:io';
import 'package:flutter/foundation.dart';

class SystemProxyHelper {
  /// 设置系统代理
  static Future<bool> setSystemProxy({
    required String host,
    required int port,
    bool enable = true,
  }) async {
    if (Platform.isWindows) {
      return await _setWindowsProxy(host, port, enable);
    } else if (Platform.isAndroid) {
      // Android 不支持编程方式设置系统代理（需要 Root 或手动设置）
      if (kDebugMode) {
        print('Android 系统代理需要用户手动设置: $host:$port');
      }
      return false;
    }
    return false;
  }

  /// Windows 系统代理设置
  static Future<bool> _setWindowsProxy(
    String host,
    int port,
    bool enable,
  ) async {
    try {
      if (enable) {
        // 启用代理
        await Process.run('reg', [
          'add',
          'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '1',
          '/f',
        ]);

        await Process.run('reg', [
          'add',
          'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
          '/v',
          'ProxyServer',
          '/d',
          '$host:$port',
          '/f',
        ]);

        if (kDebugMode) {
          print('Windows 系统代理已设置: $host:$port');
        }
      } else {
        // 禁用代理
        await Process.run('reg', [
          'add',
          'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '0',
          '/f',
        ]);

        if (kDebugMode) {
          print('Windows 系统代理已禁用');
        }
      }

      // 刷新系统设置
      await _refreshWindowsProxy();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('设置 Windows 系统代理失败: $e');
      }
      return false;
    }
  }

  /// 刷新 Windows 代理设置
  static Future<void> _refreshWindowsProxy() async {
    try {
      // 通知系统刷新 Internet 设置
      await Process.run('netsh', ['winhttp', 'import', 'proxy', 'source=ie']);
    } catch (e) {
      if (kDebugMode) {
        print('刷新 Windows 代理设置失败: $e');
      }
    }
  }

  /// 清除系统代理
  static Future<bool> clearSystemProxy() async {
    return await setSystemProxy(host: '', port: 0, enable: false);
  }

  /// 获取当前系统代理状态
  static Future<Map<String, dynamic>> getProxyStatus() async {
    if (Platform.isWindows) {
      return await _getWindowsProxyStatus();
    }
    return {'enabled': false};
  }

  static Future<Map<String, dynamic>> _getWindowsProxyStatus() async {
    try {
      final enableResult = await Process.run('reg', [
        'query',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyEnable',
      ]);

      final serverResult = await Process.run('reg', [
        'query',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyServer',
      ]);

      final enabledMatch = RegExp(
        r'ProxyEnable\s+REG_DWORD\s+0x(\d+)',
      ).firstMatch(enableResult.stdout.toString());
      final serverMatch = RegExp(
        r'ProxyServer\s+REG_SZ\s+(.+)',
      ).firstMatch(serverResult.stdout.toString());

      final enabled = enabledMatch != null && enabledMatch.group(1) == '1';
      final server = serverMatch?.group(1)?.trim() ?? '';

      return {'enabled': enabled, 'server': server};
    } catch (e) {
      if (kDebugMode) {
        print('获取 Windows 代理状态失败: $e');
      }
      return {'enabled': false};
    }
  }
}
