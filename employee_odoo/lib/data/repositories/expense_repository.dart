import 'dart:convert';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/expense_approval_item.dart';
import '../models/expense_record.dart';
import '../../core/utils/api_logger.dart';
import '../models/expense_sheet.dart';

class ExpenseModuleUnavailable implements Exception {}

/// The Expenses app is installed, but this account may not read it. A rights
/// problem, which needs a different answer than "ask your admin to install it".
class ExpenseAccessDenied implements Exception {}

/// This database has no expense-report model (`hr.expense.sheet`). Odoo 19
/// dropped it — an expense now carries its own approval state — so the
/// report screens do not apply.
class ExpenseReportsUnsupported implements Exception {}

class ExpenseAttachment {
  final int id;
  final String name;
  final String mimetype;

  ExpenseAttachment({required this.id, required this.name, required this.mimetype});
}

class ExpenseRepository {
  final OdooClient _client;
  ExpenseRepository(this._client);
  static const _fields = [
    'id', 'name', 'product_id', 'price_unit',
    'total_amount', 'total_amount_currency', 'date', 'state', 'employee_id',
    'sheet_id',
  ];

  /// What `hr.expense` actually offers on this database, discovered once from
  /// `fields_get`.
  ///
  /// Odoo renames and drops fields between versions -- `sheet_id` is gone on
  /// Odoo 19 -- and `search_read` fails the *entire* request if a single
  /// requested field is unknown. So the field list is intersected with what
  /// the server reports instead of being hard-coded.
  /// Schema cache, per server **and per model**. Odoo renames fields and
  /// moves whole models between versions, so nothing about the expense
  /// workflow is assumed — it is read from the database in use.
  static final Map<String, _ModelMeta> _metaCache = {};

  /// Forget cached schemas — call on logout or when switching database.
  static void resetMetaCache() => _metaCache.clear();

  String _metaKey(String model) => '${_client.baseURL}|$model';

  String? get _sheetLinkField =>
      _metaCache[_metaKey('hr.expense')]?.sheetLinkField;

  /// Reads a model's fields and its `state` labels once. A model that doesn't
  /// exist on this version caches as [_ModelMeta.absent] instead of retrying.
  Future<_ModelMeta> _modelMeta(String model) async {
    final key = _metaKey(model);
    final cached = _metaCache[key];
    if (cached != null) return cached;

    try {
      final result = await _client.callKw({
        'model': model,
        'method': 'fields_get',
        'args': [<String>[], ['type', 'relation', 'selection']],
        'kwargs': {},
      });
      if (result is! Map) {
        return _metaCache[key] = const _ModelMeta.absent();
      }

      final names = <String>{};
      final stateLabels = <String, String>{};
      String? sheetLink;
      for (final entry in result.entries) {
        final name = entry.key.toString();
        names.add(name);
        final info = entry.value;
        if (info is! Map) continue;
        if (info['type'] == 'many2one' &&
            info['relation'] == 'hr.expense.sheet') {
          sheetLink = name;
        }
        if (name == 'state' && info['selection'] is List) {
          for (final option in info['selection'] as List) {
            if (option is List && option.length >= 2) {
              stateLabels[option[0].toString()] = option[1].toString();
            }
          }
        }
      }

      final meta = _ModelMeta(
        exists: true,
        fields: names,
        stateLabels: stateLabels,
        sheetLinkField: sheetLink,
      );
      ApiLogger.info(
        '$model meta: ${names.length} fields, states=${stateLabels.keys.toList()}'
        '${model == 'hr.expense' ? ', sheet link => ${sheetLink ?? 'none'}' : ''}',
      );
      return _metaCache[key] = meta;
    } catch (e) {
      // A missing model is the normal answer on some versions, not a failure.
      ApiLogger.info('$model not available here: $e');
      return _metaCache[key] = const _ModelMeta.absent();
    }
  }

  /// Whether this database still has the expense-report model. Odoo 19 removed
  /// `hr.expense.sheet` — each expense carries its own workflow — so the
  /// report screens must stay hidden there rather than 404.
  Future<bool> supportsExpenseReports() async {
    final meta = await _modelMeta('hr.expense.sheet');
    return meta.exists;
  }

  /// The connected database's own `state` labels for `hr.expense`.
  Future<Map<String, String>> _expenseStateLabels() async =>
      (await _modelMeta('hr.expense')).stateLabels;

