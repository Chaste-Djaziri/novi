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
Writing materials and paper indicators are implemented. All 35 automated tests pass and `flutter analyze` reports no issues. The final native macOS run passed all 30 tests, including stationary-pointer scrolling and touch/filter refinements. Physical stylus and Windows/Linux verification remain pending.

## Previous completed work — Text Tool
Implemented Text Tool options and popovers matching the user's design reference screenshots:
- **Text Tool Floating Bar & Anchored Popovers**:
  - **Color Popover (`TextColorMenuDialog`)**:
    - Triggered by `( ▾ )` Color button (`Key('text-collapse-button')`) on the left of the Text floating toolbar.
    - Features header with tune/sliders icon button, centered "Text Color" title, and "Edit" action pill.
    - Segmented tabs: `Presets`, `Custom`, `History`.
    - Three-row color palette: Row 1 vibrant colors (Red, Orange, Yellow, Green, Cyan, Blue, Purple, Pink); Row 2 muted/dark tones; Row 3 monochrome neutrals (White, Light Gray, Mid Gray, Dark Gray, Black) with active selection checkmark and a dotted circle `+` button for custom colors.
  - **Font Size Popover (`FontSizeMenuDialog`)**:
    - Triggered by `[ 24 ˅ ]` font size pill (`Key('text-font-size-button')`).
    - Anchored capsule card with size value container `[ 24 ]`, dynamic slider with blue active track and white thumb knob, and `[ - | + ]` stepper pill.
    - Horizontal preset chips (`12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64`) that apply size and dismiss the popover immediately on tap.
  - **Font Family Menu (`FontFamilyMenuDialog`)**:
    - Triggered by `[ Modern ˅ ]` font family pill (`Key('text-font-family-button')`).
    - Anchored dark card displaying `Modern` (sans-serif), `Classic` (serif), `Technical` (Courier monospace), with blue checkmarks for the active font and dividers, plus a bottom pill button `More Fonts...`.
  - **Text Style Popover (`TextStyleMenuDialog`)**:
    - Triggered by `[ B I ]` text style button (`Key('text-bold-italic-button')`, tooltip `Text Style`).
    - Horizontal capsule menu with 4 style toggles: `B` (Bold), `I` (Italic), `U` (Underline), `S` (Strikethrough).
    - Fully wired with `Notebook` persistence, `EditorSession`, and `PaperTextEditor` rendering with combined `TextDecoration` support.
  - **Text Alignment, Line Height, and Text Box Style Popovers**:
    - Preserved and harmonized with existing popover architecture.
- **Automated Verification**:
  - `flutter analyze`: clean (0 issues).
  - `flutter test`: all 29 automated tests pass across `test/widget_test.dart`, `test/workspace_test.dart`, and `test/library_ui_test.dart`.
- [x] Configured `EditorTool.select` as initial tool when opening notebooks/documents.
- [x] Converted top toolbar items and sub-components to icon-only buttons with zero text clutter, passing text names and actions into tooltips.
- [x] Moved all more controls / tool options out of the top header into `FloatingToolControls`, freeing header vertical space to a clean 44px.
- [x] Designed `FloatingToolControls` floating over the document canvas in the viewport Stack with glassmorphism blur, soft shadow, hover micro-interactions, and freeform draggable positioning (`Key('floating-drag-handle')`).
- [x] Simplified page scrolling to clean, natural 1:1 movement, eliminating artificial animation controllers and sudden delta multipliers.
- [x] Added contextual icon-based sub-controls for all active tools:
  - `select`: select mode indicator, delete selected ink, clear selection.
  - `pen` & `highlighter`: stroke width slider, dynamic width preview dot, auto contrast wand, ink shade selector pills.
  - `eraser`: eraser radius slider, radius preview, delete selected ink.
  - `text`: font size selector, bold toggle button.
  - `hand`: hand/pan mode indicator.
  - zoom & view: zoom in, zoom out, current zoom percentage pill, reset view icon button.
