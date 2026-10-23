import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../theme/text_styles.dart';
import '../../data/repositories/chatter_repository.dart';

class ChatterWidget extends StatefulWidget {
  final String model;
  final int recordId;

  const ChatterWidget({
    super.key,
    required this.model,
    required this.recordId,
  });

  @override
  State<ChatterWidget> createState() => _ChatterWidgetState();
}

class _ChatterWidgetState extends State<ChatterWidget> {
  final ChatterRepository _repo = Get.find<ChatterRepository>();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // Tab: 0 = Send Message, 1 = Log Note, 2 = Activity
  int _tab = 0;

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _activityTypes = [];
  List<Map<String, dynamic>> _users = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollCtrl.addListener(() {
      // reverse list: load more when near top (high pixels value)
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMessages(),
      _loadActivityTypes(),
      _loadUsers(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMessages() async {
    _offset = 0;
    _hasMore = true;
    final msgs = await _repo.fetchMessages(
      model: widget.model,
      recordId: widget.recordId,
      limit: _limit,
      offset: 0,
    );

    // Fetch clean partner names
    final partnerIds = msgs
        .map((m) {
      final a = m['author_id'];
      return (a is List && a.isNotEmpty && a.first is int) ? a.first as int : null;
    })
        .whereType<int>()
        .toSet()
        .toList();

    final nameMap = await _repo.fetchPartnerNames(partnerIds);

    // Inject clean name back into each message
    final enriched = msgs.map((m) {
      final copy = Map<String, dynamic>.from(m);
      final a = copy['author_id'];
      if (a is List && a.isNotEmpty && a.first is int) {
        final cleanName = nameMap[a.first as int];
        if (cleanName != null) {
          copy['author_id'] = [a.first, cleanName];
        }
      }
      return copy;
    }).toList();

    if (!mounted) return;
    setState(() {
      _messages = enriched;
      _offset = msgs.length;
      if (msgs.length < _limit) _hasMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    final msgs = await _repo.fetchMessages(
      model: widget.model,
      recordId: widget.recordId,
      limit: _limit,
      offset: _offset,
    );
    if (!mounted) return;
    setState(() {
      _messages.addAll(msgs);
      _offset += msgs.length;
      if (msgs.length < _limit) _hasMore = false;
    });
  }

  Future<void> _loadActivityTypes() async {
    final types = await _repo.fetchActivityTypes();
    if (!mounted) return;
    setState(() => _activityTypes = types);
  }

  Future<void> _loadUsers() async {
    final users = await _repo.fetchUsers();
    if (!mounted) return;
    setState(() => _users = users);
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    final ok = await _repo.postMessage(
      model: widget.model,
      recordId: widget.recordId,
      body: text,
      isNote: _tab == 1,
    );
    if (ok) {
      _msgCtrl.clear();
      FocusScope.of(context).unfocus();
      await _loadMessages();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
    if (mounted) setState(() => _isSending = false);
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  String _formatMsgDate(dynamic date) {
    if (date == null) return '';
    try {
      String s = date.toString();
      if (!s.endsWith('Z') && !s.contains('+')) s = '${s}Z';
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      final time = DateFormat('h:mm a').format(dt);
      if (msgDay == today) return 'Today at $time';
      if (msgDay == today.subtract(const Duration(days: 1))) {
        return 'Yesterday at $time';
      }
      return '${DateFormat('MMM dd, yyyy').format(dt)} at $time';
    } catch (_) {
      return '';
    }
  }

  String _dateHeader(dynamic date) {
    if (date == null) return '';
    try {
      String s = date.toString();
      if (!s.endsWith('Z') && !s.contains('+')) s = '${s}Z';
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      if (msgDay == today) return 'Today';
      if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
      return DateFormat('EEEE, MMMM dd, yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }



  String _cleanHtml(String? html) {
    if (html == null) return '';
    return html.replaceAll(RegExp(r'<[^>]*>', multiLine: true), '').trim();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
      ),
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Tab pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _tabPill('Send Message', 0),
                  const SizedBox(width: 8),
                  _tabPill('Log Note', 1),
                  const SizedBox(width: 8),
                  _tabPill('Activity', 2),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),

// Content
            Expanded(
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary))
                  : _tab == 2
                  ? _buildActivityForm()
                  : _buildMessagesView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(String label, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _tab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _tab = index);
        if (index == 2) _showActivityDialog();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected
                ? AppColors.white
                : (isDark ? AppColors.darkTextSecondary : const Color(0xFF999999)),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
  // ── Messages view ─────────────────────────────────────────────────────────

  Widget _buildMessagesView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 56,
                    color: isDark ? AppColors.darkPrimary : Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No messages yet',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ],
            ),
          )
              : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadMessages,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  // messages in chronological order (oldest first = top)
                  ..._messages.reversed.toList().asMap().entries.map((entry) {
                    final idx = entry.key;
                    final msg = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (idx == 0 ||
                            _dateHeader(msg['date']) !=
                                _dateHeader(_messages.reversed.toList()[idx - 1]['date']))
                          _buildDateDivider(_dateHeader(msg['date'])),
                        _buildMessageItem(msg),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // Input box
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            border: Border(
                top: BorderSide(color: isDark ? AppColors.darkPrimary : Colors.grey[200]!)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkInputFill : const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: null,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: _tab == 1
                          ? 'Write a note...'
                          : 'Write a message...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextHint : Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _tab == 1
                        ? AppColors.stageInProgress
                        : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateDivider(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: isDark ? AppColors.darkDivider : Colors.grey[300])),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: isDark ? AppColors.darkDivider : Colors.grey[300])),
        ],
      ),
    );
  }


  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = _cleanHtml(msg['body']?.toString());
    final trackingRaw = msg['_tracking_lines'];
    final trackingLines = trackingRaw is List
        ? trackingRaw
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];
    final authorId = msg['author_id'];

    // Extract only the person name — take only first part before " - "
    // Odoo sometimes returns "Mitchell Admin - My Company" format
    final rawName = authorId is List && authorId.length > 1
        ? authorId[1].toString()
        : 'Unknown';
    final authorName = rawName.contains(' - ')
        ? rawName.split(' - ').first.trim()
        : rawName.trim();

    final date = _formatMsgDate(msg['date']);
    final isNote = msg['message_type']?.toString() == 'notification';
    final avatarRaw = msg['author_avatar'];
    final hasAvatar = avatarRaw is String && avatarRaw.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rectangular rounded avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              color: isNote
                  ? (isDark ? AppColors.darkWarningLight : Colors.orange[100])
                  : (isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface),
              child: hasAvatar
                  ? Image.memory(
                base64Decode(avatarRaw),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    authorName.isNotEmpty
                        ? authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isNote
                          ? (isDark ? AppColors.darkWarningText : Colors.orange[700])
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              )
                  : Center(
                child: Text(
                  authorName.isNotEmpty
                      ? authorName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: isNote
                        ? (isDark ? AppColors.darkWarningText : Colors.orange[700])
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + NOTE badge + time — all in one row
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            authorName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          if (isNote) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkWarningLight : Colors.orange[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'NOTE',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkWarningText : Colors.orange[700],
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      date,
                      style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.darkTextHint : Colors.grey[500]),
                    ),
                  ],
                ),
                // User text / HTML body
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppTextStyles.bodyMedium.copyWith(
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey[700],
                    ),
                  ),
                ],
                // Odoo field tracking (stage changes, etc.) — often no `body` text.
                if (trackingLines.isNotEmpty) ...[
                  if (body.isNotEmpty) const SizedBox(height: 6),
                  ...trackingLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $line',
                        style: AppTextStyles.bodyMedium.copyWith(
                          height: 1.35,
                          color: isDark ? AppColors.darkTextSecondary : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Activity placeholder (shown before dialog) ────────────────────────────

  Widget _buildActivityForm() {
    return Center(
      child: TextButton.icon(
        onPressed: _showActivityDialog,
        icon: const Icon(Icons.event_note,
            color: AppColors.primary),
        label: const Text('Schedule Activity',
            style: TextStyle(color: AppColors.primary)),
      ),
    );
  }

  // ── Activity dialog ───────────────────────────────────────────────────────

  void _showActivityDialog() {
    int? selectedTypeId;
    int? selectedUserId;
    DateTime? selectedDeadline;
    final summaryCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) {
            final isDark = Theme
                .of(ctx)
                .brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 40),
              child: Container(
                constraints: const BoxConstraints(
                    maxWidth: 500, maxHeight: 700),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isDark
                      ? Border.all(color: AppColors.darkBorder)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_note,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Schedule Activity',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              if (mounted) setState(() => _tab = 0);
                            },
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            _dialogLabel('Activity Type *'),
                            const SizedBox(height: 6),
                            _dialogDropdown<int>(
                              hint: 'Select activity type',
                              value: selectedTypeId,
                              items: _activityTypes
                                  .map((t) =>
                                  DropdownMenuItem<int>(
                                    value: t['id'] as int?,
                                    child: Text(
                                        t['name']?.toString() ??
                                            ''),
                                  ))
                                  .toList(),
                              onChanged: (v) =>
                                  setS(() => selectedTypeId = v),
                            ),
                            const SizedBox(height: 16),
                            _dialogLabel('Summary *'),
                            const SizedBox(height: 6),
                            _dialogTextField(summaryCtrl,
                                'Brief description'),
                            const SizedBox(height: 16),
                            _dialogLabel('Assigned To'),
                            const SizedBox(height: 6),
                            _dialogDropdown<int>(
                              hint: 'Select user',
                              value: selectedUserId,
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Unassigned'),
                                ),
                                ..._users.map((u) =>
                                    DropdownMenuItem<int>(
                                      value: u['id'] as int?,
                                      child: Text(
                                          u['name']?.toString() ??
                                              ''),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setS(() => selectedUserId = v),
                            ),
                            const SizedBox(height: 16),
                            _dialogLabel('Due Date *'),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDeadline ??
                                      DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(
                                      days: 365)),
                                );
                                if (picked != null) {
                                  setS(() =>
                                  selectedDeadline = picked);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isDark ? Border.all(color: AppColors.darkBorder) : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 16,
                                        color: isDark ? AppColors.darkTextHint : Colors.grey),
                                    const SizedBox(width: 10),
                                    Text(
                                      selectedDeadline == null
                                          ? 'Select date'
                                          : DateFormat('dd/MM/yyyy').format(selectedDeadline!),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: selectedDeadline == null
                                            ? (isDark ? AppColors.darkTextHint : Colors.grey[400])
                                            : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _dialogLabel('Note'),
                            const SizedBox(height: 6),
                            _dialogTextField(noteCtrl,
                                'Additional details',
                                maxLines: 3),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : Colors.grey[50],
                        border: Border(
                            top: BorderSide(
                                color: isDark ? AppColors.darkDivider : Colors.grey[200]!)),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                if (mounted) {
                                  setState(() => _tab = 0);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                side: BorderSide(
                                    color: isDark ? AppColors.darkBorder : Colors.grey[300]!),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                              ),
                              child: Text('Cancel',
                                  style: AppTextStyles.labelMedium.copyWith(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                if (selectedTypeId == null) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Select activity type')));
                                  return;
                                }
                                if (summaryCtrl.text
                                    .trim()
                                    .isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Enter summary')));
                                  return;
                                }
                                if (selectedDeadline == null) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                      content:
                                      Text('Select due date')));
                                  return;
                                }
                                Navigator.of(ctx).pop();
                                final ok = await _repo.scheduleActivity(
                                  model: widget.model,
                                  recordId: widget.recordId,
                                  activityTypeId: selectedTypeId!,
                                  deadline: selectedDeadline!,
                                  summary: summaryCtrl.text.trim(),
                                  note: noteCtrl.text
                                      .trim()
                                      .isNotEmpty
                                      ? noteCtrl.text.trim()
                                      : null,
                                  userId: selectedUserId,
                                );
                                if (mounted) setState(() => _tab = 0);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(ok
                                      ? 'Activity scheduled!'
                                      : 'Failed to schedule activity'),
                                  backgroundColor:
                                  ok ? AppColors.success : AppColors.error,
                                ));
                              },
                              child: const Text('Schedule',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      ),

    ).then((_) {
      if (mounted && _tab == 2) setState(() => _tab = 0);
    });
  }

  // ── Dialog helpers ────────────────────────────────────────────────────────

  Widget _dialogLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
    );
  }

  Widget _dialogTextField(
      TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium.copyWith(
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.darkTextHint : Colors.grey[400]),
        filled: true,
        fillColor: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: isDark ? const BorderSide(color: AppColors.darkBorder) : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: isDark ? const BorderSide(color: AppColors.darkBorder) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dialogDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: isDark ? AppColors.darkSurface2 : AppColors.white,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          hint: Text(hint,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextHint : Colors.grey[400])),
          items: items,
          onChanged: onChanged,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}