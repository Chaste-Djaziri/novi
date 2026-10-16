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

## Header controls alignment, curved panel frames, and collapsed icon rail — 2026-10-15
- [x] Aligned navigation buttons (`< > [|]`), tabs, and window controls on the exact vertical center axis (y = 16px) with native macOS traffic lights.
- [x] Implemented curved panel transitions (`BorderRadius.circular(12)`) on the sidebar, library documents gallery, and editor canvas panels where they meet the top header matching the ChatGPT desktop layout.
- [x] Configured the sidebar to collapse into a 52px icon-only rail (Documents, Favorites, Back up library, Restore backup) when toggled collapsed.
- [x] Implemented active item highlighting in the collapsed sidebar rail matching the ChatGPT desktop interface (36×36 rounded container, `Color(0xff2e2e2e)`, subtle white border, bright white icon vs muted inactive icons).
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 6 tests pass (`test/library_ui_test.dart` and `test/workspace_test.dart`).
- [x] Native macOS integration test suite: all 5 tests pass in a live macOS process (`flutter test -d macos integration_test/notebook_test.dart`).
- [x] Verified regenerated visual previews in `build/ui-preview/` (`library.png`, `creation.png`, `editor.png`, `minimum-editor.png`, `minimum-dialog.png`).
- [ ] Hands-on interaction check in the running Mac app.

