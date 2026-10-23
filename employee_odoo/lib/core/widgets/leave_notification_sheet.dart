import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/repositories/leave_repository.dart';
import '../../data/models/leave_record.dart';
import '../../modules/auth/controllers/auth_controller.dart';
import '../theme/app_colors.dart';

void showLeaveNotificationSheet(BuildContext context, int leaveId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _LeaveNotificationSheetBody(leaveId: leaveId),
  );
}

class _LeaveNotificationSheetBody extends StatefulWidget {
  const _LeaveNotificationSheetBody({required this.leaveId});
  final int leaveId;

  @override
  State<_LeaveNotificationSheetBody> createState() => _LeaveNotificationSheetBodyState();
}

class _LeaveNotificationSheetBodyState extends State<_LeaveNotificationSheetBody> {
  late final LeaveRepository _repo;


  LeaveRecord? _record;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    final client = Get.find<AuthController>().odooClient;
    _repo = LeaveRepository(client!);
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final record = await _repo.fetchLeaveById(widget.leaveId);
    setState(() {
      _record = record;
      _notFound = record == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
          : _notFound
          ? _buildNotFound(context)
          : _buildDetail(context, _record!),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 32, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('This leave request is no longer available.'),
          const SizedBox(height: 4),
          const Text('It may have been deleted or updated.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context, LeaveRecord r) {
    final stateColor = switch (r.state) {
      LeaveState.approved => Colors.green,
      LeaveState.refused => Colors.red,
      LeaveState.cancelled => Colors.grey,
      _ => Colors.orange,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(r.leaveTypeName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: stateColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(r.state.label,
                  style: TextStyle(color: stateColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _infoRow(Icons.person_outline, 'Employee', r.employeeName),
        _infoRow(Icons.calendar_today_outlined, 'Dates', r.dateRangeLabel),
        _infoRow(Icons.timelapse_outlined, 'Duration', '${r.numberOfDays} day(s)'),
        if (r.description.isNotEmpty)
          _infoRow(Icons.notes_outlined, 'Note', r.description),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}