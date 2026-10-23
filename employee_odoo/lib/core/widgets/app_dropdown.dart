import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared open-menu styling for app dropdowns and popup menus.
abstract final class AppDropdownStyle {
  static const double menuMaxHeight = 280;
  static const int elevation = 8;
  static const Color backgroundColor = AppColors.white;
  static const double itemHeight = 52;
  static const double itemRadius = 8;
  static const EdgeInsets menuPadding = EdgeInsets.zero;

  static BorderRadius get borderRadius => BorderRadius.circular(12);

  static BorderRadius get itemBorderRadius =>
      BorderRadius.circular(itemRadius);

  static ShapeBorder get menuShape =>
      RoundedRectangleBorder(borderRadius: borderRadius);

  static ButtonStyle get menuItemButtonStyle => ButtonStyle(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, itemHeight),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  /// Single dropdown row — use [items] for lists (adds dividers automatically).
  static DropdownMenuItem<T> item<T>({
    required T value,
    required Widget child,
    bool showDivider = false,
  }) {
    return DropdownMenuItem<T>(
      value: value,
      child: child,
    );
  }

  /// Builds menu rows with a divider between each entry.
  static List<DropdownMenuItem<T>> items<T>({
    required List<T> values,
    required Widget Function(T value) labelBuilder,
  }) {
    return List.generate(values.length, (index) {
      return item<T>(
        value: values[index],
        child: labelBuilder(values[index]),
      );
    });
  }

  /// Wraps raw [DropdownMenuItem]s with branded shells and dividers.
  static List<DropdownMenuItem<T>> prepareMenuItems<T>(
    List<DropdownMenuItem<T>> source,
  ) {
    return source;
  }

  static Widget labelChild(Widget child) {
    if (child is _DropdownItemShell) {
      return child.child;
    }
    return child;
  }

  /// Popup menu row with optional divider below.
  static PopupMenuEntry<T> popupItem<T>({
    required T value,
    required Widget child,
    bool showDivider = false,
    VoidCallback? onTap,
  }) {
    return _AppDropdownMenuEntry<T>(
      value: value,
      showDivider: showDivider,
      onTap: onTap,
      child: child,
    );
  }

  static List<PopupMenuEntry<T>> popupItems<T>({
    required List<T> values,
    required Widget Function(T value) labelBuilder,
    void Function(T value)? onTap,
  }) {
    return List.generate(values.length, (index) {
      final value = values[index];
      return popupItem<T>(
        value: value,
        showDivider: index < values.length - 1,
        onTap: onTap != null ? () => onTap(value) : null,
        child: labelBuilder(value),
      );
    });
  }

  static RelativeRect menuPosition(BuildContext context, RenderBox anchor) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    return RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );
  }

  /// Positions the menu centered horizontally under [anchor], matching its width.
  static RelativeRect centeredMenuPosition(
    BuildContext context,
    RenderBox anchor, {
    required double menuWidth,
  }) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final overlaySize = overlay.size;
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final anchorWidth = anchor.size.width;
    final anchorHeight = anchor.size.height;

    final left = topLeft.dx + (anchorWidth - menuWidth) / 2;
    final top = topLeft.dy;
    final right = overlaySize.width - left - menuWidth;
    final bottom = overlaySize.height - top - anchorHeight;

    return RelativeRect.fromLTRB(
      left.clamp(0.0, overlaySize.width),
      top,
      right.clamp(0.0, overlaySize.width),
      bottom,
    );
  }

  static Future<T?> showBrandedMenu<T>({
    required BuildContext context,
    required RenderBox anchor,
    required List<PopupMenuEntry<T>> entries,
    double? menuWidth,
  }) {
    final resolvedWidth = menuWidth ?? anchor.size.width;

    return showMenu<T>(
      context: context,
      positionBuilder: (menuContext, constraints) {
        return centeredMenuPosition(
          context,
          anchor,
          menuWidth: resolvedWidth,
        );
      },
      color: backgroundColor,
      elevation: elevation.toDouble(),
      shape: menuShape,
      constraints: BoxConstraints(
        minWidth: resolvedWidth,
        maxWidth: resolvedWidth,
        maxHeight: menuMaxHeight,
      ),
      items: entries,
    );
  }

  static List<PopupMenuEntry<T>> menuEntriesFromItems<T>(
    List<DropdownMenuItem<T>> items, {
    bool addDividers = true,
  }) {
    return List.generate(items.length, (index) {
      final entry = items[index];
      return _AppDropdownMenuEntry<T>(
        value: entry.value as T,
        enabled: entry.enabled,
        showDivider: addDividers && index < items.length - 1,
        child: labelChild(entry.child),
      );
    });
  }
}

