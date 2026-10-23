import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/odoo_orders_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/network_service.dart';
import '../../core/utils/logger.dart';
import '../models/fsm_location_dialog_model.dart';
import '../models/kanban_board_data.dart';
import '../models/kanban_stage_model.dart';
import '../models/order_model.dart';
import '../providers/api_provider.dart';

/// Loads stages + orders from Odoo when online; caches in Hive when offline.
class OrderRepository {
  OrderRepository(
    this._api,
    this._connectivity,
    this._network,
  );

  final ApiProvider _api;
  final ConnectivityService _connectivity;
  final NetworkService _network;
  static const String _worksheetModel = 'worksheet_template';

  static const String _boxName = 'fsm_orders';
  static const String _rawKeyItems = 'items';
  static const String _rawKeyStages = 'kanban_stages';
  static const String _rawKeyPendingOrderCreates = 'pending_order_creates';
  /// Merged `write` payloads for existing FSM orders (applied when back online).
  static const String _rawKeyPendingFsmOrderWrites = 'pending_fsm_order_writes';
  /// Queued `action_complete` / `action_cancel` calls while offline.
  static const String _rawKeyPendingFsmOrderActions = 'pending_fsm_order_actions';
  static const String _rawKeyLocalOrderIdSeq = 'local_order_id_seq';
  static const String _rawKeyFieldOptionsCache = 'field_options_cache_v1';
  static const String _rawKeySavedRouteLocal = 'saved_route_local_v1';
  static const String _rawKeyRouteGeometryCache = 'route_geometry_cache_v1';
  static const String _rawKeyRoutingConfigCache = 'routing_config_cache_v1';

  /// Order detail / `search_read` use Odoo many2one shape `[id, name]`; storing a
  /// bare int makes the form show the id string offline after save + reopen.
  static const Set<String> _orderDetailMany2oneKeys = <String>{
    'partner_id',
    'location_id',
    'person_id',
    'vehicle_id',
    'company_id',
    'template_id',
    'worksheet_template_id',
    'stage_id',
  };

  static const String _rawKeySaleOrderByFsm    = 'sale_order_by_fsm_';
  static const String _rawKeySaleOrderById     = 'sale_order_by_id_';
  static const String _rawKeyInvoicesByFsm     = 'invoices_by_fsm_';
  static const String _rawKeyInvoiceById       = 'invoice_by_id_';
  static const String _rawKeyPickingsBySale    = 'pickings_by_sale_';
  static const String _rawKeyPickingMoveLines  = 'picking_move_lines_';
  static const String _rawKeyPendingSaleOrders = 'pending_sale_orders';
  static const String _rawKeyPendingProductQty = 'pending_product_qty';
  static const String _rawKeyCarInventoryByFsm = 'car_inventory_fsm_';
  static const String _rawKeyPendingChatter    = 'pending_chatter_msgs';
  static const String _rawKeyPendingCreateInvoice  = 'pending_create_invoice';
  static const String _rawKeyPendingConfirmInvoice  = 'pending_confirm_invoice';
  static const String _rawKeyPendingValidatePicking = 'pending_validate_picking';
  static const String _rawKeyPendingWorksheetOps = 'pending_worksheet_ops';

  String _cacheScope() {
    final base = (_network.baseUrl ?? '').trim().toLowerCase();
    var db = '';
    var companiesScope = '';
    if (Get.isRegistered<StorageService>()) {
      final storage = Get.find<StorageService>();
      db = storage.selectedDb.trim().toLowerCase();
      final selected = storage.selectedCompanyIds.toList()..sort();
      companiesScope = selected.join(',');
    }
    return '$base|$db|$companiesScope';
  }

  String _scopedKey(String raw) => '${_cacheScope()}::$raw';

  String get _keyItems => _scopedKey(_rawKeyItems);
  String get _keyStages => _scopedKey(_rawKeyStages);
  String get _keyPendingOrderCreates => _scopedKey(_rawKeyPendingOrderCreates);
  String get _keyPendingFsmOrderWrites => _scopedKey(_rawKeyPendingFsmOrderWrites);
  String get _keyPendingFsmOrderActions => _scopedKey(_rawKeyPendingFsmOrderActions);
  String get _keyLocalOrderIdSeq => _scopedKey(_rawKeyLocalOrderIdSeq);
  String get _keyFieldOptionsCache => _scopedKey(_rawKeyFieldOptionsCache);
  String get _keySavedRouteLocal => _scopedKey(_rawKeySavedRouteLocal);
  String get _keyRouteGeometryCache => _scopedKey(_rawKeyRouteGeometryCache);
  String get _keyRoutingConfigCache => _scopedKey(_rawKeyRoutingConfigCache);

  String _orderDetailKey(int id) => _scopedKey('order_detail_$id');
  String _orderTimesheetsKey(int id) => _scopedKey('order_timesheets_$id');
  String _orderMapCoordsKey(int id) => _scopedKey('order_map_coords_$id');

  String _saleOrderByFsmKey(int fsmId) => _scopedKey('$_rawKeySaleOrderByFsm$fsmId');
  String _saleOrderByIdKey(int id)     => _scopedKey('$_rawKeySaleOrderById$id');
  String _invoicesByFsmKey(int fsmId)  => _scopedKey('$_rawKeyInvoicesByFsm$fsmId');
  String _invoiceByIdKey(int id)       => _scopedKey('$_rawKeyInvoiceById$id');
  String _pickingsBySaleKey(int saleId)     => _scopedKey('$_rawKeyPickingsBySale$saleId');
  String _pickingMoveLinesKey(int pickId)   => _scopedKey('$_rawKeyPickingMoveLines$pickId');
  String get _keyPendingSaleOrders => _scopedKey(_rawKeyPendingSaleOrders);
  String get _keyPendingProductQty => _scopedKey(_rawKeyPendingProductQty);
  String get _keyPendingChatter    => _scopedKey(_rawKeyPendingChatter);
  String get _keyPendingCreateInvoice  => _scopedKey(_rawKeyPendingCreateInvoice);
  String get _keyPendingConfirmInvoice  => _scopedKey(_rawKeyPendingConfirmInvoice);
  String get _keyPendingValidatePicking => _scopedKey(_rawKeyPendingValidatePicking);
  String get _keyPendingWorksheetOps => _scopedKey(_rawKeyPendingWorksheetOps);
  String _carInventoryByFsmKey(int fsmId) => _scopedKey('$_rawKeyCarInventoryByFsm$fsmId');

  /// Worksheet form schema: scope by server + DB only. Including
  /// [selectedCompanyIds] in the key breaks offline reads when that list
  /// differs from the moment the cache was written.
  String _worksheetFormDbScope() {
    final base = (_network.baseUrl ?? '').trim().toLowerCase();
    var db = '';
    if (Get.isRegistered<StorageService>()) {
      db = Get.find<StorageService>().selectedDb.trim().toLowerCase();
    }
    return '$base|$db';
  }

  String _worksheetFormCreateStorageKey(int fsmOrderId) =>
      '${_worksheetFormDbScope()}::worksheet_form_create_$fsmOrderId';

  String _worksheetFormRecordStorageKey(int fsmOrderId, int recordId) =>
      '${_worksheetFormDbScope()}::worksheet_form_record_${fsmOrderId}_$recordId';

  Map<String, dynamic>? _normalizeWorksheetFormDetail(dynamic raw) {
    if (raw is! Map) return null;
    final meta = raw['fields_meta'];
    final uf = raw['user_fields'];
    final vals = raw['values'];
    if (meta is! Map || vals is! Map) return null;
    if (uf is! List || uf.isEmpty) return null;
    final userFields = uf.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    if (userFields.isEmpty) return null;
    return <String, dynamic>{
      'fields_meta': Map<String, dynamic>.from(meta.map(
        (k, v) => MapEntry(k.toString(), v),
      )),
      'user_fields': userFields,
      'values': Map<String, dynamic>.from(vals.map(
        (k, v) => MapEntry(k.toString(), v),
      )),
    };
  }

