/// Shared editor tool types. Keep this file dependency-free so tool modules
/// and controllers can depend on it without importing the legacy toolbar.
enum LassoType { rectangular, freehand }

enum WritingMode { pen, pencil, highlighter, tape, drawShape }

enum PenType { fountain, ballpoint, brush }

enum EraserType { precision, standard, stroke }

enum EditorTool { select, pen, highlighter, eraser, text, hand }
