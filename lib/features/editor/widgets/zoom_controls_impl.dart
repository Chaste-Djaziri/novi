part of '../../../../workspace_tools.dart';

extension FloatingToolControlsZoomcontrols on FloatingToolControlsState {
  Widget _buildZoomControls(EditorSession session) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesktopIconButton(
          tooltip: 'Zoom out',
          onPressed: () => widget.onZoom(0.8),
          icon: const Icon(CupertinoIcons.minus, size: 16),
        ),
        Tooltip(
          message: 'Current zoom',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${(session.view.value.getMaxScaleOnAxis() * 100).round()}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        DesktopIconButton(
          tooltip: 'Zoom in',
          onPressed: () => widget.onZoom(1.25),
          icon: const Icon(CupertinoIcons.plus, size: 16),
        ),
        DesktopIconButton(
          tooltip: 'Reset view',
          onPressed: () => widget.onZoom(0),
          icon: const Icon(Icons.aspect_ratio, size: 16),
        ),
      ],
    );
  }
}
