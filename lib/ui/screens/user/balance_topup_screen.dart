import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/v2board_provider.dart';

class BalanceTopupScreen extends ConsumerStatefulWidget {
  const BalanceTopupScreen({super.key});

  @override
  ConsumerState<BalanceTopupScreen> createState() => _BalanceTopupScreenState();
}

class _BalanceTopupScreenState extends ConsumerState<BalanceTopupScreen> {
  bool _loading = false;
  Map<String, dynamic>? _userInfo;
  final TextEditingController _customAmountController = TextEditingController();
  int? _selectedAmount;
  bool _autoRenew = false;

  // Presets from screenshot or common values
  final List<int> _presets = [50, 100, 200, 300, 400, 500, 600, 800];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);
    try {
      final info = await service.getUserInfo();
      if (mounted) {
        setState(() {
          _userInfo = info;
          // Check both keys commonly used
          final autoRenewVal =
              _userInfo?['auto_renew'] ?? _userInfo?['auto_renewal'];
          if (autoRenewVal != null) {
            if (autoRenewVal is int) {
              _autoRenew = autoRenewVal == 1;
            } else if (autoRenewVal is bool) {
              _autoRenew = autoRenewVal;
            }
          } else {
            _autoRenew = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAutoRenew(bool value) async {
    setState(() => _autoRenew = value);
    final service = ref.read(v2boardServiceProvider);
    try {
      final success = await service.updateUserInfo({
        'auto_renew': value ? 1 : 0,
      });
      if (!success && mounted) {
        setState(() => _autoRenew = !value);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('设置自动续费失败')));
      }
    } catch (e) {
      if (mounted) setState(() => _autoRenew = !value);
    }
  }

  Future<void> _submitRecharge() async {
    int amount = 0;
    if (_selectedAmount != null) {
      amount = _selectedAmount!;
    } else {
      amount = int.tryParse(_customAmountController.text) ?? 0;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的充值金额')));
      return;
    }

    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);

    try {
      final tradeNo = await service.submitDepositOrder(amount);
      if (tradeNo != null) {
        // Order created, now what?
        // Usually need to pay.
        // Slux flow: maybe just show success and direct to payment page/sheet?
        // Or if using generic Payment, we might need to open URL or check methods.
        // V2Board usually returns trade_no.
        // We can use generic payment URL or fetch payment methods.
        // For now, let's assume we redirect to web payment or show trade no.

        // MOMclash uses PaymentSheet. But simplified approach: Open web Checkout?
        // Standard V2board: `/user/order/{trade_no}` for checkout?
        // Let's launch generic checkout URL if possible or just show Success.
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('订单已创建: $tradeNo')));
          // TODO: Implement PaymentSheet or launching payment URL
          // For now, launch URL if we can construct one, or just tell user to pay on web.
          // Actually, we can fetch payment methods next.
          _showPaymentSheet(tradeNo, amount.toDouble());
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('创建订单失败')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPaymentSheet(String tradeNo, double amount) async {
    // This would be the next step (Payment integration).
    // For now, we can redirect to a webview or browser if we know the URL.
    // Typically V2Board doesn't have a direct "pay link" unless we call checkout.
    // We'll leave this as a placeholder or simple dialog.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('订单已创建'),
        content: Text('订单号: $tradeNo\n金额: ¥$amount\n\n请前往网页端或者等待应用接入收银台支付。'),
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
    final theme = Theme.of(context);
    // balance usually in cents or divided by 100? V2Board returns `balance` in cents usually?
    // Wait, V2Board `balance` is usually in cents (int). MOMclash divides by 100.
    final balance = (_userInfo?['balance'] ?? 0) / 100.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('余额充值'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('账户余额', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Text(
                        '¥${balance.toStringAsFixed(2)}',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '充值后的余额仅限消费',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('自动续费', style: theme.textTheme.titleMedium),
                          Switch(
                            value: _autoRenew,
                            onChanged: _toggleAutoRenew,
                          ),
                        ],
                      ),
                      Text(
                        '账户余额充足时自动续费套餐',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '充值金额',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.info, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '充值后的余额仅限消费，无法提现',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presets.map((amount) {
                  final isSelected = _selectedAmount == amount;
                  return SizedBox(
                    width:
                        (MediaQuery.of(context).size.width - 32 - 24) /
                        3, // 3 columns
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected
                            ? theme.colorScheme.primaryContainer
                            : null,
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedAmount = amount;
                          _customAmountController.clear();
                        });
                      },
                      child: Text(
                        '¥$amount',
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '请输入充值金额',
                  labelText: '自定义金额',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixText: '¥ ',
                  suffixIcon: _selectedAmount == null
                      ? const Icon(LucideIcons.check, color: Colors.green)
                      : null,
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && _selectedAmount != null) {
                    setState(() => _selectedAmount = null);
                  }
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _loading ? null : _submitRecharge,
                icon: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(LucideIcons.shoppingCart),
                label: Text(_loading ? '处理中...' : '立即充值'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
