# Novi progress

## Checklist
- [x] Read product roadmap and inspect workspace.
- [x] Step 1: Save roadmap and checklist.
- [x] Step 2: Verify desktop tools — Flutter 3.47.7, Dart 3.13.5, Xcode 27, CocoaPods, and macOS target available.
- [x] Step 3: Scaffold macOS, Windows, and Linux; build and launch on macOS.
- [x] Step 4: Create notebooks with one blank page each.
- [x] Step 5: Capture and render ink; automated mouse drawing check passes. Physical stylus remains unverified.
- [x] Step 6: Add and edit typed text.
- [x] Step 7: Save to local SQLite and restore after reopening.
- [x] Step 8: Undo and redo text and ink in the active session.
- [x] Step 9: Implement ZIP/JSON version-1 .novi export/import; round-trip tests pass.
- [x] Step 10: Implement full-library .novibackup backup/restore; multi-notebook restore test passes.
- [ ] Step 11: Complete hands-on desktop acceptance checks listed below.

## Current
The first technical alpha is implemented. A reported native crash on New notebook has been addressed by switching macOS to system SQLite. Native integration checks pass, but the original crash was not reproduced in a fresh test process. Hands-on acceptance remains current; this is not yet a release-quality v0.1.

## Verification — 2026-10-15
- `flutter analyze`: no issues.
- `flutter test`: all 3 tests pass. Covers notebook creation, typing, drawing, undo/redo, text and ink after workspace recreation, SQLite close/reopen, both portable formats, multi-notebook restore preserving existing content, and rejection of a future version.
- `flutter run -d macos --no-resident`: exit 0; built and launched the native macOS application using Metal rendering.
- Original ink points and pressure are stored. Pressure-based rendering is implemented; physical tablet behavior is not verified.
- macOS sandbox allows user-selected read/write files. Native file-dialog interactions have not been exercised.

## Notebook creation crash follow-up — 2026-10-15
- User report: native EXC_BAD_ACCESS in SQLite `vdbeUnbind` / `bindText` when creating a notebook. The crash report lists two loaded images of the bundled SQLite framework. Replacing bundled native assets while an older app process remains running is the suspected trigger, not a confirmed reproduction.
- Changed macOS SQLite build hooks to load `/usr/lib/libsqlite3.dylib`; other platforms retain bundled SQLite. No notebook schema or user data changes.
- Added `integration_test/notebook_test.dart` to run the editing, persistence, and portable-file scenarios inside a native desktop process with temporary libraries.
- Native macOS integration: all 3 tests pass, including New notebook, typing, ink, undo/redo, and reopening.
- `flutter analyze`: no issues. `flutter test`: all 3 tests pass.
- Cleaned build artifacts, rebuilt and launched the normal macOS app successfully. The clean app bundle has no SQLite framework. Flutter reported that automatic foreground activation failed, so visual inspection is still pending.
- Next: confirm New notebook in the rebuilt normal app, then continue the acceptance checklist below.

## Desktop window sizing — 2026-10-15
- [x] Set opening dimensions to 1200 × 800 logical units on all desktop runners.
- [x] Set minimum content dimensions to 960 × 640, with independent width/height resizing. Windows minimum accounts for display DPI and window borders.
- [x] macOS debug build passes after the native window change.
- [ ] Confirm opening size and drag-resize limits visually after fully reopening the app.
- Windows/Linux native builds and behavior remain unverified on this Mac.

## Grayscale library and document styling — 2026-10-15
- [x] Black and grayscale interface, white novi. wordmark, and dark native window decoration settings.
- [x] Documents library with grayscale covers, search, document-type filtering, grid/list views, and saved favorites.
- [x] New document dialog: Notebook, Whiteboard, Text document, Quick note; name, six grayscale cover shades, five paper patterns, three paper tones, portrait/landscape, and live previews.
- [x] Existing-document styling through the editor toolbar; style choices persist in SQLite, undo snapshots, document export, and library backups.
- [x] Backward-compatible defaults for existing documents; no user database migration required.
- [x] `flutter analyze`: clean. Widget/model suite: all 5 tests pass. Native macOS suite: all 4 tests pass.
- [x] Rendered and visually inspected library, creation dialog, dark-paper editor, and minimum-size dialog previews in `build/ui-preview/`. Layout assertions pass at 960 × 640; the dialog scrolls when shorter than its content.
- [x] Native test cursor animation made deterministic after the initial integration run stalled; rerun passes.
- [ ] Hands-on visual and interaction check in the normal rebuilt Mac app.
- Whiteboards currently use a fixed landscape page with dotted paper by default, not an infinite canvas. All four types use the same text/ink engine. Recording, photos, folders, and study sets remain future features.
- Native Windows/Linux decoration changes are implemented but unverified on their hosts.

## Hands-on acceptance — next actions in order
- [ ] In the Mac app, create a notebook, draw, and type; confirm the page looks right and the status says Saved locally.
- [ ] Close the app, reopen it, and confirm the same content appears in the native window.
- [ ] Export a .novi using the file dialog, import it, and compare the imported copy.
- [ ] Back up two notebooks, restore the backup, and confirm copies appear without replacing the originals.
- [ ] Try a physical drawing tablet and record device, driver, pressure, and input behavior.
- [ ] Build and run on Windows and Linux before claiming those platforms verified.

