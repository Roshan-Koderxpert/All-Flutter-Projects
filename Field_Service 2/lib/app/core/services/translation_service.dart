import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:get/get.dart';
import '../localization/en_base_translations.dart';
import '../services/storage_service.dart';
import '../services/network_service.dart';
import '../utils/logger.dart';

/// Dynamic translation service — PO-file based, fetched from Odoo.
///
/// Flow:
///   1. English bundled — instant.
///   2. Other lang → fetch PO from Odoo via base.language.export callKw.
///   3. Parse PO → match msgid against our English strings.
///   4. Cache result → offline-ready on next launch.
class TranslationService extends GetxService {
  static TranslationService get to => Get.find<TranslationService>();

  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;
  final currentLangCode = 'en_US'.obs;
  final currentLangName = 'English'.obs;

  static const _cachePrefix = 'trans_po_v6_';

  static const _cacheTimestampPrefix = 'trans_po_ts_v6_';
  static const _cacheMaxAge = Duration(hours: 24);

  /// Timeout for the entire PO export operation.
  /// base.language.export on a large Odoo instance can take 30–60 s.
  static const _downloadTimeout = Duration(seconds: 90);

  @override
  void onInit() {
    super.onInit();
    _registerEnglish();
    final saved = StorageService.to.selectedLanguageCode;
    if (saved.isNotEmpty && !_isEnglish(saved)) {
      // Step 1: Load cache INSTANTLY — UI is immediately correct language
      final hadCache = _loadCached(saved);
      // Only background-refresh if cache is stale (>24h old)
      // This avoids hitting Odoo on every single app start
      if (hadCache && _isCacheStale(saved)) {
        _silentBackgroundRefresh(saved);
      }
    }
    AppLogger.success('TranslationService initialized', tag: 'I18N');
  }

  /// Refreshes translations from Odoo in the background after app start.
  /// Does NOT show the download spinner. UI keeps showing cached language.
  /// New translations apply only after the refresh completes.
  void _silentBackgroundRefresh(String langCode) {
    Future.delayed(const Duration(seconds: 3), () async {
      // Abort if user switched language during the delay
      if (currentLangCode.value != langCode) {
        AppLogger.info('Silent refresh cancelled — language changed to ${currentLangCode.value}', tag: 'I18N');
        return;
      }
      try {
        AppLogger.info('Silent background refresh for $langCode', tag: 'I18N');
        await _downloadWithGuards(langCode, silent: true);
        AppLogger.success('Silent background refresh complete for $langCode', tag: 'I18N');
      } catch (e) {
        AppLogger.warning('Silent background refresh failed: $e', tag: 'I18N');
      }
    });
  }

  // ── Public API ────────────────────────────────────────────────────────

  Future<void> changeLanguage(
      String odooLangCode,
      String displayName, {
        bool forceRefresh = false, // true = skip cache, always re-fetch PO from Odoo
      }) async {
    final code = odooLangCode.trim();
    if (code.isEmpty) return;
    currentLangCode.value = code;
    currentLangName.value = displayName;
    AppLogger.info('Changing language → $code ($displayName) forceRefresh=$forceRefresh', tag: 'I18N');
    if (_isEnglish(code)) {
      _applyLocale(code);
      return;
    }
    // Always try cache first — instant load
// Always try cache first — instant load
    if (_loadCached(code)) {
      // Refresh in background if: explicitly requested OR cache is older than 24h
      if (forceRefresh || _isCacheStale(code)) {
        AppLogger.info('Cache hit but stale/forced — refreshing in background for $code', tag: 'I18N');
        _silentBackgroundRefresh(code);
      }
      return;
    }
    // No cache → must download (shows spinner, expected on first use)
    await _downloadWithGuards(code, silent: false);
  }

  Future<void> syncFromOdoo(String odooLangCode, {String displayName = ''}) =>
      changeLanguage(
        odooLangCode,
        displayName.isNotEmpty ? displayName : odooLangCode,
      );

  Future<void> clearCache(String langCode) async {
    await StorageService.to.remove('$_cachePrefix$langCode');
    AppLogger.info('Cleared cache for $langCode', tag: 'I18N');
  }

