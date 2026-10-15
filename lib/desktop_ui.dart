import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart' as mac;

/// Desktop control layer. macos_ui paints macOS-style controls in Flutter;
/// native window chrome and file panels remain provided by the operating system.
class DesktopTheme extends StatelessWidget {
  const DesktopTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => mac.MacosTheme(
    data: mac.MacosThemeData(
      brightness: Brightness.dark,
      accentColor: mac.AccentColor.graphite,
      primaryColor: const Color(0xffc4c4c4),
      canvasColor: const Color(0xff1e1e1e),
      dividerColor: const Color(0xff353535),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: '.AppleSystemUIFont', fontSize: 13),
      child: child,
    ),
  );
}

class DesktopIconButton extends StatelessWidget {
  const DesktopIconButton({
    super.key,
    this.tooltip,
    required this.icon,
    this.onPressed,
    this.isSelected = false,
  });
  final String? tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isSelected;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: mac.MacosIconButton(
      semanticLabel: tooltip,
      onPressed: onPressed,
      icon: IconTheme.merge(
        data: IconThemeData(
          size: 18,
          color: onPressed == null
              ? const Color(0xff666666)
              : const Color(0xffdddddd),
        ),
        child: icon,
      ),
      backgroundColor: isSelected
          ? const Color(0xff505050)
          : Colors.transparent,
      hoverColor: const Color(0xff404040),
      borderRadius: BorderRadius.circular(5),
      boxConstraints: const BoxConstraints.tightFor(width: 30, height: 28),
      padding: const EdgeInsets.all(5),
    ),
  );
}

class DesktopButton extends StatelessWidget {
  const DesktopButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.primary = false,
  });
  const DesktopButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
    this.primary = false,
  }) : child = label;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool primary;
  @override
  Widget build(BuildContext context) => mac.PushButton(
    controlSize: mac.ControlSize.regular,
    onPressed: onPressed,
    secondary: !primary,
    color: primary ? const Color(0xffbdbdbd) : null,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: 12,
        color: primary ? Colors.black : const Color(0xffeeeeee),
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          size: 15,
          color: primary ? Colors.black : const Color(0xffdddddd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            child,
          ],
        ),
      ),
    ),
  );
}

class DesktopToolButton extends StatelessWidget {
  const DesktopToolButton({
    super.key,
    required this.label,
    this.avatar,
    required this.selected,
    required this.onSelected,
  });
  final Widget label;
  final Widget? avatar;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: mac.MacosIconButton(
      onPressed: () => onSelected(!selected),
      backgroundColor: selected ? const Color(0xff4c4c4c) : Colors.transparent,
      hoverColor: const Color(0xff363636),
      borderRadius: BorderRadius.circular(5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      boxConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 12, color: Color(0xffeeeeee)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[avatar!, const SizedBox(width: 6)],
            label,
          ],
        ),
      ),
    ),
  );
}

class DesktopMenuItem<T> extends StatelessWidget {
  const DesktopMenuItem({
    super.key,
    required this.value,
    required this.child,
    this.enabled = true,
  });
  final T value;
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => child;
}

class DesktopPopupButton<T> extends StatelessWidget {
  const DesktopPopupButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final List<DesktopMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  @override
  Widget build(BuildContext context) => mac.MacosPopupButton<T>(
    value: value,
    style: const TextStyle(fontSize: 12, color: Color(0xffeeeeee)),
    onChanged: onChanged,
    items: items
        .map(
          (item) =>
              mac.MacosPopupMenuItem<T>(value: item.value, child: item.child),
        )
        .toList(),
  );
}

class DesktopPopupMenuButton<T> extends StatelessWidget {
  const DesktopPopupMenuButton({
    super.key,
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
  });
  final String tooltip;
  final ValueChanged<T> onSelected;
  final List<DesktopMenuItem<T>> Function(BuildContext) itemBuilder;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: mac.MacosPulldownButton(
      icon: Icons.more_horiz,
      items: itemBuilder(context)
          .map(
            (item) => mac.MacosPulldownMenuItem(
              title: item.child,
              enabled: item.enabled,
              onTap: () => onSelected(item.value),
            ),
          )
          .toList(),
    ),
  );
}

class DesktopSlider extends StatelessWidget {
  const DesktopSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => mac.MacosSlider(
    value: value,
    min: min,
    max: max,
    onChanged: onChanged,
    color: const Color(0xffbcbcbc),
    backgroundColor: const Color(0xff4a4a4a),
  );
}

class DesktopTextField extends StatelessWidget {
  const DesktopTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.maxLines = 1,
    this.expands = false,
    this.style,
    this.cursorColor,
    this.textAlignVertical,
    this.onChanged,
    this.placeholder,
    this.prefix,
    this.borderless = false,
  });
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final int? maxLines;
  final bool expands;
  final TextStyle? style;
  final Color? cursorColor;
  final TextAlignVertical? textAlignVertical;
  final ValueChanged<String>? onChanged;
  final String? placeholder;
  final Widget? prefix;
  final bool borderless;
  @override
  Widget build(BuildContext context) => mac.MacosTextField(
    controller: controller,
    focusNode: focusNode,
    maxLines: maxLines,
    expands: expands,
    style: style ?? const TextStyle(fontSize: 13, color: Color(0xffeeeeee)),
    cursorColor: cursorColor ?? Colors.white,
    textAlignVertical: textAlignVertical,
    onChanged: onChanged,
    placeholder: placeholder,
    placeholderStyle: TextStyle(
      color: (style?.color ?? Colors.white).withValues(alpha: 0.4),
      fontSize: style?.fontSize ?? 13,
    ),
    prefix: prefix,
    padding: borderless
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: borderless
        ? null
        : BoxDecoration(
            color: const Color(0xff282828),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xff505050)),
          ),
    focusedDecoration: borderless
        ? null
        : BoxDecoration(
            color: const Color(0xff282828),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xffaaaaaa), width: 2),
          ),
  );
}

class DesktopDialog extends StatelessWidget {
  const DesktopDialog({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Material(
        color: const Color(0xff242424),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        elevation: 20,
        child: child,
      ),
    ),
  );
}

class DesktopListTile extends StatefulWidget {
  const DesktopListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
  });
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  @override
  State<DesktopListTile> createState() => _DesktopListTileState();
}

class _DesktopListTileState extends State<DesktopListTile> {
  bool hover = false;
  bool focus = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.onTap != null,
    onShowFocusHighlight: (v) => setState(() => focus = v),
    onShowHoverHighlight: (v) => setState(() => hover = v),
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap?.call();
          return null;
        },
      ),
    },
    child: Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xff383838)
                : hover || focus
                ? const Color(0xff303030)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xffdddddd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [widget.title, ?widget.subtitle],
                  ),
                ),
              ),
              ?widget.trailing,
            ],
          ),
        ),
      ),
    ),
  );
}