  /// Requested fields minus anything this database doesn't have, plus the
  /// report link under whatever name it carries here.
  Future<List<String>> _readFields() async {
    final meta = await _modelMeta('hr.expense');
    if (!meta.exists || meta.fields.isEmpty) return _fieldsBasic;

    final fields = _fields.where(meta.fields.contains).toList();
    final link = meta.sheetLinkField;
    if (link != null && !fields.contains(link)) fields.add(link);
    return fields;
  }

  /// Present on every supported Odoo version. Used when the full set above is
  /// refused because this database lacks one of the newer names
  /// (`total_amount_currency` and `price_unit` are Odoo 17+).
  static const _fieldsBasic = [
    'id', 'name', 'product_id', 'total_amount', 'date', 'state', 'employee_id',
  ];

  /// True only when Odoo says the model itself is absent.
  ///
  /// This used to accept a bare '404' anywhere in the message, so any Odoo
  /// traceback that merely mentioned line 404 matched — an ordinary error (a
  /// field this version doesn't have, or an access failure) was then shown to
  /// the user as "your organization hasn't installed Expenses".
  bool _isMissingModelError(Object e) {
    final msg = e.toString();
    if (!msg.contains('hr.expense')) return false;
    return msg.contains("KeyError: 'hr.expense'") ||
        msg.contains('KeyError: "hr.expense"') ||
        msg.contains("Object hr.expense doesn't exist") ||
        msg.contains('Object hr.expense does not exist') ||
        msg.contains('Model not found');
  }