- [x] `flutter analyze`: clean (0 issues). Full test suite: all 24 tests pass.

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

## Strict side-scroll disallowance when fitting and edge-clamped scrolling when zoomed — 2026-10-16
- [x] Strictly disallowed side scrolling when paper fits within the viewport horizontally (`paperWidth <= constraints.maxWidth`):
  - Dynamic `InteractiveViewer.panAxis` set to `PanAxis.vertical`, blocking horizontal drag interactions while fitting.
  - Horizontal boundary margin set to `0.0` (`boundaryMargin: const EdgeInsets.symmetric(horizontal: 0, vertical: 50)`), preventing drag past bounds.
  - In `_handleCanvasScroll`, horizontal scroll delta is ignored when fitting (`minX = maxX = 0.0`), locking horizontal translation strictly to center.
  - Child width adapts to `constraints.maxWidth / scale` when fitting, keeping the paper centered with zero horizontal drift or slack.
- [x] Clamped scrolling strictly to paper edges without scrolling past into empty whitespace when zoomed out of view (`paperWidth > constraints.maxWidth`):
  - `InteractiveViewer.panAxis` dynamically switches to `PanAxis.free`.
  - Child width is set to `pageWidth`, eliminating horizontal margins inside the child so child boundaries match paper boundaries exactly.
  - Horizontal translation is clamped strictly between `minX = constraints.maxWidth - paperWidth` and `maxX = 0.0`. Left and right edge scrolling stops flush with the viewport edges with zero margin or overshoot.
  - `_snapHorizontalToCenter` clamps within `[minX, 0.0]` on interaction end.
- [x] Updated automated widget test in `test/widget_test.dart` to verify:
  - `panAxis == PanAxis.vertical` and `boundaryMargin.horizontal == 0.0` when fitting in view.
  - Horizontal scrolling attempts while fitting maintain center position.
  - `panAxis == PanAxis.free` and `boundaryMargin.horizontal == 0.0` when zoomed beyond viewport.
  - Large scroll deltas to the right clamp to right edge of paper without exceeding it.
  - Large scroll deltas to the left clamp to left edge of paper without exceeding it.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 17 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [ ] Hands-on interaction check in the running Mac app.

## Small zoom out smaller than viewport and centered side scroll — 2026-10-16
- [x] Allowed zooming out the page to small sizes even smaller than the viewport:
  - Lowered minimum scale threshold to 5% (`minScale: 0.05` on `InteractiveViewer` and `.clamp(0.05, 3.0)` in `zoom()`).
  - Sized viewer child dynamically with `childHeight: isFitting ? math.max(constraints.maxHeight / scale, pageHeight + 48) : math.max(constraints.maxHeight, pageHeight + 48)` and `childWidth: isFitting ? (constraints.maxWidth / scale) : pageWidth`, allowing small zoom scales to render cleanly without being clipped or restricted by viewport bounds.
  - Centered child contents vertically and horizontally via `Align(alignment: isFitting ? Alignment.center : Alignment.topCenter)`.
- [x] Maintained center alignment on side scroll when smaller than the viewport:
  - In `_handleCanvasScroll`, horizontal translation bounds remain locked (`minX = maxX = 0.0`) when `paperWidth <= constraints.maxWidth`.
  - When smaller than the viewport height (`totalHeight <= constraints.maxHeight`), vertical bounds also lock (`minY = maxY = 0.0`) to preserve vertical centering.
  - Reset view button resets back to 100% scale and centers the paper in the viewport.
- [x] Added automated widget test in `test/widget_test.dart`:
  - Verified zooming out 8 steps reaches `< 0.5` scale and paper width/height are smaller than the viewport.
  - Verified paper center aligns with viewport center horizontally.
  - Verified left and right pointer scroll events keep the paper centered with 0 drift.
  - Verified Reset view restores 1.0 scale and centered alignment.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 17 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [ ] Hands-on interaction check in the running Mac app.

