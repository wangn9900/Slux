import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/system_proxy_helper.dart';

class TrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final Ref ref;

  TrayService(this.ref);

  Future<void> init() async {
    // 图标路径：默认尝试读取程序目录下�?app_icon.ico
    // 如果没有，托盘图标可能显示为空白，请确保 .ico 文件存在
    String? iconPath;
    if (Platform.isWindows) {
      final candidates = [
        'app_icon.ico', // 优先读取运行目录下的自定义图�?        'windows/runner/resources/app_icon.ico', // 开发环境默认路�?        'resources/app_icon.ico', // 可能的打包路�?      ];
      for (final path in candidates) {
        if (await File(path).exists()) {
          iconPath = File(path).absolute.path;
          break;
        }
      }
    } else {
      iconPath = 'assets/app_icon.png';
    }

    if (iconPath == null) {
      if (kDebugMode) print("Tray Icon not found in candidates.");
      // 仍然尝试初始化，可能导致异常但已捕获
      iconPath = 'app_icon.ico';
    }

    // 初始化托�?    try {
      await _systemTray.initSystemTray(title: "Slux", iconPath: iconPath);
    } catch (e) {
      if (kDebugMode) {
        print("SystemTray init failed (likely missing icon): $e");
      }
      return;
    }

    await _buildMenu();

    // 注册事件监听
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        Platform.isWindows ? windowManager.show() : windowManager.show();
        windowManager.focus();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  Future<void> _buildMenu() async {
    await _menu.buildFrom([
      MenuItemLabel(
        label: '显示 Slux',
        onClicked: (menuItem) async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuSeparator(),
      // 常用功能捷径（直接调�?Helper，不涉及 UI 状态）
      MenuItemLabel(
        label: '重置系统代理',
        onClicked: (menuItem) async {
          await SystemProxyHelper.clearSystemProxy();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '退�?,
        onClicked: (menuItem) async {
          // 退出前清理
          await SystemProxyHelper.clearSystemProxy();
          await windowManager.destroy();
        },
      ),
    ]);
    _systemTray.setContextMenu(_menu);
  }
}

final trayServiceProvider = Provider<TrayService>((ref) => TrayService(ref));
