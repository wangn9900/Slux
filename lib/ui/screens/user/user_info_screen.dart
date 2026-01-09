import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/v2board_provider.dart';

class UserInfoScreen extends ConsumerStatefulWidget {
  const UserInfoScreen({super.key});

  @override
  ConsumerState<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends ConsumerState<UserInfoScreen> {
  bool _loading = false;
  Map<String, dynamic>? _userInfo;
  final _giftCardController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _giftCardController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);
    try {
      final info = await service.getUserInfo();
      if (mounted) {
        setState(() {
          _userInfo = info;
        });
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeemGiftCard() async {
    final code = _giftCardController.text.trim();
    if (code.isEmpty) return;

    final service = ref.read(v2boardServiceProvider);
    // Show loading?
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('正在兑换...')));

    final result = await service.redeemGiftCard(code);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (result['success'] == true) {
        _giftCardController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '兑换成功'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserInfo(); // Reload balance might be needed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '兑换失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotification(String key, bool value) async {
    if (_userInfo == null) return;

    // Optimistic update
    setState(() {
      _userInfo![key] = value ? 1 : 0;
    });

    final service = ref.read(v2boardServiceProvider);
    final success = await service.updateUserInfo({key: value ? 1 : 0});

    if (!success && mounted) {
      // Revert on failure
      setState(() {
        _userInfo![key] = !value ? 1 : 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置失败')));
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              decoration: const InputDecoration(labelText: '旧密码'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              decoration: const InputDecoration(labelText: '新密码'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              final service = ref.read(v2boardServiceProvider);
              final success = await service.changePassword(
                oldController.text,
                newController.text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '密码修改成功' : '修改失败，请检查旧密码'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户中心'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading && _userInfo == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserInfo,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildBasicInfoCard(context),
                    const SizedBox(height: 16),
                    _buildGiftCardSection(context),
                    const SizedBox(height: 16),
                    _buildNotificationSection(context),
                    const SizedBox(height: 16),
                    _buildSecuritySection(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBasicInfoCard(BuildContext context) {
    if (_userInfo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final email = _userInfo!['email'] ?? '';
    final createdAt = _userInfo!['created_at'];
    final dateStr = createdAt != null
        ? DateFormat(
            'yyyy/MM/dd',
          ).format(DateTime.fromMillisecondsSinceEpoch(createdAt * 1000))
        : '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本信息',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '邮箱账号',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: theme.textTheme.titleMedium),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '创建时间',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: theme.textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftCardSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '礼品卡兑换',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _giftCardController,
                    decoration: const InputDecoration(
                      hintText: '输入礼品卡代码',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _redeemGiftCard,
                  icon: const Icon(LucideIcons.gift, size: 18),
                  label: const Text('兑换'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection(BuildContext context) {
    if (_userInfo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final remindExpire = (_userInfo!['remind_expire'] ?? 0) == 1;
    final remindTraffic = (_userInfo!['remind_traffic'] ?? 0) == 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '通知设置',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('到期提醒'),
              subtitle: const Text(
                '接收账户到期提醒邮件',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              value: remindExpire,
              onChanged: (val) => _toggleNotification('remind_expire', val),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('流量提醒'),
              subtitle: const Text(
                '接收流量用尽提醒邮件',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              value: remindTraffic,
              onChanged: (val) => _toggleNotification('remind_traffic', val),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '安全设置',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ), // Style as per image (Red?) Or Primary. Image uses Black/Red titles? No, Image used Red for "Safe Setting" maybe?
            // Actually image uses Red for title "安全设置"
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showChangePasswordDialog,
                  icon: const Icon(LucideIcons.lock, size: 16),
                  label: const Text('修改密码'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            // Note: Device Management button is visible in image but cut off.
            // We can add it if needed later.
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('功能暂未开放')));
              },
              icon: const Icon(LucideIcons.monitor, size: 16),
              label: const Text('设备管理'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