## Blockers and limits
- Native UI inspection timed out twice, so native visual and file-dialog acceptance remains pending.
- This Mac cannot verify Windows/Linux builds or a physical tablet without those environments/devices.
- Android command-line tools/licenses and Chrome are missing; neither blocks desktop development.
- One fixed-size page per notebook, a single editable text area, and session-only undo. PDF, attachments, advanced input, rich text, multiple pages, and specialized modes remain later work.
- Restore/import add copies; no existing notebook is overwritten. Current library backups contain all notebook content; preferences and attachments do not exist yet.
- ZIP manifests are versioned and unencrypted. The initial reader limits archive/manifest size to 50 MB.

## Desktop system UI controls — 2026-10-15
- [x] Replaced mobile/Material chips, pill buttons, and default controls with desktop macOS-styled components (`DesktopTheme`, `DesktopIconButton`, `DesktopButton`, `DesktopToolButton`, `DesktopPopupButton`, `DesktopPopupMenuButton`, `DesktopTextField`, `DesktopSlider`, `DesktopDialog`, `DesktopListTile`).
- [x] Configured native macOS graphite palette, dark canvas, subtle borders, and macOS-style outline glyphs.
- [x] Resolved popup menu route flex overflow by scaling items cleanly with `FittedBox` and applying `.AppleSystemUIFont` typography.
- [x] `flutter analyze`: clean.
- [x] Unit/widget test suite: all 5 tests pass (`test/library_ui_test.dart` and `test/workspace_test.dart`).
- [x] Native macOS integration test suite: all 5 tests pass in a live macOS process (`flutter test -d macos integration_test/notebook_test.dart`).
- [x] Regenerated visual preview images in `build/ui-preview/` (`library.png`, `creation.png`, `editor.png`, `minimum-editor.png`, `minimum-dialog.png`); verified desktop layout and typography.
- [ ] Hands-on visual and interaction check in the normal rebuilt Mac app.

## Forui desktop UI integration — 2026-10-15
- [x] Added `forui` (0.27.6) and `forui_lucide` (0.27.0) dependencies.
- [x] Configured Forui application root in `lib/main.dart` with `FTheme.neutral.dark.desktop` (adaptive desktop/touch), `FToaster`, `FTooltipGroup`, and `FLocalizations`.
- [x] Migrated desktop buttons in `lib/desktop_ui.dart` to Forui `FButton` and `FButton.icon` (primary, secondary, and ghost variants).
- [x] Loaded Forui Inter font and ForuiLucide icon font in preview tests.
- [x] `flutter analyze`: clean.
- [x] Unit/widget test suite: all 5 tests pass (`test/library_ui_test.dart` and `test/workspace_test.dart`).
- [x] Native macOS integration test suite: all 5 tests pass in a live macOS process (`flutter test -d macos integration_test/notebook_test.dart`).
- [x] Verified regenerated visual previews in `build/ui-preview/` (`library.png`, `creation.png`, `editor.png`, `minimum-editor.png`, `minimum-dialog.png`).
- [ ] Hands-on visual and interaction check in the rebuilt Mac app.

## macOS hidden title bar with custom window controls — 2026-10-15
- [x] Added `window_manager` (0.5.2) dependency and registered in macOS `MainFlutterWindow.swift`.
- [x] Initialized `windowManager` in `lib/main.dart` with `TitleBarStyle.hidden`, transparent background, 1200×800 initial window size, and 960×640 minimum content size.
- [x] Added `DragToMoveArea` window drag zones and ~78px traffic light leading offset in editor top bar.
- [x] Added `DragToMoveArea` and top breathing room in library sidebar and library documents header.
- [x] `flutter analyze`: clean.
- [x] Unit/widget test suite: all 5 tests pass (`test/library_ui_test.dart` and `test/workspace_test.dart`).
- [x] Native macOS integration test suite: all 5 tests pass in a live macOS process (`flutter test -d macos integration_test/notebook_test.dart`).
- [ ] Hands-on visual and drag verification in the rebuilt Mac app.

## Unified desktop top header bar (ChatGPT reference layout) — 2026-10-15
- [x] Implemented continuous `DesktopWindowHeader` spanning the entire window width above both sidebar and workspace.
- [x] Integrated macOS traffic light clearance (~78px `DragToMoveArea`) on the top-left edge.
- [x] Added desktop navigation controls directly alongside traffic lights: Back (`←` / `CupertinoIcons.chevron_left`), Forward (`→` / `CupertinoIcons.chevron_right`), and Sidebar toggle (`[|]` / `CupertinoIcons.sidebar_left`).
- [x] Implemented document tabs with kind icon, title, active elevated styling, and close buttons (`×`) right in the top header.
- [x] Placed rounded square `[+]` New document button directly adjacent to the tabs/navigation controls matching ChatGPT UI.
- [x] Configured middle empty space with `DragToMoveArea` for native window drag affordance.
- [x] Kept trailing document actions (`Open document` folder button, `Import, export and backup` menu) on the top-right.
- [x] Built bidirectional navigation history (`_navHistory`, `_navIndex`) for back/forward navigation between documents and library.
- [x] Added `showSidebar` toggling in `LibraryView` and unified workspace.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit/widget test suite: all tests pass (`test/library_ui_test.dart` and `test/workspace_test.dart`).
- [x] Native macOS integration test suite: all 5 tests pass in a live macOS process (`flutter test -d macos integration_test/notebook_test.dart`).
- [x] Regenerated visual previews in `build/ui-preview/` (`library.png`, `creation.png`, `editor.png`, `minimum-editor.png`, `minimum-dialog.png`); verified top header buttons, tabs, and layout across library and editor.
- [ ] Hands-on interaction check in the running Mac app.

## Next
Perform hands-on visual and drag verification in the rebuilt Mac app. Continue the desktop acceptance checks listed in the checklist above, recording results here.


