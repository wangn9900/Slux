import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'vpn_manager.dart'; // Import VPN manager

// 1. 定义接口
abstract class ISingboxService {
  bool get isRunning;
  Future<void> start(String configPath);
  Future<void> stop();
  Future<bool> get isCoreInstalled;
}

// 2. Desktop 实现 (原 SingboxService)
class DesktopSingboxService implements ISingboxService {
  Process? _process;
  bool _isRunning = false;

  @override
  bool get isRunning => _isRunning;

  // 获取 sing-box 可执行文件路径
  Future<String> get _executablePath async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'core', 'sing-box.exe');
  }

  // Check if core exists
  @override
  Future<bool> get isCoreInstalled async {
    final path = await _executablePath;
    return File(path).exists();
  }

  @override
  Future<void> start(String configPath) async {
    if (_isRunning) {
      await stop();
    }

    // 强制清理可能残留的旧进程
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe']);
      } catch (e) {
        // 忽略错误
      }
    }

    final exePath = await _executablePath;
    if (!await File(exePath).exists()) {
      throw Exception("Sing-box core not found at $exePath");
    }

    try {
      if (kDebugMode) {
        print("Starting Sing-box (Desktop): $exePath run -c $configPath");
      }

      _process = await Process.start(
        exePath,
        ['run', '-c', configPath],
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      _isRunning = true;

      _process!.stdout.transform(utf8.decoder).listen((data) {
        if (kDebugMode) print("[SingBox] $data");
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        if (kDebugMode) print("[SingBox Error] $data");
      });

      _process!.exitCode.then((code) {
        if (kDebugMode) print("Sing-box exited with code $code");
        _isRunning = false;
        _process = null;
      });
    } catch (e) {
      _isRunning = false;
      throw Exception("Failed to start Sing-box: $e");
    }
  }

  @override
  Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      await Future.delayed(const Duration(milliseconds: 500));
      _process = null;
    }
    _isRunning = false;
  }
}

// 3. Mobile 实现 (MethodChannel -> Android Service)
class MobileSingboxService implements ISingboxService {
  bool _isRunning = false;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<bool> get isCoreInstalled async {
    // 移动端核心集成在 App 中，不需要检查“安装”
    return true;
  }

  @override
  Future<void> start(String configPath) async {
    if (_isRunning) return;

    // 读取配置文件内容
    final file = File(configPath);
    if (!await file.exists()) {
      throw Exception("Config file not found: $configPath");
    }
    final content = await file.readAsString();

    if (kDebugMode) {
      print("Starting Sing-box (Mobile Gomobile)...");
    }

    // Android: 直接调用 VPN Service 启动 (传递配置内容)
    if (Platform.isAndroid) {
      final hasPermission = await VpnManager.checkVpnPermission();
      if (!hasPermission) {
        // 请求权限并启动 (如果用户同意，Android 层应该会自动启动，但为了保险，可以在回调里再调一次，或者这里直接调)
        // 实际上，我们的 startVpn 实现中包含了权限请求逻辑
        final started = await VpnManager.startVpn(content);
        if (!started) {
          throw Exception(
              "Failed to start VPN service (permission denied or error)");
        }
      } else {
        // 已有权限，直接启动
        final started = await VpnManager.startVpn(content);
        if (!started) {
          throw Exception("Failed to start VPN service");
        }
      }
    } else {
      // iOS 未实现
      // TODO: iOS implementation using NetworkExtension
      throw UnimplementedError("iOS support not yet migrated to Gomobile");
    }

    _isRunning = true;
  }

  @override
  Future<void> stop() async {
    _isRunning = false;

    // Android 需要停止 VPN Service
    if (Platform.isAndroid) {
      await VpnManager.stopVpn();
    }
  }
}
