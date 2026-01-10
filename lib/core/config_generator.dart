import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models/proxy_node.dart';

class ConfigGenerator {
  static String generate(
    List<ProxyNode> nodes, {
    int localPort = 20808,
    String? selectedNodeTag,
  }) {
    final Map<String, dynamic> config = {
      "log": {"level": kDebugMode ? "debug" : "info", "timestamp": true},
      "dns": {
        "servers": [
          {
            "type": "https",
            "tag": "dns_google",
            "server": "dns.google",
            "server_port": 443,
            "detour": "proxy"
          },
          {
            "type": "https",
            "tag": "dns_cloudflare",
            "server": "cloudflare-dns.com",
            "server_port": 443,
            "detour": "proxy"
          },
          {
            "type": "udp",
            "tag": "dns_local",
            "server": "223.5.5.5",
            "server_port": 53,
            "detour": "direct"
          },
        ],
        "rules": [
          {"outbound": "any", "server": "dns_local"},
          {
            "query_type": ["A", "AAAA"],
            "server": "dns_google",
          },
        ],
      },
      "inbounds": [
        {
          "type": "mixed",
          "tag": "mixed-in",
          "listen": "127.0.0.1",
          "listen_port": localPort,
          "sniff": true,
          "set_system_proxy": true,
        },
      ],
      "outbounds": _buildOutbounds(nodes, selectedNodeTag),
      "route": {
        "rules": [
          {"protocol": "dns", "outbound": "dns-out"},
          // Payment & Direct domains
          {
            "domain_suffix": [
              "niupay.club",
              "niupay.com",
              "alipay.com",
              "alipayobjects.com",
              "qq.com",
              "weixin.com",
              "wechat.com",
              "tenpay.com",
              "unionpay.com",
              "95516.com",
              "boc.cn",
              "icbc.com.cn",
              "cmbchina.com",
              "ccb.com",
            ],
            "outbound": "direct",
          },
          // 移除 clash_mode 路由规则，它们在 Sing-box 1.12+ 已废弃
          // 客户端的模式切换通常由 Selector 里的 'Global'/'Direct' 选项接管，
          // 或者通过修改 config.json 实现。
          // 这里我们保持最简配置，流量默认走 'proxy' selector。
        ],
        "auto_detect_interface": true,
        "final": "proxy", // 默认所有流量走 proxy selector
      },
      "experimental": {
        "clash_api": {"external_controller": "127.0.0.1:9090"},
      },
    };

    if (kDebugMode) {
      print('Config generated with localPort: $localPort');
    }
    return jsonEncode(config);
  }

  static List<Map<String, dynamic>> _buildOutbounds(
    List<ProxyNode> nodes,
    String? selectedTag,
  ) {
    final outbounds = <Map<String, dynamic>>[];

    // 1. Selector
    // 2. Nodes
    // 3. Direct/Block/Dns

    final nodeTags = nodes.map((n) => n.name).toList();

    // 如果有选中的节点，让它排在第一个（默认选中）
    final selectorOutbounds = ["auto", ...nodeTags];
    String defaultTag = "auto";

    if (selectedTag != null && nodeTags.contains(selectedTag)) {
      defaultTag = selectedTag;
    }

    // Selector
    outbounds.add({
      "type": "selector",
      "tag": "proxy",
      "outbounds": selectorOutbounds,
      "default": defaultTag,
    });

    // URL Test (Auto)
    outbounds.add({
      "type": "urltest",
      "tag": "auto",
      "outbounds": nodeTags,
      "url": "http://www.gstatic.com/generate_204",
      "interval": "10m",
    });

    // Add actual nodes
    for (var node in nodes) {
      outbounds.add(_convertNode(node));
    }

    // Default outbounds
    outbounds.add({"type": "direct", "tag": "direct"});
    outbounds.add({"type": "block", "tag": "block"});
    outbounds.add({"type": "dns", "tag": "dns-out"});

    return outbounds;
  }

  static Map<String, dynamic> _convertNode(ProxyNode node) {
    final base = <String, dynamic>{
      "tag": node.name,
      "server": node.server,
      "server_port": node.port,
    };

    if (node.type == 'vmess') {
      base['type'] = 'vmess';
      base['uuid'] = node.uuid;
      base['alter_id'] = node.alterId;
      base['security'] = node.cipher.isEmpty ? 'auto' : node.cipher;
    } else if (node.type == 'vless') {
      base['type'] = 'vless';
      base['uuid'] = node.uuid;
      if (node.tls['flow'] != null) {
        base['flow'] = node.tls['flow'];
      }
    } else if (node.type == 'shadowsocks') {
      base['type'] = 'shadowsocks';
      base['password'] = node.uuid;
      base['method'] = node.cipher;
    } else if (node.type == 'trojan') {
      base['type'] = 'trojan';
      base['password'] = node.uuid;
    } else {
      base['type'] = node.type;
      // Fallback for others
    }

    // TLS Configuration
    if (node.tls['enabled'] == true) {
      final tlsConfig = <String, dynamic>{
        "enabled": true,
        "server_name": node.tls['server_name'] ?? node.server,
        "insecure": node.tls['insecure'] ?? false,
      };

      // Reality
      if (node.tls['reality'] != null) {
        final reality = node.tls['reality'] as Map;
        tlsConfig['reality'] = {
          "enabled": true,
          "public_key": reality['public_key'],
          "short_id": reality['short_id'] ?? '',
        };
        // Reality uses utls usually
        tlsConfig['utls'] = {"enabled": true, "fingerprint": "chrome"};
      } else {
        // Even for normal TLS, use utls to avoid fingerprinting
        tlsConfig['utls'] = {"enabled": true, "fingerprint": "chrome"};
      }

      base['tls'] = tlsConfig;
    }

    // Transport Configuration
    if (node.network == 'ws' || node.network == 'websocket') {
      base['transport'] = {
        "type": "ws",
        "path": node.tls['path'] ?? '/',
        "headers": node.tls['headers'] ??
            {"Host": node.tls['server_name'] ?? node.server},
      };
    } else if (node.network == 'grpc') {
      base['transport'] = {
        "type": "grpc",
        "service_name": node.tls['service_name'] ?? 'grpc',
      };
    }

    return base;
  }
}