## Notebook cover as Page 1 and paper canvas as Page 2 — 2026-10-16
- [x] Configured multi-page continuous vertical layout for notebooks (`note.kind == 'Notebook'`):
  - Page 1 renders the notebook cover (`DocumentCover(note)`) with rounded corners and drop shadow.
  - Page 2 renders the paper canvas (`PaperPainter`, text editor, ink layer) directly under the cover, separated by a 24px vertical gap.
  - Other document types (`Whiteboard`, `Text document`, `Quick note`) remain single-page canvas layouts.
- [x] Extended scroll and zoom bounds:
  - Total content height dynamically adapts to `pageHeight * 2 + 72.0` when a cover is present, maintaining 24px margins at the top, between pages, and at the bottom.
  - Page indicator in the bottom bar dynamically updates (`Page 1 of 2` vs `Page 2 of 2`) based on the scroll position.
  - Zoom preserves and scales the vertical scroll position clamped to valid bounds rather than jumping to 0.0.
- [x] Test coverage:
  - Updated `test/widget_test.dart` to assert cover (Page 1) and paper (Page 2) are vertically stacked, 24px apart, centered horizontally, and scroll bounds stick to top and bottom margins correctly.
  - Updated `test/workspace_test.dart` and `test/library_ui_test.dart` to verify drawing, erasing, undo/redo, selection, and zoom interactions on Page 2 pass seamlessly.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 17 tests pass.
- [ ] Hands-on interaction check in the running Mac app.

## Bottom overscroll interactive loader and page creation — 2026-10-16
- [x] Multi-page data architecture:
  - Added `NotebookPage` to `lib/notebook.dart` and migrated `Notebook` to support `List<NotebookPage> pages` with backward-compatible getters and setters for `text`, `strokes`, and `inkStyles`.
  - Added multi-page controller management in `EditorSession` (`lib/workspace_tools.dart`).
- [x] Interactive bottom overscroll loader & threshold page creation:
  - In `_handleCanvasScroll`, detects when the user scrolls downward while already at the bottom of the document and accumulates `_bottomOverscroll`.
  - Provides physical rubber-band resistance easing (`overscrollShift = math.min(50.0, _bottomOverscroll * 0.25)`).
  - Renders `_PageCreationLoader` below the last paper page with an animated circular progress indicator showing the exact pull percentage (`Scroll to add page X%`).
  - Upon reaching the threshold (`>= 100.0`), invokes `_createNextPage` to append a new page to the notebook, save to SQLite, take an undo snapshot, and update status (`Page X created`).
  - Upward scrolling recovers smoothly by consuming overscroll before scrolling up.
  - An idle timer resets sub-threshold overscroll back to 0.0 with a gentle snap-back.
  - Page indicator in the bottom bar dynamically updates (`Page X of Y`).
  - Hardened `Notebook.pages` with a lazy-initialization getter backed by `_pages` to guarantee null-safety during hot reload on long-running processes.
- [x] Test coverage:
  - Added test in `test/widget_test.dart` verifying that scrolling past bottom renders the loader with progress, reaching threshold creates a new page with a 24px gap, page indicator reflects new page count, and undo restores previous state.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 18 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [ ] Hands-on interaction check in the running Mac app.

## PC mouse and keyboard scrolling & stylus-conditional Hand tool — 2026-10-16
- [x] PC mouse and keyboard scrolling without Hand tool:
  - Enabled mouse wheel and trackpad smooth continuous scrolling without needing to switch to the Hand tool.
  - Implemented Spacebar + drag canvas panning: holding Spacebar turns cursor into a pan gesture without drawing ink strokes.
  - Implemented middle mouse click drag: pressing and dragging with middle button pans the canvas directly.
  - Implemented background margin drag panning: clicking and dragging empty canvas background margins outside paper sheets translates the view directly.
  - Implemented keyboard pan shortcuts in `CallbackShortcuts`: Arrow keys (Up, Down, Left, Right) pan by 60px increments, PageUp/PageDown pan by 300px increments, and Home/End scroll to the top or bottom of the document.
