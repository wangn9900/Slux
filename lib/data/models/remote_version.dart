class RemoteVersion {
  final String version;
  final String minAppVersion;
  final String updateMessage;
  final List<RemoteFile> files;

  RemoteVersion({
    required this.version,
    required this.minAppVersion,
    required this.updateMessage,
    required this.files,
  });

  factory RemoteVersion.fromJson(Map<String, dynamic> json) {
    return RemoteVersion(
      version: json['version'] ?? '0.0.0',
      minAppVersion: json['min_app_version'] ?? '0.0.0',
      updateMessage: json['update_message'] ?? '',
      files:
          (json['files'] as List?)
              ?.map((e) => RemoteFile.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class RemoteFile {
  final String name;
  final String path;
  final String hash;
  final String type; // core, asset, app
  final String? platform; // windows, macos, android, ios

  RemoteFile({
    required this.name,
    required this.path,
    required this.hash,
    required this.type,
    this.platform,
  });

  factory RemoteFile.fromJson(Map<String, dynamic> json) {
    return RemoteFile(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      hash: json['hash'] ?? '',
      type: json['type'] ?? 'asset',
      platform: json['platform'],
    );
  }
}
