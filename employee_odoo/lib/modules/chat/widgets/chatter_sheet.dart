import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../controllers/chatter_controller.dart';
import '../views/chat_thread_view.dart';
import '../views/mailbox_list_view.dart';
import '../views/new_chat_picker_view.dart';

Future<void> showChatterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ChatterSheet(),
  );
}

class ChatterSheet extends StatefulWidget {
  const ChatterSheet({super.key});

  @override
  State<ChatterSheet> createState() => _ChatterSheetState();
}

class _ChatterSheetState extends State<ChatterSheet> {
  late final ChatterController _controller;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ChatterController>()
        ? Get.find<ChatterController>()
        : Get.put(ChatterController(), permanent: true);
    _controller.loadConversations();
    _controller.startListPolling();
  }

  @override
  void dispose() {
    _controller.stopListPolling();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) => setState(() => _query = value);

  List<ChatterConversation> get _filteredConversations {
    if (_query.trim().isEmpty) return _controller.conversations;
    final q = _query.trim().toLowerCase();
    return _controller.conversations.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  List<ChatterConversation> get _channels => _filteredConversations.where((c) => !c.isDirect).toList();
  List<ChatterConversation> get _directMessages => _filteredConversations.where((c) => c.isDirect).toList();

  void _openMailbox(String box, String title) {
    Navigator.of(context).pop();
    Get.to(() => MailboxListView(box: box, title: title));
  }

  Future<void> _openThread(int channelId, String title, String? imageBase64) async {
    Navigator.of(context).pop();
    await Get.to(() => ChatThreadView(channelId: channelId, title: title, imageBase64: imageBase64));
    _controller.loadConversations();
  }

  void _openNewChatPicker() {
    Navigator.of(context).pop();
    Get.to(() => const NewChatPickerView());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text('Chats', style: AppTextStyles.style(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_comment_rounded, color: AppColors.brandBlue),
                      tooltip: 'New chat',
                      onPressed: _openNewChatPicker,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Obx(() => Column(
                  children: [
                    _MailboxRow(
                      icon: Icons.inbox_rounded,
                      label: 'Inbox',
                      count: _controller.inboxCount.value,
                      onTap: () => _openMailbox('inbox', 'Inbox'),
                    ),
                    _MailboxRow(
                      icon: Icons.star_rounded,
                      label: 'Starred',
                      count: _controller.starredCount.value,
                      onTap: () => _openMailbox('starred', 'Starred'),
                    ),
                    _MailboxRow(
                      icon: Icons.history_rounded,
                      label: 'History',
                      count: 0,
                      onTap: () => _openMailbox('history', 'History'),
                    ),
                  ],
                )),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 20, color: AppColors.brandBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: AppTextStyles.style(fontSize: 13.5),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            hintText: 'Search your chats',
                            hintStyle: AppTextStyles.style(fontSize: 13, color: AppColors.textSecondary),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Obx(() {
                  final channels = _channels;
                  final directMessages = _directMessages;
                  final nothingAtAll = channels.isEmpty && directMessages.isEmpty;

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    children: [
                      _SectionHeader(title: 'Channels'),
                      if (channels.isNotEmpty)
                        for (final c in channels) _ConversationTile(conversation: c, onTap: () => _openThread(c.id, c.name, c.imageBase64))
                      else if (!_controller.isLoadingConversations.value)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Text('No channels', style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary)),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _SectionHeader(title: 'Direct Messages')),
                          TextButton.icon(
                            onPressed: _openNewChatPicker,
                            icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.brandBlue),
                            label: Text('New', style: AppTextStyles.style(fontSize: 12.5, color: AppColors.brandBlue)),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                        ],
                      ),
                      if (directMessages.isNotEmpty)
                        for (final c in directMessages) _ConversationTile(conversation: c, onTap: () => _openThread(c.id, c.name, c.imageBase64))
                      else if (!_controller.isLoadingConversations.value)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Text(
                            _query.trim().isEmpty ? 'No direct messages yet' : 'No chats match "$_query"',
                            style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ),
                      if (nothingAtAll && _controller.isLoadingConversations.value)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: CircularProgressIndicator(color: AppColors.brandBlue)),
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MailboxRow extends StatelessWidget {
  const _MailboxRow({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.brandBlue),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.brandOrange, borderRadius: BorderRadius.circular(20)),
                  constraints: const BoxConstraints(minWidth: 22),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.style(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Text(
        title,
        style: AppTextStyles.style(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final ChatterConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              _Avatar(imageBase64: conversation.imageBase64, name: conversation.name, isChannel: !conversation.isDirect),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.name,
                      style: AppTextStyles.style(
                        fontSize: 14.5,
                        fontWeight: conversation.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conversation.isDirect ? 'Direct message' : 'Channel',
                      style: AppTextStyles.style(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (conversation.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.brandOrange, borderRadius: BorderRadius.circular(20)),
                  constraints: const BoxConstraints(minWidth: 22),
                  child: Text(
                    conversation.unreadCount > 9 ? '9+' : '${conversation.unreadCount}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.style(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.imageBase64, required this.name, required this.isChannel});

  final String? imageBase64;
  final String name;
  final bool isChannel;

  @override
  Widget build(BuildContext context) {
    final safe = OdooImage.sanitize(imageBase64);
    if (safe != null) {
      return CircleAvatar(radius: 24, backgroundImage: MemoryImage(base64Decode(safe)));
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: isChannel ? AppColors.brandBlueLight.withValues(alpha: 0.15) : AppColors.brandOrange.withValues(alpha: 0.12),
      child: isChannel
          ? const Icon(Icons.tag_rounded, size: 20, color: AppColors.brandBlue)
          : Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.style(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandOrange),
      ),
    );
  }
}