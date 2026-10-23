import 'package:flutter/widgets.dart';

/// Layout breakpoints for the app.
///
/// The phone layout is the reference design and is not touched: every helper
/// here short-circuits below [tablet], so Android phones and iPhones render
/// exactly as before. Only iPad / large-tablet widths take a different path.
class AppBreakpoints {
  AppBreakpoints._();

  /// Width at or above which a screen is treated as a tablet.
  ///
  /// 600dp is the conventional tablet cut-off — every iPhone (including the
  /// Pro Max at 440pt) and every phone-sized Android device stays below it,
  /// while the smallest iPad (mini, 744pt) sits above it.
  static const double tablet = 600;

  /// Width above which a tablet gets the roomier gutter (13" iPad, landscape).
  static const double largeTablet = 1000;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  /// Side margin added to page content on tablets.
  ///
  /// Content still spans the full screen — this only keeps cards off the very
  /// edge of a large display, the way the phone's 16pt padding does. Returns 0
  /// on phones, so their padding is untouched.
  static double gutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < tablet) return 0;
    return width < largeTablet ? 24 : 48;
  }

  /// Column count for the phone's 3-up tile grids.
  ///
  /// Holding 3 columns on an iPad turns each tile into a wide, flat slab. The
  /// divisor keeps every tile at roughly the phone's ~140pt width, so the grid
  /// fills the screen while each tile keeps its designed proportions.
  static int tileColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < tablet) return 3;
    return (width / 165).floor().clamp(4, 7);
  }

  /// Height of a quick-action tile — a little taller on tablets so the wider
  /// tiles don't read as flat.
  static double tileHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tablet ? 100 : 118;

  /// Cap for modal sheets. Sheets are transient overlays, so unlike page
  /// content they stay at a readable width rather than spanning a 13" iPad.
  static const double sheetMaxWidth = 640;
}

/// Adds tablet side margins to page content.
///
/// On phones this returns [child] untouched — same widget tree, same layout,
/// no extra render objects — so the Android and iPhone UI is unchanged. On
/// tablets the content still fills the width of the screen; it just gains the
/// side margin from [AppBreakpoints.gutter] so cards don't run into the bezel.
///
/// Wrap the *content*, not the background: a full-bleed coloured header should
/// stay full width and use this around its inner column instead.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Optional hard width cap, for content that genuinely reads badly when wide
  /// (single-column forms). Page content normally leaves this null so it fills.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = AppBreakpoints.gutter(context);
    if (gutter == 0 && maxWidth == null) return child;

    Widget content = child;
    if (maxWidth != null) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: content,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: content,
    );
  }
}
