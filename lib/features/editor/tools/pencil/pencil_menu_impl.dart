part of '../../../../workspace_tools.dart';

Future<void> showPencilMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Pencil Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        PencilMenuDialog(
          targetRect: targetRect,
          session: session,
          onUpdate: onUpdate,
        ),
  );
}

class PencilMenuDialog extends StatelessWidget {
  const PencilMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = (targetRect.center.dx - 150).clamp(12.0, screen.width - 312.0);
    final top = targetRect.bottom + 6;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: Navigator.of(context).pop,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: const Color(0xff1c1c1e),
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Standard Pencil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _toggle(
                      context,
                      'Reduce Latency',
                      session.pencilReduceLatency,
                      (v) => session.pencilReduceLatency = v,
                    ),
                    _toggle(
                      context,
                      'Draw and Hold',
                      session.pencilDrawAndHold,
                      (v) => session.pencilDrawAndHold = v,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggle(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      value: value,
      onChanged: (next) {
        onChanged(next);
        onUpdate();
      },
      activeThumbColor: const Color(0xff34c759),
    );
  }
}
