import 'package:flutter/material.dart';

/// Shared shell for editor tool menus. Tool modules provide only their content.
class ToolMenuPopup extends StatelessWidget {
  const ToolMenuPopup({
    super.key,
    required this.targetRect,
    required this.child,
    this.width = 300,
  });

  final Rect targetRect;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = (targetRect.center.dx - width / 2).clamp(
      12.0,
      screen.width - width - 12.0,
    );
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
          top: targetRect.bottom + 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: width / 2 - 9),
                child: CustomPaint(
                  size: const Size(18, 9),
                  painter: _ToolMenuArrowPainter(
                    color: const Color(0xff1c1c1e),
                    borderColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Container(
                width: width,
                decoration: BoxDecoration(
                  color: const Color(0xff1c1c1e),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 28,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: child,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolMenuArrowPainter extends CustomPainter {
  const _ToolMenuArrowPainter({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _ToolMenuArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