/// Menu row without framework [InkWell] — only rounded local press feedback.
class _AppDropdownMenuEntry<T> extends PopupMenuEntry<T> {
  const _AppDropdownMenuEntry({
    required this.value,
    required this.child,
    this.enabled = true,
    this.showDivider = false,
    this.onTap,
  });

  final T value;
  final Widget child;
  final bool enabled;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  double get height => AppDropdownStyle.itemHeight;

  @override
  bool represents(T? selected) => selected == value;

  @override
  State<_AppDropdownMenuEntry<T>> createState() =>
      _AppDropdownMenuEntryState<T>();
}

class _AppDropdownMenuEntryState<T> extends State<_AppDropdownMenuEntry<T>> {
  @override
  Widget build(BuildContext context) {
    return _DropdownItemShell(
      showDivider: widget.showDivider,
      enabled: widget.enabled,
      onTap: widget.enabled
          ? () {
              Navigator.pop<T>(context, widget.value);
              widget.onTap?.call();
            }
          : null,
      child: widget.child,
    );
  }
}

/// Rounded inset row with divider support for dropdown / popup menus.
class _DropdownItemShell extends StatefulWidget {
  const _DropdownItemShell({
    required this.child,
    this.showDivider = false,
    this.enabled = true,
    this.onTap,
  });

  final Widget child;
  final bool showDivider;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_DropdownItemShell> createState() => _DropdownItemShellState();
}

class _DropdownItemShellState extends State<_DropdownItemShell> {
  bool _pressed = false;

