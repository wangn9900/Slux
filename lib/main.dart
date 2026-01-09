import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/theme/app_theme.dart';
import 'ui/layouts/main_layout.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/proxies_screen.dart';
import 'ui/screens/profiles_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/login_screen.dart';
import 'providers/app_settings_provider.dart';
import 'providers/api_service_provider.dart';
import 'data/api/api_service.dart';

import 'utils/system_proxy_helper.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // 启动时强制清理一次系统代理，防止上次非正常退出残�?
  await SystemProxyHelper.clearSystemProxy();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(960, 640),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // 阻止直接关闭，改为隐藏到托盘
    await windowManager.setPreventClose(true);
  });

  runApp(const ProviderScope(child: SluxApp()));
}

final _router = GoRouter(
  initialLocation: '/', // Will redirect to login if not auth
  redirect: (context, state) {
    // Basic auth check using a global variable for simplicity in this turn
    // Ideally use a Riverpod provider listener.
    // For now, let's assume if 'auth_token' is not in prefs (we need async check).
    // Actually, GoRouter + Riverpod async redirect is better.
    // Simplifying: we will check this inside the SluxApp or make router a provider.
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/proxies', builder: (_, __) => const ProxiesScreen()),
        GoRoute(path: '/profiles', builder: (_, __) => const ProfilesScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);
// To properly handle async redirect, we need to read SharedPrefs before logic.
// But main() is async.

class SluxApp extends ConsumerStatefulWidget {
  const SluxApp({super.key});

  @override
  ConsumerState<SluxApp> createState() => _SluxAppState();
}

class _SluxAppState extends ConsumerState<SluxApp> with WindowListener {
  GoRouter? _appRouter;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // 初始化托盘服�?
    ref.read(trayServiceProvider).init();
    _initRouter();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 检查是否阻止关闭（即是否最小化到托盘）
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    } else {
      // 彻底退出流程（通常由托盘菜单触�?setPreventClose(false) 后调�?close，或者直�?destroy�?
      await SystemProxyHelper.clearSystemProxy();
      await windowManager.destroy();
    }
  }

  Future<void> _initRouter() async {
    final api = ref.read(apiServiceProvider);
    // api is initialized in constructor which is sync, but loading prefs is async internal in it?
    // Actually ApiService constructor fires _loadConfig async.
    // We should wait a bit or explicitly check prefs here.

    // Quick Fix: Create a router that checks auth state
    // We'll rely on the LoginScreen to redirect IF we manually go there?
    // No, we want to auto-redirect TO login.

    // Let's make a simple async check here
    await Future.delayed(
      const Duration(milliseconds: 100),
    ); // wait for ApiService loadConfig might be racey.

    // Better: explicit check
    final apiService = ref.read(apiServiceProvider);

    // We need to wait for prefs to load in apiService.
    // Let's re-instantiate ApiService or make it async init.
    // For now, let's just proceed. The user will be redirected to Login if fetches fail?
    // No, UX: Open App -> Login.

    setState(() {
      _appRouter = GoRouter(
        initialLocation: '/',
        redirect: (context, state) async {
          // 使用 SharedPreferences 检�?V2Board token
          final prefs = await SharedPreferences.getInstance();
          final isLoggedIn = prefs.getString('v2board_token') != null;
          final isLoggingIn = state.uri.toString() == '/login';

          if (!isLoggedIn && !isLoggingIn) return '/login';
          if (isLoggedIn && isLoggingIn) return '/';
          return null;
        },
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          ShellRoute(
            builder: (context, state, child) {
              return MainLayout(child: child);
            },
            routes: [
              GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
              GoRoute(
                path: '/proxies',
                builder: (_, __) => const ProxiesScreen(),
              ),
              GoRoute(
                path: '/profiles',
                builder: (_, __) => const ProfilesScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_appRouter == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
        debugShowCheckedModeBanner: false,
      );
    }

    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'SLux',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _appRouter,
    );
  }
}
