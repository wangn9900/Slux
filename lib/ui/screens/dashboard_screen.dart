import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../providers/proxy_provider.dart';
import '../../data/models/proxy_node.dart';
import '../../data/managers/core_manager.dart';
import '../../providers/singbox_provider.dart';
import '../../core/config_generator.dart';
import '../../providers/v2board_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/subscribe_parser.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Stats
  String _upSpeed = '0 B/s';
  String _downSpeed = '0 B/s';
  WebSocket? _trafficSocket;

  @override
  void initState() {
    super.initState();
    // Start core update check
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(coreManagerProvider.notifier).checkAndDownload();
        if (mounted) _loadNodesFromV2Board();
      } catch (e) {
        if (kDebugMode) print('Update check failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _stopTrafficMonitor(fromDispose: true);
    super.dispose();
  }

  Future<void> _loadNodesFromV2Board() async {
    try {
      final v2board = ref.read(v2boardServiceProvider);

      final subContent = await v2board.fetchSubscriptionContent();
      if (subContent == null || subContent.isEmpty) {
        if (mounted) {
          ref
              .read(proxyProvider.notifier)
              .setError('Failed to fetch subscription');
        }
        return;
      }

      final nodes = await _parseSubscription(subContent);
      if (nodes.isEmpty) {
        if (mounted) {
          ref
              .read(proxyProvider.notifier)
              .setError('No nodes found in subscription');
        }
        return;
      }

      if (mounted) {
        ref.read(proxyProvider.notifier).updateNodes(nodes);
      }
    } catch (e) {
      if (mounted) {
        ref.read(proxyProvider.notifier).setError(e.toString());
      }
    }
  }

  Future<List<ProxyNode>> _parseSubscription(String content) async {
    return SubscribeParser.parse(content);
  }

  void _startTrafficMonitor() async {
    _stopTrafficMonitor();
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      _trafficSocket = await WebSocket.connect('ws://127.0.0.1:9090/traffic');
      _trafficSocket!.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            if (mounted) {
              setState(() {
                _upSpeed = _formatSpeed(json['up']);
                _downSpeed = _formatSpeed(json['down']);
              });
            }
          } catch (e) {
            // ignore parse error
          }
        },
        onError: (e) {
          if (kDebugMode) print("Traffic WS Error: $e");
        },
        onDone: () {
          if (kDebugMode) print("Traffic WS Closed");
        },
      );
    } catch (e) {
      if (kDebugMode) print("Failed to connect to traffic WS: $e");
    }
  }

  void _stopTrafficMonitor({bool fromDispose = false}) {
    if (_trafficSocket != null) {
      _trafficSocket!.close();
      _trafficSocket = null;
    }
    if (!fromDispose && mounted) {
      setState(() {
        _upSpeed = '0 B/s';
        _downSpeed = '0 B/s';
      });
    }
  }

  String _formatSpeed(dynamic bytes) {
    if (bytes == null) return '0 B/s';
    int b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b B/s';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB/s';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final coreState = ref.watch(coreManagerProvider);
    final isUpdateError =
        coreState.statusMessage.toLowerCase().contains('failed') ||
            coreState.statusMessage.toLowerCase().contains('error');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Top Update Bar
          if (coreState.isUpdating)
            Container(
              width: double.infinity,
              color: Colors.blue.withOpacity(0.1),
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  '正在更新核心: ${coreState.progress.toStringAsFixed(1)}%...',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ),
          if (isUpdateError)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.all(8),
              child: const Center(
                child: Text(
                  '核心更新检查失败 (网络错误)',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),

          // Main Connect Area
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ConnectButtonHelper(
                    onConnect: _startTrafficMonitor,
                    onDisconnect: _stopTrafficMonitor,
                  ),

                  const SizedBox(height: 32),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CompactStat(
                        label: '下行',
                        value: _downSpeed,
                        icon: LucideIcons.download,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 24),
                      _CompactStat(
                        label: '上行',
                        value: _upSpeed,
                        icon: LucideIcons.upload,
                        color: Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  _NodeSelector(),

                  const SizedBox(height: 24),

                  _ModeSwitcher(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitcher extends StatefulWidget {
  @override
  State<_ModeSwitcher> createState() => _ModeSwitcherState();
}

class _ModeSwitcherState extends State<_ModeSwitcher> {
  String _mode = '规则';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton('规则', _mode == '规则'),
          Container(
            width: 1,
            height: 20,
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          _buildButton('全局', _mode == '全局'),
        ],
      ),
    );
  }

  Widget _buildButton(String text, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() => _mode = text);
        // TODO: Switch mode API
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

class _ConnectButtonHelper extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectButtonHelper({
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return _ConnectButton(onConnect: onConnect, onDisconnect: onDisconnect);
  }
}

class _ConnectButton extends ConsumerStatefulWidget {
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectButton({required this.onConnect, required this.onDisconnect});

  @override
  ConsumerState<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<_ConnectButton>
    with SingleTickerProviderStateMixin {
  bool isConnected = false;
  bool isConnecting = false;

  @override
  Widget build(BuildContext context) {
    // Listen for node changes to dynamically switch while connected
    ref.listen<ProxyState>(proxyProvider, (previous, next) {
      if (isConnected &&
          next.selectedNode != null &&
          next.selectedNode?.name != previous?.selectedNode?.name) {
        _switchNode(next.selectedNode!.name);
      }
    });

    return GestureDetector(
      onTap: isConnecting ? null : _toggleConnection,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isConnected
                ? [const Color(0xFF10B981), const Color(0xFF059669)] // Green
                : [const Color(0xFF3B82F6), const Color(0xFF2563EB)], // Blue
          ),
          boxShadow: [
            BoxShadow(
              color: (isConnected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF3B82F6))
                  .withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isConnecting)
              const CircularProgressIndicator(color: Colors.white)
            else ...[
              Icon(
                LucideIcons.power,
                size: 40,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(height: 8),
              Text(
                isConnected ? '已连接' : '点击连接',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              if (isConnected)
                const Text(
                  'CONNECTED',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _switchNode(String tag) async {
    try {
      final client = HttpClient();
      final request = await client.openUrl(
        'PUT',
        Uri.parse('http://127.0.0.1:9090/proxies/proxy'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'name': tag}));
      final response = await request.close();
      if (response.statusCode == 204) {
        if (kDebugMode) print('Success switch to $tag');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已切换节点: $tag'),
              duration: const Duration(milliseconds: 1000),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (kDebugMode) print('Switch failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Switch API Error: $e');
    }
  }

  Future<void> _toggleConnection() async {
    final singbox = ref.read(singboxServiceProvider);

    final updateState = ref.read(coreManagerProvider);
    if (updateState.isUpdating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot connect while core is updating.')),
      );
      return;
    }

    setState(() => isConnecting = true);

    try {
      if (isConnected) {
        await singbox.stop();
        setState(() => isConnected = false);
        widget.onDisconnect();
      } else {
        final v2board = ref.read(v2boardServiceProvider);
        final proxyState = ref.read(proxyProvider);

        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('v2board_token') == null) {
          final logged = await _showLoginDialog();
          if (!logged) {
            setState(() => isConnecting = false);
            return;
          }
        }

        List<ProxyNode> nodes = proxyState.nodes;

        if (nodes.isEmpty) {
          final subContent = await v2board.fetchSubscriptionContent();
          if (subContent == null || subContent.isEmpty) {
            throw Exception('Failed to fetch subscription');
          }
          nodes = await _parseSubscription(subContent);
          if (nodes.isEmpty) throw Exception('No nodes found');
          ref.read(proxyProvider.notifier).updateNodes(nodes);
        }

        // 读取广告拦截设置
        final blockAds = prefs.getBool('blockAds') ?? false;

        final configJson = ConfigGenerator.generate(
          nodes,
          selectedNodeTag: proxyState.selectedNode?.name,
          blockAds: blockAds,
        );

        final appDir = await getApplicationSupportDirectory();
        final configPath = p.join(appDir.path, 'config.json');
        await File(configPath).writeAsString(configJson);

        await singbox.start(configPath);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!singbox.isRunning) {
          throw Exception(
            'Sing-box core crashed immediately. See logs for details.',
          );
        }

        setState(() => isConnected = true);
        widget.onConnect();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => isConnecting = false);
    }
  }

  Future<bool> _showLoginDialog() async {
    final emailCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    bool success = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('V2Board 登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: '邮箱'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pwdCtrl,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(v2boardServiceProvider);
              final resp = await service.login(
                email: emailCtrl.text.trim(),
                password: pwdCtrl.text,
              );
              if (resp != null) {
                success = true;
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('登录成功')));
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('登录失败')));
                }
              }
              Navigator.of(c).pop();
            },
            child: const Text('登录'),
          ),
        ],
      ),
    );
    return success;
  }

  Future<List<ProxyNode>> _parseSubscription(String content) async {
    return SubscribeParser.parse(content);
  }
}

