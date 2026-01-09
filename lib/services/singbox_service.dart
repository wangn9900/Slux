import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/ffi/libbox.dart'; // Import FFI bindings
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
        environment: {'ENABLE_DEPRECATED_SPECIAL_OUTBOUNDS': 'true'},
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

// 3. Mobile 实现 (FFI)
class MobileSingboxService implements ISingboxService {
  bool _isRunning = false;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<bool> get isCoreInstalled async {
    // 移动端核心集成在 App 中 (libbox.so)，不需要检查“安装”
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
      print("Starting Sing-box (Mobile FFI with VPN)...");
    }

    // Android 需要先启动 VPN Service
    if (Platform.isAndroid) {
      // 检查权限
      final hasPermission = await VpnManager.checkVpnPermission();
      if (!hasPermission) {
        // 请求权限并启动 VPN
        final started = await VpnManager.startVpn();
        if (!started) {
          throw Exception("Failed to start VPN service");
        }
      } else {
        // 已有权限，直接启动
        await VpnManager.startVpn();
      }

      // 等待 VPN 建立
      await Future.delayed(const Duration(milliseconds: 500));

      // 获取 TUN FD
      final tunFd = await VpnManager.getTunFd();
      if (tunFd < 0) {
        throw Exception("Failed to get TUN file descriptor");
      }

      if (kDebugMode) {
        print("VPN started, TUN FD: $tunFd");
      }
    }

    // 调用 FFI 启动 Sing-box
    final error = LibBox.start(content);
    if (error != null) {
      throw Exception("Failed to start libbox: $error");
    }

    _isRunning = true;
  }

  @override
  Future<void> stop() async {
    LibBox.stop();
    _isRunning = false;
  }
}