## Anchored New document popover menu — 2026-10-15
- [x] Replaced generic New buttons with macOS active-blue capsule pill button (`NewPillButton`, `Color(0xff007aff)`, rounded corners `20px`, plus icon, white text).
- [x] Implemented anchored popover (`showNewDocumentMenu`) positioned beneath the button with an upward-pointing caret triangle aligned to the trigger button center.
- [x] Implemented top 3 creation cards: Notebook (`CupertinoIcons.book`), Whiteboard (`CupertinoIcons.rectangle_grid_2x2`, with olive/gold "NEW" badge), and Text Doc (`CupertinoIcons.doc_text`, with "NEW" badge).
- [x] Implemented second row of cards: Import (`CupertinoIcons.arrow_down_to_line`) and Quick Record (`CupertinoIcons.mic_fill` with sparkle).
- [x] Implemented grouped rounded card list: QuickNote (`CupertinoIcons.pencil`), Study Set (`CupertinoIcons.rectangle_stack`), Image (`CupertinoIcons.photo`), and Take Photo (`CupertinoIcons.camera`) separated by subtle 1px dividers.
- [x] Implemented standalone Folder card and Import from Cloud Storage card with gold lock badge (emphasizing Novi's 100% local-first and offline privacy guarantee).
- [x] Wired popup to both library header `+ New` button and unified window header `+` create button.
- [x] Updated `CreateDocumentDialog` to support `initialKind` for direct preset selection upon clicking a document kind.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 6 tests pass (`test/library_ui_test.dart` and `test/workspace_test.dart`) and all 4 tests in `test/widget_test.dart` pass.
- [x] Native macOS integration test suite: all 5 tests pass in a live macOS process (`flutter test -d macos integration_test/notebook_test.dart`).
- [x] Captured and visually inspected visual preview artifact `build/ui-preview/new-popup.png`.
- [ ] Hands-on interaction check in the running Mac app.

## Goodnotes-style New Notebook creation dialog — 2026-10-15
- [x] Implemented dedicated Goodnotes-style creation dialog in `CreateDocumentDialog`:
  - Top header with circular dark close button (`X`), centered title ("New Notebook" / "Document Style"), and macOS active-blue pill button ("✓ Create" / "✓ Save style").
  - Top section with side-by-side interactive preview cards:
    - **COVER**: Miniature notebook cover with real shade, spine shadow, elastic band, and document title.
    - **PAPER**: Miniature paper preview with live pattern and tone rendering, framed with active blue indicator line.
  - Grouped settings cards on right:
    - Name field with `document-name` key and real-time live preview synchronization.
    - Format dropdown selector (Notebook, Whiteboard, Text document, Quick note).
    - Cover switch toggle.
    - Paper template size selector ("Standard, Portrait" / "Standard, Landscape").
    - Paper template color selector (Yellow, White, Dark).
  - Bottom sections:
    - **Paper Templates**: Essentials row with Blank, Dotted Paper, Squared Paper (with active circular blue checkmark badge `(✓)`), Ruled Narrow, and Ruled Wide, plus individual 3-color tone dots under each template card.
    - **Cover Styles**: Essentials row with 6 cover shades (Charcoal, Graphite, Slate, Silver, Bright, Alabaster) with `Cover 1`–`Cover 6` tooltips.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 6 tests pass (`test/library_ui_test.dart` and `test/workspace_test.dart`) and all 4 tests in `test/widget_test.dart` pass.
- [x] Native macOS integration test suite: all 5 tests pass in a live macOS process (`flutter test -d macos integration_test/notebook_test.dart`).
- [x] Captured and visually verified visual preview artifact `build/ui-preview/creation.png`.
- [ ] Hands-on interaction check in the running Mac app.

## Custom cover colors, palettes, and image cover uploads — 2026-10-16
- [x] Added `coverImage` (optional base64-encoded image string) to `Notebook` model:
  - Stored in SQLite data column with zero database migration needed.
  - Encoded into `.novi` and `.novibackup` portable archives; self-contained, offline, account-free, and resistant to macOS sandbox permission loss.
  - Fully backwards-compatible with existing documents and historical formats.
- [x] Implemented dedicated desktop `CustomColorPickerDialog`:
  - Live color swatch preview with light/dark luminance indicator icon.
  - Hex code text field with automatic `#` prefix, live input parsing, and instant swatch synchronization.
  - 36-shade curated spectrum palette spanning reds, corals, oranges, yellows, greens, teals, cyans, blues, purples, violets, and earth tones.
  - Independent Red, Green, and Blue sliders (0–255) with monospace value readouts.
- [x] Added "Color Palettes" row to `CreateDocumentDialog`:
  - 12 curated vibrant and classic notebook tones (Merlot, Terracotta, Amber, Forest, Teal, Cobalt, Indigo, Plum, Rose, Espresso, Sage, Midnight).
  - Interactive "Custom..." swatch card with rainbow gradient badge opening the custom color picker.
- [x] Added native image cover upload to `CreateDocumentDialog`:
  - "Upload Image..." capsule button in Cover Styles header and dedicated "IMAGE UPLOAD" dropzone card.
  - Native file picker (`openFile`) accepting PNG, JPG, JPEG, and WEBP images.
  - Downsamples large images and encodes them to base64.
  - When an image is active, displays thumbnail, status badge, "Change Image" button, and "Remove photo" button to revert to color.
- [x] Updated `DocumentCover`:
  - Decodes base64 `coverImage` and renders it with `BoxFit.cover`.
  - Applies subtle dark gradient overlay, spine line, strap shadow, and drop-shadowed white typography for high legibility.
- [x] Fixed `DesktopSlider` layout by constraining height to 20px.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all tests pass (`test/widget_test.dart`, `test/library_ui_test.dart`, `test/workspace_test.dart`).
- [x] Native macOS integration test suite: all 7 tests pass in a live macOS desktop process (`flutter test -d macos integration_test/notebook_test.dart`).
- [x] Visual preview artifact regenerated and verified: `build/ui-preview/creation.png`.
- [ ] Hands-on interaction check in the running Mac app.

## Reposition search input under the new button — 2026-10-16
- [x] Updated the document gallery header layout in `lib/library_ui.dart`:
  - **Top row**: Title (`Documents` / `Favorites`, 24pt bold) with count badge on the left, `Expanded` `DragToMoveArea` in the middle, and primary actions on the right: Import button, Grid/List view toggle, and `+ New` button.
  - **Second row**: Document kind filter dropdown (`DesktopPopupButton<String>`) on the left, `Spacer()`, and search input field (`DesktopTextField` width 220, placeholder 'Search documents') positioned directly under the `+ New` button on the right.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 13 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [x] Regenerated visual preview artifact `build/ui-preview/library.png` confirming the balanced dual-row header layout with right-aligned search beneath `+ New`.
- [ ] Hands-on interaction check in the running Mac app.

## Home button on notebook write page — 2026-10-16
- [x] Added dedicated Home button (`CupertinoIcons.house`) to `DesktopWindowHeader` in `lib/main.dart`:
  - Positioned right before the previous and next route buttons (`<` and `>`), directly following the macOS traffic lights zone.
  - Dynamically displayed when in the notebook write / editor page (`showTabs: true`), allowing one-click return to the documents library.
  - Wired directly to `onOpenDocument` (cleans up active drawing strokes, unfocuses active text inputs, and navigates home).
- [x] Added automated widget test `home button appears on notebook write page right before route buttons and returns to library` in `test/widget_test.dart`.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 14 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [x] Regenerated visual preview artifact `build/ui-preview/editor.png` confirming the Home button placement alongside the traffic lights and navigation buttons.
- [ ] Hands-on interaction check in the running Mac app.

## Open tabs preservation until specifically closed by user — 2026-10-16
- [x] Preserved open document tabs in `DesktopWindowHeader` whenever `openIds.isNotEmpty`, so tabs remain visible and accessible in the window header even when navigating back to the documents library or between documents.
- [x] Persisted open tab IDs in SQLite `app_state` table (`loadOpenTabs`, `saveOpenTabs` in `LibraryStore`), restoring open tabs across app launches and sessions.
- [x] Ensured tabs are strictly preserved open until specifically closed by the user tapping the tab's close (`x`) button (`closeTab`).
- [x] Added automated widget test in `test/widget_test.dart` verifying multi-document tab preservation across library navigation, active tab switching, selective closing, and final cleanup.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 15 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [ ] Hands-on interaction check in the running Mac app.

## Pin folder and 3-dots actions to the right end in top bar — 2026-10-16
- [x] Identified layout cause: in `DesktopWindowHeader`, wrapping tabs in `Flexible(fit: FlexFit.loose)` alongside `Expanded(child: DragToMoveArea)` caused Flutter's `RenderFlex` to divide the remaining width equally between them upfront. Unused loose space from the tabs was not reallocated, leaving trailing actions stranded near the middle with a blank void on the right.
- [x] Solved layout in `lib/main.dart` using `LayoutBuilder`:
  - Wrapped tabs in `ConstrainedBox(constraints: BoxConstraints(maxWidth: maxTabsWidth))` (calculated from `constraints.maxWidth - 320`) so tabs only take their natural content width.
  - Designated `DragToMoveArea` as the sole `Expanded` in the header `Row`, absorbing 100% of all remaining horizontal space.
  - Pinned the `DesktopIconButton` (Open document folder) and `DesktopPopupMenuButton` (••• ⌵ Import, export and backup) completely flush to the right window edge with a clean 6px margin.
- [x] Added automated widget test `folder and 3 dots actions stay pinned to the right end of the top bar with or without tabs` in `test/widget_test.dart`.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 16 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [x] Regenerated visual preview artifact `build/ui-preview/editor.png` and visually verified that the folder and 3-dots buttons sit flush against the far right edge of the top bar above the content panel.
- [ ] Hands-on interaction check in the running Mac app.

## Center notebook paper in viewport and stick to top/bottom on scroll — 2026-10-16
- [x] Replaced top-pinned canvas alignment with centered viewport layout in `lib/main.dart`:
  - Positioned the paper inside `SizedBox(width: math.max(constraints.maxWidth, pageWidth), height: math.max(constraints.maxHeight, pageHeight))` with `Align(alignment: Alignment.center)`.
  - Added subtle realistic drop shadow around the paper sheet (`BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))`) with clean anti-aliased clipping.
  - When the paper fits inside the viewport (or when zoomed out), it automatically centers itself both horizontally and vertically.
- [x] Implemented scroll clamping to stick to top and bottom bounds:
  - Added `Listener` handling `PointerScrollEvent` on the canvas viewport, allowing smooth vertical/horizontal scrolling via trackpad or mouse wheel across all editor tools (pen, highlighter, eraser, select, text, and hand).
  - Clamped vertical scroll offsets strictly between `constraints.maxHeight - totalHeight` (bottom limit) and `0.0` (top limit).
  - Pinned `boundaryMargin` vertical limits so the paper sticks flush to the top and bottom of the viewport without drifting into empty space.
- [x] Added automated widget test `notebook paper centers itself in viewport and on scroll sticks to top and bottom` in `test/widget_test.dart`.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 17 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [x] Regenerated visual preview artifact `build/ui-preview/editor.png` and visually verified the centered sheet layout.
- [ ] Hands-on interaction check in the running Mac app.

## Horizontal center lock on scroll and vertical gaps — 2026-10-16
- [x] Locked horizontal position strictly to the viewport center in `lib/main.dart`:
  - When scrolling left or right via trackpad or mouse wheel gestures, `matrix.storage[12]` is continuously pinned to `centeredTx = (constraints.maxWidth - totalWidth) / 2`.
  - Prevents horizontal drift or sideways wobbling during scrolling, ensuring the sheet of paper always remains centered.
- [x] Configured 24px vertical breathing room above and below the paper:
  - Wrapped the sheet in `Padding(padding: const EdgeInsets.symmetric(vertical: 24))`, extending canvas height to `pageHeight + 48`.
  - When scrolled to the top, the paper stops with a clear 24px gap below the top toolbar.
  - When scrolled to the bottom, the paper stops with a clear 24px gap above the bottom bar.
  - When the paper fits inside the viewport, it stays centered with equal gaps on all sides.
- [x] Updated automated widget test in `test/widget_test.dart` to verify horizontal lock under large left/right scroll deltas and exact 24px top/bottom gaps.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 17 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [x] Regenerated visual preview artifact `build/ui-preview/editor.png` and verified 24px gaps and centered alignment.
- [ ] Hands-on interaction check in the running Mac app.

## Center-aligned zoom with conditional edge-clamped horizontal scroll — 2026-10-16
- [x] Configured horizontal scrolling behavior in `lib/main.dart` based on paper width vs viewport width:
  - When paper fits within the viewport horizontally (`paperWidth <= constraints.maxWidth`): left/right scrolling is strictly disallowed, locking `tx` to the horizontal center.
  - On zoom: `zoom()` calculates `centeredTx = (constraints.maxWidth - (2 * paperLeftInChild + paperWidth)) / 2` so that zooming in or out always keeps the paper centered in the view.
  - When zoomed in beyond view (`paperWidth > constraints.maxWidth`): left and right scrolling is fully enabled, clamped strictly between `minX = constraints.maxWidth - (paperLeftInChild + paperWidth)` and `maxX = -paperLeftInChild` so users can pan across the paper to its exact edges without drifting into whitespace.
  - On gesture release (`onInteractionEnd`), `_snapHorizontalToCenter` smoothly clamps/snaps the horizontal offset within bounds (to center if within view, or to the paper edges if out of view).
- [x] Extended automated test in `test/widget_test.dart` to verify that zoom centers the view, and once wider than the viewport, left and right scrolling smoothly reaches and sticks to each paper edge.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 17 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [x] Regenerated visual preview artifact `build/ui-preview/editor.png` and verified centered sheet layout with 24px gaps.
- [ ] Hands-on interaction check in the running Mac app.

## Next
Perform hands-on visual and drag verification in the rebuilt Mac app. Continue the desktop acceptance checks listed in the checklist above, recording results here.



