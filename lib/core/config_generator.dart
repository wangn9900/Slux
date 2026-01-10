import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/models/proxy_node.dart';

class ConfigGenerator {
  static String generate(
    List<ProxyNode> nodes, {
    int localPort = 20808,
    String? selectedNodeTag,
    bool blockAds = false, // 实验性广告拦截功能
  }) {
    final Map<String, dynamic> config = {
      "log": {"level": kDebugMode ? "debug" : "info", "timestamp": true},
      "dns": {
        "servers": [
          {
            "tag": "dns_google",
            if (Platform.isWindows) "type": "https",
            if (Platform.isWindows) "server": "8.8.8.8",
            if (!Platform.isWindows) "address": "https://dns.google/dns-query",
            if (!Platform.isWindows) "address_resolver": "dns_local",
            "detour": "proxy"
          },
          {
            "tag": "dns_cloudflare",
            if (Platform.isWindows) "type": "https",
            if (Platform.isWindows) "server": "1.1.1.1",
            if (!Platform.isWindows)
              "address": "https://cloudflare-dns.com/dns-query",
            if (!Platform.isWindows) "address_resolver": "dns_local",
            "detour": "proxy"
          },
          {"tag": "dns_local", "type": "local"},
        ],
        "rules": [
          // 解析代理服务器地址用本地 DNS（防止循环）
          {"outbound": "any", "server": "dns_local"},
          // 中国域名用本地 DNS（快速解析）
          {"rule_set": "geosite-cn", "server": "dns_local"},
          // 其他域名用加密 DNS（走代理，防泄露）
          {
            "query_type": ["A", "AAAA"],
            "server": "dns_google"
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
      "route": _buildRoute(blockAds),
      "experimental": {
        "clash_api": {"external_controller": "127.0.0.1:9090"},
        // 启用缓存，加速规则集加载
        "cache_file": {"enabled": true},
      },
    };

    // 如果启用广告拦截，添加 DNS 拦截规则
    if (blockAds) {
      final dnsConfig = config["dns"] as Map<String, dynamic>;
      // Windows Legacy 不支持 rcode:// DNS，跳过 DNS 层拦截
      // 广告拦截仍由 Route Rules 的 action: reject 提供
      if (!Platform.isWindows) {
        // 添加 DNS 拦截服务器 (仅非 Windows)
        (dnsConfig["servers"] as List).add({
          "tag": "dns_block",
          "address": "rcode://success", // 返回空结果
        });
        // 在 DNS 规则开头添加广告拦截规则
        (dnsConfig["rules"] as List).insert(1, {
          "rule_set": [
            "geosite-category-ads-all",
            "geosite-malware",
            "geosite-phishing",
            "geosite-cryptominers",
          ],
          "server": "dns_block",
        });
      }
    }

    if (kDebugMode) {
      print('Config generated with localPort: $localPort, blockAds: $blockAds');
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

  /// 构建路由配置，支持广告拦截
  static Map<String, dynamic> _buildRoute(bool blockAds) {
    // 基础规则集
    final ruleSets = <Map<String, dynamic>>[
      // 中国网站规则集
      {
        "type": "remote",
        "tag": "geosite-cn",
        "format": "binary",
        "url":
            "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs",
        "download_detour": "direct"
      },
      // 中国 IP 规则集
      {
        "type": "remote",
        "tag": "geoip-cn",
        "format": "binary",
        "url":
            "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs",
        "download_detour": "direct"
      },
      // 非中国网站规则集
      {
        "type": "remote",
        "tag": "geosite-geolocation-!cn",
        "format": "binary",
        "url":
            "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs",
        "download_detour": "direct"
      },
    ];

    // 基础路由规则
    final rules = <Map<String, dynamic>>[
      // DNS 流量走 DNS 出站 -> 改为 hijack-dns
      {"protocol": "dns", "action": "hijack-dns"},
      // 私有 IP 地址直连
      {"ip_is_private": true, "outbound": "direct"},
      // 支付 & 重要国内域名直连
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
    ];

    // 如果启用广告拦截，添加广告拦截规则集和规则
    if (blockAds) {
      // 添加广告/恶意软件规则集
      ruleSets.addAll([
        {
          "type": "remote",
          "tag": "geosite-category-ads-all",
          "format": "binary",
          "url":
              "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geosite-category-ads-all.srs",
          "download_detour": "direct"
        },
        {
          "type": "remote",
          "tag": "geosite-malware",
          "format": "binary",
          "url":
              "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geosite-malware.srs",
          "download_detour": "direct"
        },
        {
          "type": "remote",
          "tag": "geosite-phishing",
          "format": "binary",
          "url":
              "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geosite-phishing.srs",
          "download_detour": "direct"
        },
        {
          "type": "remote",
          "tag": "geosite-cryptominers",
          "format": "binary",
          "url":
              "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geosite-cryptominers.srs",
          "download_detour": "direct"
        },
        {
          "type": "remote",
          "tag": "geoip-malware",
          "format": "binary",
          "url":
              "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geoip-malware.srs",
          "download_detour": "direct"
        },
        {
          "type": "remote",
          "tag": "geoip-phishing",
          "format": "binary",
          "url":
              "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geoip-phishing.srs",
          "download_detour": "direct"
        },
      ]);

      // 在规则列表前面插入广告拦截规则（优先级高）
      rules.insert(2, {
        "rule_set": [
          "geosite-category-ads-all",
          "geosite-malware",
          "geosite-phishing",
          "geosite-cryptominers",
          "geoip-malware",
          "geoip-phishing",
        ],
        "action": "reject",
      });
    }

    // 添加最后的分流规则
    rules.addAll([
      // 中国网站直连
      {"rule_set": "geosite-cn", "outbound": "direct"},
      // 中国 IP 直连
      {"rule_set": "geoip-cn", "outbound": "direct"},
      // 非中国网站走代理
      {"rule_set": "geosite-geolocation-!cn", "outbound": "proxy"},
    ]);

    return {
      "rule_set": ruleSets,
      "rules": rules,
      "auto_detect_interface": true,
      "final": "proxy",
    };
  }
}
