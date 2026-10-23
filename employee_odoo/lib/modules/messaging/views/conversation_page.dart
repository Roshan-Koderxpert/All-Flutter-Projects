import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_back_button.dart';
import '../controllers/messaging_controller.dart';
import '../../../core/utils/responsive.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.conversation});

  final Map<String, dynamic> conversation;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _controller = Get.find<MessagingController>();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  int get _channelId => widget.conversation['id'] as int;

  @override
  void initState() {
    super.initState();
    _controller.currentConversation.value = widget.conversation;
    _controller.loadConversationMessages(_channelId);
    _controller.startMessagePolling(_channelId);
    _controller.markAsRead(_channelId);
  }

  @override
  void dispose() {
    _controller.stopMessagePolling();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    final success = await _controller.sendMessage(_channelId, text);
    if (!mounted) return;

    setState(() => _sending = false);

    if (success) {
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
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

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String _authorName(dynamic authorId) {
    if (authorId is List && authorId.length > 1) {
      return authorId[1].toString();
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.conversation['name']?.toString() ?? 'Conversation';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const AppBackButton(color: Colors.white),
        title: Text(
          name,
          style: AppTextStyles.style(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1F5786),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ResponsiveBody(child: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_controller.isLoadingMessages.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1F5786)),
                );
              }

              final messages = _controller.conversationMessages;
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet. Say hello!',
                    style: AppTextStyles.style(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final body = _stripHtml(msg['body']?.toString() ?? '');
                  if (body.isEmpty) return const SizedBox.shrink();

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _authorName(msg['author_id']),
                            style: AppTextStyles.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F5786),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: AppTextStyles.style(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          _buildInputBar(),
        ],
      )),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _sendMessage,
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: Color(0xFF1F5786)),
          ),
        ],
      ),
    );
  }
}
