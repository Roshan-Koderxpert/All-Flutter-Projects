import 'package:flutter/material.dart' show Color;

/// Asset paths — images under `assets/images/`, icons under `assets/Icons/`.
class AppImage {
  AppImage._();

  static const String logo = 'assets/images/Group 18.png';
  static const String loginBg = 'assets/images/login_bg.png';

  static const String url = 'assets/images/url.png';
  static const String arrowDown = 'assets/images/arrow_down.png';
  static const String database = 'assets/images/database.png';
  static const String username = 'assets/images/username.png';
  static const String password = 'assets/images/password.png';
}

class AppAnimation {
  AppAnimation._();

  static const String splash = 'assets/animations/animation2.mp4';

  /// Matches the splash video's own backdrop, so the frame before the first
  /// decoded frame lands is seamless rather than a flash of another colour.
  static const Color splashBackground = Color(0xFFFFFFFF);
}

class AppIcon {
  AppIcon._();

  static const String add = 'assets/Icons/add.png';
  static const String addAccount = 'assets/Icons/add-account.png';
  static const String approval = 'assets/Icons/approval.png';
  static const String attendance = 'assets/Icons/attendance.png';
  static const String back = 'assets/Icons/back.png';
  static const String calendar = 'assets/Icons/calendar.png';
  static const String home = 'assets/Icons/home.png';
  static const String kanban = 'assets/Icons/kanban.png';
  static const String leaves = 'assets/Icons/Leaves.png';
  static const String list = 'assets/Icons/list.png';
  static const String delete = 'assets/Icons/delete.png';
  static const String remove = 'assets/Icons/remove.png';
  static const String graph = 'assets/Icons/graph.png';
  static const String grid = 'assets/Icons/grid.png';
  static const String help = 'assets/Icons/help.png';
  static const String logout = 'assets/Icons/logout.png';
  static const String message = 'assets/Icons/message.png';
  static const String setting = 'assets/Icons/setting.png';
  static const String timer = 'assets/Icons/timer.png';
  static const String timesheet = 'assets/Icons/timesheet.png';

  static const String facebook = 'assets/Icons/facebook (1).png';
  static const String twitter = 'assets/Icons/twitter (1).png';
  static const String instagram = 'assets/Icons/instagram (1).png';
  static const String linkedin = 'assets/Icons/linkedin (1).png';
  static const String youtube = 'assets/Icons/youtube.png';


  //login screen
  static const String url = 'assets/Icons/url.png';
  static const String database = 'assets/Icons/db.png';
  static const String user = 'assets/Icons/user.png';
  static const String password = 'assets/Icons/pwd.png';

  //home screen
  static const String notification = 'assets/Icons/notification.png';
  static const String checkIn = 'assets/Icons/login 2.png';
  static const String checkOut = 'assets/Icons/logout 2.png';
  static const String viewHistory = 'assets/Icons/login.png';
}
