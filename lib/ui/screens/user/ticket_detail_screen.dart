import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/v2board_provider.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final int ticketId;
  final String subject;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.subject,
  });

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  bool _loading = false;
  List<dynamic>? _messages;
  final _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final service = ref.read(v2boardServiceProvider);
    try {
      final detail = await service.getTicketDetail(widget.ticketId);
      if (detail != null && mounted) {
        setState(() {
          // Assuming detail is List of messages or Map with 'message' list
          if (detail is List) {
            _messages = detail;
          } else if (detail is Map && detail['message'] is List) {
            _messages = detail['message'];
          } else {
            _messages = [];
          }
          // Sort messages by created_at asc usually
          // But V2Board usually returns desc? Let's check. Assuming ASC for chat.
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading ticket detail: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final msg = _replyController.text.trim();
    if (msg.isEmpty) return;

    _replyController.clear();
    final service = ref.read(v2boardServiceProvider);

    // Optimistic UI? Or just wait. Wait is safer.
    final success = await service.replyTicket(widget.ticketId, msg);

    if (success && mounted) {
      _loadMessages();
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('回复失败')));
    }
  }

  Future<void> _closeTicket() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭工单'),
        content: const Text('确定要关闭此工单吗？'),
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
    final service = ref.read(v2boardServiceProvider);
    final success = await service.closeTicket(widget.ticketId);
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('工单已关闭')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.xCircle, color: Colors.red),
            tooltip: '关闭工单',
            onPressed: _closeTicket,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _messages == null
                ? const Center(child: CircularProgressIndicator())
                : (_messages == null || _messages!.isEmpty)
                ? const Center(child: Text('暂无消息'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages!.length,
                    itemBuilder: (context, index) {
                      final msg = _messages![index];
                      final isMe =
                          msg['is_me'] == true ||
                          msg['user_id'] !=
                              0; // V2Board logic depending on version
                      // Usually `is_me` provided? Or check user_id vs admin_id.
                      // Actually, standard V2Board: user messages have user_id != 0? Or maybe reply structure.
                      // Let's assume standard V2Board message structure:
                      // { "message": "...", "is_me": true/false, "created_at": ... } usually.
                      // If `is_me` is missing, we check if `user_id` matches current user?
                      // Or simply: if it's admin reply, `user_id` might be null or 0?

                      // Simplified assumption based on common implementations:
                      final isUser =
                          (msg['user_id'] != null &&
                          msg['user_id'] !=
                              0); // Not always true if structure differs
                      // Assuming response adds `is_me`. If not, we might need logic.
                      // Let's use left/right bubbles generically.

                      return _buildMessageBubble(context, msg, isUser);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: '输入回复内容...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendReply,
                  icon: const Icon(LucideIcons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    Map<String, dynamic> msg,
    bool isMe,
  ) {
    final theme = Theme.of(context);
    // If msg['is_me'] exists use it, otherwise fallback to logic (User > 0 usually means user sent it, 0 means system/admin)
    final bool actuallyIsMe = msg.containsKey('is_me')
        ? msg['is_me']
        : (msg['user_id'] != 0);

    return Align(
      alignment: actuallyIsMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: actuallyIsMe
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: actuallyIsMe ? Radius.zero : const Radius.circular(16),
            bottomLeft: actuallyIsMe ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['message'] ?? '',
              style: TextStyle(
                color: actuallyIsMe
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MM-dd HH:mm').format(
                DateTime.fromMillisecondsSinceEpoch(
                  (msg['created_at'] ?? 0) * 1000,
                ),
              ),
              style: TextStyle(
                fontSize: 10,
                color: actuallyIsMe
                    ? theme.colorScheme.onPrimary.withOpacity(0.7)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