  Future<Map<String, dynamic>?> _readWorksheetFormDetailOffline({
    required String primaryKey,
    required String keySuffix,
  }) async {
    final tryKeys = <String>[
      primaryKey,
      _scopedKey(keySuffix),
    ];
    for (final key in tryKeys) {
      final raw = await _readWorksheetFormDetailCache(key);
      final norm = _normalizeWorksheetFormDetail(raw);
      if (norm != null) return norm;
    }
    final endsWith = '::$keySuffix';
    try {
      final box = await _openBox();
      for (final k in box.keys) {
        if (k is! String || !k.endsWith(endsWith)) continue;
        final raw = await _readWorksheetFormDetailCache(k);
        final norm = _normalizeWorksheetFormDetail(raw);
        if (norm != null) return norm;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveWorksheetFormDetailCache(
    String key,
    Map<String, dynamic> detail,
  ) async {
    try {
      final box = await _openBox();
      await box.put(key, jsonDecode(jsonEncode(detail)));
    } catch (e) {
      AppLogger.warning(
        'worksheet form cache save failed: $e',
        tag: 'ORDER_REPO',
      );
    }
  }

  Future<Map<String, dynamic>?> _readWorksheetFormDetailCache(String key) async {
    try {
      final box = await _openBox();
      final raw = box.get(key);
      if (raw == null) return null;
      final decoded = jsonDecode(jsonEncode(raw));
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  String _worksheetResolvedModelKey(int fsmOrderId) =>
      '${_worksheetFormDbScope()}::worksheet_model_$fsmOrderId';

  Future<void> _cacheWorksheetModelNameForOrder(
    int fsmOrderId,
    String model,
  ) async {
    final m = model.trim();
    if (m.isEmpty) return;
    try {
      final box = await _openBox();
      await box.put(_worksheetResolvedModelKey(fsmOrderId), m);
    } catch (_) {}
  }

  Future<String?> _readCachedWorksheetModelNameForOrder(int fsmOrderId) async {
    try {
      final box = await _openBox();
      final v = box.get(_worksheetResolvedModelKey(fsmOrderId));
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  Future<int> _nextLocalWorksheetId() async {
    final box = await _openBox();
    final key = '${_worksheetFormDbScope()}::worksheet_local_id_seq';
    final cur = _coerceInt(box.get(key)) ?? 0;
    final next = cur - 1;
    await box.put(key, next);
    return next;
  }

  Future<void> _enqueuePendingWorksheetJob(Map<String, dynamic> job) async {
    final box = await _openBox();
    final raw = box.get(_keyPendingWorksheetOps);
    final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
    list.add(job);
    await box.put(_keyPendingWorksheetOps, list);
  }

  Future<bool> _mergeIntoPendingWorksheetCreate(
    int fsmOrderId,
    int localId,
    Map<String, dynamic> patch,
  ) async {
    final box = await _openBox();
    final raw = box.get(_keyPendingWorksheetOps);
    if (raw is! List) return false;
    final list = raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null).whereType<Map<String, dynamic>>().toList();
    for (var i = 0; i < list.length; i++) {
      final j = list[i];
      if (j['op'] == 'create' &&
          _coerceInt(j['fsm_order_id']) == fsmOrderId &&
          _coerceInt(j['local_id']) == localId) {
        final valsRaw = j['values'];
        final vals = valsRaw is Map
            ? Map<String, dynamic>.from(valsRaw as Map)
            : <String, dynamic>{};
        vals.addAll(patch);
        j['values'] = vals;
        list[i] = j;
        await box.put(_keyPendingWorksheetOps, list);
        return true;
      }
    }
    return false;
  }

  Future<void> _upsertWorksheetListCacheRow(
    int fsmOrderId,
    Map<String, dynamic> row,
  ) async {
    final cacheKey = _scopedKey('worksheet_records_$fsmOrderId');
    final box = await _openBox();
    final raw = box.get(cacheKey);
    var list = raw is List
        ? raw
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>()
            .toList()
        : <Map<String, dynamic>>[];
    final rid = _coerceInt(row['id']);
    if (rid != null) {
      list.removeWhere((m) => _coerceInt(m['id']) == rid);
    }
    list.insert(0, Map<String, dynamic>.from(row));
    await box.put(cacheKey, list);
  }

  Future<void> _patchWorksheetCachesAfterEdit(
    int fsmOrderId,
    int recordId,
    Map<String, dynamic> patch,
  ) async {
    final cacheKey = _scopedKey('worksheet_records_$fsmOrderId');
    final box = await _openBox();
    final raw = box.get(cacheKey);
    if (raw is List) {
      final list = raw
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final row in list) {
        if (_coerceInt(row['id']) == recordId) {
          for (final e in patch.entries) {
            if (e.key == 'id') continue;
            row[e.key] = e.value;
          }
          break;
        }
      }
      await box.put(cacheKey, list);
    }

    final formKey = _worksheetFormRecordStorageKey(fsmOrderId, recordId);
    var detail = await _readWorksheetFormDetailCache(formKey);
    detail ??= await _readWorksheetFormDetailOffline(
      primaryKey: formKey,
      keySuffix: 'worksheet_form_record_${fsmOrderId}_$recordId',
    );
    if (detail != null) {
      final valsRaw = detail['values'];
      if (valsRaw is Map) {
        final vals = Map<String, dynamic>.from(valsRaw as Map);
        for (final e in patch.entries) {
          if (e.key == 'id') continue;
          vals[e.key] = e.value;
        }
        detail['values'] = vals;
        await _saveWorksheetFormDetailCache(formKey, detail);
      }
    }
  }

  Future<void> _replaceWorksheetLocalIdWithRemote(
    int fsmOrderId,
    int localId,
    int remoteId,
  ) async {
    final cacheKey = _scopedKey('worksheet_records_$fsmOrderId');
    final box = await _openBox();
    final raw = box.get(cacheKey);
    if (raw is List) {
      final list = raw
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final row in list) {
        if (_coerceInt(row['id']) == localId) {
          row['id'] = remoteId;
          break;
        }
      }
      await box.put(cacheKey, list);
    }

    final oldFormKey = _worksheetFormRecordStorageKey(fsmOrderId, localId);
    final newFormKey = _worksheetFormRecordStorageKey(fsmOrderId, remoteId);
    final formDetail = await _readWorksheetFormDetailCache(oldFormKey);
    if (formDetail != null) {
      final valsRaw = formDetail['values'];
      if (valsRaw is Map) {
        final vals = Map<String, dynamic>.from(valsRaw as Map);
        vals['id'] = remoteId;
        formDetail['values'] = vals;
      }
      await _saveWorksheetFormDetailCache(newFormKey, formDetail);
      try {
        await box.delete(oldFormKey);
      } catch (_) {}
    }
  }

  Future<void> _syncPendingWorksheets() async {
    if (!_canRequestOdoo()) return;
    final box = await _openBox();
    final raw = box.get(_keyPendingWorksheetOps);
    if (raw is! List || raw.isEmpty) return;

    var jobs = raw
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();

    final idMap = <int, int>{};
    final failed = <Map<String, dynamic>>[];

    for (final job in jobs) {
      if (job['op'] != 'create') continue;
      final fsmId = _coerceInt(job['fsm_order_id']);
      final localId = _coerceInt(job['local_id']);
      final model = job['worksheet_model']?.toString();
      final valsRaw = job['values'];
      if (fsmId == null || localId == null || model == null || model.isEmpty) {
        failed.add(job);
        continue;
      }
      final vals = valsRaw is Map
          ? Map<String, dynamic>.from(valsRaw as Map)
          : <String, dynamic>{};
      try {
        final res = await _api.callKw(
          model: model,
          method: 'create',
          args: <dynamic>[vals],
          kwargs: const <String, dynamic>{},
        );
        if (!res.success || res.data == null) {
          failed.add(<String, dynamic>{
            ...job,
            'last_error': res.error ?? 'create failed',
          });
          continue;
        }
        final remoteId = _coerceInt(res.data);
        if (remoteId == null) {
          failed.add(<String, dynamic>{...job, 'last_error': 'bad create id'});
          continue;
        }
        idMap[localId] = remoteId;
        await _replaceWorksheetLocalIdWithRemote(fsmId, localId, remoteId);
        AppLogger.success(
          'worksheet offline create synced local=$localId → $remoteId',
          tag: 'ORDER_REPO',
        );
      } catch (e) {
        failed.add(<String, dynamic>{...job, 'last_error': e.toString()});
      }
    }

    for (final job in jobs) {
      if (job['op'] != 'write') continue;
      final fsmId = _coerceInt(job['fsm_order_id']);
      var rid = _coerceInt(job['record_id']);
      final model = job['worksheet_model']?.toString();
      final valsRaw = job['values'];
      if (fsmId == null || rid == null || model == null || model.isEmpty) {
        failed.add(job);
        continue;
      }
      if (rid < 0) {
        final mapped = idMap[rid];
        if (mapped == null) {
          failed.add(job);
          continue;
        }
        rid = mapped;
      }
      final vals = valsRaw is Map
          ? Map<String, dynamic>.from(valsRaw as Map)
          : <String, dynamic>{};
      try {
        final res = await _api.callKw(
          model: model,
          method: 'write',
          args: <dynamic>[<int>[rid], vals],
          kwargs: const <String, dynamic>{},
        );
        if (!res.success) {
          failed.add(<String, dynamic>{
            ...job,
            'last_error': res.error ?? 'write failed',
          });
          continue;
        }
        AppLogger.success(
          'worksheet offline write synced id=$rid',
          tag: 'ORDER_REPO',
        );
      } catch (e) {
        failed.add(<String, dynamic>{...job, 'last_error': e.toString()});
      }
    }

    await box.put(_keyPendingWorksheetOps, failed);
  }

  Box<dynamic>? _box;

  Future<Box<dynamic>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<dynamic>(_boxName);
    return _box!;
  }

  bool _canRequestOdoo() {
    final sid = _network.sessionId;
    final base = _network.baseUrl;
    return _connectivity.hasConnection &&
        sid != null &&
        sid.isNotEmpty &&
        base != null &&
        base.isNotEmpty;
  }

  Future<List<KanbanStageModel>> _fetchStagesFromOdoo() async {
    final response = await _api.callKw(
      model: OdooOrdersConfig.stageModel,
      method: 'search_read',
      args: <dynamic>[OdooOrdersConfig.stageSearchDomain],
      kwargs: <String, dynamic>{
        'fields': OdooOrdersConfig.stageFields,
        'limit': OdooOrdersConfig.stageLimit,
        'order': OdooOrdersConfig.stageOrder,
      },
    );

    if (!response.success) {
      throw Exception(response.error ?? 'Could not load stages from Odoo.');
    }

    final result = response.data;
    if (result is! List) {
      throw Exception('Unexpected stages response from Odoo.');
    }

    return result
        .map((e) {
          if (e is Map) {
            return KanbanStageModel.fromOdooRecord(
              Map<String, dynamic>.from(e),
            );
          }
          return null;
        })
        .whereType<KanbanStageModel>()
        .where((s) => s.id > 0)
        .toList();
  }

  Future<List<OrderModel>> _fetchOrdersFromOdoo() async {
    final response = await _api.callKw(
      model: OdooOrdersConfig.model,
      method: 'search_read',
      args: <dynamic>[OdooOrdersConfig.searchDomain],
      kwargs: <String, dynamic>{
        'fields': OdooOrdersConfig.fields,
        'limit': OdooOrdersConfig.searchLimit,
        'order': OdooOrdersConfig.searchOrder,
      },
    );

    if (!response.success) {
      throw Exception(response.error ?? 'Could not load orders from Odoo.');
    }

    final result = response.data;
    if (result is! List) {
      throw Exception('Unexpected response from Odoo.');
    }

    return result
        .map((e) {
          if (e is Map) {
            return OrderModel.fromOdooRecord(
              Map<String, dynamic>.from(e),
            );
          }
          return null;
        })
        .whereType<OrderModel>()
        .toList();
  }

  Future<List<OrderModel>> _readOrdersHive(Box<dynamic> box) async {
    final raw = box.get(_keyItems);
    if (raw is! List) return [];

    return raw
        .map((e) {
          if (e is Map) {
            return OrderModel.fromMap(Map<String, dynamic>.from(e));
          }
          return null;
        })
        .whereType<OrderModel>()
        .toList();
  }

  List<KanbanStageModel> _readStagesHive(Box<dynamic> box) {
    final raw = box.get(_keyStages);
    if (raw is! List) return [];

    return raw
        .map((e) {
          if (e is Map) {
            return KanbanStageModel.fromMap(Map<String, dynamic>.from(e));
          }
          return null;
        })
        .whereType<KanbanStageModel>()
        .toList();
  }

  KanbanStageModel? _firstOrderedStageFromBox(Box<dynamic> box) {
    final stages = _readStagesHive(box);
    if (stages.isEmpty) return null;
    final sorted = List<KanbanStageModel>.from(stages)
      ..sort((a, b) {
        final c = a.sequence.compareTo(b.sequence);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    for (final s in sorted) {
      if (s.id > 0) return s;
    }
    return null;
  }

  /// When the form has no stage, use the first cached Odoo stage so the card
  /// appears in a real column while offline (not only under "Other").
  Map<String, dynamic> _mergeDefaultStageFromCache(
    Box<dynamic> box,
    Map<String, dynamic> values,
  ) {
    final merged = Map<String, dynamic>.from(values);
    if (_m2oId(merged['stage_id']) != null) return merged;
    final stage = _firstOrderedStageFromBox(box);
    if (stage == null) return merged;
    // Odoo `create` expects many2one ids as integers (not [id, label] arrays).
    merged['stage_id'] = stage.id;
    return merged;
  }

  Future<KanbanBoardData> _readKanbanFromHive() async {
    final box = await _openBox();
    final orders = await _readOrdersHive(box);
    final stages = _readStagesHive(box);
    final pending = orders.where((o) {
      final n = int.tryParse(o.id);
      return n != null && n < 0;
    }).length;
    AppLogger.debug(
      'Hive kanban read: ${orders.length} orders ($pending negative/local ids), '
      '${stages.length} stages, canOdoo=${_canRequestOdoo()}',
      tag: 'ORDER_REPO',
    );
    return KanbanBoardData(stages: stages, orders: orders);
  }

  Future<KanbanBoardData> fetchKanban() async {
    if (_canRequestOdoo()) {
      try {
        await syncPendingOrders();
        var stages = <KanbanStageModel>[];
        try {
          stages = await _fetchStagesFromOdoo();
        } catch (e) {
          AppLogger.error(
            'Odoo stages fetch failed (check odoo_orders_config.stageModel)',
            tag: 'ORDER_REPO',
            error: e,
          );
        }

        final remoteOrders = await _fetchOrdersFromOdoo();
        await saveKanbanCache(stages, remoteOrders);
        // Re-read from Hive: saveKanbanCache merges offline-created (negative id)
        // rows; returning [remoteOrders] alone drops those from the UI.
        final merged = await _readKanbanFromHive();
        AppLogger.success(
          'Kanban synced: ${merged.stages.length} stages, '
          '${merged.orders.length} orders in UI (Odoo returned ${remoteOrders.length})',
          tag: 'ORDER_REPO',
        );
        return merged;
      } catch (e) {
        AppLogger.error('Odoo orders fetch failed, using cache',
            tag: 'ORDER_REPO', error: e);
        return _readKanbanFromHive();
      }
    }

    AppLogger.debug('fetchKanban: offline / no session — reading Hive only',
        tag: 'ORDER_REPO');
    return _readKanbanFromHive();
  }

  Future<void> saveKanbanCache(
    List<KanbanStageModel> stages,
    List<OrderModel> orders,
  ) async {
    final box = await _openBox();
    await box.put(_keyStages, stages.map((e) => e.toMap()).toList());
    final remote = orders.map((e) => e.toMap()).toList();
    // Only merge offline-created rows (negative Odoo id). Do not merge every
    // cached row with missing sync_status — that overwrote fresh server data.
    final pendingLocal = _readPendingLocalOrderMaps(box);
    final byId = <String, Map<String, dynamic>>{};
    for (final e in remote) {
      final m = Map<String, dynamic>.from(e);
      byId[m['id']?.toString() ?? ''] = m;
    }
    for (final m in pendingLocal) {
      byId[m['id']?.toString() ?? ''] = Map<String, dynamic>.from(m);
    }
    AppLogger.debug(
      'saveKanbanCache: remote=${remote.length}, pending_offline_overlays='
      '${pendingLocal.length}, merged=${byId.length}',
      tag: 'ORDER_REPO',
    );
    await box.put(_keyItems, byId.values.toList());
  }

  Future<Map<String, List<OdooFieldOption>>> fetchCreateOrderFieldOptions(
    List<String> fieldNames,
  ) async {
    if (!_canRequestOdoo()) {
      return _readFieldOptionsCache(fieldNames);
    }

    final fieldsRes = await _api.callKw(
      model: OdooOrdersConfig.model,
      method: 'fields_get',
      args: <dynamic>[fieldNames],
      kwargs: const <String, dynamic>{
        'attributes': <String>['type', 'relation', 'selection'],
      },
    );

    if (!fieldsRes.success || fieldsRes.data is! Map) {
      throw Exception(fieldsRes.error ?? 'Could not read Odoo field metadata.');
    }

    final meta = Map<String, dynamic>.from(fieldsRes.data as Map);
    final result = <String, List<OdooFieldOption>>{};

    for (final field in fieldNames) {
      final fieldMetaRaw = meta[field];
      if (fieldMetaRaw is! Map) {
        result[field] = const <OdooFieldOption>[];
        continue;
      }
      final fieldMeta = Map<String, dynamic>.from(fieldMetaRaw);
      final type = fieldMeta['type']?.toString();

      if (type == 'many2one') {
        final relation = fieldMeta['relation']?.toString();
        if (relation == null || relation.isEmpty) {
          result[field] = const <OdooFieldOption>[];
          continue;
        }
        final optionRes = await _api.callKw(
          model: relation,
          method: 'search_read',
          args: const <dynamic>[<dynamic>[]],
          kwargs: const <String, dynamic>{
            'fields': <String>['id', 'display_name'],
            'limit': 100,
            'order': 'id desc',
          },
        );
        if (!optionRes.success || optionRes.data is! List) {
          result[field] = const <OdooFieldOption>[];
          continue;
        }
        result[field] = (optionRes.data as List)
            .map((e) {
              if (e is! Map) return null;
              final map = Map<String, dynamic>.from(e);
              final id = map['id'];
              if (id == null) return null;
              final label = map['display_name']?.toString() ?? id.toString();
              return OdooFieldOption(id: id, label: label);
            })
            .whereType<OdooFieldOption>()
            .toList();
      } else if (type == 'selection') {
        final selection = fieldMeta['selection'];
        if (selection is! List) {
          result[field] = const <OdooFieldOption>[];
          continue;
        }
        result[field] = selection
            .map((e) {
              if (e is List && e.length >= 2) {
                return OdooFieldOption(
                  id: e[0],
                  label: e[1]?.toString() ?? e[0].toString(),
                );
              }
              return null;
            })
            .whereType<OdooFieldOption>()
            .toList();
      } else {
        result[field] = const <OdooFieldOption>[];
      }
    }

    await _saveFieldOptionsCache(result);
    return result;
  }

  Future<int> createOrder(Map<String, dynamic> values) async {
    AppLogger.debug(
      'createOrder: canOdoo=${_canRequestOdoo()}, valueKeys=${values.keys.toList()}',
      tag: 'ORDER_REPO',
    );
    if (_canRequestOdoo()) {
      try {
        final odooCreate = _valuesForOdooWrite(values);
        final created = await _createOrderRemote(odooCreate);
        await _upsertOrderCacheById(
          created,
          _buildLocalOrderMap(
            id: created,
            values: values,
            syncStatus: 'synced',
          ),
        );
        await _saveOrderDetailCache(
          created,
          _buildOrderDetailFromValues(
            id: created,
            values: values,
            syncStatus: 'synced',
          ),
        );
        return created;
      } catch (e) {
        AppLogger.warning(
          'Remote create failed, storing local pending order: $e',
          tag: 'ORDER_REPO',
        );
        return _createOrderLocalPending(values);
      }
    }
    return _createOrderLocalPending(values);
  }

  Future<Map<String, dynamic>> fetchOrderById(
    int id, {
    required List<String> fields,
  }) async {
    if (_canRequestOdoo()) {
      try {
        final res = await _api.callKw(
          model: OdooOrdersConfig.model,
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[
              <dynamic>['id', '=', id]
            ]
          ],
          kwargs: <String, dynamic>{
            'fields': fields,
            'limit': 1,
          },
        );
        if (res.success && res.data is List) {
          final list = res.data as List;
          if (list.isNotEmpty && list.first is Map) {
            final map = Map<String, dynamic>.from(list.first as Map);
            await _saveOrderDetailCache(id, map);
            final wt = map['worksheet_template_id'];
            if (wt != null && wt != false) {
              fetchWorksheetRecords(fsmOrderId: id).then(
                (_) {},
                onError: (_e, _st) {},
              );
            }
            return map;
          }
        }
        AppLogger.error(
          'fetchOrderById remote failed: ${res.error}',
          tag: 'ORDER_REPO',
        );
      } catch (e) {
        AppLogger.error('fetchOrderById remote error', tag: 'ORDER_REPO', error: e);
      }
    }

    final cached = await _readOrderDetailCache(id);
    if (cached != null) return cached;
    final listFallback = await _readOrderFromItemsCacheById(id);
    if (listFallback != null) return listFallback;
    throw Exception(
      'Could not load order $id (offline and no cached copy). Open this order once while online.',
    );
  }

  /// Resolves map coordinates from `fsm.location.date_localization`
  /// using the order's `location_id`.
  Future<OrderMapCoordinates?> fetchOrderMapCoordinates(int orderId) async {
    if (!_canRequestOdoo()) {
      return _readCachedMapCoordinates(orderId);
    }
    final locationId = await _fetchOrderLocationId(orderId);
    if (locationId == null) return null;
    final coords = await _fetchLocationCoordinatesFromDateLocalization(locationId);
    if (coords != null) {
      await _saveMapCoordinatesCache(orderId, coords);
    }
    return coords;
  }

  Future<FsmLocationDialogModel> fetchMapDialogLocationDetails(int orderId) async {
    if (!_canRequestOdoo()) {
      return await _readMapDialogLocationFromOrderCache(orderId);
    }
    final locationId = await _fetchOrderLocationId(orderId);
    if (locationId == null) return FsmLocationDialogModel.empty();
    try {
      final res = await _api.callKw(
        model: 'fsm.location',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['id', '=', locationId],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': const <String>[
            'id',
            'phone',
            'mobile',
            'street',
            'street2',
            'city',
            'state_id',
            'zip',
            'country_id',
          ],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List) return FsmLocationDialogModel.empty();
      final rows = res.data as List;
      if (rows.isEmpty || rows.first is! Map) return FsmLocationDialogModel.empty();
      final row = Map<String, dynamic>.from(rows.first as Map);
      String _text(dynamic v) => (v == null || v == false) ? '' : v.toString();
      return FsmLocationDialogModel(
        phone: _text(row['phone']),
        mobile: _text(row['mobile']),
        street: _text(row['street']),
        street2: _text(row['street2']),
        city: _text(row['city']),
        state: _m2oLabel(row['state_id']),
        zip: _text(row['zip']),
        country: _m2oLabel(row['country_id']),
      );
    } catch (_) {
      return FsmLocationDialogModel.empty();
    }
  }

  Future<int?> _fetchOrderLocationId(int orderId) async {
    try {
      final res = await _api.callKw(
        model: OdooOrdersConfig.model,
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['id', '=', orderId],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'location_id'],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List) return null;
      final rows = res.data as List;
      if (rows.isEmpty || rows.first is! Map) return null;
      final row = Map<String, dynamic>.from(rows.first as Map);
      await _saveOrderDetailCache(orderId, row);
      return _m2oId(row['location_id']);
    } catch (_) {
      return null;
    }
  }

  Future<OrderMapCoordinates?> _fetchLocationCoordinatesFromDateLocalization(
      int locationId,
      ) async {
    try {
      final res = await _api.callKw(
        model: 'fsm.location',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['id', '=', locationId],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': const <String>['id', 'partner_latitude', 'partner_longitude'],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List) return null;
      final rows = res.data as List;
      if (rows.isEmpty || rows.first is! Map) return null;
      final row = Map<String, dynamic>.from(rows.first as Map);
      final lat = _toDouble(row['partner_latitude']);
      final lng = _toDouble(row['partner_longitude']);
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) return null;
      return OrderMapCoordinates(latitude: lat, longitude: lng);
    } catch (_) {
      return null;
    }
  }

  int? _m2oId(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is int) return first;
      if (first is num) return first.toInt();
      return int.tryParse(first.toString());
    }
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  double? _toDouble(dynamic v) {
    if (v == null || v == false) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Odoo `sale.order` / `account.move` use `currency_id` (m2o → `res.currency`).
  /// JSON-RPC `search_read` on those models does not include `symbol`; read
  /// `res.currency` for `symbol` and `position` (`before` / `after` amount).
  Future<void> _attachCurrencyDisplay(Map<String, dynamic> record) async {
    if (!_canRequestOdoo()) return;
    final cid = _m2oId(record['currency_id']);
    if (cid == null || cid <= 0) return;
    try {
      final res = await _api.callKw(
        model: 'res.currency',
        method: 'read',
        args: <dynamic>[
          <int>[cid],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['symbol', 'position'],
        },
      );
      if (!res.success || res.data is! List) return;
      final list = res.data as List;
      if (list.isEmpty || list.first is! Map) return;
      final c = Map<String, dynamic>.from(list.first as Map);
      final sym = c['symbol']?.toString().trim();
      if (sym != null && sym.isNotEmpty) {
        record['currency_symbol'] = sym;
      }
      final pos = c['position']?.toString().trim();
      if (pos != null && pos.isNotEmpty) {
        record['currency_position'] = pos;
      }
    } catch (_) {}
  }

  Future<void> _attachCurrencyDisplayForRecords(
    List<Map<String, dynamic>> records,
  ) async {
    if (!_canRequestOdoo() || records.isEmpty) return;
    final ids = <int>{};
    for (final r in records) {
      final id = _m2oId(r['currency_id']);
      if (id != null && id > 0) ids.add(id);
    }
    if (ids.isEmpty) return;
    try {
      final res = await _api.callKw(
        model: 'res.currency',
        method: 'read',
        args: <dynamic>[ids.toList()],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'symbol', 'position'],
        },
      );
      if (!res.success || res.data is! List) return;
      final byId = <int, Map<String, dynamic>>{};
      for (final e in res.data as List) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = _coerceInt(m['id']);
        if (id != null) byId[id] = m;
      }
      for (final r in records) {
        final cid = _m2oId(r['currency_id']);
        if (cid == null) continue;
        final c = byId[cid];
        if (c == null) continue;
        final sym = c['symbol']?.toString().trim();
        if (sym != null && sym.isNotEmpty) r['currency_symbol'] = sym;
        final pos = c['position']?.toString().trim();
        if (pos != null && pos.isNotEmpty) r['currency_position'] = pos;
      }
    } catch (_) {}
  }

  Future<void> _saveOrderDetailCache(int id, Map<String, dynamic> map) async {
    try {
      final box = await _openBox();
      final existingRaw = box.get(_orderDetailKey(id));
      final existing = existingRaw is Map
          ? Map<String, dynamic>.from(existingRaw)
          : <String, dynamic>{};
      final merged = <String, dynamic>{
        ...existing,
        ...map,
        'id': id,
      };
      await box.put(_orderDetailKey(id), merged);
    } catch (e) {
      AppLogger.error('saveOrderDetailCache', tag: 'ORDER_REPO', error: e);
    }
  }

  Future<Map<String, dynamic>?> _readOrderDetailCache(int id) async {
    try {
      final box = await _openBox();
      final raw = box.get(_orderDetailKey(id));
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (e) {
      AppLogger.error('readOrderDetailCache', tag: 'ORDER_REPO', error: e);
    }
    return null;
  }

  Future<void> saveTimesheetsCache(int orderId, List<Map<String, dynamic>> rows) async {
    try {
      final box = await _openBox();
      await box.put(_orderTimesheetsKey(orderId), rows);
    } catch (e) {
      AppLogger.error('saveTimesheetsCache', tag: 'ORDER_REPO', error: e);
    }
  }

  Future<List<Map<String, dynamic>>> readTimesheetsCache(int orderId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_orderTimesheetsKey(orderId));
      if (raw is! List) return [];
      return raw
          .map((e) {
            if (e is! Map) return null;
            final m = Map<String, dynamic>.from(e);
            final rawUa = m['unit_amount'];
            m['unit_amount'] = OdooOrdersConfig.parseUnitAmountHours(rawUa);
            return m;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      AppLogger.error('readTimesheetsCache', tag: 'ORDER_REPO', error: e);
    }
    return [];
  }

  /// Loads timesheet lines for [orderId] from Odoo when online; otherwise from Hive.
  Future<List<Map<String, dynamic>>> fetchTimesheetsForOrder(int orderId) async {
    if (_canRequestOdoo()) {
      final merged = <Map<String, dynamic>>[];
      final seen = <int>{};

      void addAll(List<Map<String, dynamic>>? rows) {
        if (rows == null) return;
        for (final r in rows) {
          final rid = r['id'];
          if (rid is int && seen.add(rid)) merged.add(r);
        }
      }

      final idList = await _readTimesheetIdsFromOrder(orderId);
      if (idList.isNotEmpty) {
        addAll(await _searchReadTimesheetLines(<dynamic>[
          <dynamic>['id', 'in', idList],
        ]));
      }

      for (final domain in OdooOrdersConfig.timesheetDomainsForOrder(orderId)) {
        addAll(await _searchReadTimesheetLines(<dynamic>[domain]));
      }

      await saveTimesheetsCache(orderId, merged);
      return merged;
    }
    return readTimesheetsCache(orderId);
  }

  Future<Duration?> fetchOrderTimesheetCreateTime(int orderId) async {
    if (!_canRequestOdoo()) return null;
    try {
      // Call action_itis_timer_stop directly — this is what Odoo calls
      // when user stops the timer. It calculates rounded hours and returns
      // the action dict with default_time_spent in context.
      final res = await _api.callKw(
        model: 'fsm.order',
        method: 'action_itis_timer_stop',
        args: <dynamic>[
          <int>[orderId],
        ],
        kwargs: const <String, dynamic>{},
      );

      if (!res.success || res.data == null) {
        AppLogger.warning(
          'action_itis_timer_stop returned no data: ${res.error}',
          tag: 'ORDER_REPO',
        );
        return null;
      }

      // Response is an action dict — extract default_time_spent from context
      if (res.data is! Map) return null;
      final action = Map<String, dynamic>.from(res.data as Map);
      final context = action['context'];
      if (context is! Map) return null;

      final ctxMap = Map<String, dynamic>.from(context);
      final timeSpentRaw = ctxMap['default_time_spent'];
      if (timeSpentRaw == null) return null;

      // default_time_spent usually comes as float hours, but some servers
      // may return HH:MM text depending on customizations.
      final hours = _parseDefaultTimeSpentHours(timeSpentRaw);
      AppLogger.info(
        'action_itis_timer_stop: default_time_spent=$timeSpentRaw hours=$hours',
        tag: 'ORDER_REPO',
      );

      final microseconds = (hours * Duration.microsecondsPerHour).round();
      return Duration(microseconds: microseconds);
    } catch (e) {
      AppLogger.error(
        'fetchOrderTimesheetCreateTime error',
        tag: 'ORDER_REPO',
        error: e,
      );
      return null;
    }
  }

  double _parseDefaultTimeSpentHours(dynamic raw) {
    // Standard path: numeric float hours from Odoo wizard context.
    final asFloat = OdooOrdersConfig.parseUnitAmountHours(raw);
    if (asFloat > 0) return asFloat;

    // Fallback path: custom modules may send HH:MM or HH:MM:SS strings.
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return 0.0;
    final parts = text.split(':');
    if (parts.length < 2 || parts.length > 3) return asFloat;

    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = parts.length == 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
    if (h < 0 || m < 0 || s < 0) return asFloat;

    return h + (m / 60.0) + (s / 3600.0);
  }

  Future<List<OdooFieldOption>> fetchOptionsFromModel({
    required String model,
    String labelField = 'name',
  }) async {
    // Try from cache first if offline
    if (!_canRequestOdoo()) {
      return _readFieldOptionsCacheForModel(model);
    }
    try {
      final res = await _api.callKw(
        model: model,
        method: 'search_read',
        args: const <dynamic>[<dynamic>[]],
        kwargs: <String, dynamic>{
          'fields': <String>['id', labelField],
          'limit': 200,
          'order': 'id asc',
        },
      );
      if (!res.success || res.data is! List) return [];
      final options = (res.data as List).map((e) {
        if (e is! Map) return null;
        final m = Map<String, dynamic>.from(e);
        final id = m['id'];
        if (id == null) return null;
        final label = m[labelField]?.toString() ?? id.toString();
        return OdooFieldOption(id: id, label: label);
      }).whereType<OdooFieldOption>().toList();

      // Cache it
      await _saveFieldOptionsCacheForModel(model, options);
      return options;
    } catch (e) {
      AppLogger.error('fetchOptionsFromModel $model error', tag: 'ORDER_REPO', error: e);
      return _readFieldOptionsCacheForModel(model);
    }
  }

  Future<void> _saveFieldOptionsCacheForModel(
      String model, List<OdooFieldOption> options) async {
    try {
      final box = await _openBox();
      final key = _scopedKey('model_options_$model');
      await box.put(key, options
          .map((o) => <String, dynamic>{'id': o.id, 'label': o.label})
          .toList());
    } catch (_) {}
  }

  List<OdooFieldOption> _readFieldOptionsCacheForModel(String model) {
    try {
      final box = _box;
      if (box == null) return [];
      final key = _scopedKey('model_options_$model');
      final raw = box.get(key);
      if (raw is! List) return [];
      return raw.map((e) {
        if (e is! Map) return null;
        final m = Map<String, dynamic>.from(e);
        return OdooFieldOption(
          id: m['id'],
          label: m['label']?.toString() ?? '',
        );
      }).whereType<OdooFieldOption>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Dart mirror of Odoo's `_itis_timer_rounding`
  double _itisDartTimerRounding(double minutesSpent, int minimum, int rounding) {
    // max(minimum, minutes_spent)
    minutesSpent = minutesSpent < minimum ? minimum.toDouble() : minutesSpent;

    // if rounding > 0 and minutes_spent % rounding != 0 → ceil to next interval
    if (rounding > 0 && minutesSpent % rounding != 0) {
      minutesSpent = ((minutesSpent / rounding).ceil() * rounding).toDouble();
    }

    return minutesSpent;
  }

  Future<List<int>> _readTimesheetIdsFromOrder(int orderId) async {
    if (!_canRequestOdoo()) return [];
    try {
      final res = await _api.callKw(
        model: OdooOrdersConfig.model,
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['id', '=', orderId],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['timesheet_ids'],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List) return [];
      final list = res.data as List;
      if (list.isEmpty || list.first is! Map) return [];
      final raw = (list.first as Map)['timesheet_ids'];
      if (raw is! List) return [];
      return raw
          .map((e) => e is int ? e : (e is num ? e.toInt() : int.tryParse('$e')))
          .whereType<int>()
          .toList();
    } catch (e) {
      AppLogger.error('timesheet_ids on order', tag: 'ORDER_REPO', error: e);
      return [];
    }
  }

  /// Tries [OdooOrdersConfig.timesheetLineFields]; retries with a smaller field set if Odoo rejects unknown columns.
  Future<List<Map<String, dynamic>>?> _searchReadTimesheetLines(
    List<dynamic> domain,
  ) async {
    final attempts = <List<String>>[
      List<String>.from(OdooOrdersConfig.timesheetLineFields),
      const <String>['id', 'date', 'name', 'unit_amount', 'employee_id'],
      const <String>['id', 'date', 'name', 'unit_amount'],
    ];
    for (final fieldList in attempts) {
      try {
        final res = await _api.callKw(
          model: OdooOrdersConfig.timesheetLineModel,
          method: 'search_read',
          args: <dynamic>[domain],
          kwargs: <String, dynamic>{
            'fields': fieldList,
            'limit': 200,
            'order': 'id desc',
          },
        );
        if (!res.success) continue;
        if (res.data is! List) continue;
        final list = res.data as List;
        return list
            .map((e) {
              if (e is! Map) return null;
              final m = Map<String, dynamic>.from(e);
              final rawUa = m['unit_amount'];
              m['unit_amount'] = OdooOrdersConfig.parseUnitAmountHours(rawUa);
              return m;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (e) {
        AppLogger.error(
          'timesheet search_read retry',
          tag: 'ORDER_REPO',
          error: e,
        );
      }
    }
    return null;
  }

  /// Creates a timesheet line on Odoo when online. Returns new id or null on failure.
  /// Resolves `hr.employee` id for the logged-in Odoo user (`res.users`).
  Future<int?> findHrEmployeeIdForSessionUser() async {
    if (!_canRequestOdoo()) return null;
    if (!Get.isRegistered<StorageService>()) return null;
    final uid = int.tryParse(Get.find<StorageService>().userId);
    if (uid == null || uid <= 0) return null;
    try {
      final res = await _api.callKw(
        model: 'hr.employee',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['user_id', '=', uid],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id'],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List) return null;
      final list = res.data as List;
      if (list.isEmpty || list.first is! Map) return null;
      final id = (list.first as Map)['id'];
      if (id is int) return id;
      if (id is num) return id.toInt();
      return int.tryParse(id.toString());
    } catch (e) {
      AppLogger.error('findHrEmployeeIdForSessionUser', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  Future<int?> createTimesheetLine(Map<String, dynamic> values) async {
    if (!_canRequestOdoo()) return null;
    final payload = Map<String, dynamic>.from(values);
    if (payload.containsKey('unit_amount')) {
      payload['unit_amount'] =
          OdooOrdersConfig.parseUnitAmountHours(payload['unit_amount']);
    }
    final res = await _api.callKw(
      model: OdooOrdersConfig.timesheetLineModel,
      method: 'create',
      args: <dynamic>[payload],
      kwargs: const <String, dynamic>{},
    );
    if (!res.success || res.data == null) {
      AppLogger.error(
        'createTimesheetLine failed: ${res.error} values=$payload',
        tag: 'ORDER_REPO',
      );
      return null;
    }
    final created = res.data;
    if (created is int) return created;
    if (created is num) return created.toInt();
    return int.tryParse(created.toString());
  }

  Future<void> updateOrder(int id, Map<String, dynamic> values) async {
    final odooVals = _valuesForOdooWrite(values);
    if (!_canRequestOdoo()) {
      final prior = await _readRawKanbanItemRow(id);
      final merged = await _mergeOrderDetailValuesLocally(id, values);
      if (prior != null) {
        if (merged['stage_id'] == null || merged['stage_id'] == false) {
          final s = prior['stage_id'];
          if (s != null && s != false) merged['stage_id'] = s;
        }
        final sl = prior['section_label']?.toString().trim();
        if (sl != null && sl.isNotEmpty) {
          merged['_kanban_section_label'] = sl;
        }
        final tit = prior['title']?.toString().trim();
        if (tit != null &&
            tit.isNotEmpty &&
            (merged['name'] == null || merged['name'].toString().trim().isEmpty)) {
          merged['name'] = tit;
        }
      }
      await _upsertOrderCacheById(
        id,
        _buildLocalOrderMap(
          id: id,
          values: merged,
          syncStatus: id > 0 ? 'pending_update' : 'pending_create',
        ),
      );
      await _enqueueFsmOrderWrite(id, Map<String, dynamic>.from(odooVals));
      return;
    }
    final res = await _api.callKw(
      model: OdooOrdersConfig.model,
      method: 'write',
      args: <dynamic>[
        <int>[id],
        odooVals,
      ],
      kwargs: const <String, dynamic>{},
    );
    if (!res.success) {
      throw Exception(res.error ?? 'Could not update order.');
    }
    await _clearFsmOrderWriteForId(id);
    final merged = await _mergeOrderDetailValuesLocally(id, values);
    await _upsertOrderCacheById(
      id,
      _buildLocalOrderMap(id: id, values: merged, syncStatus: 'synced'),
    );
  }

  Future<void> syncPendingOrders() async {
    if (!_canRequestOdoo()) {
      AppLogger.debug('syncPendingOrders: skipped (no Odoo session / offline)',
          tag: 'ORDER_REPO');
      return;
    }
    await _syncPendingFsmOrderWrites();
    await _syncPendingFsmOrderActions();
    final box = await _openBox();
    final raw = box.get(_keyPendingOrderCreates);
    if (raw is! List || raw.isEmpty) {
      AppLogger.debug('syncPendingOrders: queue empty', tag: 'ORDER_REPO');
      // Still run other sync tasks even if FSM order queue is empty
      await syncPendingVehicleStockTransfers();
      await _syncPendingProductQty();
      await _syncPendingInvoicesAndDeliveries();
      await _syncPendingWorksheets();
      return;
    }

    final pending = raw
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();

    AppLogger.debug(
      'syncPendingOrders: processing ${pending.length} job(s)',
      tag: 'ORDER_REPO',
    );
    final remaining = <Map<String, dynamic>>[];
    for (final job in pending) {
      final localId = _coerceInt(job['local_id']);
      final valuesRaw = job['values'];
      final values = valuesRaw is Map
          ? Map<String, dynamic>.from(valuesRaw)
          : <String, dynamic>{};
      if (localId == null || values.isEmpty) {
        AppLogger.warning(
          'syncPendingOrders: skipping bad job localId=$localId '
          'valuesEmpty=${values.isEmpty}',
          tag: 'ORDER_REPO',
        );
        continue;
      }

      try {
        final remoteId = await _createOrderRemote(_valuesForOdooWrite(values));
        AppLogger.success(
          'syncPendingOrders: local $localId → remote $remoteId',
          tag: 'ORDER_REPO',
        );
        await _replaceLocalOrderAfterSync(
          localId: localId,
          remoteId: remoteId,
          values: values,
        );
      } catch (e) {
        final retries = (_coerceInt(job['retries']) ?? 0) + 1;
        AppLogger.warning(
          'syncPendingOrders: failed localId=$localId retry=$retries: $e',
          tag: 'ORDER_REPO',
        );
        remaining.add(<String, dynamic>{
          ...job,
          'retries': retries,
          'last_error': e.toString(),
        });
      }
    }
    await box.put(_keyPendingOrderCreates, remaining);
    if (remaining.isNotEmpty) {
      AppLogger.warning(
        'syncPendingOrders: ${remaining.length} job(s) still queued',
        tag: 'ORDER_REPO',
      );
    }
    await syncPendingVehicleStockTransfers();
    await _syncPendingProductQty();
    await _syncPendingInvoicesAndDeliveries();
    await _syncPendingWorksheets();
  }

  Future<void> _syncPendingProductQty() async {
    if (!_canRequestOdoo()) return;

      final box = await _openBox();
      final raw = box.get(_keyPendingProductQty);
      if (raw is! List || raw.isEmpty) return;
      final jobs = List<Map<String, dynamic>>.from(
        raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      );
      final remaining = <Map<String, dynamic>>[];
      for (final job in jobs) {
        final fsmId = job['fsmOrderId'] as int?;
        final prodId = job['productId'] as int?;
        final qty = (job['qty'] as num?)?.toDouble() ?? 0.0;
        final useWarehouse = (job['useWarehouse'] as bool?) ?? false;
        if (fsmId == null || prodId == null) continue;
        try {
          await setFsmProductQuantity(
            fsmOrderId: fsmId,
            productId: prodId,
            quantity: qty,
            useWarehouseStock: useWarehouse,
          );
        } catch (e) {
          remaining.add(job);
        }
      }
      await box.put(_keyPendingProductQty, remaining);
  }

  /// Proactively warms offline caches after a successful online sync.
  ///
  /// - Caches create-form dropdown options
  /// - Caches full detail payload for listed orders
  /// - Caches map coordinates for listed orders (best effort)
  Future<void> warmOfflineCachesForOrders(List<OrderModel> orders) async {
    if (!_canRequestOdoo()) return;
    try {
      await fetchCreateOrderFieldOptions(const <String>[
        'partner_id',
        'template_id',
        'type',
        'location_id',
        'person_id',
        'vehicle_id',
        'company_id',
        'timesheet_type_id',
        'employee_id',
      ]);
    } catch (_) {
      // Best effort only.
    }

    final ids = orders
        .map((o) => _coerceInt(o.id))
        .whereType<int>()
        .where((id) => id > 0)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    const detailFields = <String>[
      'id',
      'partner_id',
      'template_id',
      'type',
      'location_id',
      'person_id',
      'vehicle_id',
      'company_id',
      'priority',
      'description',
      'resolution',
      'request_early',
      'request_late',
      'scheduled_date_start',
      'scheduled_duration',
      'scheduled_date_end',
      'todo',
      'location_directions',
      'date_start',
      'date_end',
      'duration',
      'worksheet_template_id',
    ];

    const chunkSize = 40;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      final chunk = ids.sublist(i, end);
      try {
        final res = await _api.callKw(
          model: OdooOrdersConfig.model,
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[
              <dynamic>['id', 'in', chunk],
            ],
          ],
          kwargs: const <String, dynamic>{
            'fields': detailFields,
            'limit': 500,
          },
        );
        if (res.success && res.data is List) {
          for (final e in (res.data as List)) {
            if (e is! Map) continue;
            final map = Map<String, dynamic>.from(e);
            final id = _coerceInt(map['id']);
            if (id == null) continue;
            await _saveOrderDetailCache(id, map);
          }
        }
      } catch (_) {
        // Best effort only.
      }
    }

    // ── Warm products FIRST (highest priority for offline use) ──────────────
    final Set<int> warmedPartnerIds = {};
    final Set<int> warmedVehicleIds = {};

    for (final id in ids) {
      try {
        final detail = await _readOrderDetailCache(id);
        if (detail == null) continue;

        final partnerRaw = detail['partner_id'];
        final partnerId = _m2oId(partnerRaw) ?? _coerceInt(partnerRaw);

        if (partnerId != null && partnerId > 0 && !warmedPartnerIds.contains(partnerId)) {
          warmedPartnerIds.add(partnerId);
          try {
            await fetchProductsForPartner(partnerId: partnerId);
          } catch (_) {}
        }

        final vehicleId = _m2oId(detail['vehicle_id']) ?? _coerceInt(detail['vehicle_id']);
        if (vehicleId != null && vehicleId > 0 && !warmedVehicleIds.contains(vehicleId)) {
          warmedVehicleIds.add(vehicleId);
          try {
            await fetchVehicleStockWizardDefaults(fsmOrderId: id);
            await fetchVehicleStockProducts(vehicleId: vehicleId);
          } catch (_) {}
        }

        try {
          await fetchVehicleStockProducts_ForCarInventory(fsmOrderId: id);
        } catch (_) {}

      } catch (_) {
        // Best effort only.
      }
    }

    // ── Map coordinates (lower priority) ────────────────────────────────────
    for (final id in ids) {
      try {
        await fetchOrderMapCoordinates(id);
      } catch (_) {
        // Best effort only.
      }
    }

    // ── Sale orders / invoices / deliveries ──────────────────────────────────
    for (final id in ids) {
      try {
        final saleOrder = await fetchSaleOrderForFsmOrder(id);
        if (saleOrder != null) {
          final saleId = saleOrder['id'] as int?;
          if (saleId != null) {
            await fetchPickingsForSaleOrder(saleId);
            await fetchInvoicesForSaleOrder(saleId);
          }
        }
      } catch (_) {
        // Best effort only.
      }
    }

    // Worksheets are prefetched first via [prefetchAllWorksheetsForOrders]
    // when the board loads online (see OrderController.loadOrders).
  }


  Future<int> _createOrderRemote(Map<String, dynamic> values) async {
    final res = await _api.callKw(
      model: OdooOrdersConfig.model,
      method: 'create',
      args: <dynamic>[values],
      kwargs: const <String, dynamic>{},
    );
    if (!res.success || res.data == null) {
      throw Exception(res.error ?? 'Could not create order.');
    }
    final created = res.data;
    if (created is int) return created;
    if (created is num) return created.toInt();
    final parsed = int.tryParse(created.toString());
    if (parsed == null) {
      throw Exception('Unexpected create response: $created');
    }
    return parsed;
  }

  Future<int> _createOrderLocalPending(Map<String, dynamic> values) async {
    final box = await _openBox();
    final merged = _mergeDefaultStageFromCache(box, values);
    final partnerLabel = _lookupFieldOptionLabelFromCache(
      box: box,
      fieldKey: 'partner_id',
      selectedValue: merged['partner_id'],
    );
    final localId = await _nextLocalOrderId();
    final localOrder = _buildLocalOrderMap(
      id: localId,
      values: merged,
      syncStatus: 'pending_create',
      partnerLabelOverride: partnerLabel,
    );
    final localDetail = _buildOrderDetailFromValues(
      id: localId,
      values: merged,
      syncStatus: 'pending_create',
    );

    await _upsertOrderMapInItems(box, localOrder);
    await _saveOrderDetailCache(localId, localDetail);
    await _enqueuePendingCreate(
      box,
      localId,
      _valuesForOdooWrite(Map<String, dynamic>.from(merged)),
    );
    final q = box.get(_keyPendingOrderCreates);
    final qLen = q is List ? q.length : 0;
    AppLogger.debug(
      '_createOrderLocalPending: localId=$localId, pending_queue_len=$qLen',
      tag: 'ORDER_REPO',
    );
    return localId;
  }

  Future<int> _nextLocalOrderId() async {
    final box = await _openBox();
    final cur = _coerceInt(box.get(_keyLocalOrderIdSeq)) ?? -1;
    final next = cur <= -1 ? cur - 1 : -1;
    await box.put(_keyLocalOrderIdSeq, next);
    return next;
  }

  Future<void> _enqueuePendingCreate(
    Box<dynamic> box,
    int localId,
    Map<String, dynamic> values,
  ) async {
    final raw = box.get(_keyPendingOrderCreates);
    final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
    // Inject company_id if not already set — required for multi-company Odoo
    final enrichedValues = Map<String, dynamic>.from(values);
    if (enrichedValues['company_id'] == null) {
      if (Get.isRegistered<StorageService>()) {
        final companyIds = Get.find<StorageService>().selectedCompanyIds;
        if (companyIds.isNotEmpty) {
          enrichedValues['company_id'] = companyIds.first;
        }
      }
    }
    list.add(<String, dynamic>{
      'local_id': localId,
      'values': enrichedValues,
      'retries': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    await box.put(_keyPendingOrderCreates, list);
  }

  Future<void> _replaceLocalOrderAfterSync({
    required int localId,
    required int remoteId,
    required Map<String, dynamic> values,
  }) async {
    final box = await _openBox();
    final items = box.get(_keyItems);
    final maps = items is List
        ? items
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>()
            .toList()
        : <Map<String, dynamic>>[];

    maps.removeWhere((m) => _coerceInt(m['id']) == localId);
    maps.add(_buildLocalOrderMap(id: remoteId, values: values, syncStatus: 'synced'));
    await box.put(_keyItems, maps);

    final localDetail = await _readOrderDetailCache(localId);
    if (localDetail != null) {
      final moved = Map<String, dynamic>.from(localDetail)
        ..['id'] = remoteId
        ..['sync_status'] = 'synced';
      await _saveOrderDetailCache(remoteId, moved);
    } else {
      await _saveOrderDetailCache(
        remoteId,
        _buildOrderDetailFromValues(id: remoteId, values: values, syncStatus: 'synced'),
      );
    }

    await _remapOfflineOrderLinksAfterSync(
      box: box,
      localId: localId,
      remoteId: remoteId,
    );
  }

  Future<void> _remapOfflineOrderLinksAfterSync({
    required Box<dynamic> box,
    required int localId,
    required int remoteId,
  }) async {
    // Move "sale order by fsm" cache from local temporary id to real remote id.
    final localSaleRaw = box.get(_saleOrderByFsmKey(localId));
    if (localSaleRaw is Map) {
      await box.put(_saleOrderByFsmKey(remoteId), Map<String, dynamic>.from(localSaleRaw));
      await box.delete(_saleOrderByFsmKey(localId));
    }

    // Remap queued offline product-qty jobs that still reference local fsm id.
    final qtyRaw = box.get(_keyPendingProductQty);
    if (qtyRaw is List && qtyRaw.isNotEmpty) {
      final jobs = qtyRaw
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
      var changed = false;
      for (final j in jobs) {
        if (_coerceInt(j['fsmOrderId']) == localId) {
          j['fsmOrderId'] = remoteId;
          changed = true;
        }
      }
      if (changed) {
        await box.put(_keyPendingProductQty, jobs);
      }
    }
  }

  /// Rows merged on top of a fresh Odoo `search_read` when saving kanban cache:
  /// - Offline-created orders (negative id)
  /// - Offline-edited server orders (`pending_update`) so they stay visible and
  ///   are not replaced by stale server rows until `write` sync succeeds.
  List<Map<String, dynamic>> _readPendingLocalOrderMaps(Box<dynamic> box) {
    final items = box.get(_keyItems);
    if (items is! List) return <Map<String, dynamic>>[];
    return items
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .where((m) {
          final id = _coerceInt(m['id']);
          if (id != null && id < 0) return true;
          return m['sync_status']?.toString() == 'pending_update';
        })
        .toList();
  }

  Future<Map<String, dynamic>?> _readRawKanbanItemRow(int orderId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyItems);
      if (raw is! List) return null;
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        if (_coerceInt(m['id']) == orderId) return m;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _enqueueFsmOrderWrite(int orderId, Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingFsmOrderWrites);
      final merged = raw is Map
          ? Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)))
          : <String, dynamic>{};
      final key = orderId.toString();
      final prev = merged[key] is Map
          ? Map<String, dynamic>.from(merged[key] as Map)
          : <String, dynamic>{};
      prev.addAll(patch);
      merged[key] = prev;
      await box.put(_keyPendingFsmOrderWrites, merged);
    } catch (_) {}
  }

  Future<void> _enqueueFsmOrderAction(String action, int orderId) async {
    if (orderId <= 0) return;
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingFsmOrderActions);
      final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
      list.add(<String, dynamic>{
        'action': action,
        'order_id': orderId,
        'created_at': DateTime.now().toIso8601String(),
      });
      await box.put(_keyPendingFsmOrderActions, list);
    } catch (_) {}
  }

  Future<void> _syncPendingFsmOrderWrites() async {
    if (!_canRequestOdoo()) return;
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingFsmOrderWrites);
      if (raw is! Map || raw.isEmpty) return;
      final map = Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
      final remaining = <String, dynamic>{};
      for (final e in map.entries) {
        final id = int.tryParse(e.key);
        if (id == null || id <= 0) continue;
        final vals = e.value is Map ? Map<String, dynamic>.from(e.value as Map) : null;
        if (vals == null || vals.isEmpty) continue;
        try {
          final res = await _api.callKw(
            model: OdooOrdersConfig.model,
            method: 'write',
            args: <dynamic>[
              <int>[id],
              vals,
            ],
            kwargs: const <String, dynamic>{},
          );
          if (!res.success) {
            remaining[e.key] = vals;
          } else {
            await _patchKanbanItemSyncStatus(id, 'synced');
          }
        } catch (_) {
          remaining[e.key] = vals;
        }
      }
      await box.put(_keyPendingFsmOrderWrites, remaining);
    } catch (_) {}
  }

  Future<void> _syncPendingFsmOrderActions() async {
    if (!_canRequestOdoo()) return;
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingFsmOrderActions);
      if (raw is! List || raw.isEmpty) return;
      final jobs = raw
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
      final remaining = <Map<String, dynamic>>[];
      for (final job in jobs) {
        final action = job['action']?.toString() ?? '';
        final oid = _coerceInt(job['order_id']);
        if (oid == null || oid <= 0) continue;
        try {
          final method = action == 'cancel' ? 'action_cancel' : 'action_complete';
          final res = await _api.callKw(
            model: OdooOrdersConfig.model,
            method: method,
            args: <dynamic>[
              <int>[oid],
            ],
            kwargs: const <String, dynamic>{},
          );
          if (!res.success) {
            remaining.add(job);
          } else {
            await _patchKanbanItemSyncStatus(oid, 'synced');
          }
        } catch (_) {
          remaining.add(job);
        }
      }
      await box.put(_keyPendingFsmOrderActions, remaining);
    } catch (_) {}
  }

  Future<void> _clearFsmOrderWriteForId(int id) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingFsmOrderWrites);
      if (raw is! Map) return;
      final map = Map<String, dynamic>.from(
        (raw as Map).map((k, v) => MapEntry(k.toString(), v)),
      );
      if (map.remove(id.toString()) != null) {
        await box.put(_keyPendingFsmOrderWrites, map);
      }
    } catch (_) {}
  }

  Future<void> _patchKanbanItemSyncStatus(int orderId, String status) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyItems);
      if (raw is! List) return;
      final maps = raw
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
      var changed = false;
      for (final m in maps) {
        if (_coerceInt(m['id']) == orderId) {
          m['sync_status'] = status;
          changed = true;
          break;
        }
      }
      if (changed) await box.put(_keyItems, maps);
    } catch (_) {}
  }

  Future<void> _upsertOrderCacheById(int id, Map<String, dynamic> orderMap) async {
    final box = await _openBox();
    await _upsertOrderMapInItems(box, orderMap);
  }

  Future<void> _upsertOrderMapInItems(
    Box<dynamic> box,
    Map<String, dynamic> orderMap,
  ) async {
    final items = box.get(_keyItems);
    final maps = items is List
        ? items
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>()
            .toList()
        : <Map<String, dynamic>>[];
    final id = _coerceInt(orderMap['id']);
    maps.removeWhere((m) => _coerceInt(m['id']) == id);
    maps.add(orderMap);
    await box.put(_keyItems, maps);
  }

  Map<String, dynamic> _valuesForOdooWrite(Map<String, dynamic> values) {
    final out = Map<String, dynamic>.from(values);
    for (final k in _orderDetailMany2oneKeys) {
      if (!out.containsKey(k)) continue;
      final v = out[k];
      if (v is List && v.isNotEmpty) {
        final oid = _coerceInt(v.first);
        if (oid != null) out[k] = oid;
      }
    }
    return out;
  }

  Map<String, dynamic> _mergeDetailMapsPreservingMany2one(
    Box<dynamic> box,
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    for (final e in incoming.entries) {
      if (e.key == 'id') continue;
      if (_orderDetailMany2oneKeys.contains(e.key)) {
        merged[e.key] = _mergeMany2oneDetailValue(
          box: box,
          existing: existing[e.key],
          incoming: e.value,
          key: e.key,
        );
      } else {
        merged[e.key] = e.value;
      }
    }
    return merged;
  }

  dynamic _mergeMany2oneDetailValue({
    required Box<dynamic> box,
    required dynamic existing,
    required dynamic incoming,
    required String key,
  }) {
    if (incoming == null || incoming == false) return incoming;
    if (incoming is List && incoming.isNotEmpty) return incoming;
    final inId = _coerceInt(incoming);
    if (inId == null) return incoming;
    if (existing is List && existing.isNotEmpty) {
      final exId = _coerceInt(existing.first);
      if (exId == inId) return existing;
    }
    final label = _lookupFieldOptionLabelFromCache(
      box: box,
      fieldKey: key,
      selectedValue: inId,
    );
    if (label != null && label.isNotEmpty) {
      return <dynamic>[inId, label];
    }
    return incoming;
  }

  Future<Map<String, dynamic>> _mergeOrderDetailValuesLocally(
    int id,
    Map<String, dynamic> values,
  ) async {
    final existing = await _readOrderDetailCache(id) ?? <String, dynamic>{'id': id};
    final box = await _openBox();
    final merged = _mergeDetailMapsPreservingMany2one(box, existing, values);
    await _saveOrderDetailCache(id, merged);
    return merged;
  }

  Map<String, dynamic> _buildLocalOrderMap({
    required int id,
    required Map<String, dynamic> values,
    required String syncStatus,
    String? partnerLabelOverride,
  }) {
    final title = (values['name']?.toString().trim().isNotEmpty ?? false)
        ? values['name'].toString().trim()
        : ((partnerLabelOverride?.trim().isNotEmpty ?? false)
            ? partnerLabelOverride!.trim()
            : (_displayFromM2o(values['partner_id']).trim().isNotEmpty
                ? _displayFromM2o(values['partner_id']).trim()
                : 'Order #$id'));
    final subtitle = _displayFromM2o(values['location_id']);
    dynamic stageRaw = values['stage_id'];
    if (stageRaw == false) stageRaw = null;
    var stageDisp = stageRaw != null ? _displayFromM2o(stageRaw) : '';
    if (stageDisp.isEmpty) {
      final fb = values['_kanban_section_label']?.toString().trim();
      if (fb != null && fb.isNotEmpty) stageDisp = fb;
    }
    final stage = stageDisp.isEmpty
        ? (syncStatus == 'synced' ? 'None' : 'None')
        : stageDisp;
    final stageId = _m2oId(stageRaw);
    return <String, dynamic>{
      'id': id.toString(),
      'title': title,
      'subtitle': subtitle,
      'priority': values['priority'] ?? 0,
      'sequence': _coerceInt(values['sequence']) ?? 0,
      'section_label': stage.isEmpty ? 'None' : stage,
      if (stageId != null) 'stage_id': stageId,
      'scheduled_start': values['scheduled_date_start']?.toString() ?? '',
      'assigned_to': _displayFromM2o(values['person_id']),
      'company': _displayFromM2o(values['company_id']),
      'phone': values['phone']?.toString() ?? '',
      'mobile': values['mobile']?.toString() ?? '',
      'street': values['street']?.toString() ?? '',
      'street2': values['street2']?.toString() ?? '',
      'city': values['city']?.toString() ?? '',
      'state': _displayFromM2o(values['state_id']).isNotEmpty
          ? _displayFromM2o(values['state_id'])
          : (values['state']?.toString() ?? ''),
      'zip': values['zip']?.toString() ?? '',
      'country': _displayFromM2o(values['country_id']).isNotEmpty
          ? _displayFromM2o(values['country_id'])
          : (values['country']?.toString() ?? ''),
      'sync_status': syncStatus,
    };
  }

  String? _lookupFieldOptionLabelFromCache({
    required Box<dynamic> box,
    required String fieldKey,
    required dynamic selectedValue,
  }) {
    final selected = _coerceInt(selectedValue);
    if (selected == null) return null;
    final raw = box.get(_keyFieldOptionsCache);
    if (raw is! Map) return null;
    final all = Map<String, dynamic>.from(raw);
    final listRaw = all[fieldKey];
    if (listRaw is! List) return null;
    for (final e in listRaw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      if (_coerceInt(m['id']) == selected) {
        final label = (m['label'] ?? '').toString().trim();
        if (label.isNotEmpty) return label;
      }
    }
    return null;
  }

  Map<String, dynamic> _buildOrderDetailFromValues({
    required int id,
    required Map<String, dynamic> values,
    required String syncStatus,
  }) {
    return <String, dynamic>{
      'id': id,
      ...values,
      'sync_status': syncStatus,
    };
  }

  String _displayFromM2o(dynamic v) {
    if (v == null || v == false) return '';
    if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
    return '';
  }

  String _m2oLabel(dynamic v) {
    if (v == null || v == false) return '';
    if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
    return '';
  }

  int? _coerceInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  Future<void> _saveMapCoordinatesCache(int orderId, OrderMapCoordinates c) async {
    try {
      final box = await _openBox();
      await box.put(_orderMapCoordsKey(orderId), <String, dynamic>{
        'lat': c.latitude,
        'lng': c.longitude,
      });
    } catch (_) {}
  }

  Future<OrderMapCoordinates?> _readCachedMapCoordinates(int orderId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_orderMapCoordsKey(orderId));
      if (raw is! Map) return null;
      final m = Map<String, dynamic>.from(raw);
      final lat = _toDouble(m['lat']);
      final lng = _toDouble(m['lng']);
      if (lat == null || lng == null) return null;
      return OrderMapCoordinates(latitude: lat, longitude: lng);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, List<OdooFieldOption>>> _readFieldOptionsCache(
    List<String> fieldNames,
  ) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyFieldOptionsCache);
      if (raw is! Map) {
        return <String, List<OdooFieldOption>>{
          for (final f in fieldNames) f: const <OdooFieldOption>[],
        };
      }
      final all = Map<String, dynamic>.from(raw);
      final out = <String, List<OdooFieldOption>>{};
      for (final f in fieldNames) {
        final listRaw = all[f];
        if (listRaw is! List) {
          out[f] = const <OdooFieldOption>[];
          continue;
        }
        out[f] = listRaw
            .map((e) {
              if (e is! Map) return null;
              final m = Map<String, dynamic>.from(e);
              if (!m.containsKey('id')) return null;
              return OdooFieldOption(
                id: m['id'],
                label: (m['label'] ?? m['id']).toString(),
              );
            })
            .whereType<OdooFieldOption>()
            .toList();
      }
      return out;
    } catch (_) {
      return <String, List<OdooFieldOption>>{
        for (final f in fieldNames) f: const <OdooFieldOption>[],
      };
    }
  }

  Future<void> _saveFieldOptionsCache(
    Map<String, List<OdooFieldOption>> options,
  ) async {
    try {
      final box = await _openBox();
      final existingRaw = box.get(_keyFieldOptionsCache);
      final existing = existingRaw is Map
          ? Map<String, dynamic>.from(existingRaw)
          : <String, dynamic>{};
      final encoded = <String, dynamic>{
        ...existing,
        for (final entry in options.entries)
          entry.key: entry.value
              .map((o) => <String, dynamic>{'id': o.id, 'label': o.label})
              .toList(),
      };
      await box.put(_keyFieldOptionsCache, encoded);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readOrderFromItemsCacheById(int id) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyItems);
      if (raw is! List) return null;
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final mid = _coerceInt(m['id']);
        if (mid != id) continue;
        return <String, dynamic>{
          'id': id,
          'name': m['title'],
          'location_id': (m['subtitle']?.toString().isNotEmpty ?? false)
              ? <dynamic>[0, m['subtitle']]
              : false,
          'scheduled_date_start': m['scheduled_start'] ?? '',
          'person_id': (m['assigned_to']?.toString().isNotEmpty ?? false)
              ? <dynamic>[0, m['assigned_to']]
              : false,
          'company_id': (m['company']?.toString().isNotEmpty ?? false)
              ? <dynamic>[0, m['company']]
              : false,
          'stage_id': (m['section_label']?.toString().isNotEmpty ?? false)
              ? <dynamic>[0, m['section_label']]
              : false,
          'priority': m['priority'] ?? 0,
        };
      }
    } catch (_) {}
    return null;
  }


  // ─────────────────────────────────────────────────────────────
  //  FSM Vehicle Stock Load Wizard
  // ─────────────────────────────────────────────────────────────

  static const String _rawKeyVehicleStockWizardCache = 'vehicle_stock_wizard_cache_v1';
  String get _keyVehicleStockWizardCache => _scopedKey(_rawKeyVehicleStockWizardCache);

  /// Fetches the wizard header data (fsm_order_id, vehicle_id, location_dest_id)
  /// from Odoo by creating a transient wizard record OR reading existing one.
  /// Falls back to offline cache if not connected.
  Future<Map<String, dynamic>> fetchVehicleStockWizardDefaults({
    required int fsmOrderId,
  }) async {
    final cacheKey = _scopedKey('vsw_defaults_$fsmOrderId');
    if (_canRequestOdoo()) {
      try {
        // Step 1: Fetch order name + vehicle_id from FSM order
        final orderRes = await _api.callKw(
          model: OdooOrdersConfig.model,
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[<dynamic>['id', '=', fsmOrderId]],
          ],
          kwargs: const <String, dynamic>{
            'fields': <String>['id', 'name', 'vehicle_id'],
            'limit': 1,
          },
        );

        Map<String, dynamic> orderData = {};
        if (orderRes.success && orderRes.data is List) {
          final rows = orderRes.data as List;
          if (rows.isNotEmpty && rows.first is Map) {
            orderData = Map<String, dynamic>.from(rows.first as Map);
          }
        }

        final vehicleIdRaw = orderData['vehicle_id'];
        final vehicleId = _m2oId(vehicleIdRaw);

        final map = <String, dynamic>{
          'fsm_order_id': fsmOrderId,
          '_fsm_order_name': orderData['name']?.toString() ?? 'Order #$fsmOrderId',
          if (vehicleIdRaw != null && vehicleIdRaw != false) 'vehicle_id': vehicleIdRaw,
        };

        // Step 2: Fetch location_dest_id directly from fsm.vehicle
        if (vehicleId != null) {
          try {
            final vehicleRes = await _api.callKw(
              model: 'fsm.vehicle',
              method: 'search_read',
              args: <dynamic>[
                <dynamic>[<dynamic>['id', '=', vehicleId]],
              ],
              kwargs: const <String, dynamic>{
                'fields': <String>['id', 'name', 'stock_location_id'],
                'limit': 1,
              },
            );
            if (vehicleRes.success && vehicleRes.data is List) {
              final vRows = vehicleRes.data as List;
              if (vRows.isNotEmpty && vRows.first is Map) {
                final vMap = Map<String, dynamic>.from(vRows.first as Map);
                final locRaw = vMap['stock_location_id'];
                if (locRaw != null && locRaw != false) {
                  map['location_dest_id'] = locRaw;
                }
              }
            }
          } catch (e) {
            AppLogger.warning('fetchVehicleStockWizardDefaults vehicle fetch failed: $e', tag: 'VSW');
          }
        }

        final box = await _openBox();
        await box.put(cacheKey, map);
        return map;
      } catch (e) {
        AppLogger.warning('fetchVehicleStockWizardDefaults failed: $e', tag: 'VSW');
      }
    }

    // Offline fallback
    try {
      final box = await _openBox();
      final raw = box.get(cacheKey);
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return <String, dynamic>{'fsm_order_id': fsmOrderId};
  }

  /// Resolves [fsm.vehicle.stock_location_id] for [vehicleId] (Odoo vehicle stock).
  Future<int?> _vehicleStockLocationId(int vehicleId) async {
    if (vehicleId <= 0) return null;
    if (!_canRequestOdoo()) return null;
    try {
      final vehicleRes = await _api.callKw(
        model: 'fsm.vehicle',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', vehicleId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['stock_location_id'],
          'limit': 1,
        },
      );
      if (vehicleRes.success && vehicleRes.data is List) {
        final vRows = vehicleRes.data as List;
        if (vRows.isNotEmpty && vRows.first is Map) {
          final vMap = Map<String, dynamic>.from(vRows.first as Map);
          return _m2oId(vMap['stock_location_id']);
        }
      }
    } catch (e) {
      AppLogger.warning('_vehicleStockLocationId failed: $e', tag: 'VSW');
    }
    return null;
  }

  /// Fetches stock.quant rows for the vehicle's stock location only — same domain as
  /// Odoo `action_view_vehicle_stock_and_transfers`: [('location_id', '=', vehicle_location.id)].
  ///
  /// Fields: location_id, product_id, lot_id, inventory_quantity_auto_apply,
  /// reserved_quantity, product_uom_id.
  ///
  /// [vehicleStockLocationId] optional; when omitted online, resolved from [fsm.vehicle].
  Future<List<Map<String, dynamic>>> fetchVehicleStockProducts({
    required int vehicleId,
    int? vehicleStockLocationId,
  }) async {
    final cacheKey = _scopedKey('vsw_vehicle_quants_$vehicleId');

    int? locationId = (vehicleStockLocationId != null && vehicleStockLocationId > 0)
        ? vehicleStockLocationId
        : null;
    if (locationId == null && _canRequestOdoo()) {
      locationId = await _vehicleStockLocationId(vehicleId);
    }

    if (_canRequestOdoo()) {
      if (locationId == null || locationId <= 0) {
        return const <Map<String, dynamic>>[];
      }
      try {
        final res = await _api.callKw(
          model: 'stock.quant',
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[
              <dynamic>['location_id', '=', locationId],
            ],
          ],
          kwargs: <String, dynamic>{
            'fields': <String>[
              'id',
              'location_id',
              'product_id',
              'lot_id',
              'inventory_quantity_auto_apply',
              'reserved_quantity',
              'product_uom_id',
            ],
            'limit': 200,
            'order': 'id desc',
            'context': <String, dynamic>{
              'location': locationId,
              'default_location_id': locationId,
              'vehicle_location_id': locationId,
              'active_id': locationId,
              'active_model': 'stock.location',
              'search_default_internal_loc': 1,
              'search_default_on_hand': 1,
            },
          },
        );
        if (res.success && res.data is List) {
          final rows = (res.data as List)
              .map((e) {
                if (e is! Map) return null;
                return Map<String, dynamic>.from(e);
              })
              .whereType<Map<String, dynamic>>()
              .toList();
          final box = await _openBox();
          await box.put(cacheKey, <String, dynamic>{
            'vehicle_stock_location_id': locationId,
            'rows': rows,
          });
          return rows;
        }
      } catch (e) {
        AppLogger.warning('fetchVehicleStockProducts quant failed: $e',
            tag: 'VSW');
      }
    }

    try {
      final box = await _openBox();
      final raw = box.get(cacheKey);
      if (raw is Map) {
        final list = raw['rows'];
        if (list is List) {
          return list
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      if (raw is List) {
        return raw
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAllProductsForDropdown() async {
    if (!_canRequestOdoo()) return [];
    try {
      final res = await _api.callKw(
        model: 'product.product',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['type', 'in', <String>['consu', 'product']],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': <String>['id', 'name'],
          'limit': 500,
          'order': 'name asc',
        },
      );
      if (res.success && res.data is List) {
        return (res.data as List)
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (e) {
      AppLogger.warning('fetchAllProductsForDropdown failed: $e', tag: 'VSW');
    }
    return [];
  }

  /// Fetches available qty for a specific product (optionally by lot).
  /// Used when user selects a product in the wizard line.
  Future<double> fetchProductAvailableQty({
    required int productId,
    int? vehicleId,
  }) async {
    if (_canRequestOdoo()) {
      try {
        int? locationId;
        if (vehicleId != null && vehicleId > 0) {
          locationId = await _vehicleStockLocationId(vehicleId);
        }
        final domain = <dynamic>[
          <dynamic>['product_id', '=', productId],
          if (vehicleId != null && vehicleId > 0)
            if (locationId != null && locationId > 0)
              <dynamic>['location_id', '=', locationId]
            else
              <dynamic>['id', '=', -1],
          if (vehicleId == null || vehicleId <= 0)
            <dynamic>['location_id.usage', '=', 'internal'],
        ];
        final res = await _api.callKw(
          model: 'stock.quant',
          method: 'search_read',
          args: <dynamic>[domain],
          kwargs: const <String, dynamic>{
            'fields': <String>['inventory_quantity_auto_apply'],
            'limit': 200,
          },
        );
        if (res.success && res.data is List) {
          var sum = 0.0;
          for (final row in res.data as List) {
            if (row is! Map) continue;
            final m = Map<String, dynamic>.from(row);
            sum += _toDouble(m['inventory_quantity_auto_apply']) ?? 0.0;
          }
          return sum;
        }
      } catch (e) {
        AppLogger.warning('fetchProductAvailableQty failed: $e', tag: 'VSW');
      }
    }
    return 0.0;
  }


  /// Fetches total qty available in ALL internal (warehouse) locations for a product.
  /// Used in the Vehicle Stock Warning dialog for "Available In Warehouse".
  Future<double> fetchWarehouseAvailableQty({required int productId}) async {
    if (!_canRequestOdoo()) return 0.0;
    try {
      final res = await _api.callKw(
        model: 'stock.quant',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['product_id', '=', productId],
            <dynamic>['location_id.usage', '=', 'internal'],
            <dynamic>['quantity', '>', 0],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['quantity'],
          'limit': 200,
        },
      );
      if (!res.success || res.data is! List) return 0.0;
      var total = 0.0;
      for (final row in res.data as List) {
        if (row is! Map) continue;
        total += _toDouble(Map<String, dynamic>.from(row)['quantity']) ?? 0.0;
      }
      return total;
    } catch (e) {
      AppLogger.error('fetchWarehouseAvailableQty error', tag: 'ORDER_REPO', error: e);
      return 0.0;
    }
  }

  /// Creates a sale.order with the given partner and product lines.
  /// Returns the created sale order id, or null on failure.
  Future<Map<String, dynamic>?> createSaleOrder({
    required int partnerId,
    required int fsmOrderId,
    required List<Map<String, dynamic>> lines,
  }) async
  {
    if (!_canRequestOdoo()) return null;
    try {
      // Build order lines as Odoo (0, 0, vals) commands
      final orderLines = lines.map((l) => <dynamic>[
        0, 0,
        <String, dynamic>{
          'product_id': l['product_id'],
          'product_uom_qty': l['qty'] ?? 1.0,
          'price_unit': l['price_unit'] ?? 0.0,
        },
      ]).toList();

      // Build base values — try common FSM link field names
      final baseValues = <String, dynamic>{
        'partner_id': partnerId,
        'order_line': orderLines,
      };

// Try to detect which FSM link field exists on sale.order
      final linkField = await _detectFsmLinkField();
      if (linkField != null) {
        // Detect if field is many2many (ends with _ids) or many2one
        if (linkField.endsWith('_ids')) {
          // many2many → use [(6, 0, [id])] command to set ids
          baseValues[linkField] = <dynamic>[
            <dynamic>[6, 0, <int>[fsmOrderId]],
          ];
        } else {
          // many2one → single id
          baseValues[linkField] = fsmOrderId;
        }
        AppLogger.info('Using FSM link field: $linkField (value: ${baseValues[linkField]})', tag: 'ORDER_REPO');
      }

      final createRes = await _api.callKw(
        model: 'sale.order',
        method: 'create',
        args: <dynamic>[baseValues],
        kwargs: const <String, dynamic>{},
      );

      if (!createRes.success || createRes.data == null) {
        AppLogger.error('createSaleOrder failed: ${createRes.error}', tag: 'ORDER_REPO');
        return null;
      }

      final newId = createRes.data is int
          ? createRes.data as int
          : int.tryParse(createRes.data.toString());
      if (newId == null) return null;

// Confirm the sale order to move it from Quotation (draft) → Sales Order (sale)
      final confirmRes = await _api.callKw(
        model: 'sale.order',
        method: 'action_confirm',
        args: <dynamic>[
          <int>[newId],
        ],
        kwargs: const <String, dynamic>{},
      );
      if (!confirmRes.success) {
        AppLogger.warning(
            'action_confirm failed (order stays as quotation): ${confirmRes.error}',
            tag: 'ORDER_REPO');
      } else {
        AppLogger.info('Sale order $newId confirmed successfully', tag: 'ORDER_REPO');
      }

// Fetch the created sale order details (now confirmed)
      return fetchSaleOrderById(newId);
    } catch (e) {
      AppLogger.error('createSaleOrder error', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  String? _cachedFsmLinkField;
  bool _fsmLinkFieldChecked = false;

  /// Detects the FSM link field on sale.order — different Odoo FSM modules use different names.
  Future<String?> _detectFsmLinkField() async {
    if (_fsmLinkFieldChecked) return _cachedFsmLinkField;
    _fsmLinkFieldChecked = true;

    try {
      final res = await _api.callKw(
        model: 'sale.order',
        method: 'fields_get',
        args: const <dynamic>[],
        kwargs: const <String, dynamic>{
          'attributes': <String>['type', 'relation'],
        },
      );
      if (!res.success || res.data is! Map) return null;

      final fields = Map<String, dynamic>.from(res.data as Map);
      // Try known FSM field names in order of likelihood
      final candidates = <String>[
        'fsm_order_ids',
        'fsm_order_id',
        'x_fsm_order_id',
        'field_service_id',
        'task_id',
      ];

      for (final name in candidates) {
        if (fields.containsKey(name)) {
          final info = Map<String, dynamic>.from(fields[name] as Map);
          final rel = info['relation']?.toString() ?? '';
          if (rel == 'fsm.order' || rel.contains('fsm')) {
            _cachedFsmLinkField = name;
            return name;
          }
        }
      }

      // Generic scan — any field relating to fsm.order
      for (final entry in fields.entries) {
        final info = entry.value;
        if (info is Map) {
          final rel = info['relation']?.toString() ?? '';
          if (rel == 'fsm.order') {
            _cachedFsmLinkField = entry.key;
            AppLogger.info('Auto-detected FSM link field: ${entry.key}', tag: 'ORDER_REPO');
            return entry.key;
          }
        }
      }

      AppLogger.warning('No FSM link field found on sale.order', tag: 'ORDER_REPO');
      return null;
    } catch (e) {
      AppLogger.error('_detectFsmLinkField error', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }


  /// Updates order lines on an existing sale.order.
  /// Replaces all lines with the new set from cart.
  Future<Map<String, dynamic>?> updateSaleOrderLines({
    required int saleOrderId,
    required List<Map<String, dynamic>> lines,
  }) async {
    if (!_canRequestOdoo()) return null;
    try {
      // Step 1: Read existing line ids
      final existing = await _api.callKw(
        model: 'sale.order',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', saleOrderId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['order_line'],
          'limit': 1,
        },
      );

      final List<int> existingLineIds = [];
      if (existing.success && existing.data is List &&
          (existing.data as List).isNotEmpty) {
        final row = Map<String, dynamic>.from(
            (existing.data as List).first as Map);
        final raw = row['order_line'];
        if (raw is List) {
          existingLineIds.addAll(raw.whereType<int>());
        }
      }

      // Step 2: Build write commands
      // (2, id, 0) = delete existing line
      // (0, 0, vals) = create new line
      final commands = <dynamic>[
        // Delete all existing lines
        ...existingLineIds.map((id) => <dynamic>[2, id, 0]),
        // Create new lines from cart
        ...lines.map((l) => <dynamic>[
          0, 0,
          <String, dynamic>{
            'product_id': l['product_id'],
            'product_uom_qty': l['qty'] ?? 1.0,
            'price_unit': l['price_unit'] ?? 0.0,
          },
        ]),
      ];

      final writeRes = await _api.callKw(
        model: 'sale.order',
        method: 'write',
        args: <dynamic>[
          <int>[saleOrderId],
          <String, dynamic>{'order_line': commands},
        ],
        kwargs: const <String, dynamic>{},
      );

      if (!writeRes.success) {
        AppLogger.error(
            'updateSaleOrderLines write failed: ${writeRes.error}',
            tag: 'ORDER_REPO');
        return null;
      }

// Re-confirm in case state changed
      await _api.callKw(
        model: 'sale.order',
        method: 'action_confirm',
        args: <dynamic>[
          <int>[saleOrderId],
        ],
        kwargs: const <String, dynamic>{},
      );

// Step 3: Return fresh sale order data
      return fetchSaleOrderById(saleOrderId);
    } catch (e) {
      AppLogger.error('updateSaleOrderLines error',
          tag: 'ORDER_REPO', error: e);
      return null;
    }
  }


  // ─────────────────────────────────────────────────────────────────────────────
//  FSM Product Catalog (matches Odoo's product.catalog.mixin flow)
// ─────────────────────────────────────────────────────────────────────────────

  /// Calls the custom FSM product catalog endpoint to update quantity for a product.
  /// This mirrors Odoo's product_catalog_update_order_line_info controller.
  /// It internally:
  ///   1. Creates sale.order if not exists (via fsm.order.sale_id)
  ///   2. Calls product.set_fsm_quantity(quantity)
  ///   3. Calls product._sync_fsm_products_to_sale_order()
  ///   4. Returns the sale order line with price_unit
  Future<Map<String, dynamic>?> updateFsmCatalogQuantity({
    required int fsmOrderId,
    required int productId,
    required double quantity,
  }) async {
    if (!_canRequestOdoo()) return null;
    try {
      final res = await _api.callKw(
        model: 'product.product',
        method: 'set_fsm_quantity',
        args: <dynamic>[
          <int>[productId],
          quantity,
        ],
        kwargs: <String, dynamic>{
          'context': <String, dynamic>{
            'fsm_order_id': fsmOrderId,
          },
        },
      );
      if (!res.success) {
        AppLogger.error('set_fsm_quantity failed: ${res.error}',
            tag: 'ORDER_REPO');
        return null;
      }



      return <String, dynamic>{
        'action': res.data,
      };
    } catch (e) {
      AppLogger.error('updateFsmCatalogQuantity error',
          tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  /// Fetches the sale order already linked to an FSM order via fsm.order.sale_id.
  /// This is the canonical way — Odoo's fsm.order has a sale_id field.
  Future<Map<String, dynamic>?> fetchOrCreateSaleOrderForFsm({
    required int fsmOrderId,
  }) async {
    if (!_canRequestOdoo()) {
      return _readSaleOrderByFsmCache(fsmOrderId);
    }
    try {
      // Step 1: Read fsm.order to check if sale_id already exists
      final fsmRes = await _api.callKw(
        model: 'fsm.order',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', fsmOrderId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'sale_id', 'partner_id'],
          'limit': 1,
        },
      );
      if (!fsmRes.success || fsmRes.data is! List) return null;
      final fsmRows = fsmRes.data as List;
      if (fsmRows.isEmpty) return null;

      final fsm = Map<String, dynamic>.from(fsmRows.first as Map);
      final saleIdRaw = fsm['sale_id'];

      int? saleOrderId;
      if (saleIdRaw is List && saleIdRaw.isNotEmpty) {
        saleOrderId = saleIdRaw.first is int
            ? saleIdRaw.first as int
            : int.tryParse(saleIdRaw.first.toString());
      }

      // Step 2: Return existing sale order if linked
      if (saleOrderId != null && saleOrderId > 0) {
        AppLogger.info('Found existing sale.order: $saleOrderId for FSM: $fsmOrderId',
            tag: 'ORDER_REPO');
        return fetchSaleOrderById(saleOrderId);
      }

      AppLogger.info('No sale.order linked yet for FSM: $fsmOrderId',
          tag: 'ORDER_REPO');
      return null;
    } catch (e) {
      AppLogger.error('fetchOrCreateSaleOrderForFsm error',
          tag: 'ORDER_REPO', error: e);
      return _readSaleOrderByFsmCache(fsmOrderId);
    }
  }


  /// Matches Odoo's /product_catalog/update_order_line_info controller exactly.
  /// This calls set_fsm_quantity + checks vehicle stock + creates sale line — all server-side.
  Future<Map<String, dynamic>?> setFsmProductQuantity({
    required int fsmOrderId,
    required int productId,
    required double quantity,
    bool useWarehouseStock = false,
    double? vehicleStockQty,
    double? warehouseStockQty,
  }) async {
    if (!_canRequestOdoo()) {
      // Queue for later sync and return optimistic local result
      await _enqueuePendingProductQty(fsmOrderId, productId, quantity, useWarehouseStock);
      return <String, dynamic>{
        'queued_offline': true,
        'fsmOrderId': fsmOrderId,
        'productId': productId,
        'quantity': quantity,
      };
    }
    try {
      AppLogger.info(
          'setFsmProductQuantity: fsm=$fsmOrderId prod=$productId qty=$quantity useWarehouse=$useWarehouseStock',
          tag: 'ORDER_REPO');

      // Step 1: Ensure sale.order exists for this fsm.order
      // Call _fsm_ensure_sale_order via a write trigger or read sale_id
      final fsmRes = await _api.callKw(
        model: 'fsm.order',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', fsmOrderId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'sale_id', 'partner_id', 'company_id'],
          'limit': 1,
        },
      );
      if (!fsmRes.success || fsmRes.data is! List) return null;
      final fsmRows = fsmRes.data as List;
      if (fsmRows.isEmpty) return null;

      final fsm = Map<String, dynamic>.from(fsmRows.first as Map);
      int? saleOrderId;
      final saleIdRaw = fsm['sale_id'];
      if (saleIdRaw is List && saleIdRaw.isNotEmpty) {
        saleOrderId = saleIdRaw.first is int
            ? saleIdRaw.first as int
            : int.tryParse(saleIdRaw.first.toString());
      }

      // Step 2: If no sale order, create it using same pattern as Odoo's _fsm_create_sale_order
      if (saleOrderId == null) {
        final partnerIdRaw = fsm['partner_id'];
        int? partnerId;
        if (partnerIdRaw is List && partnerIdRaw.isNotEmpty) {
          partnerId = partnerIdRaw.first is int
              ? partnerIdRaw.first as int
              : int.tryParse(partnerIdRaw.first.toString());
        }
        if (partnerId == null) {
          AppLogger.error('No partner on FSM order to create sale order',
              tag: 'ORDER_REPO');
          return null;
        }

        final companyIdRaw = fsm['company_id'];
        int? companyId;
        if (companyIdRaw is List && companyIdRaw.isNotEmpty) {
          companyId = companyIdRaw.first is int
              ? companyIdRaw.first as int
              : int.tryParse(companyIdRaw.first.toString());
        }

        final soVals = <String, dynamic>{
          'partner_id': partnerId,
          'fsm_order_ids': <dynamic>[
            <dynamic>[4, fsmOrderId],   // (4, id) = link existing
          ],
        };
        if (companyId != null) soVals['company_id'] = companyId;

        final createSoRes = await _api.callKw(
          model: 'sale.order',
          method: 'create',
          args: <dynamic>[soVals],
          kwargs: const <String, dynamic>{},
        );
        if (!createSoRes.success || createSoRes.data == null) {
          AppLogger.error('Create sale.order failed: ${createSoRes.error}',
              tag: 'ORDER_REPO');
          return null;
        }
        saleOrderId = createSoRes.data is int
            ? createSoRes.data as int
            : int.tryParse(createSoRes.data.toString());

        // Link fsm.order → sale_id
        await _api.callKw(
          model: 'fsm.order',
          method: 'write',
          args: <dynamic>[
            <int>[fsmOrderId],
            <String, dynamic>{'sale_id': saleOrderId},
          ],
          kwargs: const <String, dynamic>{},
        );
        AppLogger.info('Created sale.order: $saleOrderId for FSM: $fsmOrderId',
            tag: 'ORDER_REPO');
      }

      if (saleOrderId == null) return null;

      // Step 3: Search existing sale.order.line for this product + fsm_order
      final existingRes = await _api.callKw(
        model: 'sale.order.line',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['order_id', '=', saleOrderId],
            <dynamic>['product_id', '=', productId],
            <dynamic>['fsm_order_id', '=', fsmOrderId],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'product_uom_qty', 'sequence'],
          'limit': 10,
          'order': 'sequence',
        },
      );

      final existingLines = <Map<String, dynamic>>[];
      if (existingRes.success && existingRes.data is List) {
        for (final row in existingRes.data as List) {
          if (row is Map) existingLines.add(Map<String, dynamic>.from(row));
        }
      }

      // Step 4: Call set_fsm_quantity with proper context
      // (mirrors what the Odoo controller does)
      final context = <String, dynamic>{
        'fsm_order_id': fsmOrderId,
        if (useWarehouseStock) 'use_warehouse_stock_for_fsm': true,
      };

      final setRes = await _api.callKw(
        model: 'product.product',
        method: 'set_fsm_quantity',
        args: <dynamic>[
          <int>[productId],
          quantity,
        ],
        kwargs: <String, dynamic>{
          'context': context,
        },
      );
      AppLogger.info('set_fsm_quantity returned: ${setRes.data}',
          tag: 'ORDER_REPO');

      // If set_fsm_quantity returns a wizard (Map), it means user confirmation needed.
      // In app, we already handled this via check_vehicle_stock_availability + dialog.
      // For now, proceed to line creation.

      // Step 5: Create or update sale.order.line manually
      // (mirrors itis_fieldservice_vehicle_stock controller logic)
      if (existingLines.isNotEmpty) {
        // Update first line, delete/zero out extras
        final firstLineId = existingLines.first['id'] as int;
        await _api.callKw(
          model: 'sale.order.line',
          method: 'write',
          args: <dynamic>[
            <int>[firstLineId],
            <String, dynamic>{'product_uom_qty': quantity},
          ],
          kwargs: <String, dynamic>{
            'context': context,
          },
        );

        if (existingLines.length > 1) {
          final extraIds = existingLines
              .skip(1)
              .map((e) => e['id'] as int)
              .toList();
          await _api.callKw(
            model: 'sale.order.line',
            method: 'unlink',
            args: <dynamic>[extraIds],
            kwargs: const <String, dynamic>{},
          );
        }
        AppLogger.info('Updated existing line $firstLineId qty=$quantity',
            tag: 'ORDER_REPO');
      } else {
        // Get product price
        final productRes = await _api.callKw(
          model: 'product.product',
          method: 'read',
          args: <dynamic>[
            <int>[productId],
            <String>['list_price'],
          ],
          kwargs: const <String, dynamic>{},
        );
        double priceUnit = 0.0;
        if (productRes.success && productRes.data is List &&
            (productRes.data as List).isNotEmpty) {
          final p = Map<String, dynamic>.from((productRes.data as List).first as Map);
          final lp = p['list_price'];
          if (lp is num) priceUnit = lp.toDouble();
        }

        // Get next sequence for the sale order
        final linesRes = await _api.callKw(
          model: 'sale.order.line',
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[<dynamic>['order_id', '=', saleOrderId]],
          ],
          kwargs: const <String, dynamic>{
            'fields': <String>['sequence'],
            'order': 'sequence desc',
            'limit': 1,
          },
        );
        int nextSeq = 10;
        if (linesRes.success && linesRes.data is List &&
            (linesRes.data as List).isNotEmpty) {
          final last = Map<String, dynamic>.from((linesRes.data as List).first as Map);
          final s = last['sequence'];
          if (s is num) nextSeq = s.toInt() + 1;
        }

        final createLineRes = await _api.callKw(
          model: 'sale.order.line',
          method: 'create',
          args: <dynamic>[
            <String, dynamic>{
              'order_id': saleOrderId,
              'product_id': productId,
              'product_uom_qty': quantity,
              'price_unit': priceUnit,
              'fsm_order_id': fsmOrderId,  // many2one — direct int
              'sequence': nextSeq,
            },
          ],
          kwargs: <String, dynamic>{
            'context': context,
          },
        );
        if (!createLineRes.success) {
          AppLogger.error('Create sale.order.line failed: ${createLineRes.error}',
              tag: 'ORDER_REPO');
          return null;
        }
        AppLogger.info(
            'Created sale.order.line id=${createLineRes.data} for product=$productId qty=$quantity',
            tag: 'ORDER_REPO');
      }

      // Step 6: Return updated sale order with lines
      return await fetchSaleOrderById(saleOrderId);
    } catch (e) {
      AppLogger.error('setFsmProductQuantity error',
          tag: 'ORDER_REPO', error: e);
      return null;
    }
  }



  /// Reads optional many2one / related fields that may exist only on some DBs
  /// (extra RPC per field; failures are ignored).
  Future<void> _mergeSaleOrderOptionalM2oFields(
    int saleOrderId,
    Map<String, dynamic> order,
  ) async {
    if (!_canRequestOdoo()) return;
    const candidates = <String>[
      'fsm_location_id',
      'partner_shipping_id',
      // Not on all Odoo sale.order DBs — causes call_kw "Invalid field" on some servers:
      // 'service_location_id',
      // 'invoice_payment_term_id',
    ];
    for (final field in candidates) {
      final existing = order[field];
      if (existing != null && existing != false) continue;
      try {
        final res = await _api.callKw(
          model: 'sale.order',
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[<dynamic>['id', '=', saleOrderId]],
          ],
          kwargs: <String, dynamic>{
            'fields': <String>[field],
            'limit': 1,
          },
        );
        if (!res.success || res.data is! List) continue;
        final rows = res.data as List;
        if (rows.isEmpty || rows.first is! Map) continue;
        final row = Map<String, dynamic>.from(rows.first as Map);
        if (!row.containsKey(field)) continue;
        final v = row[field];
        if (v != null && v != false) order[field] = v;
      } catch (_) {}
    }
  }

  /// Fetches sale.order record by id with all fields needed for the sale order screen.
  Future<Map<String, dynamic>?> fetchSaleOrderById(int id) async {
    if (!_canRequestOdoo()) {
      return _readSaleOrderByIdCache(id);
    }
    try {
      final res = await _api.callKw(
        model: 'sale.order',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', id]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id', 'name', 'partner_id', 'date_order', 'payment_term_id',
            'state', 'amount_untaxed', 'amount_total', 'order_line', 'currency_id',
            // Other Info - Sales
            'user_id', 'team_id', 'company_id', 'require_signature',
            'require_payment', 'prepayment_percent', 'client_order_ref', 'tag_ids',
            // Other Info - Invoicing
            'fiscal_position_id', 'project_id', 'journal_id', 'invoice_status',
            // Other Info - Delivery
            'warehouse_id', 'incoterm', 'incoterm_location', 'picking_policy',
            'commitment_date', 'effective_date', 'delivery_status',
            // Other Info - Tracking
            'origin', 'campaign_id', 'medium_id', 'source_id',
            // Customer Signature
            'signature', 'signed_by', 'signed_on',
            // Quote Builder
            'note', 'sale_order_template_id',
          ],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List) return null;
      final rows = res.data as List;
      if (rows.isEmpty) return null;
      final order = Map<String, dynamic>.from(rows.first as Map);

      // Fetch order lines
      // Fetch order lines — query directly by order_id instead of relying on order_line ids
// This is more reliable when Odoo hasn't fully committed the m2o relationship yet
      final lineRes = await _api.callKw(
        model: 'sale.order.line',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['order_id', '=', id]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id', 'product_id', 'product_uom_qty', 'qty_delivered',
            'qty_invoiced', 'product_uom', 'price_unit', 'tax_id', 'price_subtotal',
          ],
          'limit': 200,
          'order': 'id asc',
        },
      );
      if (lineRes.success && lineRes.data is List) {
        order['lines'] = lineRes.data;
        AppLogger.info('Fetched ${(lineRes.data as List).length} lines for sale order $id',
            tag: 'ORDER_REPO');
      } else {
        order['lines'] = <dynamic>[];
        AppLogger.warning('Could not fetch lines for sale order $id: ${lineRes.error}',
            tag: 'ORDER_REPO');
      }
      await _mergeSaleOrderOptionalM2oFields(id, order);
      await _attachCurrencyDisplay(order);
      await _saveSaleOrderByIdCache(id, order);
      return order;
    } catch (e) {
      AppLogger.error('fetchSaleOrderById error', tag: 'ORDER_REPO', error: e);
      return _readSaleOrderByIdCache(id);
    }
  }

  /// Fetches existing sale order linked to an FSM order (sale_line_id / sale_id).
  Future<Map<String, dynamic>?> fetchSaleOrderForFsmOrder(int fsmOrderId) async {
    if (!_canRequestOdoo()) {
      return _readSaleOrderByFsmCache(fsmOrderId);
    }
    try {
      // Step 1: get sale_id + FSM location (service location fallback for sale screen)
      Map<String, dynamic>? fsmRow;
      final fsmRes = await _api.callKw(
        model: 'fsm.order',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', fsmOrderId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'sale_id', 'location_id'],
          'limit': 1,
        },
      );
      int? saleId;
      if (fsmRes.success && fsmRes.data is List) {
        final rows = fsmRes.data as List;
        if (rows.isNotEmpty && rows.first is Map) {
          fsmRow = Map<String, dynamic>.from(rows.first as Map);
          final raw = fsmRow['sale_id'];
          saleId = _m2oId(raw);
        }
      }
      if (saleId == null || saleId <= 0) return null;

      // Step 2: fetch that sale.order
      final res = await _api.callKw(
        model: 'sale.order',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', saleId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id', 'name', 'partner_id', 'date_order', 'payment_term_id',
            'state', 'amount_untaxed', 'amount_total', 'order_line', 'currency_id',
            // Other Info - Sales
            'user_id', 'team_id', 'company_id', 'require_signature',
            'require_payment', 'prepayment_percent', 'client_order_ref', 'tag_ids',
            // Other Info - Invoicing
            'fiscal_position_id', 'project_id', 'journal_id', 'invoice_status',
            // Other Info - Delivery
            'warehouse_id', 'incoterm', 'incoterm_location', 'picking_policy',
            'commitment_date', 'effective_date', 'delivery_status',
            // Other Info - Tracking
            'origin', 'campaign_id', 'medium_id', 'source_id',
            // Customer Signature
            'signature', 'signed_by', 'signed_on',
            // Quote Builder
            'note', 'sale_order_template_id',
          ],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List) return null;
      final rows = res.data as List;
      if (rows.isEmpty) return null;
      final order = Map<String, dynamic>.from(rows.first as Map);
      final lineIds = order['order_line'];
      if (lineIds is List && lineIds.isNotEmpty) {
        final lineRes = await _api.callKw(
          model: 'sale.order.line',
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[<dynamic>['id', 'in', lineIds]],
          ],
          kwargs: const <String, dynamic>{
            'fields': <String>[
              'id', 'product_id', 'product_uom_qty', 'qty_delivered',
              'qty_invoiced', 'product_uom', 'price_unit', 'tax_id', 'price_subtotal',
            ],
            'limit': 200,
          },
        );
        if (lineRes.success && lineRes.data is List) {
          order['lines'] = lineRes.data;
        }
      }
      final soId = _coerceInt(order['id']);
      if (soId != null) {
        await _mergeSaleOrderOptionalM2oFields(soId, order);
      }
      final loc = fsmRow?['location_id'];
      if (loc != null && loc != false) {
        order['fsm_service_location_id'] = loc;
      }
      await _attachCurrencyDisplay(order);
      await _saveSaleOrderByFsmCache(fsmOrderId, order);
      await _saveSaleOrderByIdCache(order['id'] as int, order);
      return order;
    } catch (e) {
      AppLogger.error('fetchSaleOrderForFsmOrder error', tag: 'ORDER_REPO', error: e);
      return _readSaleOrderByFsmCache(fsmOrderId);
    }
  }

  /// Calls fsm.order.check_vehicle_stock_availability to decide if user
  /// should see a warehouse warning dialog.
  /// Returns same shape as Odoo method:
  /// { insufficient, warehouse_available, partial_available, available_qty,
  ///   required_qty, warehouse_qty, missing_qty, product_name }
  Future<Map<String, dynamic>?> checkVehicleStockAvailability({
    required int fsmOrderId,
    required int productId,
    required double quantity,
  }) async {
    if (!_canRequestOdoo()) return null;
    try {
      final res = await _api.callKw(
        model: 'fsm.order',
        method: 'check_vehicle_stock_availability',
        args: <dynamic>[
          <int>[fsmOrderId],
          productId,
          quantity,
        ],
        kwargs: const <String, dynamic>{},
      );
      if (!res.success || res.data is! Map) return null;
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      AppLogger.error('checkVehicleStockAvailability error',
          tag: 'ORDER_REPO', error: e);
      return null;
    }
  }


  int? _pickingIdFromActionResult(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final resId = map['res_id'];
      if (resId is int) return resId;
      if (resId is num) return resId.toInt();
      return int.tryParse('${map['res_id']}');
    }
    return int.tryParse(value.toString());
  }

  /// Creates the stock transfer using the wizard's action on Odoo.
  /// Falls back to offline queue if not connected.
  Future<VehicleStockTransferResult> createVehicleStockTransfer({
    required int fsmOrderId,
    required int? vehicleId,
    required int? locationDestId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final payload = <String, dynamic>{
      'fsm_order_id': fsmOrderId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (locationDestId != null) 'location_dest_id': locationDestId,
      'line_ids': lines.map((l) => <dynamic>[
        0,
        0,
        <String, dynamic>{
          'product_id': l['product_id'],
          'quantity': l['quantity'] ?? 1,
          if (l['lot_id'] != null && l['lot_id'] != false) 'lot_id': l['lot_id'],
        },
      ]).toList(),
    };

    if (_canRequestOdoo()) {
      try {
        final createRes = await _api.callKw(
          model: 'fsm.vehicle.stock.load.wizard',
          method: 'create',
          args: <dynamic>[payload],
          kwargs: const <String, dynamic>{},
        );
        if (!createRes.success || createRes.data == null) {
          final message =
              createRes.error ?? 'Wizard create failed for vehicle stock transfer.';
          AppLogger.error('createVehicleStockTransfer wizard create failed: $message',
              tag: 'VSW');
          return VehicleStockTransferResult.error(message);
        }
        final wizardId = createRes.data is int
            ? createRes.data as int
            : int.tryParse(createRes.data.toString());
        if (wizardId == null) {
          return const VehicleStockTransferResult.error(
            'Vehicle stock wizard returned an invalid id.',
          );
        }

        final actionRes = await _api.callKw(
          model: 'fsm.vehicle.stock.load.wizard',
          method: 'action_create_transfer',
          args: <dynamic>[
            <int>[wizardId],
          ],
          kwargs: const <String, dynamic>{},
        );
        if (actionRes.success) {
          await _clearVehicleStockWizardPending(fsmOrderId);
          return VehicleStockTransferResult.success(
            pickingId: _pickingIdFromActionResult(actionRes.data),
          );
        }
        final message = actionRes.error ??
            'Transfer action failed. Check warehouse, picking type, and quantities.';
        AppLogger.error('action_create_transfer failed: $message', tag: 'VSW');
        return VehicleStockTransferResult.error(message);
      } catch (e) {
        AppLogger.error('createVehicleStockTransfer error: $e', tag: 'VSW');
        return VehicleStockTransferResult.error(e.toString());
      }
    }

    await _saveVehicleStockWizardPending(payload);
    return const VehicleStockTransferResult.queued();
  }

  /// Syncs any pending vehicle stock transfer jobs when online.
  Future<void> syncPendingVehicleStockTransfers() async {
    if (!_canRequestOdoo()) return;
    final box = await _openBox();
    final raw = box.get(_keyVehicleStockWizardCache);
    if (raw is! List || raw.isEmpty) return;

    final pending = raw
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();

    final remaining = <Map<String, dynamic>>[];
    for (final job in pending) {
      try {
        final fsmOrderId = _coerceInt(job['fsm_order_id']);
        if (fsmOrderId == null) continue;
        final createRes = await _api.callKw(
          model: 'fsm.vehicle.stock.load.wizard',
          method: 'create',
          args: <dynamic>[job],
          kwargs: const <String, dynamic>{},
        );
        if (!createRes.success) {
          remaining.add(job);
          continue;
        }
        final wizardId = createRes.data is int
            ? createRes.data as int
            : int.tryParse(createRes.data.toString());
        if (wizardId == null) { remaining.add(job); continue; }
        final actionRes = await _api.callKw(
          model: 'fsm.vehicle.stock.load.wizard',
          method: 'action_create_transfer',
          args: <dynamic>[<int>[wizardId]],
          kwargs: const <String, dynamic>{},
        );
        if (!actionRes.success) {
          remaining.add(<String, dynamic>{
            ...job,
            'last_error': actionRes.error ?? 'action_create_transfer failed',
          });
          continue;
        }
        AppLogger.success(
          'syncPendingVehicleStockTransfers: synced fsmOrder=$fsmOrderId',
          tag: 'VSW',
        );
      } catch (e) {
        remaining.add(<String, dynamic>{...job, 'last_error': e.toString()});
      }
    }
    await box.put(_keyVehicleStockWizardCache, remaining);
  }

  Future<void> _saveVehicleStockWizardPending(Map<String, dynamic> payload) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyVehicleStockWizardCache);
      final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
      list.add(Map<String, dynamic>.from(payload));
      await box.put(_keyVehicleStockWizardCache, list);
    } catch (_) {}
  }

  Future<void> _clearVehicleStockWizardPending(int fsmOrderId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyVehicleStockWizardCache);
      if (raw is! List) return;
      final filtered = raw
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .where((m) => _coerceInt(m['fsm_order_id']) != fsmOrderId)
          .toList();
      await box.put(_keyVehicleStockWizardCache, filtered);
    } catch (_) {}
  }

  Future<List<VehicleStockItem>> fetchVehicleStockItemsForOrder({
    required int fsmOrderId,
    int? vehicleIdOverride,
  }) async {
    final defaults = await fetchVehicleStockWizardDefaults(fsmOrderId: fsmOrderId);
    final wizardVehicleId = _coerceInt(defaults['vehicle_id']);
    final vehicleId = vehicleIdOverride ?? wizardVehicleId;
    if (vehicleId == null || vehicleId <= 0) return const <VehicleStockItem>[];

    final vehicleLocId = _m2oId(defaults['location_dest_id']);
    final rows = await fetchVehicleStockProducts(
      vehicleId: vehicleId,
      vehicleStockLocationId: vehicleLocId,
    );
    if (rows.isEmpty) return const <VehicleStockItem>[];

    return rows
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          final pidRaw = m['product_id'];
          final lotRaw = m['lot_id'];
          final locRaw = m['location_id'];

          final productId = _m2oId(pidRaw) ?? _coerceInt(m['product_id']);
          final productName = _m2oLabel(pidRaw).isNotEmpty
              ? _m2oLabel(pidRaw)
              : (m['name']?.toString().trim().isNotEmpty ?? false)
                  ? m['name'].toString().trim()
                  : 'Product';
          final lotName = _m2oLabel(lotRaw);
          final locationName = _m2oLabel(locRaw).isNotEmpty
              ? _m2oLabel(locRaw)
              : (_m2oLabel(defaults['location_dest_id']).isNotEmpty
                  ? _m2oLabel(defaults['location_dest_id'])
                  : '-');
          final onHand = _toDouble(m['inventory_quantity_auto_apply']) ?? 0;
          final reserved = _toDouble(m['reserved_quantity']) ?? 0;
          final unit = _m2oLabel(m['product_uom_id']).isNotEmpty
              ? _m2oLabel(m['product_uom_id'])
              : 'Units';

          if (productId == null || productId <= 0) return null;
          return VehicleStockItem(
            location: locationName,
            product: productName,
            lotSerial: lotName.isEmpty ? '-' : lotName,
            onHandQty: onHand,
            reservedQty: reserved,
            unit: unit,
          );
        })
        .whereType<VehicleStockItem>()
        .toList();
  }

  Future<bool> hasVehicleStockForOrder({
    required int fsmOrderId,
    int? vehicleIdOverride,
  }) async {
    final list = await fetchVehicleStockItemsForOrder(
      fsmOrderId: fsmOrderId,
      vehicleIdOverride: vehicleIdOverride,
    );
    return list.isNotEmpty;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Products for Partner
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<ProductItem>> fetchProductsForPartner({
    required int partnerId,
  }) async {
    if (!_canRequestOdoo()) {
      final cached = await _readProductsCache(partnerId: partnerId);

      return cached;
    }


    try {
      final res = await _api.callKw(
        model: 'product.product',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['active', '=', true],
            <dynamic>['sale_ok', '=', true],
            <dynamic>['company_id', 'in', <dynamic>[partnerId, false]],
            '|',
            <dynamic>['type', '=', 'consu'],
            '&',
            '&',
            <dynamic>['type', '=', 'service'],
            <dynamic>['invoice_policy', '=', 'delivery'],
            <dynamic>['service_type', '=', 'manual'],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': <String>[
            'id',
            'name',
            'default_code',
            'list_price',
            'qty_available',
            'image_128',
            'product_template_attribute_value_ids',
          ],
          'limit': 100,
          'order': 'name asc',
        },
      );

      if (!res.success || res.data is! List) {
        return _readProductsCache(partnerId: partnerId);
      }

      final rows = res.data as List;

      final attrValueIds = <int>{};
      for (final r in rows) {
        if (r is Map) {
          final ids = r['product_template_attribute_value_ids'];
          if (ids is List) {
            for (final id in ids) {
              if (id is int) attrValueIds.add(id);
            }
          }
        }
      }

      final Map<int, String> attrValueLabels = {};
      if (attrValueIds.isNotEmpty) {
        try {
          final attrRes = await _api.callKw(
            model: 'product.template.attribute.value',
            method: 'search_read',
            args: <dynamic>[
              <dynamic>[
                <dynamic>['id', 'in', attrValueIds.toList()],
              ],
            ],
            kwargs: const <String, dynamic>{
              'fields': <String>['id', 'attribute_id', 'name'],
              'limit': 500,
            },
          );
          if (attrRes.success && attrRes.data is List) {
            for (final a in attrRes.data as List) {
              if (a is! Map) continue;
              final m = Map<String, dynamic>.from(a);
              final id = m['id'];
              if (id is! int) continue;
              final attrRaw = m['attribute_id'];
              String attrName = '';
              if (attrRaw is List && attrRaw.length >= 2) {
                attrName = attrRaw[1]?.toString() ?? '';
              }
              final valName = m['name']?.toString() ?? '';
              attrValueLabels[id] =
              attrName.isNotEmpty ? '$attrName:$valName' : valName;
            }
          }
        } catch (_) {}
      }

      final items = rows.map((r) {
        if (r is! Map) return null;
        final m = Map<String, dynamic>.from(r);
        final id = m['id'];
        if (id is! int) return null;

        final attrIds = m['product_template_attribute_value_ids'];
        final attrs = <String>[];
        if (attrIds is List) {
          for (final aid in attrIds) {
            if (aid is int) {
              final label = attrValueLabels[aid];
              if (label != null && label.isNotEmpty) attrs.add(label);
            }
          }
        }

        final imageRaw = m['image_128'];
        final imageBase64 = (imageRaw != null && imageRaw != false)
            ? imageRaw.toString()
            : '';

        return ProductItem(
          id: id,
          name: m['name']?.toString() ?? '—',
          internalRef: m['default_code']?.toString() ?? '',
          price: _toDouble(m['list_price']) ?? 0.0,
          onHandQty: _toDouble(m['qty_available']) ?? 0.0,
          imageBase64: imageBase64,
          attributes: attrs,
        );
      }).whereType<ProductItem>().toList();

      await _saveProductsCache(partnerId: partnerId, items: items);
      return items;
    } catch (e) {
      AppLogger.error('fetchProductsForPartner error',
          tag: 'ORDER_REPO', error: e);
      return _readProductsCache(partnerId: partnerId);
    }
  }


  /// Fetches products available in the vehicle's stock location (qty > 0).
  /// This is what the Car Inventory tab shows — mirrors Odoo's filter_vehicle_stock logic.
  Future<List<ProductItem>> fetchVehicleStockProducts_ForCarInventory({
    required int fsmOrderId,
  }) async {
    // Offline: read from cache immediately
    if (!_canRequestOdoo()) {
      return _readCarInventoryCache(fsmOrderId);
    }

    // Step 1: get vehicle_id from FSM order
    final defaults = await fetchVehicleStockWizardDefaults(fsmOrderId: fsmOrderId);
    final vehicleIdRaw = defaults['vehicle_id'];
    final vehicleId = _m2oId(vehicleIdRaw);
    if (vehicleId == null || vehicleId <= 0) return _readCarInventoryCache(fsmOrderId);

    // Step 2: get stock_location_id from fsm.vehicle
    int? stockLocationId;
    try {
      final vehicleRes = await _api.callKw(
        model: 'fsm.vehicle',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', vehicleId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'stock_location_id'],
          'limit': 1,
        },
      );
      if (vehicleRes.success && vehicleRes.data is List) {
        final rows = vehicleRes.data as List;
        if (rows.isNotEmpty && rows.first is Map) {
          stockLocationId = _m2oId(
            Map<String, dynamic>.from(rows.first as Map)['stock_location_id'],
          );
        }
      }
    } catch (e) {
      AppLogger.error('fetchVehicleStockProducts_ForCarInventory vehicle fetch',
          tag: 'ORDER_REPO', error: e);
      return _readCarInventoryCache(fsmOrderId);
    }

    if (stockLocationId == null || stockLocationId <= 0) return _readCarInventoryCache(fsmOrderId);

    // Step 3: search stock.quant where location_id = stockLocationId AND quantity > 0
    final List<int> productIds = [];
    final Map<int, double> qtyByProduct = {};
    try {
      final quantRes = await _api.callKw(
        model: 'stock.quant',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['location_id', '=', stockLocationId],
            <dynamic>['quantity', '>', 0],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['product_id', 'quantity'],
          'limit': 200,
        },
      );
      if (quantRes.success && quantRes.data is List) {
        for (final row in quantRes.data as List) {
          if (row is! Map) continue;
          final m = Map<String, dynamic>.from(row);
          final pid = _m2oId(m['product_id']);
          if (pid == null || pid <= 0) continue;
          final qty = _toDouble(m['quantity']) ?? 0.0;
          if (!productIds.contains(pid)) productIds.add(pid);
          qtyByProduct[pid] = (qtyByProduct[pid] ?? 0.0) + qty;
        }
      }
    } catch (e) {
      AppLogger.error('fetchVehicleStockProducts_ForCarInventory quant fetch',
          tag: 'ORDER_REPO', error: e);
      return _readCarInventoryCache(fsmOrderId);
    }

    if (productIds.isEmpty) return _readCarInventoryCache(fsmOrderId);

    // Step 4: fetch full product details for those product ids
    try {
      final productRes = await _api.callKw(
        model: 'product.product',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['id', 'in', productIds],
            <dynamic>['active', '=', true],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id',
            'name',
            'default_code',
            'list_price',
            'image_128',
            'product_template_attribute_value_ids',
          ],
          'limit': 200,
        },
      );

      if (!productRes.success || productRes.data is! List) return [];

      final rows = productRes.data as List;

      // Fetch attribute labels in bulk
      final attrValueIds = <int>{};
      for (final r in rows) {
        if (r is Map) {
          final ids = r['product_template_attribute_value_ids'];
          if (ids is List) {
            for (final id in ids) {
              if (id is int) attrValueIds.add(id);
            }
          }
        }
      }

      final Map<int, String> attrValueLabels = {};
      if (attrValueIds.isNotEmpty) {
        try {
          final attrRes = await _api.callKw(
            model: 'product.template.attribute.value',
            method: 'search_read',
            args: <dynamic>[
              <dynamic>[<dynamic>['id', 'in', attrValueIds.toList()]],
            ],
            kwargs: const <String, dynamic>{
              'fields': <String>['id', 'attribute_id', 'name'],
              'limit': 500,
            },
          );
          if (attrRes.success && attrRes.data is List) {
            for (final a in attrRes.data as List) {
              if (a is! Map) continue;
              final m = Map<String, dynamic>.from(a);
              final id = m['id'];
              if (id is! int) continue;
              final attrRaw = m['attribute_id'];
              final attrName = (attrRaw is List && attrRaw.length >= 2)
                  ? attrRaw[1]?.toString() ?? ''
                  : '';
              final valName = m['name']?.toString() ?? '';
              attrValueLabels[id] =
              attrName.isNotEmpty ? '$attrName:$valName' : valName;
            }
          }
        } catch (_) {}
      }

      final result = rows.map((r) {
        if (r is! Map) return null;
        final m = Map<String, dynamic>.from(r);
        final id = m['id'];
        if (id is! int) return null;

        final attrIds = m['product_template_attribute_value_ids'];
        final attrs = <String>[];
        if (attrIds is List) {
          for (final aid in attrIds) {
            if (aid is int) {
              final label = attrValueLabels[aid];
              if (label != null && label.isNotEmpty) attrs.add(label);
            }
          }
        }

        final imageRaw = m['image_128'];
        final imageBase64 = (imageRaw != null && imageRaw != false)
            ? imageRaw.toString()
            : '';

        // Use vehicle stock qty as onHandQty
        final onHandQty = qtyByProduct[id] ?? 0.0;

        return ProductItem(
          id: id,
          name: m['name']?.toString() ?? '—',
          internalRef: m['default_code']?.toString() ?? '',
          price: _toDouble(m['list_price']) ?? 0.0,
          onHandQty: onHandQty,
          imageBase64: imageBase64,
          attributes: attrs,
        );
      }).whereType<ProductItem>().toList();
      await _saveCarInventoryCache(fsmOrderId, result);
      return result;
    } catch (e) {
      AppLogger.error('fetchVehicleStockProducts_ForCarInventory product fetch',
          tag: 'ORDER_REPO', error: e);
      return _readCarInventoryCache(fsmOrderId);
    }
  }


  String _productsCacheKey(int partnerId) =>
      _scopedKey('products_partner_$partnerId');

  Future<void> _saveProductsCache({
    required int partnerId,
    required List<ProductItem> items,
  }) async {
    try {
      final box = await _openBox();
      await box.put(
        _productsCacheKey(partnerId),
        items.map((e) => e.toMap()).toList(),
      );
    } catch (_) {}
  }

  Future<List<ProductItem>> _readProductsCache({
    required int partnerId,
  }) async {
    try {
      final box = await _openBox();
      final cacheKey = _productsCacheKey(partnerId);
      final raw = box.get(cacheKey);

      if (raw is! List) return [];
      return raw
          .map((e) {
        if (e is! Map) return null;
        return ProductItem.fromMap(Map<String, dynamic>.from(e));
      })
          .whereType<ProductItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

// ─────────────────────────────────────────────────────────────────────────────
//  Delivery & Invoice Flow
// ─────────────────────────────────────────────────────────────────────────────

  /// Fetches stock.picking (delivery orders) linked to a sale order.
  Future<List<Map<String, dynamic>>> fetchPickingsForSaleOrder(int saleOrderId) async {
    if (!_canRequestOdoo()) {
      return _readPickingsBySaleCache(saleOrderId);  // ✅ Already done
    }
    try {
      // Get picking_ids from sale.order
      final orderRes = await _api.callKw(
        model: 'sale.order',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', saleOrderId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'picking_ids'],
          'limit': 1,
        },
      );
      if (!orderRes.success || orderRes.data is! List) return [];
      final rows = orderRes.data as List;
      if (rows.isEmpty) return [];
      final pickingIds = (Map<String, dynamic>.from(rows.first as Map)['picking_ids'] as List?)
          ?.whereType<int>().toList() ?? [];
      if (pickingIds.isEmpty) return [];

      // Fetch picking details
      final pickRes = await _api.callKw(
        model: 'stock.picking',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', 'in', pickingIds]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id', 'name', 'location_id', 'location_dest_id',
            'scheduled_date', 'partner_id', 'origin',
            'company_id', 'state',
          ],
          'limit': 100,
        },
      );
      if (!pickRes.success || pickRes.data is! List) return [];

      final list = (pickRes.data as List)          // ✅ CHANGED: was directly returned,
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)  //    now stored in `list`
          .whereType<Map<String, dynamic>>()
          .toList();

      await _savePickingsBySaleCache(saleOrderId, list);  // ✅ ADDED: save to cache
      return list;                                         // ✅ ADDED: then return

    } catch (e) {
      AppLogger.error('fetchPickingsForSaleOrder error', tag: 'ORDER_REPO', error: e);
      return _readPickingsBySaleCache(saleOrderId);  // ✅ CHANGED: was `return []`
    }
  }

  /// Fetches move lines (products) for a stock.picking.
  Future<List<Map<String, dynamic>>> fetchPickingMoveLines(int pickingId) async {
    if (!_canRequestOdoo()) {
      return _readPickingMoveLinesCache(pickingId);  // ✅ Already done
    }
    try {
      final res = await _api.callKw(
        model: 'stock.move',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['picking_id', '=', pickingId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id', 'product_id', 'product_uom_qty',
            'quantity', 'product_uom', 'state',
          ],
          'limit': 200,
        },
      );
      if (!res.success || res.data is! List) return [];

      final lines = (res.data as List)              // ✅ CHANGED: stored in `lines`
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();

      await _savePickingMoveLinesCache(pickingId, lines);  // ✅ ADDED: save to cache
      return lines;                                         // ✅ ADDED: then return

    } catch (e) {
      AppLogger.error('fetchPickingMoveLines error', tag: 'ORDER_REPO', error: e);
      return _readPickingMoveLinesCache(pickingId);  // ✅ CHANGED: was `return []`
    }
  }


  /// Validates a stock.picking (delivery order).
  /// Returns true on success.
  Future<bool> validatePicking(int pickingId) async {
    if (!_canRequestOdoo()) {
      await _enqueuePendingValidatePicking(pickingId);
      return true; // Optimistic
    }
    try {
      // First check if immediate transfer is needed
      final checkRes = await _api.callKw(
        model: 'stock.picking',
        method: 'button_validate',
        args: <dynamic>[
          <int>[pickingId],
        ],
        kwargs: const <String, dynamic>{},
      );
      // button_validate may return an action dict (backorder wizard)
      // or True if done directly
      if (checkRes.success) {
        if (checkRes.data == true || checkRes.data == null) {
          return true;
        }
        // If it returns an action (backorder/immediate transfer wizard),
        // we call the wizard with 'immediate' to skip
        if (checkRes.data is Map) {
          final action = Map<String, dynamic>.from(checkRes.data as Map);
          final resModel = action['res_model']?.toString() ?? '';

          if (resModel == 'stock.immediate.transfer') {
            // Process immediately
            final wizRes = await _api.callKw(
              model: 'stock.immediate.transfer',
              method: 'process',
              args: <dynamic>[
                <int>[action['res_id'] as int? ?? 0],
              ],
              kwargs: const <String, dynamic>{},
            );
            return wizRes.success;
          }
          if (resModel == 'stock.backorder.confirmation') {
            // Create backorder — just validate what's available
            final wizRes = await _api.callKw(
              model: 'stock.backorder.confirmation',
              method: 'process',
              args: <dynamic>[
                <int>[action['res_id'] as int? ?? 0],
              ],
              kwargs: const <String, dynamic>{},
            );
            return wizRes.success;
          }
          return true;
        }
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('validatePicking error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

  /// Creates an invoice from sale order using sale.advance.payment.inv wizard.
  /// [method]: 'delivered' = Regular Invoice, 'percentage' = Down Payment %, 'fixed' = Down Payment Fixed
  Future<Map<String, dynamic>?> createInvoiceFromSaleOrder({
    required int saleOrderId,
    required String method,
    double? amount,
  }) async {
    if (!_canRequestOdoo()) {
      await _enqueuePendingCreateInvoice(saleOrderId, method, amount);
      // Return a placeholder so the UI navigates to InvoiceView showing "Pending Sync"
      return <String, dynamic>{
        'id': null,
        'name': 'Draft Invoice (Offline)',
        'state': 'draft',
        'queued_offline': true,
        'amount_untaxed': 0.0,
        'amount_total': 0.0,
        'lines': <dynamic>[],
      };
    }
    try {
      // Step 1: Create the wizard record
      final wizardData = <String, dynamic>{
        'advance_payment_method': method,
      };
      if (method == 'percentage' && amount != null) {
        wizardData['amount'] = amount;
      }
      if (method == 'fixed' && amount != null) {
        wizardData['fixed_amount'] = amount;
      }

      final createRes = await _api.callKw(
        model: 'sale.advance.payment.inv',
        method: 'create',
        args: <dynamic>[wizardData],
        kwargs: <String, dynamic>{
          'context': <String, dynamic>{
            'active_ids': <int>[saleOrderId],
            'active_id': saleOrderId,
            'active_model': 'sale.order',
          },
        },
      );
      if (!createRes.success || createRes.data == null) {
        AppLogger.error('createInvoice wizard create failed: ${createRes.error}',
            tag: 'ORDER_REPO');
        return null;
      }
      final wizardId = createRes.data is int
          ? createRes.data as int
          : int.tryParse(createRes.data.toString());
      if (wizardId == null) return null;

      // Step 2: Call create_invoices with active_ids context
      final invoiceRes = await _api.callKw(
        model: 'sale.advance.payment.inv',
        method: 'create_invoices',
        args: <dynamic>[
          <int>[wizardId],
        ],
        kwargs: <String, dynamic>{
          'context': <String, dynamic>{
            'active_ids': <int>[saleOrderId],
            'active_id': saleOrderId,
            'active_model': 'sale.order',
          },
        },
      );

      if (!invoiceRes.success) {
        AppLogger.error('create_invoices failed: ${invoiceRes.error}',
            tag: 'ORDER_REPO');
        return null;
      }

      // Step 3: Fetch the newly created invoice
      final invoiceListRes = await _api.callKw(
        model: 'account.move',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['invoice_origin', 'like', '%'],
            <dynamic>['move_type', '=', 'out_invoice'],
            <dynamic>['state', '=', 'draft'],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': <String>[
            'id', 'name', 'partner_id', 'invoice_date',
            'amount_untaxed', 'amount_total', 'state',
            'invoice_line_ids', 'payment_state',
          ],
          'limit': 1,
          'order': 'id desc',
          'context': <String, dynamic>{
            'active_ids': <int>[saleOrderId],
          },
        },
      );

      if (invoiceListRes.success && invoiceListRes.data is List) {
        final list = invoiceListRes.data as List;
        if (list.isNotEmpty) {
          final invoice = Map<String, dynamic>.from(list.first as Map);
          // Fetch invoice lines
          final lineIds = (invoice['invoice_line_ids'] as List?)
              ?.whereType<int>().toList() ?? [];
          if (lineIds.isNotEmpty) {
            final lineRes = await _api.callKw(
              model: 'account.move.line',
              method: 'search_read',
              args: <dynamic>[
                <dynamic>[<dynamic>['id', 'in', lineIds]],
              ],
              kwargs: const <String, dynamic>{
                'fields': <String>[
                  'id', 'product_id', 'quantity',
                  'price_unit', 'price_subtotal', 'tax_ids',
                ],
                'limit': 200,
              },
            );
            if (lineRes.success && lineRes.data is List) {
              invoice['lines'] = lineRes.data;
            }
          }
          return invoice;
        }
      }

      // Fallback: return success indicator even without full data
      return <String, dynamic>{'success': true};
    } catch (e) {
      AppLogger.error('createInvoiceFromSaleOrder error', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  /// Confirms (posts) a draft invoice.
  Future<bool> confirmInvoice(int invoiceId) async {
    if (!_canRequestOdoo()) {
      await _enqueuePendingConfirmInvoice(invoiceId);
      return true; // Optimistic
    }
    try {
      final res = await _api.callKw(
        model: 'account.move',
        method: 'action_post',
        args: <dynamic>[
          <int>[invoiceId],
        ],
        kwargs: const <String, dynamic>{},
      );
      return res.success;
    } catch (e) {
      AppLogger.error('confirmInvoice error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

  /// Fetches the latest customer invoice (account.move) created from a sale order.
  /// Returns a map compatible with [InvoiceView], including `lines`.
  Future<Map<String, dynamic>?> fetchLatestInvoiceForSaleOrder(int saleOrderId) async {
    if (!_canRequestOdoo()) return null;
    try {
      final soRes = await _api.callKw(
        model: 'sale.order',
        method: 'read',
        args: <dynamic>[<int>[saleOrderId]],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'name'],
        },
      );
      if (!soRes.success || soRes.data is! List || (soRes.data as List).isEmpty) {
        return null;
      }
      final so = Map<String, dynamic>.from((soRes.data as List).first as Map);
      final soName = so['name']?.toString().trim() ?? '';
      if (soName.isEmpty) return null;

      final invoiceRes = await _api.callKw(
        model: 'account.move',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['move_type', '=', 'out_invoice'],
            <dynamic>['invoice_origin', 'ilike', soName],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id',
            'name',
            'partner_id',
            'invoice_date',
            'invoice_payment_term_id',
            'invoice_date_due',
            'delivery_date',
            'payment_state',
            'journal_id',
            'company_id',
            'state',
            'amount_untaxed',
            'amount_total',
            'invoice_line_ids',
            'currency_id',
          ],
          'limit': 1,
          'order': 'id desc',
        },
      );
      if (!invoiceRes.success || invoiceRes.data is! List || (invoiceRes.data as List).isEmpty) {
        return null;
      }

      final invoice = Map<String, dynamic>.from((invoiceRes.data as List).first as Map);
      final lineIds = (invoice['invoice_line_ids'] as List?)?.whereType<int>().toList() ?? [];
      if (lineIds.isNotEmpty) {
        final lineRes = await _api.callKw(
          model: 'account.move.line',
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[<dynamic>['id', 'in', lineIds]],
          ],
          kwargs: const <String, dynamic>{
            'fields': <String>[
              'id',
              'product_id',
              'quantity',
              'price_unit',
              'price_subtotal',
              'tax_ids',
            ],
            'limit': 200,
          },
        );
        if (lineRes.success && lineRes.data is List) {
          invoice['lines'] = lineRes.data;
        }
      }
      await _attachCurrencyDisplay(invoice);
      return invoice;
    } catch (e) {
      AppLogger.error('fetchLatestInvoiceForSaleOrder error', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesForSaleOrder(int saleOrderId) async {
    if (!_canRequestOdoo()) {
      return _readInvoicesByFsmCache(saleOrderId);  // ✅ Already done
    }
    try {
      final soRes = await _api.callKw(
        model: 'sale.order',
        method: 'read',
        args: <dynamic>[<int>[saleOrderId]],
        kwargs: const <String, dynamic>{'fields': <String>['id', 'name']},
      );
      if (!soRes.success || soRes.data is! List || (soRes.data as List).isEmpty) {
        return const <Map<String, dynamic>>[];
      }
      final so = Map<String, dynamic>.from((soRes.data as List).first as Map);
      final soName = so['name']?.toString().trim() ?? '';
      if (soName.isEmpty) return const <Map<String, dynamic>>[];

      final invRes = await _api.callKw(
        model: 'account.move',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['move_type', '=', 'out_invoice'],
            <dynamic>['invoice_origin', 'ilike', soName],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id', 'name', 'invoice_date', 'state',
            'payment_state', 'partner_id', 'amount_total', 'currency_id',
          ],
          'order': 'id desc',
          'limit': 200,
        },
      );
      if (!invRes.success || invRes.data is! List) return const <Map<String, dynamic>>[];

      final list = (invRes.data as List)              // ✅ CHANGED: stored in `list`
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();

      await _attachCurrencyDisplayForRecords(list);
      await _saveInvoicesByFsmCache(saleOrderId, list);  // ✅ ADDED: save to cache
      return list;                                         // ✅ ADDED: then return

    } catch (e) {
      AppLogger.error('fetchInvoicesForSaleOrder error', tag: 'ORDER_REPO', error: e);
      return _readInvoicesByFsmCache(saleOrderId);  // ✅ CHANGED: was `return const []`
    }
  }

  Future<Map<String, dynamic>?> fetchInvoiceById(int invoiceId) async {
    if (!_canRequestOdoo()) {
      return _readInvoiceByIdCache(invoiceId);  // ✅ CHANGED: was `return null`
    }
    try {
      final res = await _api.callKw(
        model: 'account.move',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', invoiceId]],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>[
            'id', 'name', 'partner_id', 'invoice_date',
            'invoice_payment_term_id', 'invoice_date_due', 'delivery_date',
            'payment_state', 'journal_id', 'company_id', 'state',
            'amount_untaxed', 'amount_total', 'invoice_line_ids', 'currency_id',
          ],
          'limit': 1,
        },
      );
      if (!res.success || res.data is! List || (res.data as List).isEmpty) return null;
      final invoice = Map<String, dynamic>.from((res.data as List).first as Map);
      final lineIds = (invoice['invoice_line_ids'] as List?)?.whereType<int>().toList() ?? [];
      if (lineIds.isNotEmpty) {
        final lineRes = await _api.callKw(
          model: 'account.move.line',
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[<dynamic>['id', 'in', lineIds]],
          ],
          kwargs: const <String, dynamic>{
            'fields': <String>[
              'id', 'product_id', 'quantity',
              'price_unit', 'price_subtotal', 'tax_ids',
            ],
            'limit': 200,
          },
        );
        if (lineRes.success && lineRes.data is List) {
          invoice['lines'] = lineRes.data;
        }
      }

      await _attachCurrencyDisplay(invoice);
      await _saveInvoiceByIdCache(invoiceId, invoice);  // ✅ ADDED: save to cache
      return invoice;                                     // ✅ ADDED: then return

    } catch (e) {
      AppLogger.error('fetchInvoiceById error', tag: 'ORDER_REPO', error: e);
      return _readInvoiceByIdCache(invoiceId);  // ✅ CHANGED: was `return null`
    }
  }


  // ─── Sale Order Cache ────────────────────────────────────────────────────

  Future<void> _saveSaleOrderByIdCache(int id, Map<String, dynamic> data) async {
    try {
      final box = await _openBox();
      await box.put(_saleOrderByIdKey(id), data);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readSaleOrderByIdCache(int id) async {
    try {
      final box = await _openBox();
      final raw = box.get(_saleOrderByIdKey(id));
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return null;
  }

  Future<void> _saveSaleOrderByFsmCache(int fsmId, Map<String, dynamic> data) async {
    try {
      final box = await _openBox();
      await box.put(_saleOrderByFsmKey(fsmId), data);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readSaleOrderByFsmCache(int fsmId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_saleOrderByFsmKey(fsmId));
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return null;
  }



  // ─── Invoice Cache ───────────────────────────────────────────────────────

  Future<void> _saveInvoicesByFsmCache(int saleOrderId, List<Map<String, dynamic>> list) async {
    try {
      final box = await _openBox();
      await box.put(_invoicesByFsmKey(saleOrderId), list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _readInvoicesByFsmCache(int saleOrderId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_invoicesByFsmKey(saleOrderId));
      if (raw is List) {
        return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveInvoiceByIdCache(int id, Map<String, dynamic> data) async {
    try {
      final box = await _openBox();
      await box.put(_invoiceByIdKey(id), data);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readInvoiceByIdCache(int id) async {
    try {
      final box = await _openBox();
      final raw = box.get(_invoiceByIdKey(id));
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return null;
  }

  // ─── Delivery / Picking Cache ─────────────────────────────────────────────

  Future<void> _savePickingsBySaleCache(int saleId, List<Map<String, dynamic>> list) async {
    try {
      final box = await _openBox();
      await box.put(_pickingsBySaleKey(saleId), list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _readPickingsBySaleCache(int saleId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_pickingsBySaleKey(saleId));
      if (raw is List) {
        return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _savePickingMoveLinesCache(int pickingId, List<Map<String, dynamic>> list) async {
    try {
      final box = await _openBox();
      await box.put(_pickingMoveLinesKey(pickingId), list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _readPickingMoveLinesCache(int pickingId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_pickingMoveLinesKey(pickingId));
      if (raw is List) {
        return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Pending Product Qty (offline queue) ─────────────────────────────────

  Future<void> _enqueuePendingProductQty(
      int fsmOrderId, int productId, double qty, bool useWarehouse,
      ) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingProductQty);
      final list = raw is List ? List<Map<String, dynamic>>.from(
        raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      ) : <Map<String, dynamic>>[];
      // Remove older entry for same fsm+product
      list.removeWhere((e) => e['fsmOrderId'] == fsmOrderId && e['productId'] == productId);
      list.add({
        'fsmOrderId': fsmOrderId,
        'productId': productId,
        'qty': qty,
        'useWarehouse': useWarehouse,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      await box.put(_keyPendingProductQty, list);
      AppLogger.info('Queued offline product qty: fsm=$fsmOrderId prod=$productId qty=$qty', tag: 'ORDER_REPO');

      // Save a local sale order placeholder to Hive so flash→Sale Order works offline
      final existingCache = await _readSaleOrderByFsmCache(fsmOrderId);
      if (existingCache == null || existingCache['queued_offline'] == true) {
        final localSaleOrder = <String, dynamic>{
          'id': null,
          'name': 'Pending Sale Order (Offline)',
          'state': 'draft',
          'queued_offline': true,
          'lines': <dynamic>[],
        };
        await _saveSaleOrderByFsmCache(fsmOrderId, localSaleOrder);
      }
    } catch (_) {}
  }
  // ─── Pending Invoice / Delivery Queue ────────────────────────────────────


  /// Saves a locally-built offline sale order to Hive cache so that
  /// flash → Sale Order can find it without a network call.
  Future<void> saveOfflineSaleOrderForFsm({
    required int fsmOrderId,
    required Map<String, dynamic> localSaleOrder,
  }) async {
    try {
      await _saveSaleOrderByFsmCache(fsmOrderId, localSaleOrder);
      AppLogger.debug(
        'saveOfflineSaleOrderForFsm: saved for fsmOrderId=$fsmOrderId',
        tag: 'ORDER_REPO',
      );
    } catch (e) {
      AppLogger.error('saveOfflineSaleOrderForFsm error', tag: 'ORDER_REPO', error: e);
    }
  }
  Future<void> _enqueuePendingCreateInvoice(
      int saleOrderId, String method, double? amount) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingCreateInvoice);
      final list = raw is List
          ? List<Map<String, dynamic>>.from(
          raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
          : <Map<String, dynamic>>[];
      list.add({
        'saleOrderId': saleOrderId,
        'method': method,
        'amount': amount,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      await box.put(_keyPendingCreateInvoice, list);
      AppLogger.info('Queued offline createInvoice for saleOrder=$saleOrderId', tag: 'ORDER_REPO');
    } catch (_) {}
  }

  Future<void> _enqueuePendingConfirmInvoice(int invoiceId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingConfirmInvoice);
      final list = raw is List
          ? List<Map<String, dynamic>>.from(
          raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
          : <Map<String, dynamic>>[];
      // Avoid duplicates
      list.removeWhere((e) => e['invoiceId'] == invoiceId);
      list.add({'invoiceId': invoiceId, 'ts': DateTime.now().millisecondsSinceEpoch});
      await box.put(_keyPendingConfirmInvoice, list);
      AppLogger.info('Queued offline confirmInvoice id=$invoiceId', tag: 'ORDER_REPO');
    } catch (_) {}
  }

  Future<void> _enqueuePendingValidatePicking(int pickingId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyPendingValidatePicking);
      final list = raw is List
          ? List<Map<String, dynamic>>.from(
          raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
          : <Map<String, dynamic>>[];
      list.removeWhere((e) => e['pickingId'] == pickingId);
      list.add({'pickingId': pickingId, 'ts': DateTime.now().millisecondsSinceEpoch});
      await box.put(_keyPendingValidatePicking, list);
      AppLogger.info('Queued offline validatePicking id=$pickingId', tag: 'ORDER_REPO');
    } catch (_) {}
  }

  Future<void> _syncPendingInvoicesAndDeliveries() async {
    if (!_canRequestOdoo()) return;
    final box = await _openBox();

    // Sync create invoice jobs
    try {
      final raw = box.get(_keyPendingCreateInvoice);
      if (raw is List && raw.isNotEmpty) {
        final jobs = List<Map<String, dynamic>>.from(
            raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}));
        final remaining = <Map<String, dynamic>>[];
        for (final job in jobs) {
          try {
            await createInvoiceFromSaleOrder(
              saleOrderId: job['saleOrderId'] as int,
              method: job['method'] as String,
              amount: (job['amount'] as num?)?.toDouble(),
            );
            AppLogger.info('Synced pending createInvoice for sale=${job['saleOrderId']}', tag: 'ORDER_REPO');
          } catch (_) {
            remaining.add(job);
          }
        }
        await box.put(_keyPendingCreateInvoice, remaining);
      }
    } catch (_) {}

    // Sync confirm invoice jobs
    try {
      final raw = box.get(_keyPendingConfirmInvoice);
      if (raw is List && raw.isNotEmpty) {
        final jobs = List<Map<String, dynamic>>.from(
            raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}));
        final remaining = <Map<String, dynamic>>[];
        for (final job in jobs) {
          try {
            final ok = await confirmInvoice(job['invoiceId'] as int);
            if (!ok) remaining.add(job);
          } catch (_) {
            remaining.add(job);
          }
        }
        await box.put(_keyPendingConfirmInvoice, remaining);
      }
    } catch (_) {}

    // Sync validate delivery jobs
    try {
      final raw = box.get(_keyPendingValidatePicking);
      if (raw is List && raw.isNotEmpty) {
        final jobs = List<Map<String, dynamic>>.from(
            raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}));
        final remaining = <Map<String, dynamic>>[];
        for (final job in jobs) {
          try {
            final ok = await validatePicking(job['pickingId'] as int);
            if (!ok) remaining.add(job);
          } catch (_) {
            remaining.add(job);
          }
        }
        await box.put(_keyPendingValidatePicking, remaining);
      }
    } catch (_) {}
  }

  // ─── Car Inventory Cache ─────────────────────────────────────────────────

  Future<void> _saveCarInventoryCache(int fsmOrderId, List<ProductItem> items) async {
    try {
      final box = await _openBox();
      await box.put(
        _carInventoryByFsmKey(fsmOrderId),
        items.map((e) => e.toMap()).toList(),
      );
    } catch (_) {}
  }

  Future<List<ProductItem>> _readCarInventoryCache(int fsmOrderId) async {
    try {
      final box = await _openBox();
      final raw = box.get(_carInventoryByFsmKey(fsmOrderId));
      if (raw is List) {
        return raw
            .map((e) => e is Map ? ProductItem.fromMap(Map<String, dynamic>.from(e)) : null)
            .whereType<ProductItem>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> actionCompleteOrder(int orderId) async {
    if (!_canRequestOdoo()) {
      await _enqueueFsmOrderAction('complete', orderId);
      try {
        await _mergeOrderDetailValuesLocally(
          orderId,
          const <String, dynamic>{'is_closed': true},
        );
      } catch (_) {}
      return true;
    }
    try {
      final res = await _api.callKw(
        model: 'fsm.order',
        method: 'action_complete',
        args: <dynamic>[<int>[orderId]],
        kwargs: const <String, dynamic>{},
      );
      return res.success;
    } catch (e) {
      AppLogger.error('actionCompleteOrder error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

  Future<bool> actionCancelOrder(int orderId) async {
    if (!_canRequestOdoo()) {
      await _enqueueFsmOrderAction('cancel', orderId);
      try {
        await _mergeOrderDetailValuesLocally(
          orderId,
          const <String, dynamic>{'is_closed': true},
        );
      } catch (_) {}
      return true;
    }
    try {
      final res = await _api.callKw(
        model: 'fsm.order',
        method: 'action_cancel',
        args: <dynamic>[<int>[orderId]],
        kwargs: const <String, dynamic>{},
      );
      return res.success;
    } catch (e) {
      AppLogger.error('actionCancelOrder error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }


  Future<bool> createStage(String name) async {
    if (!_canRequestOdoo()) return false;
    try {
      final res = await _api.callKw(
        model: OdooOrdersConfig.stageModel,
        method: 'create',
        args: <dynamic>[<String, dynamic>{'name': name}],
        kwargs: const <String, dynamic>{},
      );
      return res.success && res.data != null;
    } catch (e) {
      AppLogger.error('createStage error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

  Future<bool> updateStageName(int stageId, String name) async {
    if (!_canRequestOdoo()) return false;
    try {
      final res = await _api.callKw(
        model: OdooOrdersConfig.stageModel,
        method: 'write',
        args: <dynamic>[<int>[stageId], <String, dynamic>{'name': name}],
        kwargs: const <String, dynamic>{},
      );
      return res.success;
    } catch (e) {
      AppLogger.error('updateStageName error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

  Future<bool> deleteStage(int stageId) async {
    if (!_canRequestOdoo()) return false;
    try {
      final res = await _api.callKw(
        model: OdooOrdersConfig.stageModel,
        method: 'unlink',
        args: <dynamic>[<int>[stageId]],
        kwargs: const <String, dynamic>{},
      );
      return res.success;
    } catch (e) {
      AppLogger.error('deleteStage error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

  Future<bool> foldStage(int stageId, bool folded) async {
    if (!_canRequestOdoo()) return false;
    try {
      final res = await _api.callKw(
        model: OdooOrdersConfig.stageModel,
        method: 'write',
        args: <dynamic>[<int>[stageId], <String, dynamic>{'fold': folded}],
        kwargs: const <String, dynamic>{},
      );
      return res.success;
    } catch (e) {
      AppLogger.error('foldStage error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }


  /// Checks if 'worksheet_template_id' field exists on fsm.order (module installed check).
  Future<bool> checkWorksheetModuleInstalled() async {
    if (!_canRequestOdoo()) {
      try {
        final box = await _openBox();
        final cached = box.get(_scopedKey('worksheet_module_installed'));
        if (cached is bool) return cached;
      } catch (_) {}
      return false;
    }
    try {
      final res = await _api.callKw(
        model: 'fsm.order',
        method: 'fields_get',
        args: const <dynamic>[],
        kwargs: const <String, dynamic>{
          'attributes': <String>['type'],
        },
      );
      if (!res.success || res.data is! Map) return false;
      final fields = Map<String, dynamic>.from(res.data as Map);
      final installed = fields.containsKey('worksheet_template_id');
      final box = await _openBox();
      await box.put(_scopedKey('worksheet_module_installed'), installed);
      return installed;
    } catch (e) {
      AppLogger.error('checkWorksheetModuleInstalled error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

  /// Call while online right after the kanban board loads: for every FSM order,
  /// caches worksheet list + new-form schema + each row’s form (full offline).
  Future<void> prefetchAllWorksheetsForOrders(List<OrderModel> orders) async {
    if (!_canRequestOdoo()) return;
    final ids = orders
        .map((o) => _coerceInt(o.id))
        .whereType<int>()
        .where((id) => id > 0)
        .toSet()
        .toList()
      ..sort();
    if (ids.isEmpty) return;
    AppLogger.info(
      'prefetchAllWorksheetsForOrders: ${ids.length} orders (runs before other warm tasks)',
      tag: 'ORDER_REPO',
    );
    // Each order runs resolve + list + create detail + N row reads — keep low parallelism.
    const orderConcurrency = 2;
    for (var i = 0; i < ids.length; i += orderConcurrency) {
      if (!_canRequestOdoo()) {
        AppLogger.warning(
          'prefetchAllWorksheetsForOrders: stopped (lost connection)',
          tag: 'ORDER_REPO',
        );
        return;
      }
      final end = (i + orderConcurrency < ids.length)
          ? i + orderConcurrency
          : ids.length;
      final batch = ids.sublist(i, end);
      await Future.wait(
        batch.map(
          (fsmId) => fetchWorksheetRecords(fsmOrderId: fsmId).then(
            (_) {},
            onError: (Object e, StackTrace st) {
              AppLogger.debug(
                'prefetchAllWorksheetsForOrders: order $fsmId: $e',
                tag: 'ORDER_REPO',
              );
            },
          ),
        ),
        eagerError: false,
      );
    }
    AppLogger.success(
      'prefetchAllWorksheetsForOrders: done for ${ids.length} orders',
      tag: 'ORDER_REPO',
    );
  }

  /// Prefetches [fetchWorksheetRecordDetail] for every server row so offline
  /// open never depends on “already opened once online”.
  Future<void> _prefetchWorksheetRecordDetailsOnline({
    required int fsmOrderId,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (!_canRequestOdoo()) return;
    final ids = rows
        .map((r) => _coerceInt(r['id']))
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
    if (ids.isEmpty) return;
    const concurrency = 8;
    for (var i = 0; i < ids.length; i += concurrency) {
      if (!_canRequestOdoo()) return;
      final end = (i + concurrency < ids.length) ? i + concurrency : ids.length;
      final batch = ids.sublist(i, end);
      await Future.wait(
        batch.map(
          (rid) => fetchWorksheetRecordDetail(
            fsmOrderId: fsmOrderId,
            recordId: rid,
          ),
        ),
        eagerError: false,
      );
    }
  }

  /// Fetches worksheet records for an FSM order from [x_fsm_order_worksheet_template_4].
  Future<List<Map<String, dynamic>>> fetchWorksheetRecords({
    required int fsmOrderId,
  }) async
  {
    final cacheKey = _scopedKey('worksheet_records_$fsmOrderId');
    if (!_canRequestOdoo()) {
      try {
        final box = await _openBox();
        final raw = box.get(cacheKey);
        if (raw is List) {
          return raw
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      } catch (_) {}
      return [];
    }
    try {
      final worksheetModel = await _resolveWorksheetModelForOrder(fsmOrderId);
      await _cacheWorksheetModelNameForOrder(fsmOrderId, worksheetModel);
      final res = await _api.callKw(
        model: worksheetModel,
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['x_fsm_order_id', '=', fsmOrderId],
          ],
        ],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'x_name', 'create_date'],
          'limit': 200,
          'order': 'create_date desc',
        },
      );
      if (!res.success || res.data is! List) return [];
      final rows = (res.data as List)
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
      final box = await _openBox();
      await box.put(cacheKey, rows);
      // Warm form schema for offline "New" (must finish before user goes offline).
      await fetchWorksheetCreateDetail(fsmOrderId: fsmOrderId);
      // Cache every list row's form payload (parallel batches; no row cap).
      await _prefetchWorksheetRecordDetailsOnline(
        fsmOrderId: fsmOrderId,
        rows: rows,
      );
      return rows;
    } catch (e) {
      AppLogger.error('fetchWorksheetRecords error', tag: 'ORDER_REPO', error: e);
      return [];
    }
  }

  /// Fetches all fields defined on [x_fsm_order_worksheet_template_4] via fields_get,
  /// then reads the record values. Returns field metadata + record values.
  Future<Map<String, dynamic>?> fetchWorksheetRecordDetail({
    required int fsmOrderId,
    required int recordId,
  }) async
  {
    final cacheKey = _worksheetFormRecordStorageKey(fsmOrderId, recordId);
    if (!_canRequestOdoo()) {
      return _readWorksheetFormDetailOffline(
        primaryKey: cacheKey,
        keySuffix: 'worksheet_form_record_${fsmOrderId}_$recordId',
      );
    }
    try {
      final worksheetModel = await _resolveWorksheetModelForOrder(fsmOrderId);
      await _cacheWorksheetModelNameForOrder(fsmOrderId, worksheetModel);
      // Step 1: Get all fields metadata
      final fieldsRes = await _api.callKw(
        model: worksheetModel,
        method: 'fields_get',
        args: const <dynamic>[],
        kwargs: const <String, dynamic>{
          'attributes': <String>['string', 'type', 'selection', 'required'],
        },
      );
      if (!fieldsRes.success || fieldsRes.data is! Map) return null;
      final allFields = Map<String, dynamic>.from(fieldsRes.data as Map);

      // Filter out internal/system fields, keep only user-visible ones
      final skipPrefixes = ['__', 'write_', 'create_uid', 'write_uid',
        'display_name', 'message_', 'activity_', 'website_'];
      final skipFields = {'id', 'create_uid', 'write_uid', '__last_update'};
      final userFields = <String>[];
      for (final key in allFields.keys) {
        if (skipFields.contains(key)) continue;
        if (skipPrefixes.any((p) => key.startsWith(p))) continue;
        userFields.add(key);
      }

      if (userFields.isEmpty) return null;

      // Step 2: Read the record with those fields
      final readRes = await _api.callKw(
        model: worksheetModel,
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[<dynamic>['id', '=', recordId]],
        ],
        kwargs: <String, dynamic>{
          'fields': userFields,
          'limit': 1,
        },
      );
      if (!readRes.success || readRes.data is! List) return null;
      final rows = readRes.data as List;
      if (rows.isEmpty) return null;

      final viewFieldOrder = await _fetchWorksheetViewFieldOrder(worksheetModel);
      final detail = <String, dynamic>{
        'fields_meta': allFields,
        'user_fields': userFields,
        'values': Map<String, dynamic>.from(rows.first as Map),
        'view_field_order': viewFieldOrder,
      };
      await _saveWorksheetFormDetailCache(cacheKey, detail);
      return detail;
    } catch (e) {
      AppLogger.error('fetchWorksheetRecordDetail error', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchWorksheetCreateDetail({
    required int fsmOrderId,
  }) async
  {
    final cacheKey = _worksheetFormCreateStorageKey(fsmOrderId);
    if (!_canRequestOdoo()) {
      return _readWorksheetFormDetailOffline(
        primaryKey: cacheKey,
        keySuffix: 'worksheet_form_create_$fsmOrderId',
      );
    }
    try {
      final worksheetModel = await _resolveWorksheetModelForOrder(fsmOrderId);
      await _cacheWorksheetModelNameForOrder(fsmOrderId, worksheetModel);
      final fieldsRes = await _api.callKw(
        model: worksheetModel,
        method: 'fields_get',
        args: const <dynamic>[],
        kwargs: const <String, dynamic>{
          'attributes': <String>['string', 'type', 'selection', 'required'],
        },
      );
      if (!fieldsRes.success || fieldsRes.data is! Map) return null;
      final allFields = Map<String, dynamic>.from(fieldsRes.data as Map);

      final skipPrefixes = ['__', 'write_', 'create_uid', 'write_uid', 'display_name', 'message_', 'activity_', 'website_'];
      final skipFields = {'id', 'create_uid', 'write_uid', '__last_update'};
      final userFields = <String>[];
      for (final key in allFields.keys) {
        if (skipFields.contains(key)) continue;
        if (skipPrefixes.any((p) => key.startsWith(p))) continue;
        userFields.add(key);
      }
      if (userFields.isEmpty) return null;

      final defaultsRes = await _api.callKw(
        model: worksheetModel,
        method: 'default_get',
        args: <dynamic>[userFields],
        kwargs: <String, dynamic>{
          'context': <String, dynamic>{'default_x_fsm_order_id': fsmOrderId},
        },
      );

      final values = <String, dynamic>{};
      if (defaultsRes.success && defaultsRes.data is Map) {
        values.addAll(Map<String, dynamic>.from(defaultsRes.data as Map));
      }
      values['x_fsm_order_id'] = fsmOrderId;

      final viewFieldOrder = await _fetchWorksheetViewFieldOrder(worksheetModel);
      final detail = <String, dynamic>{
        'fields_meta': allFields,
        'user_fields': userFields,
        'values': values,
        'view_field_order': viewFieldOrder,
      };
      await _saveWorksheetFormDetailCache(cacheKey, detail);
      return detail;
    } catch (e) {
      AppLogger.error('fetchWorksheetCreateDetail error', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  Future<int?> createWorksheetRecord({
    required int fsmOrderId,
    required Map<String, dynamic> values,
  }) async
  {
    if (!_canRequestOdoo()) {
      final model = await _readCachedWorksheetModelNameForOrder(fsmOrderId) ??
          'x_fsm_order_worksheet_template_4';
      final localId = await _nextLocalWorksheetId();
      final clean = Map<String, dynamic>.from(values);
      await _enqueuePendingWorksheetJob(<String, dynamic>{
        'op': 'create',
        'fsm_order_id': fsmOrderId,
        'local_id': localId,
        'values': clean,
        'worksheet_model': model,
      });
      final name = clean['x_name']?.toString() ??
          clean['name']?.toString() ??
          'Pending sync';
      await _upsertWorksheetListCacheRow(fsmOrderId, <String, dynamic>{
        'id': localId,
        'x_name': name,
        'create_date': DateTime.now().toUtc().toIso8601String(),
      });
      final template = await _readWorksheetFormDetailOffline(
        primaryKey: _worksheetFormCreateStorageKey(fsmOrderId),
        keySuffix: 'worksheet_form_create_$fsmOrderId',
      );
      if (template != null &&
          template['fields_meta'] is Map &&
          template['user_fields'] is List) {
        final mergedVals = Map<String, dynamic>.from(
          template['values'] is Map
              ? Map<String, dynamic>.from(template['values'] as Map)
              : <String, dynamic>{},
        );
        mergedVals.addAll(clean);
        mergedVals['id'] = localId;
        mergedVals['x_fsm_order_id'] = fsmOrderId;
        final detail = <String, dynamic>{
          'fields_meta': template['fields_meta'],
          'user_fields': template['user_fields'],
          'values': mergedVals,
        };
        await _saveWorksheetFormDetailCache(
          _worksheetFormRecordStorageKey(fsmOrderId, localId),
          detail,
        );
      }
      AppLogger.info(
        'createWorksheetRecord queued offline localId=$localId',
        tag: 'ORDER_REPO',
      );
      return localId;
    }
    try {
      final worksheetModel = await _resolveWorksheetModelForOrder(fsmOrderId);
      await _cacheWorksheetModelNameForOrder(fsmOrderId, worksheetModel);
      final res = await _api.callKw(
        model: worksheetModel,
        method: 'create',
        args: <dynamic>[values],
        kwargs: const <String, dynamic>{},
      );
      if (!res.success || res.data == null) return null;
      final id = res.data;
      if (id is int) return id;
      if (id is num) return id.toInt();
      return int.tryParse(id.toString());
    } catch (e) {
      AppLogger.error('createWorksheetRecord error', tag: 'ORDER_REPO', error: e);
      return null;
    }
  }

  Future<bool> updateWorksheetRecord({
    required int fsmOrderId,
    required int recordId,
    required Map<String, dynamic> values,
  }) async {
    if (!_canRequestOdoo()) {
      final model = await _readCachedWorksheetModelNameForOrder(fsmOrderId) ??
          'x_fsm_order_worksheet_template_4';
      final patch = Map<String, dynamic>.from(values);
      if (recordId < 0) {
        final ok = await _mergeIntoPendingWorksheetCreate(
          fsmOrderId,
          recordId,
          patch,
        );
        if (!ok) return false;
      } else {
        await _enqueuePendingWorksheetJob(<String, dynamic>{
          'op': 'write',
          'fsm_order_id': fsmOrderId,
          'record_id': recordId,
          'values': patch,
          'worksheet_model': model,
        });
      }
      await _patchWorksheetCachesAfterEdit(fsmOrderId, recordId, patch);
      return true;
    }
    try {
      final worksheetModel = await _resolveWorksheetModelForOrder(fsmOrderId);
      await _cacheWorksheetModelNameForOrder(fsmOrderId, worksheetModel);
      final res = await _api.callKw(
        model: worksheetModel,
        method: 'write',
        args: <dynamic>[<int>[recordId], values],
        kwargs: const <String, dynamic>{},
      );
      return res.success;
    } catch (e) {
      AppLogger.error('updateWorksheetRecord error', tag: 'ORDER_REPO', error: e);
      return false;
    }
  }

// Cache to avoid repeated API calls for same template
  final Map<int, String> _worksheetModelCache = {};

  Future<String> _resolveWorksheetModelForOrder(int fsmOrderId) async {
    // Step 1: Get worksheet_template_id from the FSM order
    final orderRes = await _api.callKw(
      model: 'fsm.order',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[<dynamic>['id', '=', fsmOrderId]],
      ],
      kwargs: const <String, dynamic>{
        'fields': <String>['id', 'worksheet_template_id'],
        'limit': 1,
      },
    );

    if (!orderRes.success || orderRes.data is! List) {
      return 'x_fsm_order_worksheet_template_4'; // fallback
    }
    final rows = orderRes.data as List;
    if (rows.isEmpty) return 'x_fsm_order_worksheet_template_4';

    final row = Map<String, dynamic>.from(rows.first as Map);
    final templateRaw = row['worksheet_template_id'];
    int? templateId;
    if (templateRaw is List && templateRaw.isNotEmpty) {
      templateId = templateRaw.first is int
          ? templateRaw.first as int
          : int.tryParse(templateRaw.first.toString());
    }

    if (templateId == null) return 'x_fsm_order_worksheet_template_4';

    // Return from cache if already resolved
    if (_worksheetModelCache.containsKey(templateId)) {
      return _worksheetModelCache[templateId]!;
    }

    // Step 2: Get model_id from worksheet.template
    final templateRes = await _api.callKw(
      model: 'worksheet.template',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[<dynamic>['id', '=', templateId]],
      ],
      kwargs: const <String, dynamic>{
        'fields': <String>['id', 'model_id'],
        'limit': 1,
      },
    );

    if (!templateRes.success || templateRes.data is! List) {
      return 'x_fsm_order_worksheet_template_4';
    }
    final tRows = templateRes.data as List;
    if (tRows.isEmpty) return 'x_fsm_order_worksheet_template_4';

    final tRow = Map<String, dynamic>.from(tRows.first as Map);
    final modelIdRaw = tRow['model_id'];
    int? modelId;
    if (modelIdRaw is List && modelIdRaw.isNotEmpty) {
      modelId = modelIdRaw.first is int
          ? modelIdRaw.first as int
          : int.tryParse(modelIdRaw.first.toString());
    }

    if (modelId == null) return 'x_fsm_order_worksheet_template_4';

    // Step 3: Get the actual model name from ir.model
    final irModelRes = await _api.callKw(
      model: 'ir.model',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[<dynamic>['id', '=', modelId]],
      ],
      kwargs: const <String, dynamic>{
        'fields': <String>['id', 'model'],
        'limit': 1,
      },
    );

    if (!irModelRes.success || irModelRes.data is! List) {
      return 'x_fsm_order_worksheet_template_4';
    }
    final mRows = irModelRes.data as List;
    if (mRows.isEmpty) return 'x_fsm_order_worksheet_template_4';

    final mRow = Map<String, dynamic>.from(mRows.first as Map);
    final modelName = mRow['model']?.toString();

    if (modelName == null || modelName.isEmpty) {
      return 'x_fsm_order_worksheet_template_4';
    }

    AppLogger.info(
      '_resolveWorksheetModelForOrder: fsmOrderId=$fsmOrderId '
          'templateId=$templateId → model=$modelName',
      tag: 'ORDER_REPO',
    );

    // Cache and return
    _worksheetModelCache[templateId] = modelName;
    return modelName;
  }

  Future<List<String>> _fetchWorksheetViewFieldOrder(String modelName) async {
    try {
      // ── Odoo 16+ ─────────────────────────────────────────────
      final res = await _api.callKw(
        model: modelName,
        method: 'get_views',
        args: <dynamic>[
          <dynamic>[
            <dynamic>[false, 'form'],
          ]
        ],
        kwargs: const <String, dynamic>{},
      );
      if (res.success && res.data != null) {
        final arch =
            (res.data as Map?)?['views']?['form']?['arch']?.toString() ?? '';
        if (arch.isNotEmpty) return _parseFieldOrderFromArch(arch);
      }
    } catch (e) {
      AppLogger.error('get_views failed: $e', tag: 'ORDER_REPO', error: e);
    }

    try {
      // ── Odoo 13–15 fallback ──────────────────────────────────
      final res = await _api.callKw(
        model: modelName,
        method: 'fields_view_get',
        args: const <dynamic>[],
        kwargs: const <String, dynamic>{'view_type': 'form'},
      );
      if (res.success && res.data != null) {
        final arch = (res.data as Map?)?['arch']?.toString() ?? '';
        if (arch.isNotEmpty) return _parseFieldOrderFromArch(arch);
      }
    } catch (e) {
      AppLogger.error('fields_view_get failed: $e', tag: 'ORDER_REPO', error: e);
    }

    return [];
  }

  List<String> _parseFieldOrderFromArch(String arch) {
    final result = <String>[];
    final seen = <String>{};

    final fieldTagRegex = RegExp(r'<field\s([^>]*?)(?:/>|>)', dotAll: true);

    for (final match in fieldTagRegex.allMatches(arch)) {
      final attrs = match.group(1) ?? '';

      final nameMatch = RegExp(r'\bname="([^"]+)"').firstMatch(attrs);
      if (nameMatch == null) continue;
      final name = nameMatch.group(1) ?? '';
      if (name.isEmpty) continue;

      // Skip invisible="1" or invisible="True"
      final invisMatch = RegExp(r'\binvisible="([^"]*)"').firstMatch(attrs);
      if (invisMatch != null) {
        final val = invisMatch.group(1)?.trim() ?? '';
        if (val == '1' || val.toLowerCase() == 'true') continue;
      }

      // Skip column_invisible="1"
      final colInvis =
      RegExp(r'\bcolumn_invisible="([^"]*)"').firstMatch(attrs);
      if (colInvis != null) {
        final val = colInvis.group(1)?.trim() ?? '';
        if (val == '1' || val.toLowerCase() == 'true') continue;
      }

      if (!seen.add(name)) continue;
      result.add(name);
    }

    return result;
  }

  Future<FsmLocationDialogModel> _readMapDialogLocationFromOrderCache(int orderId) async {
    try {
      final box = await _openBox();
      final items = box.get(_keyItems);
      if (items is! List) return FsmLocationDialogModel.empty();
      for (final e in items) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final rowId = _coerceInt(m['id']) ?? int.tryParse(m['id']?.toString() ?? '');
        if (rowId != orderId) continue;
        String t(dynamic v) => (v == null || v == false) ? '' : v.toString();
        return FsmLocationDialogModel(
          phone: t(m['phone']),
          mobile: t(m['mobile']),
          street: t(m['street']),
          street2: t(m['street2']),
          city: t(m['city']),
          state: t(m['state']),
          zip: t(m['zip']),
          country: t(m['country']),
        );
      }
    } catch (_) {}
    return FsmLocationDialogModel.empty();
  }

  Future<void> _saveLocalRoutePayload(Map<String, dynamic> payload) async {
    try {
      final box = await _openBox();
      await box.put(_keySavedRouteLocal, payload);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readLocalRoutePayload() async {
    try {
      final box = await _openBox();
      final raw = box.get(_keySavedRouteLocal);
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return null;
  }

  Future<void> saveRouteGeometryCache({
    required String cacheKey,
    required List<Map<String, double>> points,
    required double distanceM,
    required int durationS,
  }) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyRouteGeometryCache);
      final all = raw is Map
          ? Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)))
          : <String, dynamic>{};
      all[cacheKey] = <String, dynamic>{
        'points': points,
        'distance_m': distanceM,
        'duration_s': durationS,
        'saved_at': DateTime.now().toIso8601String(),
      };
      await box.put(_keyRouteGeometryCache, all);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> readRouteGeometryCache(String cacheKey) async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyRouteGeometryCache);
      if (raw is! Map) return null;
      final entry = raw[cacheKey];
      if (entry is Map) return Map<String, dynamic>.from(entry);
    } catch (_) {}
    return null;
  }

  Future<void> _saveRoutingConfigCache(Map<String, String> config) async {
    try {
      final box = await _openBox();
      await box.put(_keyRoutingConfigCache, config);
    } catch (_) {}
  }

  Future<Map<String, String>?> _readRoutingConfigCache() async {
    try {
      final box = await _openBox();
      final raw = box.get(_keyRoutingConfigCache);
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _defaultRoutingConfig() => <String, String>{
        'osrm_base_url': 'https://router.project-osrm.org/route/v1',
        'profile': 'driving',
        'engine_mode': 'osrm',
      };

  /// Fetch OSRM config from backend (cached locally for offline map routing).
  Future<Map<String, String>> fetchRoutingConfig() async {
    if (!_canRequestOdoo()) {
      return (await _readRoutingConfigCache()) ?? _defaultRoutingConfig();
    }
    try {
      final base = (_network.baseUrl ?? '').trimRight().replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$base/itis_fsm_routing/config');
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (_network.sessionId != null) 'Cookie': 'session_id=${_network.sessionId}',
        },
        body: jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'call',
          'params': <String, dynamic>{},
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final result = body['result'];
        if (result is Map) {
          final data = Map<String, dynamic>.from(result);
          final config = <String, String>{
            'osrm_base_url': data['osrm_base_url']?.toString() ??
                'https://router.project-osrm.org/route/v1',
            'profile': data['profile']?.toString() ?? 'driving',
            'engine_mode': data['engine_mode']?.toString() ?? 'osrm',
          };
          await _saveRoutingConfigCache(config);
          return config;
        }
      }
    } catch (e) {
      AppLogger.error('fetchRoutingConfig failed', tag: 'ORDER_REPO', error: e);
    }
    return (await _readRoutingConfigCache()) ?? _defaultRoutingConfig();
  }

  /// Load saved route — local Hive first when offline; merge server when online.
  Future<Map<String, dynamic>?> fetchSavedRoute() async {
    if (!_canRequestOdoo()) {
      return _readLocalRoutePayload();
    }
    try {
      final base = (_network.baseUrl ?? '').trimRight().replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$base/itis_fsm_routing/saved_route/get');
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (_network.sessionId != null) 'Cookie': 'session_id=${_network.sessionId}',
        },
        body: jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'call',
          'params': <String, dynamic>{},
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final result = body['result'];
        if (result is Map) {
          final data = Map<String, dynamic>.from(result);
          if (data['ok'] == true) {
            final payload = data['payload'];
            if (payload == null || payload == false) {
              return _readLocalRoutePayload();
            }
            final map = Map<String, dynamic>.from(payload as Map);
            await _saveLocalRoutePayload(map);
            return map;
          }
        }
      }
    } catch (e) {
      AppLogger.error('fetchSavedRoute failed', tag: 'ORDER_REPO', error: e);
    }
    return _readLocalRoutePayload();
  }

  /// Persist route locally always; sync to Odoo when online.
  Future<bool> saveRoute({
    required List<Map<String, dynamic>> orders,
    required String engineMode,
    required String profile,
  }) async {
    final localPayload = <String, dynamic>{
      'orders': orders,
      'routing': <String, dynamic>{
        'engine_mode': engineMode,
        'profile': profile,
      },
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _saveLocalRoutePayload(localPayload);

    if (!_canRequestOdoo()) return true;

    try {
      final base = (_network.baseUrl ?? '').trimRight().replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$base/itis_fsm_routing/saved_route/set');
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (_network.sessionId != null) 'Cookie': 'session_id=${_network.sessionId}',
        },
        body: jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'call',
          'params': <String, dynamic>{
            'payload': <String, dynamic>{
              'orders': orders,
              'routing': <String, dynamic>{
                'engine_mode': engineMode,
                'profile': profile,
              },
            },
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final result = body['result'];
        if (result is Map) {
          return Map<String, dynamic>.from(result)['ok'] == true;
        }
      }
    } catch (e) {
      AppLogger.error('saveRoute failed', tag: 'ORDER_REPO', error: e);
    }
    return false;
  }
}

class OdooFieldOption {
  const OdooFieldOption({
    required this.id,
    required this.label,
  });

  final dynamic id;
  final String label;
}

class VehicleStockTransferResult {
  const VehicleStockTransferResult._({
    required this.success,
    required this.queued,
    this.message,
    this.pickingId,
  });

  const VehicleStockTransferResult.success({
    String? message,
    int? pickingId,
  }) : this._(
          success: true,
          queued: false,
          message: message,
          pickingId: pickingId,
        );

  const VehicleStockTransferResult.queued({
    String? message,
  }) : this._(
          success: true,
          queued: true,
          message: message,
        );

  const VehicleStockTransferResult.error(String message)
      : this._(
          success: false,
          queued: false,
          message: message,
        );

  final bool success;
  final bool queued;
  final String? message;
  final int? pickingId;
}

class VehicleStockItem {
  const VehicleStockItem({
    required this.location,
    required this.product,
    required this.lotSerial,
    required this.onHandQty,
    required this.reservedQty,
    required this.unit,
  });

  final String location;
  final String product;
  final String lotSerial;
  final double onHandQty;
  final double reservedQty;
  final String unit;
}

class OrderMapCoordinates {
  const OrderMapCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}


// ─────────────────────────────────────────────────────────────────────────────
//  Product item model
// ─────────────────────────────────────────────────────────────────────────────
class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.internalRef,
    required this.price,
    required this.onHandQty,
    required this.imageBase64,
    required this.attributes,
  });

  final int id;
  final String name;
  final String internalRef;
  final double price;
  final double onHandQty;
  final String imageBase64;
  final List<String> attributes;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'internal_ref': internalRef,
    'price': price,
    'on_hand_qty': onHandQty,
    'image_base64': imageBase64,
    'attributes': attributes,
  };

  factory ProductItem.fromMap(Map<String, dynamic> m) {
    return ProductItem(
      id: m['id'] as int? ?? 0,
      name: m['name']?.toString() ?? '',
      internalRef: m['internal_ref']?.toString() ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      onHandQty: (m['on_hand_qty'] as num?)?.toDouble() ?? 0.0,
      imageBase64: m['image_base64']?.toString() ?? '',
      attributes: (m['attributes'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
    );
  }
}