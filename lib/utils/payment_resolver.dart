import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class PaymentResolveResult {
  final String? targetUrl; // 解析出的最终目标URL（DeepLink或二维码链接）
  final bool isDeepLink; // 是否为 App 跳转链接

  PaymentResolveResult(this.targetUrl, {this.isDeepLink = false});
}

class PaymentResolver {
  /// 尝试解析支付中间页，提取真正的支付链接
  static Future<PaymentResolveResult> resolve(String url) async {
    // 0. 如果本身就是 Deep Link，直接返回
    if (!url.startsWith('http')) {
      return PaymentResolveResult(url, isDeepLink: true);
    }

    // 0.5 聚合支付页面（如 submit.php）通常是交互式网页，直接打开即可，不仅快而且兼容性更好
    if (url.contains('submit.php')) {
      if (kDebugMode) print('Fast pass for payment gateway: $url');
      return PaymentResolveResult(url);
    }

    try {
      final dio = Dio();
      final options = Options(
        headers: {
          // 伪装成 iPhone Safari，许多支付网关对移动端更友好
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1',
          'Referer': url, // 带上自身作为 Referer，防止防盗链校验
        },
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      );

      print('Resolving payment URL: $url');
      final response = await dio.get(url, options: options);
      final html = response.data.toString();

      // 1. 快速嗅探常见模式 (Quick Sniff)
      // 匹配 alipays://, weixin://, wxp:// 等 Scheme
      // 使用三引号raw string以避免转义地狱
      final deepLinkMatch = RegExp(
        r"""["']((?:alipays?|weixin|wxp):\/\/[^"']+)["']""",
        caseSensitive: false,
      ).firstMatch(html);

      if (deepLinkMatch != null) {
        final deepLink = deepLinkMatch.group(1)!.replaceAll('\\/', '/');
        print('Found Deep Link: $deepLink');
        return PaymentResolveResult(deepLink, isDeepLink: true);
      }

      // 2. 嗅探 pay_url / qrcode 等 JSON 字段或 JS 变量
      final commonPattern = RegExp(
        r"""(?:qrcode|payUrl|url|pay_url|code_url)["']\s*[:=]\s*["']((?:https?:\/\/|weixin:\/\/|alipays?:\/\/)[^"']+)["']""",
        caseSensitive: false,
      ).firstMatch(html);

      if (commonPattern != null) {
        final target = commonPattern.group(1)!.replaceAll('\\/', '/');
        // 判断是否为 Deep Link
        final isDeep = !target.startsWith('http');
        print('Found Common Pattern: $target (Deep: $isDeep)');
        return PaymentResolveResult(target, isDeepLink: isDeep);
      }

      // 4. 如果没有嗅探到特定链接，但页面包含具体的跳转脚本
      final locationMatch = RegExp(
        r"""window\.location\.href\s*=\s*["']([^"']+)["']""",
        caseSensitive: false,
      ).firstMatch(html);

      if (locationMatch != null) {
        final target = locationMatch.group(1)!;
        if (target != url) {
          print('Found JS Redirect: $target');
          return PaymentResolveResult(
            target,
            isDeepLink: !target.startsWith('http'),
          );
        }
      }

      // 5. 如果实在解析不出来，返回原始 URL
      return PaymentResolveResult(url);
    } catch (e) {
      if (kDebugMode) {
        print('Payment resolve failed: $e');
      }
      // 出错时降级回原始 URL
      return PaymentResolveResult(url);
    }
  }
}
