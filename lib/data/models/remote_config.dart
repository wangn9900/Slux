class RemoteConfig {
  final List<String> apiEndpoints; // 主要 API 地址列表
  final List<String> backupEndpoints; // 备用 API 地址列表
  final String? coreVersion; // 核心版本（可选）
  final String? notice; // 公告信息（可选）

  RemoteConfig({
    required this.apiEndpoints,
    this.backupEndpoints = const [],
    this.coreVersion,
    this.notice,
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    // 兼容旧格式（单个 api_base_url）
    List<String> endpoints = [];
    if (json['api_endpoints'] != null) {
      endpoints = List<String>.from(json['api_endpoints']);
    } else if (json['api_base_url'] != null) {
      endpoints = [json['api_base_url']];
    }

    return RemoteConfig(
      apiEndpoints: endpoints,
      backupEndpoints: json['backup_endpoints'] != null
          ? List<String>.from(json['backup_endpoints'])
          : [],
      coreVersion: json['core_version'],
      notice: json['notice'],
    );
  }

  /// 获取所有可用的端点（主要 + 备用）
  List<String> getAllEndpoints() {
    return [...apiEndpoints, ...backupEndpoints];
  }
}
