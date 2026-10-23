import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

import '../utils/logger.dart';

/// Observes OS-level network interfaces (Wi‑Fi / mobile / ethernet).
///
/// ## Offline-first patterns for new FSM features
/// - **UI**: Use [isOnline] to disable remote-only actions or show hints; keep
///   navigation and local screens usable when false.
/// - **Reads**: Prefer local persistence first (GetStorage / Hive / SQLite), then
///   refresh from Odoo when [isOnline] is true.
/// - **Writes**: Save locally immediately; queue mutations and push when back online
///   (outbox / sync service — add when you build task sync).
/// - **Auth / DB list**: Require connectivity — fail fast with a clear message
///   (see [AuthRepository]).
///
/// **Note:** [isOnline] means “has a network route”, not “Odoo server reachable”.
/// Treat timeouts and HTTP errors separately from offline.
class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final RxBool isOnline = true.obs;

  bool get hasConnection => isOnline.value;

  /// True when at least one interface is not [ConnectivityResult.none].
  static bool _resultsIndicateOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _apply(results);
    } catch (e) {
      AppLogger.warning('Initial connectivity check failed: $e', tag: 'CONNECT');
      isOnline.value = true;
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object e) {
        AppLogger.warning('Connectivity stream error: $e', tag: 'CONNECT');
      },
    );
  }

  void _apply(List<ConnectivityResult> results) {
    final online = _resultsIndicateOnline(results);
    if (isOnline.value != online) {
      isOnline.value = online;
      AppLogger.info(
        online ? 'Device online' : 'Device offline',
        tag: 'CONNECT',
      );
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