  Color get _tileColor {
    if (!widget.enabled) {
      return AppColors.inputFill.withValues(alpha: 0.35);
    }
    if (_pressed) {
      return AppColors.brandBlue.withValues(alpha: 0.14);
    }
    return AppColors.inputFill.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDropdownStyle.itemHeight,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Listener(
                onPointerDown: widget.enabled
                    ? (_) => setState(() => _pressed = true)
                    : null,
                onPointerUp: widget.enabled
                    ? (_) => setState(() => _pressed = false)
                    : null,
                onPointerCancel: widget.enabled
                    ? (_) => setState(() => _pressed = false)
                    : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppDropdownStyle.itemBorderRadius,
                      color: _tileColor,
                    ),
                    alignment: Alignment.centerLeft,
                    child: DefaultTextStyle.merge(
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: widget.enabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withValues(alpha: 0.85),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Branded dropdown field — opens a [showMenu] panel without row [InkWell] splashes.
class AppDropdownButton<T> extends StatefulWidget {
  const AppDropdownButton({
    super.key,
    required this.items,
    this.value,
    this.hint,
    this.onChanged,
    this.isExpanded = false,
    this.isDense = false,
    this.icon,
    this.underline,
    this.selectedItemBuilder,
    this.style,
    this.autoDecorateItems = true,
  });

  final T? value;
  final Widget? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;
  final bool isDense;
  final Widget? icon;
  final Widget? underline;
  final DropdownButtonBuilder? selectedItemBuilder;
  final TextStyle? style;
  final bool autoDecorateItems;

  @override
  State<AppDropdownButton<T>> createState() => _AppDropdownButtonState<T>();
}

class _AppDropdownButtonState<T> extends State<AppDropdownButton<T>> {
  final GlobalKey _anchorKey = GlobalKey();

  bool get _enabled => widget.onChanged != null;

  Future<void> _openMenu() async {
    if (!_enabled || widget.items.isEmpty) return;

    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) return;
    final anchor = anchorContext.findRenderObject()! as RenderBox;

    final selected = await AppDropdownStyle.showBrandedMenu<T>(
      context: context,
      anchor: anchor,
      menuWidth: anchor.size.width,
      entries: AppDropdownStyle.menuEntriesFromItems(
        widget.items,
        addDividers: widget.autoDecorateItems,
      ),
    );

    if (selected != null) {
      widget.onChanged?.call(selected);
    }
  }

  Widget _selectedLabel(BuildContext context) {
    if (widget.selectedItemBuilder != null) {
      final index =
          widget.items.indexWhere((item) => item.value == widget.value);
      if (index >= 0) {
        return widget.selectedItemBuilder!(context).elementAt(index);
      }
    }

    if (widget.value == null) {
      return widget.hint ?? const SizedBox.shrink();
    }

    for (final item in widget.items) {
      if (item.value == widget.value) {
        return AppDropdownStyle.labelChild(item.child);
      }
    }

    return widget.hint ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = (widget.style ?? AppTextStyles.bodyMedium).copyWith(
      color: _enabled
          ? AppColors.textPrimary
          : AppColors.textSecondary.withValues(alpha: 0.7),
    );

    final field = KeyedSubtree(
      key: _anchorKey,
      child: SizedBox(
        width: widget.isExpanded ? double.infinity : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? _openMenu : null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: widget.isDense ? 0 : 2),
            child: Row(
              mainAxisSize:
                  widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (widget.isExpanded)
                  Expanded(
                    child: DefaultTextStyle(
                      style: textStyle,
                      overflow: TextOverflow.ellipsis,
                      child: _selectedLabel(context),
                    ),
                  )
                else
                  DefaultTextStyle(
                    style: textStyle,
                    overflow: TextOverflow.ellipsis,
                    child: _selectedLabel(context),
                  ),
                widget.icon ??
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _enabled
                          ? AppColors.textSecondary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                      size: widget.isDense ? 20 : 24,
                    ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.underline == null) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        widget.underline!,
      ],
    );
  }
}

/// Branded dropdown form field with rounded, scrollable menu panel.
class AppDropdownFormField<T> extends FormField<T> {
  AppDropdownFormField({
    super.key,
    required List<DropdownMenuItem<T>> items,
    T? initialValue,
    Widget? hint,
    ValueChanged<T?>? onChanged,
    InputDecoration? decoration,
    bool isExpanded = true,
    Widget? icon,
    TextStyle? style,
    bool autoDecorateItems = true,
    super.onSaved,
    super.validator,
    super.enabled = true,
    AutovalidateMode super.autovalidateMode = AutovalidateMode.disabled,
  }) : super(
          initialValue: initialValue,
          builder: (state) {
            final field = AppDropdownButton<T>(
              value: state.value,
              hint: hint,
              items: items,
              isExpanded: isExpanded,
              icon: icon,
              style: style,
              autoDecorateItems: autoDecorateItems,
              onChanged: enabled
                  ? (value) {
                      state.didChange(value);
                      onChanged?.call(value);
                    }
                  : null,
            );

            if (decoration == null) {
              return field;
            }

            return InputDecorator(
              decoration: decoration.applyDefaults(
                Theme.of(state.context).inputDecorationTheme,
              ).copyWith(
                errorText: state.errorText,
                enabled: enabled,
                hintText: null,
              ),
              isEmpty: false,
              child: field,
            );
          },
        );
}

/// Branded [PopupMenuButton] with rounded panel and max height for long lists.
class AppPopupMenuButton<T> extends StatelessWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.child,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.offset,
    this.enabled = true,
    this.menuMaxHeight = AppDropdownStyle.menuMaxHeight,
    this.menuMinWidth,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final Widget child;
  final PopupMenuItemSelected<T>? onSelected;
  final VoidCallback? onCanceled;
  final String? tooltip;
  final Offset? offset;
  final bool enabled;
  final double menuMaxHeight;
  final double? menuMinWidth;

  Future<void> _openMenu(BuildContext context) async {
    if (!enabled) return;

    final anchor = context.findRenderObject()! as RenderBox;
    final menuWidth = menuMinWidth != null
        ? math.max(anchor.size.width, menuMinWidth!)
        : anchor.size.width;
    final base = AppDropdownStyle.centeredMenuPosition(
      context,
      anchor,
      menuWidth: menuWidth,
    );
    final position = RelativeRect.fromLTRB(
      base.left + (offset?.dx ?? 0),
      base.top + (offset?.dy ?? 0),
      base.right - (offset?.dx ?? 0),
      base.bottom - (offset?.dy ?? 0),
    );

    final selected = await showMenu<T>(
      context: context,
      position: position,
      color: AppDropdownStyle.backgroundColor,
      elevation: AppDropdownStyle.elevation.toDouble(),
      shape: AppDropdownStyle.menuShape,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
        maxHeight: menuMaxHeight,
      ),
      items: itemBuilder(context),
    );

    if (selected == null) {
      onCanceled?.call();
    } else {
      onSelected?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: enabled ? () => _openMenu(context) : null,
      child: child,
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      child: button,
    );
  }
}
