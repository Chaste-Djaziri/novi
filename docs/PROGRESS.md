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
The first technical alpha is implemented. Automated checks and the macOS build/launch pass. Hands-on acceptance is the current step; this is not yet a release-quality v0.1.

## Verification — 2026-10-15
- `flutter analyze`: no issues.
- `flutter test`: all 3 tests pass. Covers notebook creation, typing, drawing, undo/redo, text and ink after workspace recreation, SQLite close/reopen, both portable formats, multi-notebook restore preserving existing content, and rejection of a future version.
- `flutter run -d macos --no-resident`: exit 0; built and launched the native macOS application using Metal rendering.
- Original ink points and pressure are stored. Pressure-based rendering is implemented; physical tablet behavior is not verified.
- macOS sandbox allows user-selected read/write files. Native file-dialog interactions have not been exercised.

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

## Next
Finish the native Mac acceptance journey above, recording results here. Then address findings before advancing to Pen Studio. Keep each edit committed individually and update this checklist after verified progress.
