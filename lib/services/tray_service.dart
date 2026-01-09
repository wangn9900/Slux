import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/system_proxy_helper.dart';

class TrayService {
  SystemTray? _systemTray;
  Menu? _menu;
  final Ref ref;

  TrayService(this.ref);

  Future<void> init() async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (kDebugMode) print("Tray not supported on mobile");
      return;
    }

    _systemTray = SystemTray();
    _menu = Menu();

    String? iconPath;
    if (Platform.isWindows) {
      final candidates = [
        'app_icon.ico',
        'windows/runner/resources/app_icon.ico',
        'resources/app_icon.ico',
      ];
      for (final path in candidates) {
        if (await File(path).exists()) {
          iconPath = File(path).absolute.path;
          break;
        }
      }
    } else {
      iconPath = 'assets/app_icon.png';
    }

    if (iconPath == null) iconPath = 'app_icon.ico';

    try {
      await _systemTray!.initSystemTray(title: "Slux", iconPath: iconPath);
    } catch (e) {
      if (kDebugMode) print("Tray init failed: $e");
      return;
    }

    await _buildMenu();

    _systemTray!.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        windowManager.show();
        windowManager.focus();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray!.popUpContextMenu();
      }
    });
  }

  Future<void> _buildMenu() async {
    if (_menu == null || _systemTray == null) return;

    await _menu!.buildFrom([
      MenuItemLabel(
        label: '显示主界面',
        onClicked: (menuItem) async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '清理系统代理',
        onClicked: (menuItem) async {
          await SystemProxyHelper.clearSystemProxy();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '退出',
        onClicked: (menuItem) async {
          await SystemProxyHelper.clearSystemProxy();
          await windowManager.destroy();
        },
      ),
    ]);
    _systemTray!.setContextMenu(_menu!);
  }
}

final trayServiceProvider = Provider<TrayService>((ref) => TrayService(ref));
