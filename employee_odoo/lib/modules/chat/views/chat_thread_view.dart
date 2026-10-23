import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../controllers/chatter_controller.dart';
import '../../../core/utils/responsive.dart';

class ChatThreadView extends StatefulWidget {
  const ChatThreadView({
    super.key,
    required this.channelId,
    required this.title,
    this.imageBase64,
  });

  final int channelId;
  final String title;
  final String? imageBase64;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _controller = Get.find<ChatterController>();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.openThread(widget.channelId);
    ever(_controller.threadMessages, (_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.closeThread();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    await _controller.sendMessage(widget.channelId, text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            _ThreadAvatar(imageBase64: widget.imageBase64, name: widget.title),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: AppTextStyles.style(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: ResponsiveBody(child: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_controller.isLoadingThread.value && _controller.threadMessages.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue));
              }
              if (_controller.threadMessages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet — say hello!',
                    style: AppTextStyles.style(fontSize: 13, color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: _controller.threadMessages.length,
                itemBuilder: (context, index) => _MessageBubble(message: _controller.threadMessages[index]),
              );
            }),
          ),
          _buildInputBar(),
        ],
      )),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.style(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    hintText: 'Message',
                    hintStyle: AppTextStyles.style(fontSize: 14, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() => Material(
              color: AppColors.brandBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _controller.isSending.value ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _controller.isSending.value
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({this.imageBase64, required this.name});

  final String? imageBase64;
  final String name;

  @override
  Widget build(BuildContext context) {
    final safe = OdooImage.sanitize(imageBase64);
    if (safe != null) {
      return CircleAvatar(radius: 18, backgroundImage: MemoryImage(base64Decode(safe)));
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white.withValues(alpha: 0.25),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatterMessage message;

  String _formatTime(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? AppColors.brandBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 14),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.authorName,
                  style: AppTextStyles.style(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brandOrange),
                ),
              ),
            Text(
              message.body,
              style: AppTextStyles.style(fontSize: 14, color: isMine ? Colors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(message.date),
                style: AppTextStyles.style(
                  fontSize: 10,
                  color: isMine ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}