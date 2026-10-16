part of '../../../../workspace_tools.dart';

enum PenFeature { settings, writingAids, mathAssist }

Future<void> showPenFeatureMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required PenFeature feature,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Pen Feature Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        PenFeatureMenuDialog(
          targetRect: targetRect,
          session: session,
          feature: feature,
          onUpdate: onUpdate,
        ),
  );
}

class PenFeatureMenuDialog extends StatelessWidget {
  const PenFeatureMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.feature,
    required this.onUpdate,
  });
  final Rect targetRect;
  final EditorSession session;
  final PenFeature feature;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final title = switch (feature) {
      PenFeature.settings => 'Pen Settings',
      PenFeature.writingAids => 'Writing Aids',
      PenFeature.mathAssist => 'Math Assist',
    };
    return ToolMenuPopup(
      targetRect: targetRect,
      width: feature == PenFeature.mathAssist ? 360 : 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(
                    CupertinoIcons.chevron_left,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      style: const TextStyle(
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
            if (feature == PenFeature.settings) ...[
              _toggle(
                'Reduce Latency',
                session.penReduceLatency,
                (v) => session.penReduceLatency = v,
              ),
              _toggle(
                'Draw and Hold',
                session.penHoldForLine,
                (v) => session.penHoldForLine = v,
              ),
              _toggle('Pen Gestures', true, (_) {}),
            ] else if (feature == PenFeature.writingAids) ...[
              _toggle(
                'Check Spelling',
                session.penSpelling,
                (v) => session.penSpelling = v,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 2, top: 4),
                child: Text(
                  'Enable spellcheck in this notebook',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recognition Language   Auto Detect',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ] else ...[
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xfff8f5ec),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '(6x − 5 + 3)(2x + 1) = 12x² + 2x − 2',
                  style: TextStyle(color: Colors.black87, fontSize: 16),
                ),
              ),
              _toggle(
                'Suggestions',
                session.penMathSuggestions,
                (v) => session.penMathSuggestions = v,
              ),
              const Text(
                'Get suggestions and solutions when you\'re working on math equations.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xff2c2c2e),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          child: SwitchListTile.adaptive(
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
          ),
        ),
      );
}