  // ── Download wrapper: timeout + typed error handling ──────────────────

  Future<void> _downloadWithGuards(String langCode, {bool silent = false}) async {
    try {
      await _doDownload(langCode, silent: silent).timeout(
        _downloadTimeout,
        onTimeout: () {
          AppLogger.warning(
            'Translation download timed out after ${_downloadTimeout.inSeconds}s '
                'for $langCode — falling back to English UI',
            tag: 'I18N',
          );
          // Ensure spinner is stopped even on timeout path
          if (!silent) isDownloading.value = false;
          downloadProgress.value = 1.0;
          _applyLocale('en_US');
        },
      );
    } on HttpException catch (e) {
      // Covers 504 Gateway Timeout, 502 Bad Gateway, 503 Service Unavailable
      // that NetworkService converts from HTML → HttpException
      AppLogger.warning(
        'Translation HTTP error (server not available): $e',
        tag: 'I18N',
      );
      if (!silent) isDownloading.value = false;
      downloadProgress.value = 1.0;
      _applyLocale('en_US');
    } on TimeoutException catch (_) {
      AppLogger.warning(
        'Translation download timed out (TimeoutException) for $langCode',
        tag: 'I18N',
      );
      if (!silent) isDownloading.value = false;
      downloadProgress.value = 1.0;
      _applyLocale('en_US');
    } catch (e, st) {
      AppLogger.error('Translation fetch error: $e\n$st', tag: 'I18N');
      if (!silent) isDownloading.value = false;
      downloadProgress.value = 1.0;
      _applyLocale('en_US');
    }
  }

  // ── Core download logic ───────────────────────────────────────────────

  Future<void> _doDownload(String langCode, {bool silent = false}) async {
    if (!silent) isDownloading.value = true;
    downloadProgress.value = 0.0;
    try {
      final network = Get.find<NetworkService>();

      // ── Step 1: Get IDs for a focused set of modules ────────────────────
      // Exporting ALL installed modules causes 504 on loaded servers.
      // We scope to the modules that actually contain strings your app uses.
      downloadProgress.value = 0.10;
      final moduleIds = await _fetchModuleIds(network);
      if (moduleIds.isEmpty) {
        AppLogger.warning('Could not find any module IDs', tag: 'I18N');
        _applyLocale('en_US');
        return;
      }
      AppLogger.info(
        'Exporting translations with ${moduleIds.length} module IDs',
        tag: 'I18N',
      );

      // ── Step 2: Create the wizard record ───────────────────────────────
      downloadProgress.value = 0.20;
      final createRaw = await network.jsonRpc(
        endpoint: '/web/dataset/call_kw',
        params: {
          'model': 'base.language.export',
          'method': 'create',
          'args': [
            {
              'name': langCode,
              'lang': langCode,
              'format': 'po',
              // Many2many command 6 = replace with list of IDs
              'modules': [[6, 0, moduleIds]],
              'state': 'choose',
            }
          ],
          'kwargs': {'context': {}},
        },
      );

      if (createRaw.containsKey('error')) {
        AppLogger.warning(
          'Export create failed: ${createRaw['error']}',
          tag: 'I18N',
        );
        _applyLocale('en_US');
        return;
      }

      final exportId = createRaw['result'];
      if (exportId == null) {
        AppLogger.warning('Export create returned null id', tag: 'I18N');
        _applyLocale('en_US');
        return;
      }
      AppLogger.info('Created export wizard id=$exportId', tag: 'I18N');

      // ── Step 3: Trigger the export (generates the PO file) ─────────────
      downloadProgress.value = 0.40;
      await network.jsonRpc(
        endpoint: '/web/dataset/call_kw',
        params: {
          'model': 'base.language.export',
          'method': 'act_getfile',
          'args': [[exportId]],
          'kwargs': {'context': {}},
        },
      );

      // ── Step 4: Read the base64-encoded PO data ─────────────────────────
      downloadProgress.value = 0.65;
      final readRaw = await network.jsonRpc(
        endpoint: '/web/dataset/call_kw',
        params: {
          'model': 'base.language.export',
          'method': 'read',
          'args': [[exportId]],
          'kwargs': {'fields': ['data'], 'context': {}},
        },
      );

      final readResult = readRaw['result'];
      if (readResult is! List || readResult.isEmpty) {
        AppLogger.warning('Export read returned no data', tag: 'I18N');
        _applyLocale('en_US');
        return;
      }

      final dataB64 = (readResult.first as Map)['data']?.toString() ?? '';
      if (dataB64.isEmpty || dataB64 == 'false') {
        AppLogger.warning('Export data field is empty', tag: 'I18N');
        _applyLocale('en_US');
        return;
      }

      // ── Step 5: Decode base64 → PO text → parse ────────────────────────
      downloadProgress.value = 0.80;
// Odoo returns MIME-wrapped base64 with embedded newlines (\n and \r\n).
// dart:convert base64Decode requires a clean string — strip all whitespace first.
      final cleanB64 = dataB64.replaceAll(RegExp(r'\s+'), '');
      final poContent = utf8.decode(base64Decode(cleanB64));
      AppLogger.info('PO file size: ${poContent.length} chars', tag: 'I18N');

      final poMap = _parsePo(poContent);
      downloadProgress.value = 0.90;

      final appMap = _buildAppMap(poMap);

      // Overlay custom terms (strings not in Odoo module PO files)
      // Overlay field label translations (ir.model.fields string attributes)
      downloadProgress.value = 0.91;
      final fieldMap = await _fetchFieldLabels(network, langCode);
      appMap.addAll(fieldMap);

      // Overlay custom terms (strings not in Odoo module PO files)
      downloadProgress.value = 0.95;
      final customMap = await _fetchCustomTerms(network, langCode);
      appMap.addAll(customMap);

      AppLogger.info(
        'Built ${appMap.length} translation entries for $langCode (${customMap.length} custom)',
        tag: 'I18N',
      );

      await StorageService.to.write('$_cachePrefix$langCode', jsonEncode(appMap));
      await StorageService.to.write(
        '$_cacheTimestampPrefix$langCode',
        DateTime.now().millisecondsSinceEpoch,
      );
      AppLogger.success(
        'Cached ${appMap.length} translations for $langCode',
        tag: 'I18N',
      );
      _registerAndApply(langCode, appMap);
    } finally {
      if (!silent) isDownloading.value = false;
      downloadProgress.value = 1.0;
    }
  }

