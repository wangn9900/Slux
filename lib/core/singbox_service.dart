import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SingboxService {
  Process? _process;

  /// Check if sing-box core exists
  Future<bool> checkCore() async {
    final path = await _getCorePath();
    return File(path).exists();
  }

  Future<String> _getCorePath() async {
    // Logic to find sing-box.exe.
    // For dev, it might be in assets or a fixed path.
    // For release, it should be in the app directory.
    if (kDebugMode) {
      return "resources/core/sing-box.exe";
    }
    final dir = await getApplicationSupportDirectory();
    return "${dir.path}/core/sing-box.exe";
  }

  Future<void> start(String configPath) async {
    final corePath = await _getCorePath();
    if (!await File(corePath).exists()) {
      throw Exception("Sing-box core not found at $corePath");
    }

    if (_process != null) {
      await stop();
    }

    debugPrint("Starting Sing-box: $corePath -c $configPath");

    _process = await Process.start(corePath, [
      'run',
      '-c',
      configPath,
      '-D',
      '.',
    ], runInShell: false);

    _process!.stdout.transform(utf8.decoder).listen((data) {
      debugPrint("[Sing-box] $data");
    });

    _process!.stderr.transform(utf8.decoder).listen((data) {
      debugPrint("[Sing-box Error] $data");
    });
  }

  Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
  }
}
