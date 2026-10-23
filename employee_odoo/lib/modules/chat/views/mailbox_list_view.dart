import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../controllers/chatter_controller.dart';
import 'chat_thread_view.dart';
import '../../../core/utils/responsive.dart';

class MailboxListView extends StatefulWidget {
  const MailboxListView({super.key, required this.box, required this.title});

  /// 'inbox' | 'starred' | 'history'
  final String box;
  final String title;

  @override
  State<MailboxListView> createState() => _MailboxListViewState();
}

class _MailboxListViewState extends State<MailboxListView> {
  final _controller = Get.find<ChatterController>();
  List<MailboxMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await _controller.fetchMailbox(widget.box);
    if (!mounted) return;
    setState(() {
      _messages = results;
      _loading = false;
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _openMessage(MailboxMessage m) {
    if (m.isChannelMessage) {
      Get.to(() => ChatThreadView(channelId: m.resId, title: m.recordName ?? 'Chat'));
    } else {
      Get.snackbar(
        m.recordName ?? 'Record',
        'This message is on a record that can\'t be opened here yet.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppMainAppBar(title: widget.title),
      body: ResponsiveBody(child: RefreshIndicator(
        color: AppColors.brandBlue,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
            : _messages.isEmpty
            ? ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 44, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('Nothing here', style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final m = _messages[index];
            return Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openMessage(m),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.authorName,
                              style: AppTextStyles.style(fontSize: 13.5, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(_formatDate(m.date), style: AppTextStyles.style(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                      if (m.recordName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          m.recordName!,
                          style: AppTextStyles.style(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.brandBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        m.body,
                        style: AppTextStyles.style(fontSize: 13, color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      )),
    );
  }
}