  // ── Fetch module integer IDs (scoped, not all-installed) ──────────────

  /// Returns IDs for a focused set of Odoo modules.
  ///
  /// WHY SCOPED: exporting all ~150+ installed modules in one wizard call
  /// routinely causes 504 Gateway Timeout errors. We only need the modules
  /// that actually contain strings used by this app.
  ///
  /// Add more module names here if you add features that bring new Odoo
  /// modules into the app's scope (e.g. 'account' if you show invoices).
  static const _targetModules = <String>[
    'base',
    'mail',
    'field_service',
    'industry_fsm_worksheet',
    'industry_fsm',
    'project',
    'sale',
    'stock',
    'account',
    'hr',
    'timesheet_grid',
    'hr_timesheet',
    'web',
    'itis_worksheet',
    'itis_timer',
    'itis_fieldservice_timesheet',
    'fieldservice',
    'itis_custom_modules',
    'hr_employee_id_card',
    'itis_attendance_break_config',
    'itis_fieldservice_account',
    'itis_fieldservice_distance',
    'itis_fieldservice_extend',
    'itis_fieldservice_geoengine_routing',
    'itis_fieldservice_material',
    'itis_fieldservice_stock',
    'itis_fieldservice_vehicle_stock',
    'itis_res_asset',
    'contacts'
  ];

