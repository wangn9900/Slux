import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/v2board_provider.dart';
import 'ticket_detail_screen.dart';

class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key});

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  bool _loading = false;
  List<dynamic>? _tickets;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);
    try {
      final tickets = await service.fetchTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _tickets?.sort(
            (a, b) => (b['updated_at'] ?? 0).compareTo(a['updated_at'] ?? 0),
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading tickets: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTicket() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String level = '2'; // Default: General

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建工单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '请输入工单标题',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: level,
                decoration: const InputDecoration(labelText: '优先级'),
                items: const [
                  DropdownMenuItem(value: '0', child: Text('低')),
                  DropdownMenuItem(value: '1', child: Text('中')),
                  DropdownMenuItem(value: '2', child: Text('高')),
                ],
                onChanged: (val) => setState(() => level = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: '问题描述',
                  hintText: '请详细描述您遇到的问题',
                ),
                maxLines: 3,
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
                if (titleController.text.isEmpty ||
                    messageController.text.isEmpty)
                  return;
                Navigator.pop(context);
                final service = ref.read(v2boardServiceProvider);
                final success = await service.createTicket(
                  titleController.text,
                  level,
                  messageController.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '工单创建成功' : '创建失败'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  if (success) _loadTickets();
                }
              },
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的工单'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          FilledButton.icon(
            onPressed: _createTicket,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('新建工单'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading && _tickets == null
          ? const Center(child: CircularProgressIndicator())
          : (_tickets == null || _tickets!.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.ticket,
                    size: 64,
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无工单记录',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTickets,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _tickets!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final req = _tickets![index];
                  // 0:待处理 1:已回复 2:已关闭
                  final status = req['status'] ?? 0;
                  Color statusColor;
                  String statusText;
                  switch (status) {
                    case 0:
                      statusColor = Colors.orange;
                      statusText = '待处理';
                      break;
                    case 1:
                      statusColor = Colors.green;
                      statusText = '已回复';
                      break;
                    default:
                      statusColor = Colors.grey;
                      statusText = '已关闭';
                      break;
                  }

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.5,
                        ),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TicketDetailScreen(
                              ticketId: req['id'],
                              subject: req['subject'] ?? '工单详情',
                            ),
                          ),
                        ).then((_) => _loadTickets());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    req['subject'] ?? '无标题',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '最后更新: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch((req['updated_at'] ?? 0) * 1000))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
