import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RemoteResourceService {
  // OSS 镜像地址（用于获取 api_config.json、version.json 和核心文件）
  static const List<String> _ossMirrors = [
    "https://oss.tianque.cc", // 主要 OSS 地址
    // 可以添加更多备用 OSS 镜像
  ];

  final Dio _dio = Dio();

  RemoteResourceService() {
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// 尝试从主从 OSS 下载文件
  /// [fileName]: 例如 "sing-box-windows.zip" 或 "geosite.db"
  /// [savePath]: 本地保存路径
  Future<bool> downloadFile(String fileName, String savePath) async {
    for (int i = 0; i < _ossMirrors.length; i++) {
      final mirror = _ossMirrors[i];
      final url = "$mirror/$fileName";

      try {
        if (kDebugMode) {
          print("Attempting download from Mirror ${i + 1}: $url");
        }

        await _dio.download(
          url,
          savePath,
          onReceiveProgress: (rec, total) {
            // distinct progress tracking could be added here
          },
        );

        if (kDebugMode) {
          print("Download successful from Mirror ${i + 1}");
        }
        return true; // 成功即返回
      } catch (e) {
        if (kDebugMode) {
          print("Failed to download from Mirror ${i + 1}: $e");
        }
        // 继续下一次循环尝试下一个镜像
        if (i == _ossMirrors.length - 1) {
          // 所有都失败了
          if (kDebugMode) {
            print("All mirrors failed for $fileName");
          }
        }
      }
    }
    return false;
  }

  /// 检查元数据或版本信息 (例如 version.json)
  Future<Map<String, dynamic>?> checkResourceMeta() async {
    for (int i = 0; i < _ossMirrors.length; i++) {
      final mirror = _ossMirrors[i];
      final url = "$mirror/version.json";

      try {
        final response = await _dio.get(url);
        if (response.statusCode == 200) {
          return response.data;
        }
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  /// Fetch dynamic API configuration from OSS
  /// This fetches 'api_config.json' which contains API URLs and Feature Flags.
  Future<Map<String, dynamic>?> fetchRemoteConfig() async {
    for (int i = 0; i < _ossMirrors.length; i++) {
      final mirror = _ossMirrors[i];
      final url = "$mirror/api_config.json";

      try {
        if (kDebugMode) print("Fetching API config from: $url");
        final response = await _dio.get(url);
        if (response.statusCode == 200) {
          if (kDebugMode) print("Got API config from Mirror ${i + 1}");
          return response.data;
        }
      } catch (e) {
        if (kDebugMode)
          print("Failed to fetch Config from Mirror ${i + 1}: $e");
        continue;
      }
    }
    return null;
  }
}
