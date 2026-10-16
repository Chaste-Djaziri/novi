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
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
  );
}

class PencilMenuDialog extends StatefulWidget {
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
  State<PencilMenuDialog> createState() => _PencilMenuDialogState();
}

class _PencilMenuDialogState extends State<PencilMenuDialog> {
  bool _showDrawAndHold = false;

  @override
  Widget build(BuildContext context) => ToolMenuPopup(
    targetRect: widget.targetRect,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: _showDrawAndHold ? _buildDrawAndHoldPage() : _buildMainPage(),
    ),
  );

  Widget _buildMainPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Center(
        child: Text(
          'Standard Pencil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 10),
      const SizedBox(
        height: 150,
        width: double.infinity,
        child: CustomPaint(painter: _PencilPreviewPainter()),
      ),
      const SizedBox(height: 8),
      const Text(
        'Settings',
        style: TextStyle(
          color: Colors.white60,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      _settingRow(
        'Reduce Latency',
        widget.session.pencilReduceLatency,
        (value) => widget.session.pencilReduceLatency = value,
      ),
      _navigationRow(
        'Draw and Hold',
        () => setState(() => _showDrawAndHold = true),
      ),
    ],
  );

  Widget _buildDrawAndHoldPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => setState(() => _showDrawAndHold = false),
            icon: const Icon(CupertinoIcons.chevron_left, color: Colors.white),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Draw and Hold',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
      _settingRow(
        'Draw and Hold',
        widget.session.pencilDrawAndHold,
        (value) => widget.session.pencilDrawAndHold = value,
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(2, 4, 2, 18),
        child: Text(
          'Transform your drawing into perfect shapes when you draw and hold your pencil.',
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.25),
        ),
      ),
      const Text(
        'Advanced Options',
        style: TextStyle(
          color: Colors.white60,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      _settingRow(
        'Snap to Other Shapes',
        widget.session.shapeSnapToOtherShapes,
        (value) => widget.session.shapeSnapToOtherShapes = value,
      ),
    ],
  );

  Widget _settingRow(String label, bool value, ValueChanged<bool> onChanged) =>
      Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xff2c2c2e),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            title: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            value: value,
            onChanged: (next) {
              onChanged(next);
              widget.onUpdate();
              setState(() {});
            },
            activeThumbColor: const Color(0xff34c759),
          ),
        ),
      );

  Widget _navigationRow(String label, VoidCallback onTap) => Container(
    margin: const EdgeInsets.only(top: 1),
    decoration: BoxDecoration(
      color: const Color(0xff2c2c2e),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: Colors.white38,
          size: 18,
        ),
        onTap: onTap,
      ),
    ),
  );
}

class _PencilPreviewPainter extends CustomPainter {
  const _PencilPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.58)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.96,
        size.width * 0.35,
        size.height * 0.16,
        size.width * 0.72,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.4,
        size.width * 0.9,
        size.height * 0.54,
        size.width * 0.94,
        size.height * 0.64,
      );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 7) {
        final point = metric.getTangentForOffset(distance)?.position;
        if (point != null) {
          canvas.drawCircle(
            point,
            1.2,
            Paint()..color = Colors.white.withValues(alpha: 0.22),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PencilPreviewPainter oldDelegate) => false;
}