  Future<List<int>> _fetchModuleIds(NetworkService network) async {
    try {
      final raw = await network.jsonRpc(
        endpoint: '/web/dataset/call_kw',
        params: {
          'model': 'ir.module.module',
          'method': 'search_read',
          'args': [
            [
              ['state', '=', 'installed'],
              ['name', 'in', _targetModules],
            ]
          ],
          'kwargs': {
            'fields': ['id', 'name'],
            'limit': 0,
            'context': {},
          },
        },
      );

      final result = raw['result'];
      if (result is! List) return [];

      final ids = result
          .map<int?>((e) => e is Map ? (e['id'] as int?) : null)
          .whereType<int>()
          .toList();

      AppLogger.info(
        'Found ${ids.length} target modules for translation export',
        tag: 'I18N',
      );

      // If none of our target modules are installed (unusual), fall back
      // to just 'base' so we get at least partial translations
      if (ids.isEmpty) {
        AppLogger.warning(
          'None of the target modules found; falling back to base-only export',
          tag: 'I18N',
        );
        return await _fetchBaseModuleId(network);
      }
      return ids;
    } catch (e) {
      AppLogger.warning('fetchModuleIds failed: $e', tag: 'I18N');
      return [];
    }
  }

  Future<List<int>> _fetchBaseModuleId(NetworkService network) async {
    try {
      final raw = await network.jsonRpc(
        endpoint: '/web/dataset/call_kw',
        params: {
          'model': 'ir.module.module',
          'method': 'search_read',
          'args': [
            [
              ['name', '=', 'base'],
              ['state', '=', 'installed'],
            ]
          ],
          'kwargs': {'fields': ['id'], 'limit': 1, 'context': {}},
        },
      );
      final result = raw['result'];
      if (result is! List || result.isEmpty) return [];
      final id = (result.first as Map)['id'] as int?;
      return id != null ? [id] : [];
    } catch (_) {
      return [];
    }
  }

  /// Fetches translated field label strings from ir.model.fields.
  /// This covers Odoo field `string` attributes (e.g. "Worksheet Template",
  /// "Scheduled Start") that appear in the UI but are NOT plain PO msgids.
  Future<Map<String, String>> _fetchFieldLabels(
      NetworkService network,
      String langCode,
      ) async {
    // Map: app_key → [model, field_name]
    // Find the model+field by inspecting Odoo's field definitions.
    const fieldLookups = <String, List<String>>{
      'order_field_worksheet_template':  ['project.task', 'worksheet_template_id'],
      'order_field_scheduled_start':     ['project.task', 'planned_date_begin'],
      'order_field_scheduled_end':       ['project.task', 'planned_date_end'],
      'order_field_scheduled_duration':  ['project.task', 'planned_hours'],
      'order_field_earliest_request_date': ['project.task', 'date_deadline'],
      'order_timesheet_log_time_spent':  ['account.analytic.line', 'unit_amount'],
      'order_timesheet_col_timespent':   ['account.analytic.line', 'unit_amount'],
    };

    try {
      // Build domain: fetch all needed fields in one call
      final modelFieldPairs = fieldLookups.values
          .map((v) => '${v[0]}.${v[1]}')
          .toSet()
          .toList();

      final domainOr = fieldLookups.values
          .map((v) => ['&', ['model', '=', v[0]], ['name', '=', v[1]]])
          .toList();

      final raw = await network.jsonRpc(
        endpoint: '/web/dataset/call_kw',
        params: {
          'model': 'ir.model.fields',
          'method': 'search_read',
          'args': [
            [
              ['model', 'in', fieldLookups.values.map((v) => v[0]).toSet().toList()],
              ['name', 'in', fieldLookups.values.map((v) => v[1]).toSet().toList()],
            ]
          ],
          'kwargs': {
            'fields': ['model', 'name', 'field_description'],
            'limit': 0,
            'context': {'lang': langCode},
          },
        },
      );

      final result = raw['result'];
      if (result is! List) return {};

      // Build lookup: "model.fieldname" → translated label
      final labelMap = <String, String>{};
      for (final rec in result) {
        if (rec is Map) {
          final model = rec['model']?.toString() ?? '';
          final name  = rec['name']?.toString() ?? '';
          final label = rec['field_description']?.toString() ?? '';
          if (model.isNotEmpty && name.isNotEmpty && label.isNotEmpty) {
            labelMap['$model.$name'] = label;
          }
        }
      }

      // Map back to app keys
      final out = <String, String>{};
      for (final entry in fieldLookups.entries) {
        final key = '${entry.value[0]}.${entry.value[1]}';
        final translated = labelMap[key];
        if (translated != null && translated.isNotEmpty) {
          out[entry.key] = translated;
          AppLogger.info(
            '[I18N_FIELD] HIT  key="${entry.key}"  =>  "$translated"',
            tag: 'I18N',
          );
        } else {
          AppLogger.info(
            '[I18N_FIELD] MISS key="${entry.key}"  field="$key"',
            tag: 'I18N',
          );
        }
      }
      return out;
    } catch (e) {
      AppLogger.warning('_fetchFieldLabels failed: $e', tag: 'I18N');
      return {};
    }
  }

