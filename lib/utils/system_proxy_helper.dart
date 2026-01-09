import 'dart:io';

class SystemProxyHelper {
  /// 强制关闭 Windows 系统代理
  /// 用于处理非正常退出后导致的代理残留问题
  static Future<void> disableSystemProxy() async {
    if (Platform.isWindows) {
      try {
        // 直接修改注册表关闭代理开关
        // ProxyEnable = 0
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '0',
          '/f',
        ], runInShell: true);
        print('System proxy disabled via registry clean-up.');
      } catch (e) {
        print('Failed to disable system proxy: $e');
      }
    }
  }
}
