import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_logger.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/odoo_datetime.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../data/models/leave_balance_item.dart';
import '../../../data/repositories/attendance_gps_repository.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../../data/services/location_tracking_service.dart';
import '../../../data/services/permission_service.dart';
import '../../attendance/utils/route_tracking_consent.dart';
import '../../auth/controllers/auth_controller.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final AuthController _auth = Get.find<AuthController>();

  AttendanceRepository? get _attendanceRepo {
    final client = _auth.odooClient;
    if (client == null) return null;
    return AttendanceRepository(client);
  }

  final isLoading = false.obs;

  /// Separate loading flags so each button only spins for its own action —
  /// checking out must not show a spinner on the Check In button.
  final isCheckingIn = false.obs;
  final isCheckingOut = false.obs;

  /// True while a check-in or check-out request is in flight (either one).
  bool get isBusyWithAttendance => isCheckingIn.value || isCheckingOut.value;

  StreamSubscription<ServiceStatus>? _locationServiceSub;
  bool _midShiftStartInFlight = false;

  /// Why the dashboard is empty, when it is.
  ///
  /// Dashboard loading used to swallow every failure into a debug print, so a
  /// server that rejects RPCs — a missing HR module, a permissions problem, a
  /// restricted database — produced a blank screen with no explanation, and
  /// nothing at all in a release build. This surfaces the server's own message
  /// so the cause is visible on the device instead of only in a logcat.
  final loadError = ''.obs;

  final employeeId = Rxn<int>();
  final employeeName = ''.obs;
  final jobTitle = ''.obs;
  final departmentName = ''.obs;
  final avatarBase64 = Rxn<String>();

  final attendanceStatus = 'not_checked'.obs;
  final checkInTime = Rxn<DateTime>();
  final checkOutTime = Rxn<DateTime>();
  final workedHoursToday = 0.0.obs;

  /// Today's finished sessions, kept so the running total can be recomputed
  /// every tick without another server round trip.
  double _closedHoursToday = 0;
  Timer? _todayHoursTicker;

  /// Id of the currently open hr.attendance record (set after check-in). This
  /// is the anchor the GPS route is attached to.
  final openAttendanceId = Rxn<int>();

  final leaveBalances = <LeaveBalanceItem>[].obs;
  final pendingApprovals = 0.obs;
  final pendingTasks = 0.obs;
  final upcomingHolidays = <String>[].obs;

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get displayName {
    if (employeeName.value.isNotEmpty) return employeeName.value;
    final account = _auth.activeAccount.value;
    if (account?.name != null && account!.name!.isNotEmpty) {
      return account.name!;
    }
    return _auth.userName.value.isNotEmpty ? _auth.userName.value : 'Employee';
  }

  /// Prefer account avatar (profile edits) over hr.employee image_128.
  String? get profileAvatarBase64 {
    final accountAvatar =
    OdooImage.sanitize(_auth.activeAccount.value?.image1920);
    if (accountAvatar != null) return accountAvatar;
    return OdooImage.sanitize(avatarBase64.value);
  }

  /// Push saved account name/avatar into home dashboard observables.
  void applyAccountProfileToDisplay() {
    final account = _auth.activeAccount.value;
    if (account == null) return;

    final accountAvatar = OdooImage.sanitize(account.image1920);
    if (accountAvatar != null) {
      avatarBase64.value = accountAvatar;
    }

    if (account.name != null && account.name!.trim().isNotEmpty) {
      employeeName.value = account.name!.trim();
    }
  }

  bool get canCheckIn => attendanceStatus.value != 'checked_in';

  bool get canCheckOut => attendanceStatus.value == 'checked_in';

  /// Whether the background route tracker is currently running.
  RxBool get isRouteTracking => LocationTrackingService.instance.isTracking;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    LocationTrackingService.instance.configure(
          () => _auth.odooClient == null
          ? null
          : AttendanceGpsRepository(_auth.odooClient!),
    );
    _watchLocationServiceStatus();
    _requestStartupPermissions();
    loadDashboard().then((_) => _resumeTrackingIfNeeded());
    _syncTodayHoursTicker();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationServiceSub?.cancel();
    _todayHoursTicker?.cancel();
    super.onClose();
  }

  /// Runs a ticker only while checked in, so today's hours keep counting up
  /// instead of freezing at whatever they were when the screen last loaded —
  /// which is what made the card read behind Odoo's live tooltip.
  void _syncTodayHoursTicker() {
    final shouldRun = attendanceStatus.value == 'checked_in' &&
        checkInTime.value != null;
    if (!shouldRun) {
      if (_todayHoursTicker != null) {
        ApiLogger.info('today hours ticker STOP');
      }
      _todayHoursTicker?.cancel();
      _todayHoursTicker = null;
      return;
    }
    if (_todayHoursTicker != null) return;
    ApiLogger.info(
      'today hours ticker START closed=$_closedHoursToday '
      'checkIn=${checkInTime.value}',
    );
    _todayHoursTicker =
        Timer.periodic(const Duration(seconds: 1), (_) => _tickTodayHours());
    // Correct immediately rather than waiting for the first tick.
    _tickTodayHours();
  }

  void _tickTodayHours() {
    final start = checkInTime.value;
    if (attendanceStatus.value != 'checked_in' || start == null) {
      _syncTodayHoursTicker();
      return;
    }
    final elapsed = DateTime.now().difference(start).inSeconds / 3600.0;
    workedHoursToday.value =
        _closedHoursToday + (elapsed > 0 ? elapsed : 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may grant location permission (or switch the service on) from
    // the OS settings and return to the app — re-check so a mid-shift route can
    // start for the still-open attendance.
    if (state == AppLifecycleState.resumed) {
      _maybeStartTrackingMidShift();
      // Timers are throttled in the background, so the running total can be
      // well behind by the time the user comes back.
      _syncTodayHoursTicker();
      _tickTodayHours();
    }
  }

  /// Ask for the runtime permissions the app needs (notifications + location),
  /// once, right after the first screen is shown.
  void _requestStartupPermissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.requestStartupPermissions();
    });
  }

  /// Detects the device location service being switched on while the app is
  /// open, so tracking can start mid-shift without needing an app restart.
  void _watchLocationServiceStatus() {
    try {
      _locationServiceSub = Geolocator.getServiceStatusStream().listen(
        (status) {
          if (status == ServiceStatus.enabled) {
            _maybeStartTrackingMidShift();
          }
        },
        onError: (Object e) =>
            ApiLogger.error('location service status stream error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      ApiLogger.error('could not watch location service status: $e');
    }
  }

  Future<void> refreshProfile() async {
    await _loadEmployee();
    applyAccountProfileToDisplay();
  }

  /// Pull-to-refresh entry point: re-reads the employee's Mobile Access rights
  /// (employee mode) so feature gating reflects admin changes live, then
  /// reloads the dashboard.
  Future<void> refreshDashboard() async {
    await _auth.refreshEmployeeAccess();
    await loadDashboard();
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    loadError.value = '';
    try {
      await _loadEmployee();
      await Future.wait([
        refreshTodayAttendance(),
        _loadLeaveBalances(),
        _loadPendingCounts(),
        _loadUpcomingHolidays(),
      ]);
    } catch (e) {
      loadError.value = _formatServerError(e);
      ApiLogger.error('Dashboard load error', e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Turns an Odoo/transport failure into something a user can act on.
  ///
  /// The server's own message is kept — when a database is restricted or a
  /// module is missing, Odoo explains exactly why and that text is far more
  /// useful than a generic "something went wrong".
  String _formatServerError(Object e) {
    var message = e.toString();
    for (final prefix in const ['OdooException: ', 'Exception: ']) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length);
      }
    }

    // Odoo wraps the useful text in a JSON-ish blob; pull out `message:` if so.
    final match = RegExp(r'message:\s*([^,}]+)').firstMatch(message);
    if (match != null) {
      final inner = match.group(1)?.trim() ?? '';
      if (inner.isNotEmpty && inner != 'Odoo Server Error') message = inner;
    }

    final lower = message.toLowerCase();
    if (lower.contains('keyerror') || lower.contains('invalid field')) {
      return "This Odoo server doesn't have the HR modules this app needs "
          '($message). Ask your administrator to install them.';
    }
    if (lower.contains('session') && lower.contains('expired')) {
      return 'Session expired. Please sign in again.';
    }
    return message.isEmpty ? 'Could not load your dashboard.' : message;
  }

  Future<void> refreshTodayAttendance() async {
    ApiLogger.info('--- HomeController.refreshTodayAttendance ---');
    final repo = _attendanceRepo;
    final empId = employeeId.value;

    if (repo == null) {
      ApiLogger.error('Attendance repo is NULL (odooClient not connected?)');
      return;
    }
    if (empId == null) {
      ApiLogger.error('employeeId is NULL — employee not loaded from Odoo');
      return;
    }

    ApiLogger.json('Using employeeId', empId);

    try {
      final summary = await repo.fetchTodaySummary(empId);
      attendanceStatus.value = summary.status;
      checkInTime.value = summary.checkIn;
      checkOutTime.value = summary.checkOut;
      _closedHoursToday = summary.closedHours;
      workedHoursToday.value = summary.liveWorkedHours;
      openAttendanceId.value = summary.openRecord?.id;
      _syncTodayHoursTicker();

      ApiLogger.info(
        'UI updated => status=${attendanceStatus.value} '
            'checkIn=${checkInTime.value} checkOut=${checkOutTime.value} '
            'hours=${workedHoursToday.value}',
      );
    } catch (e, st) {
      ApiLogger.error('refreshTodayAttendance failed', e, st);
    }
  }

  Future<void> _loadEmployee() async {
    ApiLogger.info('--- HomeController._loadEmployee ---');
    final client = _auth.odooClient;
    final userId = _auth.activeAccount.value?.userId;

    ApiLogger.json('userId', userId);
    ApiLogger.json('odooUrl', _auth.odooUrl.value);

    if (client == null) {
      ApiLogger.error('odooClient is NULL');
      return;
    }

    // Employee mode: the session runs on the shared app user, so the employee
    // comes from the login response (stored on the account), not from the user.
    final account = _auth.activeAccount.value;
    ApiLogger.info(
      'loadEmployee: loginMode=${account?.loginMode} '
      'employeeId=${account?.employeeId} userId=${account?.userId} '
      'name=${account?.name}',
    );
    if (account != null &&
        account.isEmployeeMode &&
        account.employeeId != null) {
      employeeId.value = account.employeeId;
      employeeName.value = account.name ?? '';
      await _loadEmployeeProfileById(account.employeeId!);
      ApiLogger.info('Employee mode => id=${employeeId.value}');
      return;
    }

    if (userId == null) {
      ApiLogger.error('userId is NULL');
      return;
    }

    try {
      final resolved =
      await EmployeeRepository(client).resolveForUser(userId);

      if (resolved == null) {
        ApiLogger.error('Could not resolve employee for user $userId');
        employeeId.value = null;
        loadError.value =
            'No employee record is linked to this Odoo user, so there is '
            'nothing to show. Ask your HR admin to link one.';
        return;
      }

      employeeId.value = resolved.id;
      employeeName.value = resolved.name;
      jobTitle.value = resolved.jobTitle;
      departmentName.value = resolved.departmentName;
      avatarBase64.value = resolved.avatarBase64;

      ApiLogger.info(
        'Employee set => id=${employeeId.value} name=${employeeName.value}',
      );
    } catch (e, st) {
      ApiLogger.error('_loadEmployee failed', e, st);
      // Rethrow so loadDashboard can surface it — swallowing this here is what
      // left the dashboard blank and silent.
      rethrow;
    }
  }

  /// Loads name/job/department/avatar for a known employee id (employee mode).
  Future<void> _loadEmployeeProfileById(int empId) async {
    final client = _auth.odooClient;
    if (client == null) return;
    try {
      final rows = await client.callKw({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', empId],
          ],
          ['name', 'job_title', 'department_id', 'image_128'],
        ],
        'kwargs': {'limit': 1},
      });
      if (rows is List && rows.isNotEmpty) {
        final e = Map<String, dynamic>.from(rows.first as Map);
        final n = e['name'];
        if (n is String && n.isNotEmpty) employeeName.value = n;
        final jt = e['job_title'];
        jobTitle.value = jt is String ? jt : '';
        final d = e['department_id'];
        departmentName.value =
            (d is List && d.length > 1) ? d[1].toString() : '';
        avatarBase64.value = OdooImage.sanitize(e['image_128']);
      }
    } catch (e) {
      debugPrint('employee profile by id failed: $e');
    }
  }

  Future<void> _loadLeaveBalances() async {
    final client = _auth.odooClient;
    final empId = employeeId.value;
    if (client == null || empId == null) return;

    try {
      final balances = await LeaveRepository(client).fetchBalances(empId);
      leaveBalances.assignAll(balances);
    } catch (e) {
      debugPrint('Leave balance fetch: $e');
    }
  }

  Future<void> _loadPendingCounts() async {
    final client = _auth.odooClient;
    final empId = employeeId.value;
    if (client == null || empId == null) return;

    try {
      final leaveCount = await client.callKw({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [
          [
            ['employee_id', '=', empId],
            ['state', 'in', ['confirm', 'validate1']],
          ],
        ],
        'kwargs': {},
      });
      pendingApprovals.value = leaveCount is int ? leaveCount : 0;
    } catch (e) {
      debugPrint('Pending leave count: $e');
    }

    try {
      // No `state` filter: Odoo 19 made mail.activity.state a non-stored
      // computed field, so searching it raises "Cannot convert
      // mail.activity.state to SQL because it is not stored". Filtering it out
      // costs nothing anyway — Odoo deletes an activity once it is marked done,
      // so every row that still exists is pending.
      final taskCount = await client.callKw({
        'model': 'mail.activity',
        'method': 'search_count',
        'args': [
          [
            ['user_id', '=', _auth.activeAccount.value?.userId],
          ],
        ],
        'kwargs': {},
      });
      pendingTasks.value = taskCount is int ? taskCount : 0;
    } catch (e) {
      ApiLogger.error('Activity count failed', e);
    }
  }

  Future<void> _loadUpcomingHolidays() async {
    final client = _auth.odooClient;
    final empId = employeeId.value;
    if (client == null || empId == null) return;

    try {
      final holidays = await LeaveRepository(client).fetchPublicHolidays(
        employeeId: empId,
        limit: 3,
      );

      upcomingHolidays.assignAll(
        holidays.map((h) {
          final from = h.dateFrom;
          if (from != null) {
            return '${h.title} (${_formatDate(from)})';
          }
          return h.title;
        }),
      );
    } catch (e) {
      debugPrint('Holidays fetch: $e');
    }
  }

  Future<void> checkIn() async {
    await _attendanceAction(checkOut: false);
  }

  Future<void> checkOut() async {
    await _attendanceAction(checkOut: true);
  }

  Future<void> _attendanceAction({required bool checkOut}) async {
    final repo = _attendanceRepo;
    var empId = employeeId.value;

    if (repo == null) {
      AppSnackbar.error('Attendance', 'Not connected to Odoo. Please sign in again.');
      return;
    }

    if (empId == null) {
      await _loadEmployee();
      empId = employeeId.value;
    }

    if (empId == null) {
      AppSnackbar.error(
        'Attendance',
        'Employee record not found for your account.',
      );
      return;
    }

    final progress = checkOut ? isCheckingOut : isCheckingIn;
    progress.value = true;
    try {
      if (checkOut) {
        // Capture a final point, close attendance, then stop tracking.
        final pos = await _capturePositionOrNull();
        await repo.checkOut(
          empId,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
        );
        if (pos != null) {
          // Make sure the true checkout location is the last route point,
          // not whatever the last background sample happened to catch.
          await LocationTrackingService.instance.recordFinalPoint(pos);
        }
        await LocationTrackingService.instance.stop();
        await refreshTodayAttendance();
      } else {
        // Consent is a hard gate: declining it cancels the whole check-in,
        // not just route tracking — checking in without the user's explicit
        // agreement to be located would defeat the point of asking.
        if (!await RouteTrackingConsent.ensureConsent()) {
          AppSnackbar.warning(
            'Attendance',
            'Check-in cancelled — location tracking consent is required.',
          );
          return;
        }

        // Consent is granted; _prepareTracking() now only checks the
        // technical prerequisites (service on, permission granted).
        final trackingReady = await _prepareTracking();
        final pos = trackingReady ? await _capturePositionOrNull() : null;
        await repo.checkIn(
          empId,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
        );
        await refreshTodayAttendance();
        if (trackingReady) {
          // Pass the check-in position through so it becomes the first,
          // check_in-tagged route point.
          await _startTrackingForOpenAttendance(empId, pos);
        } else {
          AppSnackbar.warning(
            'Attendance',
            'Checked in. Route not recorded (location off).',
          );
        }
      }
      AppSnackbar.success(
        'Success',
        checkOut ? 'Checked out successfully' : 'Checked in successfully',
      );
    } catch (e) {
      AppSnackbar.error('Attendance', _formatAttendanceError(e));
    } finally {
      progress.value = false;
    }
  }

  Future<void> _startTrackingForOpenAttendance(
      int employeeId,
      Position? checkInPos,
      ) async {
    var openId = openAttendanceId.value;
    if (openId == null) {
      // The freshly created record may not be visible on the first read after
      // check-in; give the server a moment and try once more.
      ApiLogger.info('checkIn: open attendance id not resolved — retrying');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await refreshTodayAttendance();
      openId = openAttendanceId.value;
    }
    if (openId == null) {
      ApiLogger.error('checkIn: could not resolve open attendance id — no route');
      AppSnackbar.warning(
        'Attendance',
        'Checked in, but could not link a route to the attendance record.',
      );
      return;
    }
    ApiLogger.info('checkIn: starting route tracking for attendance=$openId');
    final started = await LocationTrackingService.instance.start(
      attendanceId: openId,
      employeeId: employeeId,
    );
    if (!started) {
      AppSnackbar.warning(
        'Attendance',
        'Checked in, but route tracking could not start.',
      );
      return;
    }
    // start() clears the buffer, so the check-in point must be recorded AFTER
    // it. Tagged check_in server-side, so it is always the route's first point.
    if (checkInPos != null) {
      await LocationTrackingService.instance.recordInitialPoint(checkInPos);
    }
  }

  /// Checks the technical prerequisites for recording a route (location
  /// service on, permission granted). Consent is gated separately, before
  /// this is called — see the check-in branch of [_attendanceAction].
  Future<bool> _prepareTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      AppSnackbar.warning(
        'Location',
        'Turn on location services to record your route.',
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      AppSnackbar.warning(
        'Location',
        'Location permission denied. Your route will not be recorded.',
      );
      return false;
    }

    // Needed for the persistent foreground-service notification (Android 13+).
    await FlutterForegroundTask.requestNotificationPermission();
    return true;
  }

  Future<Position?> _capturePositionOrNull() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  /// Re-attach the tracker after an app restart while still checked in.
  Future<void> _resumeTrackingIfNeeded() async {
    final empId = employeeId.value;
    final openId = openAttendanceId.value;
    if (empId != null &&
        openId != null &&
        attendanceStatus.value == 'checked_in' &&
        RouteTrackingConsent.isGranted) {
      await LocationTrackingService.instance.resume(
        attendanceId: openId,
        employeeId: empId,
      );
    }
  }

  /// Starts route tracking mid-shift when location becomes available.
  ///
  /// If the user checked in while location was off or denied, no route was
  /// recorded. When they later enable location (via OS settings or the quick
  /// toggle) this begins tracking for the still-open attendance so the rest of
  /// the shift is mapped. The route will only cover from this point onward —
  /// the earlier portion of the shift can't be reconstructed.
  Future<void> _maybeStartTrackingMidShift() async {
    if (_midShiftStartInFlight) return;
    if (isBusyWithAttendance) return;
    if (attendanceStatus.value != 'checked_in') return;
    if (isRouteTracking.value) return; // already tracking
    // Respect the user's choice: never start background tracking without the
    // one-time consent they gave at check-in.
    if (!RouteTrackingConsent.isGranted) return;

    final empId = employeeId.value;
    final openId = openAttendanceId.value;
    if (empId == null || openId == null) return;

    _midShiftStartInFlight = true;
    try {
      if (!await PermissionService.hasUsableLocation()) return;

      ApiLogger.info(
        'tracking: location available mid-shift — starting route for '
        'attendance=$openId',
      );
      final pos = await _capturePositionOrNull();
      final started = await LocationTrackingService.instance.start(
        attendanceId: openId,
        employeeId: empId,
      );
      if (!started) return;
      if (pos != null) {
        await LocationTrackingService.instance.recordInitialPoint(pos);
      }
      AppSnackbar.success(
        'Attendance',
        'Location enabled — route tracking started for the rest of your shift.',
      );
    } catch (e, st) {
      ApiLogger.error('mid-shift tracking start failed', e, st);
    } finally {
      _midShiftStartInFlight = false;
    }
  }

  String _formatAttendanceError(Object e) {
    var message = e.toString();
    if (message.startsWith('OdooException: ')) {
      message = message.substring('OdooException: '.length);
    }
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }

    final lower = message.toLowerCase();
    if (lower.contains('access') && lower.contains('denied')) {
      return 'You do not have permission to update attendance. '
          'Ask your HR admin to enable backend check-in/out.';
    }
    if (lower.contains('no employee')) {
      return message;
    }
    if (lower.contains('already checked in') ||
        lower.contains('cannot check in')) {
      return 'You are already checked in.';
    }
    if (lower.contains('no open attendance') ||
        lower.contains('could not find corresponding check in')) {
      return 'No active check-in found. Please check in first.';
    }
    if (lower.contains('session') && lower.contains('expired')) {
      return 'Session expired. Please sign in again.';
    }
    return message.isEmpty
        ? 'Could not update attendance. Please try again.'
        : message;
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String formatTime(DateTime? dt) => OdooDateTime.formatTime(dt);
}