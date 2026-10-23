import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_back_button.dart';
import '../controllers/messaging_controller.dart';
import 'conversation_page.dart';
import 'new_message_page.dart';
import '../../../core/utils/responsive.dart';

class MessagingMainPage extends StatefulWidget {
  const MessagingMainPage({super.key});

  @override
  State<MessagingMainPage> createState() => _MessagingMainPageState();
}

class _MessagingMainPageState extends State<MessagingMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MessagingController _controller;

  static const _gradientStart = Color(0xFF1F5786);
  static const _gradientEnd = Color(0xFFF06022);

  @override
  void initState() {
    super.initState();
    _controller = Get.put(MessagingController());
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gradientStart, _gradientEnd],
            ),
          ),
        ),
        title: Text(
          'Messages',
          style: AppTextStyles.style(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _buildPillTab('All', Icons.forum_rounded, 0),
                const SizedBox(width: 8),
                _buildPillTab('Chats', Icons.chat_rounded, 1),
                const SizedBox(width: 8),
                _buildPillTab('Channels', Icons.tag_rounded, 2),
              ],
            ),
          ),
        ),
      ),
      body: ResponsiveBody(child: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTab(),
          _buildChatsTab(),
          _buildChannelsTab(),
        ],
      )),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: FloatingActionButton.extended(
          onPressed: () => Get.to(() => const NewMessagePage()),
          backgroundColor: _gradientEnd,
          icon: const Icon(Icons.edit, color: Colors.white),
          label: Text(
            'New Message',
            style: AppTextStyles.style(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillTab(String label, IconData icon, int index) {
    final isSelected = _tabController.index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? _gradientStart : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.style(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? _gradientStart : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllTab() {
    return Obx(() {
      if (_controller.isRefreshing.value && _controller.allConversations.isEmpty) {
        return _buildLoading();
      }
      if (_controller.allConversations.isEmpty) {
        return _buildEmptyState('No conversations yet', Icons.chat_bubble_outline);
      }
      return RefreshIndicator(
        color: _gradientStart,
        onRefresh: _controller.loadAllConversations,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 80),
          itemCount: _controller.allConversations.length,
          itemBuilder: (context, index) =>
              _buildConversationItem(_controller.allConversations[index]),
        ),
      );
    });
  }

  Widget _buildChatsTab() {
    return Obx(() {
      if (_controller.isLoadingChats.value && _controller.directMessages.isEmpty) {
        return _buildLoading();
      }
      if (_controller.directMessages.isEmpty) {
        return _buildEmptyState('No chats yet', Icons.chat);
      }
      return RefreshIndicator(
        color: _gradientStart,
        onRefresh: _controller.loadDirectMessages,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 80),
          itemCount: _controller.directMessages.length,
          itemBuilder: (context, index) =>
              _buildConversationItem(_controller.directMessages[index]),
        ),
      );
    });
  }

  Widget _buildChannelsTab() {
    return Obx(() {
      if (_controller.isLoadingChannels.value && _controller.channels.isEmpty) {
        return _buildLoading();
      }
      if (_controller.channels.isEmpty) {
        return _buildEmptyState('No channels yet', Icons.tag);
      }
      return RefreshIndicator(
        color: _gradientStart,
        onRefresh: _controller.loadChannels,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 80),
          itemCount: _controller.channels.length,
          itemBuilder: (context, index) =>
              _buildConversationItem(_controller.channels[index]),
        ),
      );
    });
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _gradientStart),
          const SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: AppTextStyles.style(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final name = conversation['name'] ?? 'Unknown';
    final channelType = conversation['channel_type'] ?? 'channel';
    final isChannel = channelType == 'channel';
    final description = conversation['description'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.to(() => ConversationPage(conversation: conversation)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isChannel
                          ? [_gradientStart, const Color(0xFF2D6FA3)]
                          : [_gradientEnd, const Color(0xFFF07842)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isChannel ? Icons.tag_rounded : Icons.person_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: AppTextStyles.style(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (description is String && description.isNotEmpty)
                            ? description
                            : (isChannel ? 'Channel' : 'Direct message'),
                        style: AppTextStyles.style(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _gradientStart.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: _gradientStart.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: AppTextStyles.style(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.to(() => const NewMessagePage()),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('New Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gradientStart,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
