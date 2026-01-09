import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models/proxy_node.dart';

class SubscribeParser {
  /// 解析订阅内容
  static List<ProxyNode> parse(String content) {
    if (content.isEmpty) return [];

    // 1. 尝试解析 Sing-box JSON (防止后端返回了 JSON)
    try {
      final json = jsonDecode(content);
      if (json is Map && json['outbounds'] != null) {
        return _parseSingboxJson(json.cast<String, dynamic>());
      }
    } catch (_) {}

    // 2. 尝试 Base64 解码 (通用格式)
    String decoded;
    try {
      decoded = utf8.decode(base64.decode(content));
    } catch (_) {
      try {
        // 尝试补全填充
        String padding = '=' * ((4 - content.length % 4) % 4);
        decoded = utf8.decode(base64.decode(content + padding));
      } catch (e) {
        // 如果不是 Base64，假设是明文列表
        decoded = content;
      }
    }

    // 3. 按行解析链接
    return _parseLinks(decoded);
  }

  static List<ProxyNode> _parseSingboxJson(Map<String, dynamic> json) {
    final List<ProxyNode> nodes = [];
    final outbounds = json['outbounds'] as List;
    for (var outbound in outbounds) {
      if (_isValidType(outbound['type'])) {
        try {
          nodes.add(ProxyNode.fromJson(outbound));
        } catch (e) {
          if (kDebugMode) print('Parse singbox node error: $e');
        }
      }
    }
    return nodes;
  }

  static List<ProxyNode> _parseLinks(String content) {
    final List<ProxyNode> nodes = [];
    final lines = LineSplitter.split(
      content,
    ).map((l) => l.trim()).where((l) => l.isNotEmpty);

    for (var line in lines) {
      try {
        if (line.startsWith('vmess://')) {
          nodes.add(_parseVmess(line));
        } else if (line.startsWith('vless://')) {
          nodes.add(_parseVless(line));
        } else if (line.startsWith('trojan://')) {
          nodes.add(_parseTrojan(line));
        } else if (line.startsWith('ss://')) {
          nodes.add(_parseShadowsocks(line));
        }
      } catch (e) {
        if (kDebugMode) print('Parse link error ($line): $e');
      }
    }
    return nodes;
  }

  static ProxyNode _parseVmess(String link) {
    final base64Str = link.substring(8);
    String jsonStr;
    try {
      jsonStr = utf8.decode(base64.decode(base64Str));
    } catch (_) {
      jsonStr = utf8.decode(
        base64.decode(base64Str + '=' * ((4 - base64Str.length % 4) % 4)),
      );
    }
    final json = jsonDecode(jsonStr);

    return ProxyNode(
      name: json['ps'] ?? 'Unknown',
      type: 'vmess',
      server: json['add'],
      port: int.parse(json['port'].toString()),
      uuid: json['id'],
      alterId: int.tryParse(json['aid'].toString()) ?? 0,
      network: json['net'] ?? 'tcp',
      tls: {
        'enabled': json['tls'] == 'tls',
        'server_name': json['sni'] ?? '',
        'insecure': true,
      }, // 简化的 TLS 配置
    );
  }

  static ProxyNode _parseVless(String link) {
    // vless://uuid@host:port?params#name
    final uri = Uri.parse(link);
    final params = uri.queryParameters;

    return ProxyNode(
      name: Uri.decodeComponent(uri.fragment),
      type: 'vless',
      server: uri.host,
      port: uri.port,
      uuid: uri.userInfo,
      network: params['type'] ?? 'tcp',
      tls: {
        'enabled':
            params['security'] == 'tls' || params['security'] == 'reality',
        'server_name': params['sni'] ?? '',
        'insecure': true,
        'flow': params['flow'],
        'reality': params['security'] == 'reality'
            ? {'public_key': params['pbk'], 'short_id': params['sid']}
            : null,
      },
    );
  }

  static ProxyNode _parseTrojan(String link) {
    // trojan://password@host:port?params#name
    final uri = Uri.parse(link);
    final params = uri.queryParameters;

    return ProxyNode(
      name: Uri.decodeComponent(uri.fragment),
      type: 'trojan',
      server: uri.host,
      port: uri.port,
      uuid: uri.userInfo, // password
      network: params['type'] ?? 'tcp',
      tls: {
        'enabled': true, // Trojan always TLS
        'server_name': params['sni'] ?? '',
        'insecure': params['allowInsecure'] == '1',
      },
    );
  }

  static ProxyNode _parseShadowsocks(String link) {
    // ss://base64(method:password)@host:port#name
    // OR ss://base64(method:password@host:port)#name
    // Simplified handling usually needed here
    final uri = Uri.parse(link);

    // Check if user info is base64 encoded
    String userInfo = uri.userInfo;
    if (!userInfo.contains(':')) {
      try {
        userInfo = utf8.decode(base64.decode(userInfo));
      } catch (_) {
        try {
          // 尝试补全 padding
          final padding = '=' * ((4 - userInfo.length % 4) % 4);
          userInfo = utf8.decode(base64.decode(userInfo + padding));
        } catch (e) {
          if (kDebugMode) print('SS decode error: $e');
        }
      }
    }

    final parts = userInfo.split(':');
    final method = parts[0];
    final password = parts.length > 1 ? parts.sublist(1).join(':') : '';

    return ProxyNode(
      name: Uri.decodeComponent(uri.fragment),
      type: 'shadowsocks',
      server: uri.host,
      port: uri.port,
      cipher: method,
      uuid:
          password, // Store password in uuid field for internal consistency or add password field
    );
  }

  static bool _isValidType(String? type) {
    return [
      'vless',
      'vmess',
      'trojan',
      'shadowsocks',
      'hysteria',
      'hysteria2',
    ].contains(type);
  }
}
