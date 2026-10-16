# novi.

One workspace. Every way of thinking.

An early desktop notebook: local, offline, and account-free.

## Start

Install Flutter, then run:

```sh
flutter pub get
flutter run -d macos
```

Windows and Linux runners are scaffolded but have not been tested. Build them on their respective operating systems.

## Your first notebook

1. Choose **New → Notebook**, name and style it, then select **Create**. Other creation types remain visible as Coming later; existing documents of those types can still be opened or imported.
2. Use **Draw** to write with a mouse or stylus, or **Type** to edit text.
3. Use the workspace toolbar for pen, highlighter, stroke eraser, rectangular ink selection, typing, or hand/pan. Select ink and drag it to move, or use Delete to remove it. Undo and redo apply to these edits.
4. Adjust stroke width and grayscale ink shades, or text size and bold. Mouse wheel and trackpad scrolling work in every tool, including over text. Use Space-drag or middle-button drag to pan; pinch and zoom controls remain available. Hand appears when a tablet is detected.
5. Wait for **Saved locally**, then close and reopen Novi.
6. Use **Document style** to change the cover, paper pattern, paper tone, or orientation.
7. Return to **Documents** to search, filter by type, switch grid/list views, or star favorites. Import and library backups are available here; export is in the editor menu.

The interface uses a black and grayscale theme with a white novi. wordmark. Documents have grayscale covers and Blank, Dotted, Squared, Ruled, or Wide ruled paper, with White, Gray, or Dark tones. Style choices and favorites are saved locally and included in portable files. Existing documents load with default styles.

Notebooks contain a cover and multiple paper pages. Add a page with the toolbar or continue scrolling past the bottom. In Type mode the paper surface is writable: click an existing row to place the caret, or below existing text to start on a later row. Text baselines follow the paper rules/grid with natural character spacing; larger type spans whole multiples of the row spacing. Blank paper shows temporary writing guides while typing, and guides are never saved as content. Long text continues onto later pages, preserving existing text and ink. Text formatting and paper orientation changes reflow overflowing text.

The centered toolbar preserves a constant-height context bar when changing tools. Calculator, shapes, images, stickers, sticky notes, laser pointer, recording, ruler, equations, graphs, and code tools are visibly planned and disabled. More Tools keeps these options accessible at smaller window sizes. The app remains grayscale.

On macOS, tablet hardware is enumerated at startup and monitored for attachment/removal through IOKit registry notifications. This does not capture raw input or request Input Monitoring. Connection differs from pen proximity; moving the pen away does not disconnect the tablet. Driver-hidden identities can remain unavailable; observed stylus activity reveals Hand with a truthful Pen observed status. There is no simulated connect button. Windows/Linux hardware enumeration is not implemented; mouse navigation and observed-pen fallback remain available. Physical tablet/driver coverage still needs verification.

Edits save to SQLite in the operating system's application-support directory. No account, cloud service, telemetry, or runtime network access is used by the application. Open documents appear as tabs. Switching tabs preserves each document’s active tool, tool settings, typing focus, canvas transform, and undo/redo history during the app session. Closing a tab keeps the saved document in the library. Ink styles and document-wide text formatting are saved and exported; open tabs are saved; view/history state remains session-only.

Outside typing mode, P selects pen, B highlighter, E eraser, V selection, T text, and H selects Hand when tablet/pen support has been detected. Delete/Backspace removes selected ink. Cmd/Ctrl+Z and Cmd/Ctrl+Shift+Z undo/redo workspace edits. Text formatting currently applies to the whole page text area; the eraser removes whole strokes. Selection operates on ink, not text.

Restore and import add copies without overwriting existing notebooks. Backups currently include all notebooks; there are no library preferences or attachments yet. Portable files are unencrypted ZIP archives with a version-1 JSON manifest. Keep them private as appropriate for their contents.

## Verification

```sh
flutter analyze
flutter test
flutter test integration_test/notebook_test.dart -d macos
flutter run -d macos --no-resident
```

Automated checks cover editing, undo/redo, drawing, reopening SQLite, and document/backup archive round trips. The integration command runs those scenarios inside the native Mac application using temporary test libraries. macOS uses the system SQLite library; Windows and Linux retain bundled SQLite. After changing native dependencies, stop the running app before rebuilding. Actual tablet hardware, native file dialogs, and Windows/Linux builds still need hands-on verification.

Follow [the progress checklist](docs/PROGRESS.md) for current work and [the product roadmap](docs/PRODUCT_ROADMAP.md) for the longer-term direction.
