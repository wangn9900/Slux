import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle; // for asset extraction

import '../../core/remote_resource_service.dart';
import '../models/remote_version.dart';
import '../../providers/resource_provider.dart';

// State to track update progress
class UpdateState {
  final bool isChecking;
  final bool isUpdating;
  final double progress;
  final String statusMessage;
  final String? version;

  const UpdateState({
    this.isChecking = false,
    this.isUpdating = false,
    this.progress = 0.0,
    this.statusMessage = '',
    this.version,
  });
}

class CoreManager extends StateNotifier<UpdateState> {
  final Ref ref;

  CoreManager(this.ref) : super(const UpdateState());

  // ------------------------------------------------------------
  // 1️⃣ 内置核心提取：如果本地没有 core/ 目录或缺少 exe，则从 assets 中复制。
  // ------------------------------------------------------------
  Future<void> _installBuiltInCoreIfMissing() async {
    final appDir = await getApplicationSupportDirectory();
    final coreDir = Directory(p.join(appDir.path, 'core'));
    if (!await coreDir.exists()) {
      await coreDir.create(recursive: true);
    }
    final exePath = p.join(
      coreDir.path,
      Platform.isWindows ? 'sing-box.exe' : 'sing-box',
    );
    if (await File(exePath).exists()) {
      // 已经有核心，无需提取
      return;
    }
    // 读取 assets/core/ 中的对应文件
    final assetPath = Platform.isWindows
        ? 'assets/core/sing-box.exe'
        : 'assets/core/sing-box';
    try {
      final bytes = await rootBundle.load(assetPath);
      await File(exePath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!Platform.isWindows) {
        // 给可执行权限
        await Process.run('chmod', ['+x', exePath]);
      }
    } catch (e) {
      if (kDebugMode) print('Failed to extract built‑in core: $e');
      // 继续让后面的 OSS 下载逻辑处理
    }
  }

  Future<void> checkAndDownload() async {
    state = const UpdateState(
      isChecking: true,
      statusMessage: 'Checking for updates...',
    );

    // 先确保内置核心已经就位（如果缺失）
    await _installBuiltInCoreIfMissing();

    final resourceService = ref.read(remoteResourceProvider);
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getString('core_version') ?? '0.0.0';

    try {
      // 1. Fetch Remote Config (API URL)
      final remoteConfigMap = await resourceService.fetchRemoteConfig();

      // Feature Flag: Remote Kill Switch for Updates
      // 如果获取到了配置，且 enable_core_update 为 false，则直接静默退出
      if (remoteConfigMap != null) {
        if (remoteConfigMap['enable_core_update'] == false) {
          if (kDebugMode) print('Core updates are disabled by remote config.');
          state = const UpdateState(statusMessage: ''); // Clear message
          return;
        }

        final newApiUrl = remoteConfigMap['api_base_url'];
        if (newApiUrl != null && newApiUrl.toString().isNotEmpty) {
          await prefs.setString('api_base_url', newApiUrl);
        }
      } else {
        // 如果连 api_config.json 都获取不到（网络错误或未配置），
        // 为了不报“红色错误”干扰用户，这里选择静默放弃本次检查。
        if (kDebugMode)
          print('Failed to fetch api_config.json, skipping update check.');
        state = const UpdateState(statusMessage: '');
        return;
      }

      // 2. Fetch version.json for Core/Assets
      final metaMap = await resourceService.checkResourceMeta();
      if (metaMap == null) {
        // 同理，如果 version.json 获取失败，也静默处理，除非我们真的想让用户知道网络有问题
        // 但用户现在的诉求是不报错。
        if (kDebugMode)
          print('Failed to fetch version.json, skipping update check.');
        state = const UpdateState(statusMessage: '');
        return;
      }

      final remoteConfig = RemoteVersion.fromJson(metaMap);

      if (_needUpdate(currentVersion, remoteConfig.version)) {
        state = UpdateState(
          isChecking: false,
          isUpdating: true,
          statusMessage:
              'Update found: v${remoteConfig.version}. Downloading...',
          version: remoteConfig.version,
        );
        await _performUpdate(remoteConfig);
      } else {
        // 版本相同，但仍然检查核心是否真的存在
        await _checkMissingCore(remoteConfig);
        state = UpdateState(
          statusMessage: 'Core is up to date (v$currentVersion)',
        );
      }
    } catch (e) {
      if (kDebugMode) print('Update Check Error: $e');
      state = UpdateState(statusMessage: 'Error checking updates: $e');
    }
  }

