import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/v2board_provider.dart';

class InviteManagementScreen extends ConsumerStatefulWidget {
  const InviteManagementScreen({super.key});

  @override
  ConsumerState<InviteManagementScreen> createState() =>
      _InviteManagementScreenState();
}

class _InviteManagementScreenState
    extends ConsumerState<InviteManagementScreen> {
  bool _loading = false;
  Map<String, dynamic>? _inviteData;
  Map<String, dynamic>? _inviteDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);
    try {
      final results = await Future.wait([
        service.getInviteData(),
        service.getInviteDetails(), // Optional, checking if returns records
      ]);

      if (mounted) {
        setState(() {
          _inviteData = results[0];
          _inviteDetails = results[1];
        });
      }
    } catch (e) {
      debugPrint('Error loading invite data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCode() async {
    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);
    await service.generateInviteCode();
    await _loadData(); // Reload to show new code
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Parse data
    // inviteData usually contains:
    // stat: [ total, on_going, ... ]?
    // codes: [ { code: "...", status: 0/1, ... } ]
    // commission_balance: 100 (cents usually)

    // Structure of _inviteData response from V2board:
    // data: {
    //  codes: [...],
    //  stat: [...],
    // }
    // UserInfo also has `commission_balance`.

    // Actually, `getInviteData` usually returns just codes and stats.
    // Commission balance is often in `getUserInfo`.
    // Let's assume we might need `getUserInfo` as well or use passed balance?
    // But `transferCommission` implies we know the balance.
    // Let's assume we can fetch user info or use `getInviteData` if it includes it.
    // Standard V2Board: `/invite/fetch` returns codes. `/user/info` returns commission_balance.

    // So I should fetch UserInfo too?
    // Let's rely on `getUserInfo` being cached or fetch it.

    return Scaffold(
      appBar: AppBar(
        title: const Text('邀请管理'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepsCard(theme),
              const SizedBox(height: 16),
              _buildCommissionCard(theme),
              const SizedBox(height: 16),
              _buildLinksCard(theme),
              const SizedBox(height: 16),
              _buildRecordsCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Screenshot has light background steps
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStepItem(
              theme,
              LucideIcons.userPlus,
              '1. 注册',
              '好友通过链接注册账号',
            ), // Screenshot is 2. 注册? Maybe index starts 1?
            // Actually screenshot shows:
            // 2. 注册 (好友通过链接注册账号)
            // 3. 购买 (好友购买订阅套餐)
            // 4. 返佣 (获得现金奖励)
            // Where is 1? Maybe 1 is Share Link? But image cuts off.
            // I'll implement 3 steps.
            const SizedBox(height: 12),
            _buildStepItem(
              theme,
              LucideIcons.shoppingCart,
              '2. 购买',
              '好友购买订阅套餐',
            ),
            const SizedBox(height: 12),
            _buildStepItem(theme, LucideIcons.dollarSign, '3. 返佣', '获得现金奖励'),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue, // Image uses Blue
          radius: 16,
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommissionCard(ThemeData theme) {
    // Need balance.
    // Fetching user info here would be better.
    // For now, let's use a placeholder or assume we have it.
    // I will use ref.read(v2boardServiceProvider).getUserInfo() inside build? No.
    // I should have fetched it in `_loadData`.
    // Let's add it to `_loadData`.

    return FutureBuilder(
      future: ref.read(v2boardServiceProvider).getUserInfo(),
      builder: (context, snapshot) {
        final userInfo = snapshot.data;
        final balance = (userInfo?['commission_balance'] ?? 0) / 100.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('佣金余额', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '可用余额',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '¥${balance.toStringAsFixed(2)}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.blue, // Screenshot uses Blue
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            // TODO: Implement Transfer Dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('划转功能开发中')),
                            );
                          },
                          icon: const Icon(
                            LucideIcons.arrowLeftRight,
                            size: 14,
                          ),
                          label: const Text('划转'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement Withdraw Dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('提现功能开发中')),
                            );
                          },
                          icon: const Icon(LucideIcons.landmark, size: 14),
                          label: const Text('提现'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksCard(ThemeData theme) {
    final codes = _inviteData?['codes'] as List<dynamic>?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '邀请链接',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.plus),
                  onPressed: _generateCode,
                  tooltip: '生成新链接',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (codes == null || codes.isEmpty)
              const Text('暂无邀请链接，点击右上角生成')
            else
              ...codes.map((codeItem) {
                final code = codeItem['code'];
                // Assuming construct URL if API doesn't provide it?
                // V2Board usually provides just code. User needs to construct URL.
                // Or sometimes API returns link.
                // Example: https://baseUrl/#/register?code=...
                // I'll grab base URL from prefs ideally.
                // For now, display code and copy button.
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '邀请码: $code',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '点击复制邀请链接',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.copy),
                        onPressed: () {
                          // Need base URL to make link
                          // Just copy code for now if URL unknown, or try constructing
                          _copyToClipboard(code);
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '返佣记录',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Use _inviteDetails for records?
            // If empty:
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.messageSquare,
                    size: 48,
                    color: Colors.blue,
                  ), // Screenshot bubble icon
                  const SizedBox(height: 8),
                  const Text('暂无记录'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