  /// Fetches translations for app-custom strings that don't exist
  /// as msgids in Odoo's module PO files.
  /// Uses ir.translation search_read by src (source string).
  Future<Map<String, String>> _fetchCustomTerms(
      NetworkService network,
      String langCode,
      ) async {
    // Map of your app key → exact English source string to look up
    // Add any key here whose English value is NOT an Odoo module string
    final customSources = EnBaseTranslations.customOdooSources;
    if (customSources.isEmpty) return {};

    final srcList = customSources.values.toList();

    try {
      final raw = await network.jsonRpc(
        endpoint: '/web/dataset/call_kw',
        params: {
          'model': 'ir.translation',
          'method': 'search_read',
          'args': [
            [
              ['lang', '=', langCode],
              ['src', 'in', srcList],
              ['value', '!=', ''],
              ['value', '!=', false],
            ]
          ],
          'kwargs': {
            'fields': ['src', 'value'],
            'limit': 0,
            'context': {},
          },
        },
      );

      final result = raw['result'];
      if (result is! List) return {};

      // src → translated value
      final srcToValue = <String, String>{};
      for (final rec in result) {
        if (rec is Map) {
          final src = rec['src']?.toString() ?? '';
          final val = rec['value']?.toString() ?? '';
          if (src.isNotEmpty && val.isNotEmpty) srcToValue[src] = val;
        }
      }

      // Now map back to app keys
      final out = <String, String>{};
      for (final entry in customSources.entries) {
        final translated = srcToValue[entry.value];
        if (translated != null && translated.isNotEmpty) {
          out[entry.key] = translated;
          AppLogger.info(
            '[I18N_CUSTOM] HIT  key="${entry.key}"  src="${entry.value}"  =>  "$translated"',
            tag: 'I18N',
          );
        } else {
          AppLogger.info(
            '[I18N_CUSTOM] MISS key="${entry.key}"  src="${entry.value}"',
            tag: 'I18N',
          );
        }
      }
      return out;
    } catch (e) {
      AppLogger.warning('_fetchCustomTerms failed: $e', tag: 'I18N');
      return {};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _registerEnglish() {
    final en = Map<String, String>.from(EnBaseTranslations.all);
    Get.addTranslations({'en_US': en, 'en': en});
  }

  bool _isEnglish(String code) => code.toLowerCase().startsWith('en');

  bool _loadCached(String langCode) {
    final raw = StorageService.to.read<String>('$_cachePrefix$langCode');
    if (raw == null) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final map = decoded.map<String, String>(
            (k, v) => MapEntry(k.toString(), v.toString()),
      );
      _registerAndApply(langCode, map);
      AppLogger.success('Loaded $langCode from cache', tag: 'I18N');
      return true;
    } catch (e) {
      AppLogger.warning('Cache decode failed: $e', tag: 'I18N');
      return false;
    }
  }

  // ── PO Parser ─────────────────────────────────────────────────────────

  Map<String, String> _parsePo(String poContent) {
    final result = <String, String>{};
    final lines = poContent.split('\n');
    String msgid = '', msgstr = '';
    bool inId = false, inStr = false;

    void flush() {
      if (msgid.isNotEmpty && msgstr.isNotEmpty) result[msgid] = msgstr;
      msgid   = '';
      msgstr  = '';
      inId    = false;
      inStr   = false;
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.startsWith('#') || line.trim().isEmpty) {
        if (line.trim().isEmpty && (inId || inStr)) flush();
        continue;
      }
      if (line.startsWith('msgid "')) {
        if (inStr) flush();
        inId  = true;
        inStr = false;
        msgid = _poStr(line.substring(6));
      } else if (line.startsWith('msgstr "')) {
        inStr = true;
        inId  = false;
        msgstr = _poStr(line.substring(7));
      } else if (line.startsWith('"')) {
        if (inId)  msgid  += _poStr(line);
        if (inStr) msgstr += _poStr(line);
      }
    }
    flush();

    AppLogger.info('[I18N_PO] Parsed ${result.length} entries', tag: 'I18N');

    return result;
  }