  bool _needUpdate(String current, String remote) => current != remote;

  Future<void> _checkMissingCore(RemoteVersion config) async {
    final appDir = await getApplicationSupportDirectory();
    final exePath = p.join(
      appDir.path,
      'core',
      Platform.isWindows ? 'sing-box.exe' : 'sing-box',
    );
    if (!await File(exePath).exists()) {
      state = UpdateState(
        isUpdating: true,
        statusMessage: 'Core missing. Downloading...',
      );
      await _performUpdate(config);
    }
  }

  // ------------------------------------------------------------
  // 3️⃣ 远程下载 & 解压（保留之前的实现）
  // ------------------------------------------------------------
  Future<void> _performUpdate(RemoteVersion config) async {
    final resourceService = ref.read(remoteResourceProvider);
    final appDir = await getApplicationSupportDirectory();
    final coreDir = Directory(p.join(appDir.path, 'core'));
    if (!await coreDir.exists()) await coreDir.create(recursive: true);

    int totalFiles = config.files.length;
    int completed = 0;
    String currentPlatform = _getCurrentPlatform();

    for (var file in config.files) {
      if (file.platform != null &&
          file.platform != 'all' &&
          file.platform != currentPlatform)
        continue;

      state = UpdateState(
        isUpdating: true,
        progress: completed / totalFiles,
        statusMessage: 'Downloading ${file.name}...',
      );
      final tempPath = p.join(coreDir.path, file.name);
      final success = await resourceService.downloadFile(file.path, tempPath);
      if (!success) {
        state = UpdateState(statusMessage: 'Failed to download ${file.name}');
        return;
      }

      if (file.name.toLowerCase().endsWith('.zip')) {
        state = UpdateState(
          isUpdating: true,
          statusMessage: 'Extracting ${file.name}...',
        );
        try {
          await _extractZip(tempPath, coreDir.path);
          await File(tempPath).delete();
        } catch (e) {
          if (kDebugMode) print('Extract error: $e');
          state = UpdateState(statusMessage: 'Extraction failed: $e');
          return;
        }
      }
      completed++;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('core_version', config.version);
    state = UpdateState(
      isUpdating: false,
      progress: 1.0,
      statusMessage: 'Update Complete: v${config.version}',
      version: config.version,
    );
  }

  String _getCurrentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  Future<void> _extractZip(String zipPath, String destPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final name = p.basename(filename);
        if (name.toLowerCase() == 'sing-box.exe' ||
            name.toLowerCase() == 'sing-box-windows-amd64.exe' ||
            name.toLowerCase() == 'sing-box' ||
            name.toLowerCase() == 'wintun.dll' ||
            name.toLowerCase().endsWith('.db')) {
          String finalName = name;
          if (name.toLowerCase().startsWith('sing-box')) {
            finalName = Platform.isWindows ? 'sing-box.exe' : 'sing-box';
          }
          final data = file.content as List<int>;
          File(p.join(destPath, finalName))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
          if (!Platform.isWindows && finalName == 'sing-box') {
            await Process.run('chmod', ['+x', p.join(destPath, finalName)]);
          }
        }
      }
    }
  }
}

final coreManagerProvider = StateNotifierProvider<CoreManager, UpdateState>(
  (ref) => CoreManager(ref),
);
