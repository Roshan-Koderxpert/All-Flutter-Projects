// ─── Worksheet List View ──────────────────────────────────────────────────────
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/assets.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/order_repository.dart';

class WorksheetListView extends StatefulWidget {
  const WorksheetListView({
    super.key,
    required this.fsmOrderId,
    required this.repository,
  });

  final int fsmOrderId;
  final OrderRepository repository;

  @override
  State<WorksheetListView> createState() => WorksheetListViewState();
}

class WorksheetListViewState extends State<WorksheetListView> {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final rows = await widget.repository.fetchWorksheetRecords(
        fsmOrderId: widget.fsmOrderId,
      );
      if (mounted) setState(() => _records = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '${AppStrings.orderWorksheetLoadFailed} $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null || raw == false) return '-';
    final s = raw.toString();
    final dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (dt == null) return s;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        toolbarHeight: 20,
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Image.asset(
                    AppImage.back,
                    width: 25,
                    height: 25,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.orderWorksheetListTitle,
                    style: AppTextStyles.h1.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final created = await Get.to<bool>(
                      () => WorksheetFormView(
                        fsmOrderId: widget.fsmOrderId,
                        repository: widget.repository,
                      ),
                    );
                    if (created == true) {
                      await _load();
                    }
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      AppStrings.orderFilterNew,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          _error,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _records.isEmpty
                        ? Center(
                            child: Text(
                              AppStrings.orderWorksheetNoRecords,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textHint,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _records.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final rec = _records[i];
                                final name = rec['x_name']?.toString() ?? '-';
                                final createdOn = _formatDate(rec['create_date']);
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final id = rec['id'];
                                    final recId =
                                        id is int ? id : int.tryParse('$id');
                                    if (recId == null) return;
                                    await Get.to(
                                      () => WorksheetFormView(
                                        recordId: recId,
                                        recordName: name,
                                        fsmOrderId: widget.fsmOrderId,
                                        repository: widget.repository,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark ? AppColors.darkCard : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : const Color(0xFFEDEDED),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: AppTextStyles.h3.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${AppStrings.orderWorksheetColCreatedOn}: $createdOn',
                                                style:
                                                    AppTextStyles.bodySmall.copyWith(
                                                  color: isDark
                                                      ? AppColors.darkTextSecondary
                                                      : AppColors.textHint,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textHint,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Worksheet Form View (Dynamic Fields) ─────────────────────────────────────
class WorksheetFormView extends StatefulWidget {
  const WorksheetFormView({
    super.key,
    this.recordId,
    this.recordName = '',
    required this.fsmOrderId,
    required this.repository,
  });

  final int? recordId;
  final String recordName;
  final int fsmOrderId;
  final OrderRepository repository;

  @override
  State<WorksheetFormView> createState() => WorksheetFormViewState();
}

class WorksheetFormViewState extends State<WorksheetFormView> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';
  List<String> _userFields = [];
  Map<String, dynamic> _fieldsMeta = {};
  final Map<String, dynamic> _values = {};
  final Map<String, dynamic> _editedValues = {};
  final Map<String, TextEditingController> _controllers = {};
  bool get _isCreateMode => widget.recordId == null;
  final Map<String, SignatureController> _sigControllers = {};
  final Map<String, bool> _sigDrawMode = {};


  // Fields to always skip in the form
  static const _skipFields = <String>{
    'id', 'create_uid', 'write_uid', '__last_update',
    'x_fsm_order_id',
    'x_name', 'name', 'create_date', 'write_date',
  };
  static const _skipPrefixes = <String>[
    '__', 'write_', 'message_', 'activity_', 'website_',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    for (final c in _sigControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final detail = _isCreateMode
          ? await widget.repository.fetchWorksheetCreateDetail(
        fsmOrderId: widget.fsmOrderId,
      )
          : await widget.repository.fetchWorksheetRecordDetail(
        fsmOrderId: widget.fsmOrderId,
        recordId: widget.recordId!,
      );

      if (detail == null) {
        if (mounted) {
          setState(() => _error = AppStrings.orderWorksheetFormLoadFailed);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _fieldsMeta =
          Map<String, dynamic>.from(detail['fields_meta'] as Map);
          _values
            ..clear()
            ..addAll(Map<String, dynamic>.from(detail['values'] as Map));

          final rawList = List<String>.from(detail['user_fields'] as List);

          // Step 1: basic filter + deduplicate
          final seenFields = <String>{};
          final filtered = rawList.where((k) {
            if (_skipFields.contains(k)) return false;
            if (_skipPrefixes.any((p) => k.startsWith(p))) return false;
            return seenFields.add(k);
          }).toList();

          // Step 2: whitelist by arch + sort
          final viewOrder = detail['view_field_order'];
          if (viewOrder is List && viewOrder.isNotEmpty) {
            final orderList =
            viewOrder.map((e) => e.toString()).toList();
            final orderSet = orderList.toSet();

            // Keep ONLY fields that exist in the form view arch
            final whitelisted =
            filtered.where((k) => orderSet.contains(k)).toList();

            // Sort by arch order
            final orderMap = <String, int>{};
            for (int i = 0; i < orderList.length; i++) {
              orderMap[orderList[i]] = i;
            }
            whitelisted.sort((a, b) =>
                (orderMap[a] ?? 9999).compareTo(orderMap[b] ?? 9999));

            _userFields = whitelisted;
          } else {
            // No arch available — use filtered as-is
            _userFields = filtered;
          }

          _editedValues
            ..clear()
            ..addAll(_values);
        });
        _syncControllers();
      }
    } catch (e) {
      if (mounted) {
        setState(
                () => _error = '${AppStrings.orderWorksheetFormLoadFailed}: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncControllers() {
    for (final key in _userFields) {
      final type = _fieldType(key);
      if (type == 'boolean' || type == 'selection') continue;
      final c = _controllers.putIfAbsent(key, TextEditingController.new);
      c.text = _textFor(key, _editedValues[key]);
    }
  }

  String _textFor(String key, dynamic value) {
    if (value == null || value == false) return '';
    if (_fieldType(key) == 'many2one' && value is List && value.length >= 2) {
      return value[1]?.toString() ?? '';
    }
    final raw = value.toString();
    final type = _fieldType(key);
    if (type == 'html' || _looksLikeHtml(raw)) {
      return _stripHtml(raw);
    }
    return raw;
  }

  bool _looksLikeHtml(String v) {
    return RegExp(r'<[^>]+>').hasMatch(v);
  }

  String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  dynamic _valueForWrite(String key) {
    final type = _fieldType(key);

    if (type == 'boolean') return (_editedValues[key] as bool?) ?? false;

    if (type == 'selection') {
      final v = _editedValues[key];
      if (v == null || v == false) return false;
      final s = v.toString().trim();
      return s.isEmpty ? false : s;
    }

    if (type == 'many2one') return false; // read-only in form

    if (type == 'many2many') {
      final v = _editedValues[key];
      if (v is List && v.isNotEmpty) {
        final ids = v
            .map((e) => e is int ? e : int.tryParse('$e'))
            .whereType<int>()
            .toList();
        return [
          [6, 0, ids]
        ];
      }
      return [
        [6, 0, <int>[]]
      ];
    }

    if (type == 'one2many') return false; // read-only

    if (type == 'binary') {
      final v = _editedValues[key];
      if (v == null || v == false || v.toString().isEmpty) return false;
      return v; // already base64 string
    }

    if (type == 'date' || type == 'datetime') {
      final v = _editedValues[key];
      if (v == null || v == false || v.toString().isEmpty) return false;
      return v.toString();
    }

    final text = _controllers[key]?.text.trim() ?? '';
    if (text.isEmpty) return false;
    if (type == 'integer') return int.tryParse(text) ?? false;
    if (type == 'float' || type == 'monetary') return double.tryParse(text) ?? false;
    return text;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{'x_fsm_order_id': widget.fsmOrderId};
      for (final key in _userFields) {
        payload[key] = _valueForWrite(key);
      }

      var savedOffline = false;
      if (_isCreateMode) {
        final created = await widget.repository.createWorksheetRecord(
          fsmOrderId: widget.fsmOrderId,
          values: payload,
        );
        if (created == null) throw Exception('create failed');
        savedOffline = created < 0;
      } else {
        final ok = await widget.repository.updateWorksheetRecord(
          fsmOrderId: widget.fsmOrderId,
          recordId: widget.recordId!,
          values: payload,
        );
        if (!ok) throw Exception('save failed');
        if (Get.isRegistered<ConnectivityService>()) {
          savedOffline = !Get.find<ConnectivityService>().isOnline.value;
        }
      }
      if (!mounted) return;
      if (savedOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved offline. Worksheet will sync when you are back online.',
            ),
          ),
        );
      }
      Get.back(result: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _fieldLabel(String key) {
    final meta = _fieldsMeta[key];
    if (meta is Map) {
      final s = meta['string']?.toString();
      if (s != null && s.isNotEmpty) return s;
    }
    // Fallback: clean up key name
    return key
        .replaceAll('x_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _fieldType(String key) {
    final meta = _fieldsMeta[key];
    if (meta is Map) return meta['type']?.toString() ?? 'char';
    return 'char';
  }

  String _binaryWidget(String key) {
    final meta = _fieldsMeta[key];
    if (meta is Map) {
      final w = meta['widget']?.toString() ?? '';
      if (w == 'signature') return 'signature';
      if (w == 'image') return 'image';
      if (w == 'pdf_viewer' || w == 'binary' || w == 'document') return 'file';
    }
    final lower = key.toLowerCase();
    if (lower.contains('image') ||
        lower.contains('photo') ||
        lower.contains('picture') ||
        lower.contains('logo') ||
        lower.contains('avatar') ||
        lower.contains('thumbnail')) return 'image';
    if (lower.contains('file') ||
        lower.contains('attachment') ||
        lower.contains('document') ||
        lower.contains('pdf')) return 'file';
    // All other binary fields (signature, sign, drawing, etc.)
    // default to signature widget — covers x_signature, x_sign,
    // x_customer_signature, custom names, everything
    return 'signature';
  }

  Widget _buildField(bool isDark, String key) {
    final label = _fieldLabel(key);
    final type = _fieldType(key);
    final metaRaw = _fieldsMeta[key];
    final meta =
    metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final requiredField = meta['required'] == true;

    Widget input;

    if (type == 'boolean') {
      final current = (_editedValues[key] as bool?) ?? false;
      input = SwitchListTile(
        value: current,
        onChanged: (v) => setState(() => _editedValues[key] = v),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(current ? 'Yes' : 'No'),
      );
    } else if (type == 'selection') {
      final options = <MapEntry<String, String>>[];
      final sel = meta['selection'];
      if (sel is List) {
        for (final s in sel) {
          if (s is List && s.length >= 2) {
            options.add(MapEntry(s[0].toString(), s[1]?.toString() ?? s[0].toString()));
          }
        }
      }
      final current = _editedValues[key]?.toString();
      input = DropdownButtonFormField<String>(
        value: options.any((e) => e.key == current) ? current : null,
        decoration: _inputDecoration(isDark),
        items: options
            .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) => setState(() => _editedValues[key] = v),
      );
    } else if (type == 'date' || type == 'datetime') {
      input = _buildDateTimeField(isDark, key, isDateTime: type == 'datetime');
    } else if (type == 'binary') {
      final widget = _binaryWidget(key);
      if (widget == 'signature') {
        input = _buildSignatureField(isDark, key);
      } else if (widget == 'image') {
        input = _buildImageField(isDark, key);
      } else {
        input = _buildFileField(isDark, key);
      }
    } else if (type == 'many2one') {
      final display = _textFor(key, _editedValues[key]);
      input = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          display.isEmpty ? '-' : display,
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
          ),
        ),
      );
    } else if (type == 'many2many' || type == 'one2many') {
      final raw = _editedValues[key];
      final items = raw is List ? raw : [];
      input = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: items.isEmpty
            ? Text(
          'No items',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
          ),
        )
            : Wrap(
          spacing: 6,
          runSpacing: 4,
          children: items.map<Widget>((item) {
            final displayText = item is List && item.length >= 2
                ? item[1].toString()
                : item.toString();
            return Chip(
              label: Text(displayText, style: const TextStyle(fontSize: 12)),
              backgroundColor:
              isDark ? AppColors.darkSurface2 : const Color(0xFFE8E8E8),
            );
          }).toList(),
        ),
      );
    } else {
      // char, text, html, integer, float, monetary
      final c = _controllers.putIfAbsent(key, TextEditingController.new);
      TextInputType keyboard = TextInputType.text;
      int? maxLines = 1;

      if (type == 'text' || type == 'html') {
        maxLines = 4;
        keyboard = TextInputType.multiline;
      } else if (type == 'integer') {
        keyboard = TextInputType.number;
      } else if (type == 'float' || type == 'monetary') {
        keyboard = const TextInputType.numberWithOptions(decimal: true);
      }

      input = TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        minLines: maxLines == null ? 3 : null,
        onChanged: (v) => _editedValues[key] = v,
        decoration: _inputDecoration(isDark),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiredField ? '$label *' : label,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color:
              isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          input,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) => InputDecoration(
    filled: true,
    fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _buildDateTimeField(bool isDark, String key, {required bool isDateTime}) {
    final raw = _editedValues[key];
    String display = '';
    if (raw != null && raw != false && raw.toString().isNotEmpty) {
      final dt = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
      if (dt != null) {
        final l = dt.toLocal();
        String two(int n) => n.toString().padLeft(2, '0');
        display = isDateTime
            ? '${l.year}-${two(l.month)}-${two(l.day)}  ${two(l.hour)}:${two(l.minute)}'
            : '${l.year}-${two(l.month)}-${two(l.day)}';
      }
    }
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked == null || !mounted) return;
        if (isDateTime) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (time == null || !mounted) return;
          final combined = DateTime(
              picked.year, picked.month, picked.day, time.hour, time.minute);
          // Store as UTC string for Odoo
          setState(() => _editedValues[key] = combined.toUtc().toIso8601String());
        } else {
          String two(int n) => n.toString().padLeft(2, '0');
          setState(() =>
          _editedValues[key] =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                display.isEmpty ? 'Select ${isDateTime ? 'date & time' : 'date'}' : display,
                style: TextStyle(
                  color: display.isEmpty
                      ? (isDark ? AppColors.darkTextSecondary : AppColors.textHint)
                      : (isDark ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
            Icon(
              isDateTime ? Icons.calendar_month_rounded : Icons.calendar_today_rounded,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureField(bool isDark, String key) {
    final existing = _editedValues[key];

    // Safely decode — value can be false (Odoo), null, empty, or real base64
    Uint8List? existingBytes;
    if (existing != null && existing != false) {
      final str = existing.toString().trim();
      if (str.isNotEmpty) {
        try {
          existingBytes = base64Decode(str);
        } catch (_) {
          existingBytes = null;
        }
      }
    }

    final isDrawMode = _sigDrawMode[key] ?? false;

    final controller = _sigControllers.putIfAbsent(
      key,
          () => SignatureController(
        penStrokeWidth: 2.5,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── View / Placeholder mode ────────────────────────────────
        if (!isDrawMode) ...[
          GestureDetector(
            onTap: () => _showSignatureOptions(isDark, key, controller),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.white,
                border: Border.all(
                  color: existingBytes != null
                      ? (isDark ? AppColors.darkBorder : const Color(0xFFD0D0D0))
                      : AppColors.primary.withOpacity(0.4),
                  width: existingBytes != null ? 1 : 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: existingBytes != null
              // ── Existing signature → show it ─────────────────
                  ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.memory(
                      existingBytes,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Small edit badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Change',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
              // ── No signature → placeholder ───────────────────
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.draw_rounded,
                      size: 40,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textHint),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to sign',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Draw or upload your signature',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Remove button only when signed
          if (existingBytes != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  controller.clear();
                  setState(() {
                    _editedValues[key] = false;
                    _sigDrawMode.remove(key);
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Remove Signature'),
                style:
                TextButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
            ),
        ],

        // ── Draw mode ──────────────────────────────────────────────
        if (isDrawMode) ...[
          // Label bar
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.draw_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Sign below',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => controller.clear(),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Canvas
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white, // always white — like real signature pad
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 1),
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: ClipRRect(
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(10)),
              child: Signature(
                controller: controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Cancel / Confirm
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    controller.clear();
                    setState(() => _sigDrawMode[key] = false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (!controller.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                            Text('Please draw your signature first')),
                      );
                      return;
                    }
                    final bytes = await controller.toPngBytes();
                    if (bytes == null || !mounted) return;
                    setState(() {
                      _editedValues[key] = base64Encode(bytes);
                      _sigDrawMode[key] = false;
                    });
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showSignatureOptions(
      bool isDark, String key, SignatureController controller) {
    // Capture the scaffold context BEFORE entering the bottom sheet builder
    final scaffoldContext = context;

    showModalBottomSheet<void>(
      context: scaffoldContext,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBorder
                        : const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Signature',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Draw ──────────────────────────────────────────
                InkWell(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.clear();
                    setState(() => _sigDrawMode[key] = true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.draw_rounded,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Draw',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary)),
                            Text('Sign with your finger on screen',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textHint)),
                          ],
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textHint),
                      ],
                    ),
                  ),
                ),

                Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : const Color(0xFFEEEEEE)),

                // ── Upload ────────────────────────────────────────
                InkWell(
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 90,
                      );
                      if (file == null) return;
                      final bytes = await file.readAsBytes();
                      if (!mounted) return;
                      setState(() {
                        _editedValues[key] = base64Encode(bytes);
                        _sigDrawMode[key] = false;
                      });
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(content: Text('Could not load image: $e')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.photo_library_rounded,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Upload',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary)),
                            Text('Pick from gallery',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textHint)),
                          ],
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textHint),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageField(bool isDark, String key) {
    final existing = _editedValues[key];
    final hasExisting = existing != null &&
        existing != false &&
        existing.toString().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasExisting)
          Container(
            height: 160,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(existing.toString()),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final file =
                  await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (file == null || !mounted) return;
                  final bytes = await file.readAsBytes();
                  setState(() => _editedValues[key] = base64Encode(bytes));
                },
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Choose Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (hasExisting) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _editedValues[key] = false),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFileField(bool isDark, String key) {
    final existing = _editedValues[key];
    final hasFile = existing != null &&
        existing != false &&
        existing.toString().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            hasFile ? Icons.attach_file_rounded : Icons.upload_file_rounded,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasFile ? 'File attached' : 'No file (manage from web)',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        toolbarHeight: 20,
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Image.asset(
                    AppImage.back,
                    width: 25,
                    height: 25,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.recordName.isNotEmpty
                        ? widget.recordName
                        : AppStrings.orderWorksheetFormTitle,
                    style: AppTextStyles.h1.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          _error,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _userFields.isEmpty
                        ? Center(
                            child: Text(
                              AppStrings.orderWorksheetNoRecords,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textHint,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _userFields
                                        .map((key) => _buildField(isDark, key))
                                        .toList(),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isSaving ? null : () => Get.back(),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.primary),
                                          minimumSize: const Size.fromHeight(46),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isSaving ? null : _save,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: AppColors.primary,
                                          disabledForegroundColor: Colors.white,
                                          minimumSize: const Size.fromHeight(46),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(_isSaving ? 'Saving...' : 'Save'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}