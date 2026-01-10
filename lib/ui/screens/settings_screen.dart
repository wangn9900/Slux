import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/api_service_provider.dart';
import '../../data/api/api_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final apiService = ref.read(apiServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Text(
            '设置',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '应用偏好设置',
            style: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),

          _SettingsSection(
            title: '外观',
            children: [
              _SettingsTile(
                icon: LucideIcons.moon,
                title: '深色模式',
                subtitle: _getThemeModeString(themeMode),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox(),
                  dropdownColor: Theme.of(context).cardColor,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text("跟随系统"),
                    ),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text("深色")),
                    DropdownMenuItem(value: ThemeMode.light, child: Text("浅色")),
                  ],
                  onChanged: (mode) {
                    if (mode != null) themeNotifier.setTheme(mode);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _SettingsSection(
            title: '语言',
            children: [
              _SettingsTile(
                icon: LucideIcons.languages,
                title: '系统语言',
                subtitle: '简体中文',
                trailing: DropdownButton<String>(
                  value: 'zh',
                  underline: const SizedBox(),
                  dropdownColor: Theme.of(context).cardColor,
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text("跟随系统")),
                    DropdownMenuItem(value: 'zh', child: Text("简体中文")),
                    DropdownMenuItem(value: 'en', child: Text("English")),
                  ],
                  onChanged: (val) {
                    // Logic to update language
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 实验性功能
          _SettingsSection(
            title: '实验性功能',
            children: [
              _SettingsSwitchTile(
                icon: LucideIcons.shieldOff,
                title: '广告拦截',
                subtitle: '拦截广告、恶意软件和钓鱼网站',
                value: ref.watch(blockAdsProvider),
                onChanged: (value) {
                  ref.read(blockAdsProvider.notifier).toggle(value);
                },
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Logout Button Area
          Container(
            width: double.infinity,
            height: 56, // Fixed height for easy clicking
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.red.withOpacity(0.05),
            ),
            child: InkWell(
              onTap: () async {
                // Confirm dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("退出登录"),
                    content: const Text("确定要退出当前账号吗？所有本地数据将被清除。"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("取消"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "退出",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await apiService.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: const Center(
                child: Text(
                  '退出账号',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.dark:
        return '已开启';
      case ThemeMode.light:
        return '已关闭';
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
