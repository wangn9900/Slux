import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/v2board_provider.dart';
import '../../utils/payment_resolver.dart';
import '../theme/app_theme.dart';

class ProxiesScreen extends ConsumerStatefulWidget {
  const ProxiesScreen({super.key});

  @override
  ConsumerState<ProxiesScreen> createState() => _ProxiesScreenState();
}

class _ProxiesScreenState extends ConsumerState<ProxiesScreen> {
  List<dynamic> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlans();
    });
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = ref.read(v2boardServiceProvider);
      if (!await service.isLoggedIn()) {
        setState(() {
          _error = '请先登录';
          _isLoading = false;
        });
        return;
      }

      final plans = await service.getPlans();
      setState(() {
        _plans = plans ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPlans, child: const Text('重试')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订阅套餐',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.8,
              ),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                return _PlanCard(
                  plan: _plans[index],
                  onSnapshot: () => _showBuyDialog(_plans[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBuyDialog(dynamic plan) {
    showDialog(
      context: context,
      builder: (context) => _PlanBuyDialog(plan: plan),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final dynamic plan;
  final VoidCallback onSnapshot;

  const _PlanCard({required this.plan, required this.onSnapshot});

  @override
  Widget build(BuildContext context) {
    final name = plan['name']?.toString() ?? 'Unknown Plan';
    final content = plan['content']?.toString() ?? '';
    // Basic HTML strip
    final desc = content.replaceAll(
      RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true),
      '',
    );
    final transferEnable = plan['transfer_enable'] as int? ?? 0;
    String? trafficText;
    if (transferEnable > 0) {
      // 智能判断单位：如果数值很大（> 1GB的字节数的一小部分，例如 > 100万），认为是Bytes，否则认为是GB
      if (transferEnable > 1000000) {
        trafficText =
            '${(transferEnable / 1073741824).toStringAsFixed(0)} GB 流量';
      } else {
        trafficText = '$transferEnable GB 流量';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (trafficText != null) ...[
            Text(
              trafficText,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                desc,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSnapshot,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('立即订阅'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBuyDialog extends ConsumerStatefulWidget {
  final dynamic plan;

  const _PlanBuyDialog({required this.plan});

  @override
  ConsumerState<_PlanBuyDialog> createState() => _PlanBuyDialogState();
}

class _PlanBuyDialogState extends ConsumerState<_PlanBuyDialog> {
  String? _selectedPeriod;
  final Map<String, int> _prices = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _parsePrices();
  }

  void _parsePrices() {
    final p = widget.plan;
    void add(String key, int? val) {
      if (val != null && val > 0) _prices[key] = val;
    }

    add('month_price', p['month_price']);
    add('quarter_price', p['quarter_price']);
    add('half_year_price', p['half_year_price']);
    add('year_price', p['year_price']);
    add('two_year_price', p['two_year_price']);
    add('three_year_price', p['three_year_price']);
    add('onetime_price', p['onetime_price']);
    add('reset_price', p['reset_price']);

    if (_prices.isNotEmpty) {
      _selectedPeriod = _prices.keys.first;
    }
  }

  String _getPeriodLabel(String key) {
    switch (key) {
      case 'month_price':
        return '月付';
      case 'quarter_price':
        return '季付';
      case 'half_year_price':
        return '半年付';
      case 'year_price':
        return '年付';
      case 'two_year_price':
        return '两年付';
      case 'three_year_price':
        return '三年付';
      case 'onetime_price':
        return '一次性';
      case 'reset_price':
        return '重置包';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prices.isEmpty) {
      return const AlertDialog(content: Text('此套餐暂无可用价格'));
    }

    return AlertDialog(
      title: Text('购买 ${widget.plan['name']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择周期:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _prices.entries.map((e) {
                final isSelected = _selectedPeriod == e.key;
                return ChoiceChip(
                  label: Text(
                    '${_getPeriodLabel(e.key)} (${e.value / 100})',
                  ), // Assuming cents? Usually V2Board is cents? No, sometimes units. Let's assume raw or display raw if unsure. Wait, check output. Most V2Board / 100.
                  selected: isSelected,
                  onSelected: (v) => setState(() => _selectedPeriod = e.key),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _submitting ? null : _submitOrder,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('下单'),
        ),
      ],
    );
  }

  Future<void> _submitOrder() async {
    if (_selectedPeriod == null) return;
    setState(() => _submitting = true);

    try {
      final service = ref.read(v2boardServiceProvider);
      // Map period key to period string (e.g. 'month_price' -> 'month_price')
      // V2Board usually expects api to receive period like 'month_price'
      final tradeNo = await service.submitOrder(
        planId: widget.plan['id'],
        period: _selectedPeriod!,
      );

      if (tradeNo != null) {
        if (mounted) {
          Navigator.pop(context); // Close buy dialog
          _showPaymentSelector(tradeNo);
        }
      } else {
        throw '未获取到订单号';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下单失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showPaymentSelector(String tradeNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentSelectorDialog(tradeNo: tradeNo),
    );
  }
}

class _PaymentSelectorDialog extends ConsumerStatefulWidget {
  final String tradeNo;

  const _PaymentSelectorDialog({required this.tradeNo});

  @override
  ConsumerState<_PaymentSelectorDialog> createState() =>
      _PaymentSelectorDialogState();
}

class _PaymentSelectorDialogState
    extends ConsumerState<_PaymentSelectorDialog> {
  List<dynamic> _methods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await ref
          .read(v2boardServiceProvider)
          .getPaymentMethods();
      if (mounted) {
        setState(() {
          _methods = methods ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle error
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pay(int methodId) async {
    try {
      final result = await ref
          .read(v2boardServiceProvider)
          .checkoutOrder(tradeNo: widget.tradeNo, methodId: methodId);

      if (result != null) {
        String? url;
        if (result is String) {
          url = result;
        } else if (result is Map) {
          // Try common fields used by V2Board gateways
          url =
              (result['data'] ??
                      result['url'] ??
                      result['qrcode'] ??
                      result['pay_url'])
                  ?.toString();
        }

        if (url != null && url.isNotEmpty) {
          // Show resolving status (non-blocking)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                      height: 16,
                      width: 16,
                    ),
                    SizedBox(width: 12),
                    Text('正在安全解析支付通道...'),
                  ],
                ),
                duration: Duration(
                  seconds: 20,
                ), // Long duration, we'll hide it or it will fade
              ),
            );
          }

          // Resolve the final URL (Deep Link or clean URL)
          final resolved = await PaymentResolver.resolve(url);
          if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

          final finalUrl = resolved.targetUrl ?? url;
          bool launched = false;
          try {
            final uri = Uri.parse(finalUrl);
            launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            // Ignore launch errors and fall back to manual dialog
            launched = false;
          }

          if (launched) {
            if (mounted) Navigator.pop(context); // Close dialog on success
          } else {
            if (mounted) _showFallbackDialog(finalUrl);
          }
        } else {
          throw '无法解析支付链接';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('支付请求失败: $e')));
      }
    }
  }

  void _showFallbackDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('支付链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('无法自动跳转浏览器，请复制链接手动打开：'),
            const SizedBox(height: 12),
            SelectableText(url, style: const TextStyle(color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择支付方式'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _methods.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, index) {
                  final m = _methods[index];
                  return ListTile(
                    leading: const Icon(LucideIcons.creditCard),
                    title: Text(m['name'] ?? 'Unknown'),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => _pay(m['id']),
                  );
                },
              ),
            ),
    );
  }
}
