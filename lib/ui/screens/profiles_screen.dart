import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../providers/v2board_provider.dart';
import '../../services/v2board_service.dart';
import 'user/order_list_screen.dart';

import 'user/user_info_screen.dart';
import 'user/traffic_details_screen.dart';
import 'user/ticket_list_screen.dart';
import 'user/balance_topup_screen.dart';
import 'user/invite_management_screen.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  bool _loading = false;
  Map<String, dynamic>? _userInfo;
  List<dynamic>? _plans;
  Map<String, dynamic>? _commConfig;

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
        service.getUserInfo(),
        service.getPlans(),
        service.getCommConfig(),
      ]);

      if (mounted) {
        setState(() {
          _userInfo = results[0] as Map<String, dynamic>?;
          _plans = results[1] as List<dynamic>?;
          _commConfig = results[2] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      debugPrint('Load profile data failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0.00 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null || timestamp <= 0) return '永久有效';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _getPlanName(int? planId) {
    if (planId == null) return 'Free Plan';
    if (_plans == null) return 'Plan #$planId';
    final plan = _plans!.firstWhere(
      (p) => p['id'] == planId,
      orElse: () => {'name': 'Plan #$planId'},
    );
    return plan['name'];
  }

  Future<void> _handleResetTraffic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置当期流量'),
        content: const Text('流量已不足，确定要重置当前流量包吗？\n这将创建一个重置订单，如余额不足需进行支付。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (_userInfo == null) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final service = ref.read(v2boardServiceProvider);
      final tradeNo = await service.submitOrder(
        planId: _userInfo!['plan_id'],
        period: 'reset_price',
      );

      if (tradeNo != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('订单创建成功: $tradeNo，请前往官网支付')));
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('创建重置订单失败')));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(context),
              const SizedBox(height: 24),
              _buildActionButtons(context),
              const SizedBox(height: 24),
              _buildMenuSection(context),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(LucideIcons.refreshCw),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final total =
        int.tryParse(_userInfo?['transfer_enable']?.toString() ?? '0') ?? 0;
    final u = int.tryParse(_userInfo?['u']?.toString() ?? '0') ?? 0;
    final d = int.tryParse(_userInfo?['d']?.toString() ?? '0') ?? 0;
    final used = u + d;
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: _userInfo?['avatar_url'] != null
                    ? NetworkImage(_userInfo!['avatar_url'])
                    : null,
                child: _userInfo?['avatar_url'] == null
                    ? Text(
                        (_userInfo?['email'] ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userInfo?['email'] ?? '未登录 / 获取失败',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getPlanName(_userInfo?['plan_id']),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('到期时间', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_userInfo?['expired_at']),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('已用流量', style: theme.textTheme.bodyMedium),
                  Text(
                    '${_formatBytes(used)} / ${_formatBytes(total)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color:
                      progress > 0.9 ? Colors.red : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              context.go('/proxies');
            },
            icon: const Icon(LucideIcons.shoppingBag),
            label: const Text('续费订阅'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _handleResetTraffic,
            icon: const Icon(LucideIcons.refreshCcw),
            label: const Text('重置流量'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final theme = Theme.of(context);
    final menuItems = [
      {
        'icon': LucideIcons.user,
        'title': '个人信息',
        'page': const UserInfoScreen(),
      },
      {
        'icon': LucideIcons.fileText,
        'title': '订单记录',
        'page': const OrderListScreen(),
      },
      {
        'icon': LucideIcons.activity,
        'title': '流量明细',
        'page': const TrafficDetailsScreen(),
      },
      {
        'icon': LucideIcons.ticket,
        'title': '我的工单',
        'page': const TicketListScreen(),
      },
      {
        'icon': LucideIcons.wallet,
        'title': '余额充值',
        'page': const BalanceTopupScreen(),
      },
      {
        'icon': LucideIcons.users,
        'title': '邀请管理',
        'page': const InviteManagementScreen(),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: menuItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == menuItems.length - 1;

          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(item['title'] as String),
                trailing: const Icon(LucideIcons.chevronRight, size: 16),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(20) : Radius.zero,
                    bottom: isLast ? const Radius.circular(20) : Radius.zero,
                  ),
                ),
                onTap: () {
                  if (item['page'] != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => item['page'] as Widget),
                    );
                  }
                },
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 24,
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