  /// The model exists but this account may not read it.
  bool _isAccessError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('accesserror') ||
        msg.contains('access denied') ||
        msg.contains('not allowed to access') ||
        msg.contains('do not have access');
  }

  /// Logs the real Odoo error, then raises the specific exception the UI knows
  /// how to explain. An unrecognised error is left for the caller to handle.
  void _classify(Object e, StackTrace st, String where) {
    ApiLogger.error('$where raw error', e, st);
    if (_isMissingModelError(e)) throw ExpenseModuleUnavailable();
    if (_isAccessError(e)) throw ExpenseAccessDenied();
  }

  Future<List<ExpenseCategory>> fetchCategories() async {
    try {
      final result = await _client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [['can_be_expensed', '=', true]],
        ],
        'kwargs': {'fields': ['id', 'name'], 'limit': 200},
      });
      if (result is! List) return [];
      return result
          .map((e) => ExpenseCategory(
        id: (e as Map)['id'] as int,
        name: e['name'] as String? ?? '',
      ))
          .toList();
    } catch (e, st) {
      _classify(e, st, 'fetchCategories');
      return [];
    }
  }

  Future<List<ExpenseRecord>> fetchMine(int employeeId) async {
    ApiLogger.info('--- ExpenseRepository.fetchMine emp=$employeeId ---');

    final stateLabels = await _expenseStateLabels();
    final attempts = [await _readFields(), _fieldsBasic];
    for (var i = 0; i < attempts.length; i++) {
      final isLastAttempt = i == attempts.length - 1;
      try {
        final result = await _client.callKw({
          'model': 'hr.expense',
          'method': 'search_read',
          'args': [
            [['employee_id', '=', employeeId]],
          ],
          'kwargs': {'fields': attempts[i], 'order': 'date desc, id desc'},
        });
        if (result is! List) return [];
        final records = result
            .map((e) =>
                ExpenseRecord.fromOdoo(Map<String, dynamic>.from(e as Map),
                stateLabels: stateLabels))
            .toList();
        ApiLogger.info('fetchMine ok emp=$employeeId count=${records.length}');
        return records;
      } catch (e, st) {
        // Rethrows for a truly missing module or an access failure; an
        // unknown-field error falls through to the version-safe field set.
        _classify(e, st, 'fetchMine');
        if (isLastAttempt) return [];
      }
    }
    return [];
  }

  Future<ExpenseRecord?> fetchById(int id) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.expense',
        'method': 'search_read',
        'args': [
          [['id', '=', id]],
        ],
        'kwargs': {'fields': await _readFields(), 'limit': 1},
      });
      if (result is! List || result.isEmpty) return null;
      return ExpenseRecord.fromOdoo(
        Map<String, dynamic>.from(result.first as Map),
        stateLabels: await _expenseStateLabels(),
      );
    } catch (e, st) {
      _classify(e, st, 'fetchById');
      return null;
    }
  }

  Future<int?> createExpense({
    required int employeeId,
    required int categoryId,
    required String description,
    required double amount,
    required DateTime date,
    bool paidByCompany = false,
    String? notes,
    List<int>? receiptBytes,
    String? receiptFileName,
    String? receiptMimeType,
  }) async {
    ApiLogger.info('--- ExpenseRepository.createExpense ---');
    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final id = await _client.callKw({
        'model': 'hr.expense',
        'method': 'create',
        'args': [
          {
            'name': description,
            'employee_id': employeeId,
            'product_id': categoryId,
            'price_unit': amount,
            'total_amount_currency': amount,
            'quantity': 1,
            'date': dateStr,
            'payment_mode': paidByCompany ? 'company_account' : 'own_account',
          }
        ],
        'kwargs': {},
      });
      if (id is! int) return null;

      if (receiptBytes != null && receiptBytes.isNotEmpty) {
        await _client.callKw({
          'model': 'ir.attachment',
          'method': 'create',
          'args': [
            {
              'name': receiptFileName ?? 'receipt',
              'res_model': 'hr.expense',
              'res_id': id,
              'datas': base64Encode(receiptBytes),
              'mimetype': receiptMimeType ?? 'application/octet-stream',
            }
          ],
          'kwargs': {},
        });
      }

      if (notes != null && notes.trim().isNotEmpty) {
        // Posted as a chatter note instead of a guessed field name —
        // works on every Odoo version since mail.thread is always present.
        await _client.callKw({
          'model': 'hr.expense',
          'method': 'message_post',
          'args': [
            [id],
          ],
          'kwargs': {'body': notes.trim()},
        });
      }

      ApiLogger.info('createExpense ok id=$id');
      return id;
    } catch (e, st) {
      // ignore: avoid_print
      print('createExpense RAW error: $e');
      ApiLogger.error('createExpense failed', e, st);
      rethrow;
    }
  }

  Future<List<ExpenseAttachment>> fetchAttachments(int expenseId) async {
    try {
      final result = await _client.callKw({
        'model': 'ir.attachment',
        'method': 'search_read',
        'args': [
          [
            ['res_model', '=', 'hr.expense'],
            ['res_id', '=', expenseId],
          ],
        ],
        'kwargs': {'fields': ['id', 'name', 'mimetype'], 'order': 'id desc'},
      });
      if (result is! List) return [];
      return result
          .map((e) => ExpenseAttachment(
        id: (e as Map)['id'] as int,
        name: e['name'] as String? ?? 'attachment',
        mimetype: e['mimetype'] as String? ?? 'application/octet-stream',
      ))
          .toList();
    } catch (e, st) {
      ApiLogger.error('fetchAttachments failed', e, st);
      return [];
    }
  }

  /// Reads the attachment's binary content via RPC (uses the same
  /// authenticated session as every other call, so it works regardless of
  /// whether the attachment is private).
  Future<List<int>?> downloadAttachment(int attachmentId) async {
    try {
      final result = await _client.callKw({
        'model': 'ir.attachment',
        'method': 'read',
        'args': [
          [attachmentId],
          ['datas'],
        ],
        'kwargs': {},
      });
      if (result is! List || result.isEmpty) return null;
      final row = Map<String, dynamic>.from(result.first as Map);
      final base64Data = row['datas'];
      if (base64Data is! String) return null;
      return base64Decode(base64Data);
    } catch (e, st) {
      ApiLogger.error('downloadAttachment id=$attachmentId failed', e, st);
      return null;
    }
  }

  /// Expenses not yet grouped into a report — these show the checkbox in the UI.
  Future<List<ExpenseRecord>> fetchUnreportedExpenses(int employeeId) async {
    try {
      final fields = await _readFields();
      final stateLabels = await _expenseStateLabels();
      final link = _sheetLinkField;
      final result = await _client.callKw({
        'model': 'hr.expense',
        'method': 'search_read',
        'args': [
          [
            ['employee_id', '=', employeeId],
            // Only filter on the report link where this version has one;
            // `state = draft` already excludes anything submitted.
            if (link != null) [link, '=', false],
            ['state', '=', 'draft'],
          ],
        ],
        'kwargs': {'fields': fields, 'order': 'date desc, id desc'},
      });
      if (result is! List) return [];
      return result
          .map((e) => ExpenseRecord.fromOdoo(Map<String, dynamic>.from(e as Map),
                stateLabels: stateLabels))
          .toList();
    } catch (e, st) {
      _classify(e, st, 'fetchUnreportedExpenses');
      return [];
    }
  }

  /// Groups the given expense lines into a new hr.expense.sheet ("Create Report").
  Future<int?> createReport({
    required int employeeId,
    required String name,
    required List<int> expenseIds,
  }) async {
    // Odoo 19 removed hr.expense.sheet; calling it there returns a bare 404.
    if (!await supportsExpenseReports()) {
      ApiLogger.info('createReport skipped: no expense-report model here');
      throw ExpenseReportsUnsupported();
    }
    try {
      final id = await _client.callKw({
        'model': 'hr.expense.sheet',
        'method': 'create',
        'args': [
          {
            'name': name,
            'employee_id': employeeId,
            'expense_line_ids': [
              [6, 0, expenseIds]
            ],
          }
        ],
        'kwargs': {},
      });
      return id is int ? id : null;
    } catch (e, st) {
      ApiLogger.error('createReport failed', e, st);
      rethrow;
    }
  }

  static const _sheetFields = [
    'id', 'name', 'employee_id', 'user_id', 'payment_mode',
    'state', 'total_amount', 'untaxed_amount', 'expense_line_ids',
  ];

  Future<ExpenseSheet?> fetchSheetById(int sheetId) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.expense.sheet',
        'method': 'search_read',
        'args': [
          [['id', '=', sheetId]],
        ],
        'kwargs': {'fields': _sheetFields, 'limit': 1},
      });
      if (result is! List || result.isEmpty) return null;
      final row = Map<String, dynamic>.from(result.first as Map);

      final lineIds = (row['expense_line_ids'] as List?)?.cast<int>() ?? [];
      List<ExpenseRecord> lines = [];
      if (lineIds.isNotEmpty) {
        final lineResult = await _client.callKw({
          'model': 'hr.expense',
          'method': 'search_read',
          'args': [
            [['id', 'in', lineIds]],
          ],
          'kwargs': {'fields': await _readFields()},
        });
        final stateLabels = await _expenseStateLabels();
        if (lineResult is List) {
          lines = lineResult
              .map((e) => ExpenseRecord.fromOdoo(Map<String, dynamic>.from(e as Map),
                stateLabels: stateLabels))
              .toList();
        }
      }

      return ExpenseSheet.fromOdoo(row, lines);
    } catch (e, st) {
      ApiLogger.error('fetchSheetById id=$sheetId failed', e, st);
      return null;
    }
  }

  /// "Submit to Manager" — moves the sheet from draft to submit, locking it.
  Future<bool> submitSheetToManager(int sheetId) async {
    try {
      await _client.callKw({
        'model': 'hr.expense.sheet',
        'method': 'action_submit_sheet',
        'args': [
          [sheetId]
        ],
        'kwargs': {},
      });
      return true;
    } catch (e, st) {
      ApiLogger.error('submitSheetToManager id=$sheetId failed', e, st);
      rethrow;
    }
  }

  /// "Reset to Draft" — moves a submitted/approved sheet back to draft.
  Future<bool> resetSheetToDraft(int sheetId) async {
    try {
      await _client.callKw({
        'model': 'hr.expense.sheet',
        'method': 'action_reset_expense_sheets',
        'args': [
          [sheetId]
        ],
        'kwargs': {},
      });
      return true;
    } catch (e, st) {
      ApiLogger.error('resetSheetToDraft id=$sheetId failed', e, st);
      rethrow;
    }
  }

  Future<bool> updatePaymentMode(int sheetId, String paymentMode) async {
    try {
      await _client.callKw({
        'model': 'hr.expense.sheet',
        'method': 'write',
        'args': [
          [sheetId],
          {'payment_mode': paymentMode},
        ],
        'kwargs': {},
      });
      return true;
    } catch (e, st) {
      ApiLogger.error('updatePaymentMode id=$sheetId failed', e, st);
      return false;
    }
  }

  /// Generic write for header fields (name, employee_id, user_id).
  Future<bool> updateSheetFields(int sheetId, Map<String, dynamic> values) async {
    try {
      await _client.callKw({
        'model': 'hr.expense.sheet',
        'method': 'write',
        'args': [[sheetId], values],
        'kwargs': {},
      });
      return true;
    } catch (e, st) {
      ApiLogger.error('updateSheetFields id=$sheetId failed', e, st);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchEmployeesForSelection() async {
    try {
      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {'fields': ['id', 'name'], 'limit': 200, 'order': 'name'},
      });
      if (result is! List) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      ApiLogger.error('fetchEmployeesForSelection failed', e, st);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchManagersForSelection() async {
    try {
      final result = await _client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {'fields': ['id', 'name'], 'limit': 200, 'order': 'name'},
      });
      if (result is! List) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      ApiLogger.error('fetchManagersForSelection failed', e, st);
      return [];
    }
  }

  /// Edits an individual expense line (description or amount) while its
  /// sheet is still in draft.
  Future<bool> updateExpenseLine(int expenseId, Map<String, dynamic> values) async {
    try {
      await _client.callKw({
        'model': 'hr.expense',
        'method': 'write',
        'args': [[expenseId], values],
        'kwargs': {},
      });
      return true;
    } catch (e, st) {
      ApiLogger.error('updateExpenseLine id=$expenseId failed', e, st);
      return false;
    }
  }

  /// Removes a line from a draft report entirely.
  Future<bool> deleteExpenseLine(int expenseId) async {
    try {
      await _client.callKw({
        'model': 'hr.expense',
        'method': 'unlink',
        'args': [[expenseId]],
        'kwargs': {},
      });
      return true;
    } catch (e, st) {
      ApiLogger.error('deleteExpenseLine id=$expenseId failed', e, st);
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Approvals. Odoo 19 has no expense reports, so approval happens on the
  // hr.expense record itself: draft -> submitted -> approved -> posted ->
  // in_payment -> paid, with refused as the rejection branch.
  // ---------------------------------------------------------------------

  // Approvals are model-agnostic: reports on Odoo <= 18, expenses on Odoo 19+.

  /// Which model this database approves on, and the state that means
  /// "waiting for an approver" there. Resolved from the live schema, so
  /// Community, Enterprise and every version answer for themselves.
  Future<({String model, String? pendingState})> _approvalTarget() async {
    final sheet = await _modelMeta('hr.expense.sheet');
    final model = sheet.exists ? 'hr.expense.sheet' : 'hr.expense';
    final meta = sheet.exists ? sheet : await _modelMeta('hr.expense');

    // `submit` on a report, `submitted` on an Odoo 19 expense; older builds
    // have used `reported`. Whichever this database actually defines wins.
    const candidates = ['submit', 'submitted', 'reported'];
    final pending = candidates.firstWhere(
      meta.stateLabels.containsKey,
      orElse: () => '',
    );
    return (model: model, pendingState: pending.isEmpty ? null : pending);
  }

  /// Fields to read for [model], limited to those it actually has.
  Future<List<String>> _approvalFields(String model) async {
    final meta = await _modelMeta(model);
    const wanted = [
      'id', 'name', 'employee_id', 'state', 'date',
      'total_amount', 'total_amount_currency', 'price_unit',
      'product_id', 'expense_line_ids', 'accounting_date', 'create_date',
    ];
    final fields = wanted.where(meta.fields.contains).toList();
    return fields.isEmpty ? const ['id', 'name', 'state'] : fields;
  }

  /// Rows waiting for an approver.
  Future<List<ExpenseApprovalItem>> fetchExpensesToApprove({
    List<int>? employeeIds,
    int limit = 120,
  }) async {
    final target = await _approvalTarget();
    return _searchApprovals(
      where: 'fetchExpensesToApprove',
      model: target.model,
      extraDomain: [
        if (target.pendingState != null) ['state', '=', target.pendingState],
      ],
      employeeIds: employeeIds,
      limit: limit,
    );
  }

  /// Every row the account may read, no state filter — the "All" tab.
  Future<List<ExpenseApprovalItem>> fetchAllExpenses({
    List<int>? employeeIds,
    int limit = 200,
  }) async {
    final target = await _approvalTarget();
    return _searchApprovals(
      where: 'fetchAllExpenses',
      model: target.model,
      extraDomain: const [],
      employeeIds: employeeIds,
      limit: limit,
    );
  }

  Future<List<ExpenseApprovalItem>> _searchApprovals({
    required String where,
    required String model,
    required List<dynamic> extraDomain,
    List<int>? employeeIds,
    required int limit,
  }) async {
    ApiLogger.info('--- ExpenseRepository.$where on $model ---');
    final meta = await _modelMeta(model);
    if (!meta.exists) return [];

    final target = await _approvalTarget();
    final domain = <dynamic>[
      ...extraDomain,
      if (employeeIds != null) ['employee_id', 'in', employeeIds],
    ];
    // `date` is absent on a report; fall back to a column every version has.
    final order = meta.fields.contains('date')
        ? 'date desc, id desc'
        : 'create_date desc, id desc';

    try {
      final result = await _client.callKw({
        'model': model,
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': await _approvalFields(model),
          'order': order,
          'limit': limit,
        },
      });
      if (result is! List) return [];

      final items = result
          .map((e) => _toApprovalItem(
                Map<String, dynamic>.from(e as Map),
                model: model,
                meta: meta,
                pendingState: target.pendingState,
              ))
          .toList();
      ApiLogger.info('$where ok model=$model count=${items.length}');
      return items;
    } catch (e, st) {
      _classify(e, st, where);
      return [];
    }
  }

  ExpenseApprovalItem _toApprovalItem(
    Map<String, dynamic> row, {
    required String model,
    required _ModelMeta meta,
    required String? pendingState,
  }) {
    String? name;
    int? employeeId;
    final employee = row['employee_id'];
    if (employee is List && employee.isNotEmpty) {
      employeeId = employee.first is int ? employee.first as int : null;
      if (employee.length > 1) name = employee[1]?.toString();
    }

    var category = '';
    final product = row['product_id'];
    if (product is List && product.length > 1) {
      category = product[1]?.toString() ?? '';
    }

    final rawState = row['state']?.toString() ?? '';
    final lines = row['expense_line_ids'];

    return ExpenseApprovalItem(
      id: row['id'] as int,
      model: model,
      title: _text(row['name']),
      rawState: rawState,
      // Odoo's own label, so the badge matches the web client and its language.
      stateLabel: meta.stateLabels[rawState] ?? rawState,
      isPending: pendingState != null && rawState == pendingState,
      employeeId: employeeId,
      employeeName: name ?? '',
      amount: _amount(row),
      date: _date(row),
      categoryName: category,
      lineCount: lines is List ? lines.length : null,
    );
  }

  static String _text(dynamic value) =>
      (value == false || value == null) ? '' : value.toString();

  static double _amount(Map<String, dynamic> row) {
    for (final key in const ['total_amount_currency', 'total_amount', 'price_unit']) {
      final value = row[key];
      if (value is num) return value.toDouble();
    }
    return 0;
  }

  static DateTime? _date(Map<String, dynamic> row) {
    for (final key in const ['date', 'accounting_date', 'create_date']) {
      final value = row[key];
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// Approves one row, on whichever model this database approves.
  Future<void> approveExpense(ExpenseApprovalItem item) async {
    await _runApprovalAction(
      item: item,
      label: 'approve',
      methods: item.isReport
          ? const [
              'action_approve_expense_sheets',
              'approve_expense_sheets',
              'action_approve',
            ]
          : const ['action_approve', 'approve_expense', 'action_validate'],
      // Anything at or past approval counts: Odoo may post or pay immediately.
      expectedStates: const {
        'approve', 'approved', 'post', 'posted', 'in_payment', 'paid', 'done',
      },
    );
  }

  /// Runs an approval action, then confirms the record actually moved.
  ///
  /// Some Odoo actions return a wizard descriptor instead of doing the work,
  /// so a call that "succeeds" proves nothing — the state does.
  Future<void> _runApprovalAction({
    required ExpenseApprovalItem item,
    required String label,
    required List<String> methods,
    required Set<String> expectedStates,
  }) async {
    var lastError = '';
    for (final method in methods) {
      try {
        await _client.callKw({
          'model': item.model,
          'method': method,
          'args': [
            [item.id],
          ],
          'kwargs': {},
        });
        final state = await _readState(item.model, item.id);
        if (state == null || expectedStates.contains(state)) {
          ApiLogger.info(
            '${label}Expense ${item.model} id=${item.id} via $method '
            '=> state=${state ?? 'unknown'}',
          );
          return;
        }
        // The call went through but nothing moved; keep trying.
        lastError = '$method left the record in "$state"';
        ApiLogger.info('${label}Expense $method did not change state: $state');
      } catch (e) {
        lastError = e.toString();
        ApiLogger.info('${label}Expense $method unavailable: $e');
      }
    }
    throw Exception('Could not $label this expense. $lastError');
  }

  /// Refuses one row with a reason.
  ///
  /// `action_refuse` on an expense only *opens* Odoo's refuse wizard: over RPC
  /// it returns the action descriptor and changes nothing, so it looked like
  /// success while the expense stayed submitted. The wizard is therefore
  /// driven directly, and the state is verified before reporting success.
  Future<void> refuseExpense(ExpenseApprovalItem item, String reason) async {
    final trimmed = reason.trim();

    // 1) The wizard is the only path that both refuses and records the reason.
    var done = await _refuseViaWizard(item, trimmed);

    // 2) Older/other versions expose a direct call instead.
    if (!done) {
      for (final attempt in <({String method, List<dynamic> args})>[
        if (item.isReport)
          (method: 'action_refuse_expense_sheets', args: [[item.id], trimmed]),
        (method: 'action_refuse', args: [[item.id]]),
      ]) {
        try {
          await _client.callKw({
            'model': item.model,
            'method': attempt.method,
            'args': attempt.args,
            'kwargs': {},
          });
          ApiLogger.info(
            'refuseExpense ${item.model} id=${item.id} via ${attempt.method}',
          );
          done = true;
          break;
        } catch (e) {
          ApiLogger.info('refuseExpense ${attempt.method} unavailable: $e');
        }
      }
    }

    // 3) Trust the record, not the return value.
    final state = await _readState(item.model, item.id);
    const refused = {'refuse', 'refused', 'cancel', 'cancelled'};
    if (state != null && refused.contains(state)) {
      // If the reason didn't reach the wizard, keep it on the record's chatter
      // rather than losing what the approver typed.
      if (!done && trimmed.isNotEmpty) {
        await _postNote(item, 'Refused: $trimmed');
      }
      ApiLogger.info('refuseExpense confirmed id=${item.id} state=$state');
      return;
    }

    throw Exception(
      'The server did not refuse this expense (state is ${state ?? 'unknown'}).',
    );
  }

  /// Creates and runs Odoo's refuse wizard for [item], carrying the reason.
  Future<bool> _refuseViaWizard(ExpenseApprovalItem item, String reason) async {
    const wizardModel = 'hr.expense.refuse.wizard';
    final context = {
      'active_id': item.id,
      'active_ids': [item.id],
      'active_model': item.model,
    };

    try {
      final wizardId = await _client.callKw({
        'model': wizardModel,
        'method': 'create',
        'args': [
          {'reason': reason.isEmpty ? 'Refused' : reason},
        ],
        'kwargs': {'context': context},
      });
      if (wizardId is! int) return false;

      for (final method in const ['expense_refuse_reason', 'action_refuse']) {
        try {
          await _client.callKw({
            'model': wizardModel,
            'method': method,
            'args': [
              [wizardId],
            ],
            'kwargs': {'context': context},
          });
          ApiLogger.info('refuseExpense id=${item.id} via wizard.$method');
          return true;
        } catch (e) {
          ApiLogger.info('refuse wizard.$method unavailable: $e');
        }
      }
    } catch (e) {
      ApiLogger.info('$wizardModel unavailable: $e');
    }
    return false;
  }

  /// Re-reads `state` — the only reliable proof an action actually landed.
  Future<String?> _readState(String model, int id) async {
    try {
      final result = await _client.callKw({
        'model': model,
        'method': 'read',
        'args': [
          [id],
          ['state'],
        ],
        'kwargs': {},
      });
      if (result is List && result.isNotEmpty) {
        final row = Map<String, dynamic>.from(result.first as Map);
        return row['state']?.toString();
      }
    } catch (e) {
      ApiLogger.info('state read failed $model:$id — $e');
    }
    return null;
  }

  /// Adds a chatter note, used to preserve a refusal reason the workflow
  /// itself had no field for.
  Future<void> _postNote(ExpenseApprovalItem item, String body) async {
    try {
      await _client.callKw({
        'model': item.model,
        'method': 'message_post',
        'args': [
          [item.id],
        ],
        'kwargs': {'body': body},
      });
    } catch (e) {
      ApiLogger.info('message_post failed for ${item.id}: $e');
    }
  }

  /// Moves a freshly created expense out of draft and into the approval queue.
  ///
  /// Version-agnostic: Odoo 19 submits the expense itself, while Odoo <= 18
  /// has to group it into a report first and submit that. The state is
  /// verified afterwards, because an action that merely opens a wizard would
  /// otherwise look like success.
  Future<bool> submitExpense({
    required int expenseId,
    required int employeeId,
    required String name,
  }) async {
    if (await supportsExpenseReports()) {
      return _submitViaReport(
        expenseId: expenseId,
        employeeId: employeeId,
        name: name,
      );
    }

    for (final method in const [
      'action_submit',
      'action_submit_expenses',
      'submit_expenses',
    ]) {
      try {
        await _client.callKw({
          'model': 'hr.expense',
          'method': method,
          'args': [
            [expenseId],
          ],
          'kwargs': {},
        });
        final state = await _readState('hr.expense', expenseId);
        if (state != null && state != 'draft') {
          ApiLogger.info(
            'submitExpense id=$expenseId via $method => state=$state',
          );
          return true;
        }
        ApiLogger.info('submitExpense $method left it in ${state ?? 'unknown'}');
      } catch (e) {
        ApiLogger.info('submitExpense $method unavailable: $e');
      }
    }
    ApiLogger.error('submitExpense id=$expenseId: still in draft');
    return false;
  }

  /// Odoo <= 18: an expense reaches an approver only through a report.
  Future<bool> _submitViaReport({
    required int expenseId,
    required int employeeId,
    required String name,
  }) async {
    try {
      final sheetId = await createReport(
        employeeId: employeeId,
        name: name.trim().isEmpty ? 'Expense' : name.trim(),
        expenseIds: [expenseId],
      );
      if (sheetId == null) return false;
      final submitted = await submitSheetToManager(sheetId);
      ApiLogger.info(
        'submitExpense id=$expenseId via report $sheetId => $submitted',
      );
      return submitted;
    } catch (e, st) {
      ApiLogger.error('submitExpense via report failed id=$expenseId', e, st);
      return false;
    }
  }

  /// Whether the signed-in account may approve expenses — the same group check
  /// used for time off, against the Expenses groups.
  Future<bool> hasExpenseApprovalAccess() async {
    ApiLogger.info('--- ExpenseRepository.hasExpenseApprovalAccess ---');
    const approverXmlIds = {
      'hr_expense.group_hr_expense_manager',
      'hr_expense.group_hr_expense_user',
      'hr_expense.group_hr_expense_team_approver',
      'base.group_system',
    };

    try {
      final session =
          await _client.callRPC('/web/session/get_session_info', 'call', {});
      final uid = (session is Map ? session['uid'] : null) as int?;
      if (uid == null || uid <= 0) return false;

      for (final xmlId in approverXmlIds) {
        try {
          final result = await _client.callKw({
            'model': 'res.users',
            'method': 'has_group',
            'args': [
              [uid],
              xmlId,
            ],
            'kwargs': {},
          });
          if (result == true) {
            ApiLogger.info('hasExpenseApprovalAccess => true ($xmlId)');
            return true;
          }
        } catch (e) {
          ApiLogger.info('has_group($xmlId) unavailable: $e');
        }
      }
      ApiLogger.info('hasExpenseApprovalAccess => false');
      return false;
    } catch (e, st) {
      ApiLogger.error('hasExpenseApprovalAccess failed', e, st);
      return false;
    }
  }
}

/// What one model looks like on the connected database.
class _ModelMeta {
  const _ModelMeta({
    required this.exists,
    this.fields = const {},
    this.stateLabels = const {},
    this.sheetLinkField,
  });

  /// The model is not installed on this Odoo version.
  const _ModelMeta.absent()
      : exists = false,
        fields = const {},
        stateLabels = const {},
        sheetLinkField = null;

  final bool exists;
  final Set<String> fields;

  /// `state` value -> Odoo's own translated label.
  final Map<String, String> stateLabels;

  final String? sheetLinkField;
}