- [x] Stylus-conditional Hand tool visibility:
  - When using PC with mouse and keyboard normally (no stylus connected), the Hand tool button is hidden from `WorkspaceToolbar`.
  - When a stylus pointer event (`PointerDeviceKind.stylus` or `invertedStylus`) is detected, the Hand tool is automatically revealed in the toolbar.
  - Added a stylus connect/disconnect toggle button in the toolbar with status tooltips (`Connect stylus / pen` / `Stylus connected (click to disconnect)`).
  - Pressing keyboard shortcut 'H' reveals the Hand tool and selects it.
  - Disconnecting stylus switches active tool back to pen if Hand was currently selected.
- [x] Test coverage:
  - Updated `test/workspace_test.dart` to connect stylus before selecting Hand tool.
  - Added test in `test/widget_test.dart` verifying:
    - Hand tool is initially hidden with mouse/keyboard.
    - View can scroll via mouse wheel, arrow keys, and PageDown without Hand tool.
    - Connecting stylus via toggle button reveals Hand tool.
    - Selecting Hand tool, then disconnecting stylus re-hides Hand and selects pen.
    - Sending stylus pointer event automatically detects stylus and reveals Hand tool.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 19 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [ ] Hands-on interaction check in the running Mac app.

## Full screen top header left alignment — 2026-10-16
- [x] Full screen window state tracking:
  - Added `WindowListener` mixin to `_WorkspaceState`, listening to `onWindowEnterFullScreen` and `onWindowLeaveFullScreen`, and querying `windowManager.isFullScreen()` during startup.
