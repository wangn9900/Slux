import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 800;
        final theme = Theme.of(context);
        final bg = theme.scaffoldBackgroundColor;

        if (isMobile) {
          return Scaffold(
            backgroundColor: bg,
            body: SafeArea(child: child),
            bottomNavigationBar: const _MobileBottomNav(),
          );
        }

        // Desktop Layout
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            color: bg.withOpacity(0.95), // High opacity background
            child: Row(
              children: [
                // Sidebar
                const SizedBox(width: 160, child: _Sidebar()),
                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      // Custom Title Bar (Draggable)
                      const _TitleBar(),
                      // Page Content
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav();

  @override
  Widget build(BuildContext context) {
    final GoRouterState state = GoRouterState.of(context);
    final currentPath = state.uri.toString();

    int getIndex() {
      if (currentPath == '/') return 0;
      if (currentPath.startsWith('/proxies')) return 1;
      if (currentPath.startsWith('/profiles')) return 2;
      if (currentPath.startsWith('/settings')) return 3;
      return 0;
    }

    return NavigationBar(
      selectedIndex: getIndex(),
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/proxies');
            break;
          case 2:
            context.go('/profiles');
            break;
          case 3:
            context.go('/settings');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(LucideIcons.layoutDashboard),
          label: '主页',
        ),
        NavigationDestination(
          icon: Icon(LucideIcons.shoppingBag),
          label: '商店',
        ),
        NavigationDestination(
          icon: Icon(LucideIcons.user),
          label: '我的',
        ),
        NavigationDestination(
          icon: Icon(LucideIcons.settings),
          label: '设置',
        ),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final titleBarWidget = Container(
      height: 32,
      color: Theme.of(context).scaffoldBackgroundColor, // Match background
      alignment: Alignment.centerRight,
    );

    // 只在桌面平台使用 DragToMoveArea
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DragToMoveArea(child: titleBarWidget);
    }
    return titleBarWidget;
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: Column(
        children: [
          // Logo Area
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.zap,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SLux',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Navigation
          const _NavItem(
            path: '/',
            icon: LucideIcons.layoutDashboard,
            label: '主页',
          ),
          const _NavItem(
            path: '/proxies',
            icon: LucideIcons.shoppingBag,
            label: '商店',
          ),
          const _NavItem(
            path: '/profiles',
            icon: LucideIcons.user,
            label: '我的',
          ),
          const Spacer(),
          const _NavItem(
            path: '/settings',
            icon: LucideIcons.settings,
            label: '设置',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String path;
  final IconData icon;
  final String label;

  const _NavItem({required this.path, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final GoRouterState state = GoRouterState.of(context);
    final isActive = state.uri.toString() == path;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = Theme.of(context).textTheme.bodyMedium?.color;
    final textMuted =
        Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8);

    return InkWell(
      onTap: () => context.go(path),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ), // Reduced padding
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: primaryColor.withOpacity(0.2))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? primaryColor : textMuted,
            ), // Reduced icon
            const SizedBox(width: 8), // Reduced gap
            Text(
              label,
              style: TextStyle(
                fontSize: 13, // Reduced font
                color: isActive ? textMain : textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
