class AppImage {
  AppImage._();

  // ── Images ────────────────────────────────────
  static const String loginBg = 'assets/images/login_bg1.png';
  static const String logo = 'assets/images/Frame 16.png';

  // ── Auth / form icons ─────────────────────────
  static const String url = 'assets/icons/driver.png';
  static const String database = 'assets/icons/Vector.png';
  static const String arrow_down = 'assets/icons/arrow-down.png';
  static const String username = 'assets/icons/user.png';
  static const String password = 'assets/icons/lock.png';
  static const String chat = 'assets/icons/messages-2.png';
  static const String clock = 'assets/icons/clock.png';
  static const String kanban = 'assets/icons/kanban.png';
  static const String search = 'assets/icons/search-normal.png';
  static const String setting = 'assets/icons/setting-2.png';
  static const String add = 'assets/icons/add.png';
  static const String more = 'assets/icons/more.png';
  static const String back = 'assets/icons/arrow-left.png';
  static const String play = 'assets/icons/play.png';
  static const String listview = 'assets/icons/row-vertical.png';
  static const String mapview = 'assets/icons/map.png';
  static const String calendarview = 'assets/icons/calendar-2.png';
  static const String smartbutton = 'assets/icons/flash.png';
  static const String navMap = 'assets/icons/location.png';
  static const String companies = 'assets/icons/building-3.png';
  static const String doc = 'assets/icons/document-text.png';
  static const String support = 'assets/icons/24-support.png';
  static const String darklightmode = 'assets/icons/sun.png';
  static const String myprofile = 'assets/icons/user 2.png';
  static const String myodooaccount = 'assets/icons/user-add.png';
  static const String logout = 'assets/icons/logout.png';
  static const String editstage = 'assets/icons/edit 2.png';
  static const String foldstage = 'assets/icons/trifold.png';
  static const String deletestage = 'assets/icons/trash.png';
  static const String pause = 'assets/icons/pause.png';
  static const String stop = 'assets/icons/stop.png';

  /// Bottom navigation & grouped feature icons.
  static const AppImageNav icons = AppImageNav._();
}

/// Paths for bottom nav — use [AppImage.icons.order], etc.
class AppImageNav {
  const AppImageNav._();

  String get order => 'assets/icons/Layer 2.png';
  String get masterData => 'assets/icons/Vector (1).png';
  String get myProfile => 'assets/icons/fi_5393061.png';
}