- [x] Top header dynamic positioning:
  - Passed `isFullScreen` to [DesktopWindowHeader](file:///Users/chastedjaziri/Documents/ChatGPT/novi/lib/main.dart).
  - In normal windowed mode on macOS, preserved the 78px `DragToMoveArea` spacer on the left to leave room for macOS window controls (traffic light close/minimize/maximize buttons).
  - In full screen mode (`isFullScreen: true`), removed the 78px left spacer so the Home button, back/forward buttons, sidebar toggle, and tabs start directly from the very left edge (0.0).
- [x] Test coverage:
  - Added automated test in `test/widget_test.dart` asserting that when `isFullScreen: false` the header begins at 78px, and when `isFullScreen: true` the Home button, back/forward buttons, and tabs start at x=0.0.
- [x] `flutter analyze`: clean (0 issues).
- [x] Unit and widget test suite: all 20 tests pass (`test/library_ui_test.dart`, `test/widget_test.dart`, `test/workspace_test.dart`).
- [ ] Hands-on interaction check in the running Mac app.

## Notebook controls, whole-paper typing, and native tablet detection — 2026-10-16
- [x] Notebook-only creation enforced in the new menu, dialog format choices, and creation callbacks. Future creation options remain visible with Coming later tooltips/disabled semantics. Imports and existing non-notebook documents remain supported.
- [x] Three toolbar regions: undo/redo/delete at left, tools centered independently, add-page/style/export at right. The context bar stays 52 logical pixels high. Compact icons preserve centering at 960 × 640; lower-priority future controls remain in More Tools.
- [x] Explicit disabled future controls: Calculator, Shapes, Images, Stickers, Sticky notes, Laser pointer, Recording, Ruler, Equations, Graphing, and Code tools. No nonworking action appears enabled.
- [x] Shared paper/text metrics in `lib/paper_layout.dart`; natural text spacing follows ruled/dotted/grid row baselines. Large fonts occupy whole multiples of row spacing.
- [x] Page-wide typing with a consistent 8px side inset. Clicking empty rows creates real blank lines and places the caret there. Existing text retains native caret/selection behavior; selecting text does not pan the canvas.
- [x] Text wraps across the available page width and continues onto later pages, preserving every character and existing ink. Font and paper/orientation changes reflow overflow. Undo/redo synchronizes all page controllers and remains one operation per composing input/format change.
- [x] Blank paper shows temporary guides in Type mode only; guides are not serialized into notes or exports.
- [x] Per-notebook active typing page/focus, tool, view, and undo history survive tab switches. Mouse wheel scrolling works over typing, ink, and margins without enabling Hand or accidentally zooming. Trackpad pan/zoom, Space-drag, middle drag, and keyboard navigation remain supported.
- [x] Removed fake connect/disconnect controls. macOS `novi/tablets` method and event channels enumerate digitizer hardware at startup and observe IOKit registry attach/removal notifications. Composite interfaces are deduplicated where physical identity is available. No raw input interception, device seizure, Input Monitoring permission, or extra entitlements were added.
- [x] Hardware connection is separate from pen proximity. Last-device removal hides Hand and restores the previous writing tool. Pen input/hover can reveal Hand with an honest Pen observed / hardware identity unavailable fallback. Status is visible in the footer. Windows/Linux retain mouse navigation and pen-observed fallback, without native hardware enumeration.
- [x] Fixed a pre-existing native startup ordering problem: fullscreen state is queried only after the window-manager plugin is initialized and a window frame is available.
- [x] `flutter analyze`: no issues. `flutter test`: all 19 tests pass. Native macOS integration: all 19 tests pass, including initial tablet method/event snapshots, text continuation, native composition protocol, guides, scrolling, and document persistence.
- [x] Rendered and inspected `build/ui-preview/typing-paper.png`, editor, creation/menu, and minimum-size previews. Typing baselines align to the visible grid and the grayscale desktop theme is preserved.
- Native integration drives keyboard input deterministically through Flutter's test text channel, avoiding races with the OS IME. Real-language IME, real hardware attach/removal, driver coverage, and Windows/Linux builds still require hands-on verification. Hardware transitions in widget tests are explicitly simulated; the native channel smoke check uses real IOKit enumeration.
- [ ] Verify physical tablet connection before first pen activity, unplugging, multiple devices, and driver-hidden identities in the normal Mac app.
- [ ] Verify normal-app row clicking/typing, selection, scrolling, and tab switching, including a real IME.

## Content Page Manager, Canvas Scroll Indicator, Smooth Sliding & Bounce Physics — 2026-10-16
- [x] Content Page Manager (Collapsible/Expandable Sidebar):
  - Created [PagesSidebar](file:///Users/chastedjaziri/Documents/ChatGPT/novi/lib/pages_sidebar.dart) matching the user reference screenshot with header (`···` menu, `Pages` title, `✕` close button), view tabs (Thumbnails, Outline, Bookmarks), filter dropdown (`All Pages ⌵` / `Bookmarked`), and page count indicator.
  - Implemented 2-column page thumbnail cards: Miniature Cover card for Page 1, Miniature Paper card with real ink and typed text previews for Page 2+, active page blue highlight ring, and bookmark ribbon toggling.
  - Implemented dashed outline card with `+` icon to add new pages directly from the sidebar.
  - Tapping a thumbnail card smoothly jumps/scrolls the viewport directly to that page.
  - Integrated sidebar collapse/expand toggle button in the header bar and workspace toolbar (`toolbar-toggle-pages`).
- [x] Canvas Scroll Indicator:
  - Added [CanvasScrollIndicator](file:///Users/chastedjaziri/Documents/ChatGPT/novi/lib/main.dart) pinned to the right edge of the editor canvas viewport.
  - Dynamically computes thumb height and position based on content-to-viewport ratio and matrix transformation.
  - Supports clicking and dragging the thumb vertically to scroll through documents smoothly with hover animations.
- [x] Trackpad & Mouse Smooth Sliding Physics:
  - Fixed rigid "per-pixel" jumping by introducing an interpolation controller (`_smoothScrollController`) with `Curves.easeOutCubic` over 220ms for discrete wheel jumps.
  - Trackpad two-finger continuous pan zoom delivers responsive 1:1 finger tracking.
  - On trackpad release, momentum fling calculates velocity based on delta and time delta for natural macOS sliding feel.
- [x] Expanded Overscroll & Rubber-Band Bounce-Back Animation:
  - Expanded bottom overscroll pull distance to 130px shift with a spacious 180.0 threshold for page creation (`_createPageThreshold = 180.0`).
  - Added rubber-band bounce-back animation (`_overscrollBounceController`) using `Curves.easeOutBack` when pulling is released or paused before reaching the threshold.
- [x] Verification:
  - `flutter analyze`: clean (0 issues).
  - `flutter test`: all 23 tests pass across `test/widget_test.dart`, `test/library_ui_test.dart`, and `test/workspace_test.dart`.
  - Added dedicated automated tests for:
    - Trackpad two-finger scroll overscroll page creation.
    - Trackpad overscroll release before threshold triggering smooth bounce-back animation.
    - Canvas scroll indicator rendering on right edge and drag-to-scroll functionality.
    - Content Page Manager collapse/open, thumbnail navigation, bookmarks, and adding pages.

## Text Tool Floating Bar, Options & Popovers — 2026-10-16
- [x] Text Tool Floating Options Bar:
  - Added floating contextual options bar for [EditorTool.text](file:///Users/chastedjaziri/Documents/ChatGPT/novi/lib/workspace_tools.dart) positioned below the main top toolbar with dark capsule theme (`#1a1c1e` / `#222428`).
  - Implemented 10 controls matching the reference designs:
    1. Collapse button: `( ⌄ )` icon.
    2. Font Size dropdown pill: `[ 24 ˅ ]` with popover (`FontSizeMenuDialog`) providing quick size presets (12 to 64 pt).
    3. Font Family dropdown pill: `[ Modern ˅ ]` (Tooltip: `Font Family`) with popover (`FontFamilyMenuDialog`) providing Modern (Inter), Classic (Georgia), Monospace (Courier), and Handwritten (Caveat).
    4. Bold & Italic button: `[ B I ]` with independent toggle states for bold and italic styling.
    5. Text Alignment button: `[ ≡ ]` opening `TextAlignmentMenuDialog` with 3-segment pill (Left, Center, Right) and active white indicator.
    6. Line Height button: `[ ↕≡ ]` (Tooltip: `Line Height`) opening `LineHeightMenuDialog` with uppercase `LINE HEIGHT` header, current value display, slider, `[ - | + ]` stepper, and green `Automatic` switch.
    7. Vertical divider.
    8. Text Box Style button: `[ ⟍ ]` (Tooltip: `Text Box Style`) opening `TextBoxStyleMenuDialog` with `[ Presets ]` and `[ Advanced ]` tabs:
       - Presets: 2x5 grid of 10 curated style swatches (None, Dark slate, Lime green, Peach, White, Coral red, Yellow, Off-white, Navy, Light grey).
       - Advanced: Background Color picker, Border Color picker, Round Corner stepper (`0 pt Round Corner`), Shadow toggle switch, Border width stepper (`0 pt Border`), and Padding stepper (`10 pt Padding`).
    9. Favorite / Saved style button: `[ T♡ ]`.
    10. Pin Text Tool button: `[ 📌 Pin Text Tool ]`.
- [x] Canvas Text Rendering & Model Persistence:
  - Stored `fontFamily`, `italicText`, `textAlign`, `lineHeight`, `lineHeightAuto`, `textBoxBgColor`, `textBoxBorderColor`, `textBoxRadius`, `textBoxBorder`, `textBoxPadding`, and `textBoxShadow` in [Notebook](file:///Users/chastedjaziri/Documents/ChatGPT/novi/lib/notebook.dart).
  - Wired text parameters through [PaperTextEditor](file:///Users/chastedjaziri/Documents/ChatGPT/novi/lib/paper_text_editor.dart) and [DesktopTextField](file:///Users/chastedjaziri/Documents/ChatGPT/novi/lib/desktop_ui.dart), updating decoration container with background color, rounded borders, padding, and soft box shadows.
- [x] Verification:
  - `flutter analyze`: clean (0 issues).
  - `flutter test`: all 29 tests pass across `test/widget_test.dart`, `test/library_ui_test.dart`, and `test/workspace_test.dart`.
  - Added comprehensive automated test in [test/widget_test.dart](file:///Users/chastedjaziri/Documents/ChatGPT/novi/test/widget_test.dart) covering all 5 popovers, tool selection, font size changes, font family selection, alignment toggles, line height stepper/slider/switch, and text box preset/advanced switches and steppers.

## Next
Confirm material feel and pressure with a physical tablet in the normal Mac app. Continue the outstanding desktop acceptance checks.

## Modular architecture guidance and compatibility boundaries — 2026-10-16
- [x] Added `docs/CODE_ARCHITECTURE.md` with the preferred 200–400 line range, 500-line soft ceiling, responsibility boundaries, tool contract expectations, and migration rules.
- [x] Added `docs/AI_CODING_GUIDE.md` with the required inspection, reuse, testing, file-size, commit, and progress-update checklist for AI-assisted changes.
- [x] Added `tool/check_file_lengths.dart`. It reports existing Dart files above the soft ceiling without blocking builds and excludes generated/platform directories.
- [x] Added compatibility boundaries under `lib/app`, `lib/core`, `lib/features`, and `lib/shared`, including the initial `ToolDefinition` contract. Existing serialization, rendering, and editor behavior remains unchanged while extraction proceeds incrementally.
- [x] `flutter analyze`: no issues. `flutter test`: all 35 tests pass.
- [ ] Extract the legacy `main.dart`, `workspace_tools.dart`, and `library_ui.dart` responsibilities into the new modules; the checker currently reports these known legacy files as warnings.

## Incremental extraction: persistence and editor tool state — 2026-10-16
- [x] Moved `LibraryStore`, `encodePortable`, and `decodePortable` into `lib/core/persistence/notebook_store.dart` using a compatibility-preserving Dart part boundary. Existing model APIs, JSON keys, archive versions, and callers remain unchanged.
- [x] Extracted `LassoType`, `WritingMode`, `PenType`, `EraserType`, and `EditorTool` into `features/editor/tools/common/tool_types.dart`; the legacy toolbar re-exports them for compatibility.
- [x] Added independent state modules for pen, pencil, highlighter, tape, and eraser under `features/editor/tools`, including serializable settings and listener-based updates.
- [x] Added focused `test/tool_state_test.dart`; `flutter analyze` is clean and the full suite now passes 38 tests.
- [ ] Continue extracting toolbar dialogs, tool renderers, pointer controllers, and `EditorSession` from `workspace_tools.dart`.

## Incremental extraction: session and stroke boundaries — 2026-10-16
- [x] Extracted `EditorSession` into `features/editor/models/editor_session_impl.dart` using a compatibility-preserving part boundary.
- [x] Added `features/editor/controllers/stroke_controller.dart` for reusable pressure-aware pointer sampling and cancellation.
- [x] Added `features/editor/tools/common/tool_renderer.dart` as the painter/indicator seam for future tool implementations.
- [x] Clean-process verification: `flutter analyze` is clean and the full suite passes 40 tests.
- [ ] Move the large private toolbar dialogs and icon painters from `workspace_tools.dart` into tool-specific modules; hot reload should be replaced by a full restart after Dart library-boundary moves.

## Incremental extraction: writing toolbar painters — 2026-10-16
- [x] Extracted the pen, pencil, highlighter, tape, and shape toolbar painters into `features/editor/tools/common/writing_icon_painters.dart`.
- [x] Updated the writing toolbar and tool controls to use the extracted public painters while preserving appearance and compatibility.
- [x] `flutter analyze`: clean. `flutter test`: all 40 tests pass.
- [ ] Extract the remaining eraser/lasso/text painters and the private tool dialogs into their feature modules.

## Incremental extraction: dialog module boundaries — 2026-10-16
- [x] Added tool-owned dialog entrypoints for pen, tape, shape, lasso/select, eraser, and text popovers under `features/editor/tools`.
- [x] Preserved the existing public dialog classes and callbacks through compatibility exports so toolbar behavior and imports remain stable.
- [x] Added dialog-boundary coverage in `test/tool_dialog_boundaries_test.dart`.
- [x] `flutter analyze`: clean. `flutter test`: all 41 tests pass.
- [ ] Replace the compatibility exports with physically moved dialog implementations and extract the remaining eraser/lasso/text painters.

## Incremental extraction: pen, tape, and shape dialogs — 2026-10-16
- [x] Physically moved `PenMenuDialog` and `showPenMenu` into `features/editor/tools/pen/pen_menu_impl.dart`.
- [x] Physically moved `TapeMenuDialog` and `showTapeMenu` into `features/editor/tools/tape/tape_menu_impl.dart`.
- [x] Physically moved `DrawShapeMenuDialog` and `showDrawShapeMenu` into `features/editor/tools/shape/shape_menu_impl.dart`.
- [x] Legacy `workspace_tools.dart` keeps compatibility exports and part wiring; toolbar behavior is unchanged.
- [x] `flutter analyze`: clean. `flutter test`: all 41 tests pass. The file checker reports `workspace_tools.dart` reduced from 6,216 to 5,406 lines.
- [x] Physically moved eraser type and advanced settings dialogs into `features/editor/tools/eraser` with compatibility-preserving part wiring.
- [x] `flutter analyze`: clean. `flutter test`: all 41 tests pass.
- [ ] Physically move lasso and text dialog implementations, then extract their remaining private painters.


## Writing materials and paper footprints — 2026-10-16
- [x] Added shared nib geometry and distinct fountain, ballpoint, brush, graphite pencil, highlighter and paper tape renderers. New styles store pen subtype/material version; legacy styles retain their renderer.
- [x] Tape responds to width presets; eraser radius is independent of writing width. Paper-local footprints use the active nib geometry and pressure in transformed paper coordinates.
- [x] Connected hold-for-line, require-hold shape recognition and shape-vertex snapping; stroke completion reads captured options. Corrected eraser material filtering.
- [x] Existing automated suite: 29 tests pass. Four added material tests pass: widths/geometry/pressure, deterministic distinct pixels and uniform marker joins, SQLite reopen and both portable formats, generated light/dark comparison.
- [x] Workspace regression covers captured tape options, held pen/shape gestures, material filters, fast eraser crossing and undo/redo, independent toolbar sizes, footprint coordinates on two pages at 50%/100%/150%, stationary-pointer scrolling, Space navigation, paper exit and touch suppression.
- [x] Added ink repaint invalidation coverage: unchanged content skips repaint; in-place points and style edits repaint. Footprints repaint separately from textured ink.
- [x] Final automated suite: 35 tests pass; analysis is clean. Rendered and visually inspected `build/ui-preview/ink-materials.png` on light and dark paper.
- [x] Final native macOS integration: all 30 tests pass, including writing controls, footprints, stationary-pointer scrolling, touch suppression, material filters, fast erasing and undo/redo.
- [ ] Physical stylus pressure/hover, normal-app hands-on acceptance, and Windows/Linux remain unverified.
