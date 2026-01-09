import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/v2board_provider.dart';

class TrafficDetailsScreen extends ConsumerStatefulWidget {
  const TrafficDetailsScreen({super.key});

  @override
  ConsumerState<TrafficDetailsScreen> createState() =>
      _TrafficDetailsScreenState();
}

class _TrafficDetailsScreenState extends ConsumerState<TrafficDetailsScreen> {
  bool _loading = false;
  List<dynamic>? _trafficLog;

  @override
  void initState() {
    super.initState();
    _loadTrafficLog();
  }

  Future<void> _loadTrafficLog() async {
    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);
    try {
      final log = await service.getTrafficLog();
      if (log != null && log is List) {
        if (mounted) {
          setState(() {
            _trafficLog = log;
            // Sort by record_at desc
            _trafficLog!.sort(
              (a, b) => (b['record_at'] ?? 0).compareTo(a['record_at'] ?? 0),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading traffic log: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('流量明细'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_trafficLog == null || _trafficLog!.isEmpty)
          ? const Center(child: Text('暂无流量记录'))
          : RefreshIndicator(
              onRefresh: _loadTrafficLog,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _trafficLog!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _trafficLog![index];
                  final recordAt = item['record_at'] ?? 0;
                  final upload = item['u'] ?? 0;
                  final download = item['d'] ?? 0;
                  final total = upload + download;
                  final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(
                    DateTime.fromMillisecondsSinceEpoch(recordAt * 1000),
                  );

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Using surfaceContainerHighest or similar for subtle look
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoColumn(
                                theme,
                                '上传',
                                _formatBytes(upload),
                                null,
                              ),
                              _buildInfoColumn(
                                theme,
                                '下载',
                                _formatBytes(download),
                                null,
                              ),
                              _buildInfoColumn(
                                theme,
                                '总计',
                                _formatBytes(total),
                                theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildInfoColumn(
    ThemeData theme,
    String label,
    String value,
    Color? valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
