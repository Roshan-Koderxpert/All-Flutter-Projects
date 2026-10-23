import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_back_button.dart';
import '../controllers/messaging_controller.dart';
import 'conversation_page.dart';
import '../../../core/utils/responsive.dart';

class NewMessagePage extends StatefulWidget {
  const NewMessagePage({super.key});

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _controller = Get.find<MessagingController>();
  final _searchController = TextEditingController();
  final _channelNameController = TextEditingController();
  final _channelDescController = TextEditingController();

  List<Map<String, dynamic>> _partners = [];
  bool _searching = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _channelNameController.dispose();
    _channelDescController.dispose();
    super.dispose();
  }

  Future<void> _searchPartners(String query) async {
    if (query.trim().length < 2) {
      setState(() => _partners = []);
      return;
    }

    setState(() => _searching = true);
    final results = await _controller.searchPartners(query);
    if (!mounted) return;
    setState(() {
      _partners = results;
      _searching = false;
    });
  }

  Future<void> _startDirectChat(int partnerId, String name) async {
    setState(() => _creating = true);
    final channelId = await _controller.createDirectMessage(partnerId);
    if (!mounted) return;
    setState(() => _creating = false);

    if (channelId != null) {
      Get.off(() => ConversationPage(conversation: {
            'id': channelId,
            'name': name,
            'channel_type': 'chat',
          }));
    } else {
      Get.snackbar('Error', 'Could not start chat', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _createChannel() async {
    final name = _channelNameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Error', 'Channel name is required', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _creating = true);
    final channelId = await _controller.createChannel(
      name,
      _channelDescController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _creating = false);

    if (channelId != null) {
      Get.off(() => ConversationPage(conversation: {
            'id': channelId,
            'name': name,
            'channel_type': 'channel',
            'description': _channelDescController.text.trim(),
          }));
    } else {
      Get.snackbar('Error', 'Could not create channel', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const AppBackButton(color: Colors.white),
        title: Text(
          'New Message',
          style: AppTextStyles.style(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1F5786),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Direct Message'),
            Tab(text: 'New Channel'),
          ],
        ),
      ),
      body: ResponsiveBody(child: _creating
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F5786)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDirectMessageTab(),
                _buildChannelTab(),
              ],
            )),
    );
  }

  Widget _buildDirectMessageTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _searchPartners,
          ),
        ),
        if (_searching) const LinearProgressIndicator(color: Color(0xFF1F5786)),
        Expanded(
          child: _partners.isEmpty
              ? Center(
                  child: Text(
                    'Search for a contact by name',
                    style: AppTextStyles.style(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: _partners.length,
                  itemBuilder: (context, index) {
                    final partner = _partners[index];
                    final name = partner['name']?.toString() ?? 'Unknown';
                    final email = partner['email']?.toString() ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1F5786).withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTextStyles.style(color: const Color(0xFF1F5786)),
                        ),
                      ),
                      title: Text(name, style: AppTextStyles.style(fontWeight: FontWeight.w600)),
                      subtitle: email.isNotEmpty
                          ? Text(email, style: AppTextStyles.style(fontSize: 13))
                          : null,
                      trailing: const Icon(Icons.chat_bubble_outline),
                      onTap: () => _startDirectChat(partner['id'] as int, name),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChannelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _channelNameController,
            decoration: InputDecoration(
              labelText: 'Channel Name',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _channelDescController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createChannel,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F5786),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Channel'),
          ),
        ],
      ),
    );
  }
}