class _NodeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyState = ref.watch(proxyProvider);
    final selectedNode = proxyState.selectedNode;

    return GestureDetector(
      onTap: () {
        if (proxyState.nodes.isNotEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => _NodeSelectionDialog(nodes: proxyState.nodes),
          );
        }
      },
      child: Container(
        width: 400,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.globe,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前节点',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (proxyState.isLoading)
                    const Text(
                      'Loading nodes...',
                      style: TextStyle(fontSize: 14),
                    )
                  else if (proxyState.error != null)
                    Text(
                      proxyState.error!.contains('No nodes')
                          ? '暂无节点 (请先登录)'
                          : 'Error loading nodes',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    )
                  else
                    Text(
                      selectedNode?.name ?? '请选择节点',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeSelectionDialog extends ConsumerStatefulWidget {
  final List<ProxyNode> nodes;
  const _NodeSelectionDialog({super.key, required this.nodes});

  @override
  ConsumerState<_NodeSelectionDialog> createState() =>
      _NodeSelectionDialogState();
}

class _NodeSelectionDialogState extends ConsumerState<_NodeSelectionDialog> {
  final Map<String, int> _latencies = {};
  final Set<String> _loadingInfo = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testAllLatencies();
    });
  }

  Future<void> _testAllLatencies() async {
    for (final node in widget.nodes) {
      if (!mounted) return;
      _testNode(node);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _testNode(ProxyNode node) async {
    if (!mounted) return;
    setState(() {
      _loadingInfo.add(node.name);
    });

    try {
      // Priority 1: Try Sing-box API (Real HTTP Delay)
      final encodedName = Uri.encodeComponent(node.name);
      final url =
          'http://127.0.0.1:9090/proxies/$encodedName/delay?url=http://www.gstatic.com/generate_204&timeout=2500';
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        final delay = json['delay'] as int;
        if (mounted) {
          setState(() {
            _latencies[node.name] = delay;
            _loadingInfo.remove(node.name);
          });
        }
      } else {
        // API failed (e.g. core not running), fallback to TCP Ping
        await _tcpPing(node);
      }
    } catch (e) {
      // API error (e.g. connection refused), fallback to TCP Ping
      await _tcpPing(node);
    }
  }

  Future<void> _tcpPing(ProxyNode node) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        node.server,
        node.port,
        timeout: const Duration(milliseconds: 2000),
      );
      socket.destroy();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _latencies[node.name] = stopwatch.elapsedMilliseconds;
          _loadingInfo.remove(node.name);
        });
      }
    } catch (e) {
      // TCP Ping failed
      stopwatch.stop();
      if (mounted) {
        setState(() {
          // Mark as failed (remove from loading, latency remains null)
          _loadingInfo.remove(node.name);
        });
      }
    }
  }

  Color _getDelayColor(int delay) {
    if (delay < 400) return Colors.green;
    if (delay < 800) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("选择节点"),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.nodes.length,
          itemBuilder: (ctx, index) {
            final node = widget.nodes[index];
            final delay = _latencies[node.name];
            final isLoading = _loadingInfo.contains(node.name);
            final isSelected =
                ref.read(proxyProvider).selectedNode?.name == node.name;

            return ListTile(
              title: Text(
                node.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primary : null,
                ),
              ),
              subtitle: Text(node.type.toUpperCase()),
              trailing: SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (delay != null)
                      Text(
                        '${delay}ms',
                        style: TextStyle(
                          color: _getDelayColor(delay),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else // Not tested yet or failed
                      const Text('-', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              onTap: () {
                ref.read(proxyProvider.notifier).selectNode(node);
                Navigator.pop(ctx);
              },
            );
          },
        ),
      ),
    );
  }
}