  String _poStr(String line) {
    final t = line.trim();
    if (t.startsWith('"') && t.endsWith('"') && t.length >= 2) {
      return t
          .substring(1, t.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\t', '\t')
          .replaceAll(r'\\', '\\');
    }
    return '';
  }

  // ── Normalise helper for fuzzy matching ──────────────────────────────
  // Strips leading/trailing punctuation+whitespace and lowercases.
  // 'Time Spent: ' → 'time spent'   so it matches PO msgid 'Time Spent'
  String _normalise(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^[\s:.,!?\-]+|[\s:.,!?\-]+$'), '');

  // ── App map builder ───────────────────────────────────────────────────

  Map<String, String> _buildAppMap(Map<String, String> poMap) {
    // Build normalised PO lookup for fuzzy matching
    final normPo = <String, String>{};
    for (final e in poMap.entries) {
      normPo[_normalise(e.key)] = e.value;
    }

    final appMap    = <String, String>{};
    int hitExact    = 0;
    int hitFuzzy    = 0;
    int miss        = 0;

    print('[I18N_MATCH] ==== MATCH START — ${EnBaseTranslations.all.length} app strings ====');

    for (final e in EnBaseTranslations.all.entries) {
      String? translated = poMap[e.value];
      String  matchType  = 'EXACT';

      if (translated == null || translated.trim().isEmpty) {
        translated = normPo[_normalise(e.value)];
        matchType  = 'FUZZY';
      }

      if (translated != null && translated.trim().isNotEmpty) {
        appMap[e.key] = translated;
        if (matchType == 'EXACT') hitExact++; else hitFuzzy++;
      } else {
        appMap[e.key] = e.value;
        miss++;
      }
    }

    AppLogger.info('[I18N_MATCH] exact=$hitExact  fuzzy=$hitFuzzy  miss=$miss', tag: 'I18N');
    return appMap;
  }

  // ── GetX locale registration ──────────────────────────────────────────

  void _registerAndApply(String langCode, Map<String, String> map) {
    final short = langCode.split('_').first.toLowerCase();
    Get.addTranslations({
      langCode: map,
      short: map,
      '${short}_${langCode.split('_').last}': map,
    });
    // Persist so next app launch restores the same language instantly from cache
    StorageService.to.saveSelectedLanguageCode(langCode);
    _applyLocale(langCode);
  }

  void _applyLocale(String langCode) {
    final parts = langCode.split('_');
    final lang = parts.first.toLowerCase();
    final country = (parts.length > 1 && parts.last.length == 2)
        ? parts.last.toUpperCase()
        : '';
    Get.updateLocale(
      country.isNotEmpty ? Locale(lang, country) : Locale(lang),
    );
    AppLogger.info('Locale set → $langCode', tag: 'I18N');
  }


  /// Force re-downloads PO from Odoo and updates cache.
  /// Shows spinner. Call this when user taps "Update" button.
  Future<void> forceRefreshLanguage(String langCode, String displayName) async {
    AppLogger.info('Force refresh requested for $langCode', tag: 'I18N');
    // Clear timestamp so it's treated as stale after this too
    await StorageService.to.remove('$_cacheTimestampPrefix$langCode');
    await clearCache(langCode);
    await _downloadWithGuards(langCode, silent: false);
  }

  bool _isCacheStale(String langCode) {
    final ts = StorageService.to.read<int>('$_cacheTimestampPrefix$langCode');
    if (ts == null) return true; // no timestamp = treat as stale
    final cached = DateTime.fromMillisecondsSinceEpoch(ts);
    final age = DateTime.now().difference(cached);
    final stale = age > _cacheMaxAge;
    AppLogger.info(
      'Cache age for $langCode: ${age.inMinutes}min — ${stale ? "STALE" : "fresh"}',
      tag: 'I18N',
    );
    return stale;
  }

}