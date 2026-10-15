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

1. Choose **New**, select Notebook, Whiteboard, Text document, or Quick note, then name it and select **Create**.
2. Use **Draw** to write with a mouse or stylus, or **Type** to edit text.
3. Undo and redo using the toolbar buttons.
4. Wait for **Saved locally**, then close and reopen Novi.
5. Use **Document style** to change the cover, paper pattern, paper tone, or orientation.
6. Return to **Documents** to search, filter by type, switch grid/list views, or star favorites. Import and library backups are available here; export is in the editor menu.

The interface uses a black and grayscale theme with a white novi. wordmark. Documents have grayscale covers and Blank, Dotted, Squared, Ruled, or Wide ruled paper, with White, Gray, or Dark tones. Style choices and favorites are saved locally and included in portable files. Existing documents load with default styles.

Each document currently has one fixed-size page with an editable text area and original ink strokes. Pressure affects stroke width when provided by the device. Whiteboards start in landscape with dotted paper; they are fixed pages rather than infinite canvases. Text documents open in typing mode. Quick notes use the same text-and-ink editor. Pen calibration, advanced input handling, multiple pages, rich text, recording, photos, and attachments are later work.

Edits save to SQLite in the operating system's application-support directory. No account, cloud service, telemetry, or runtime network access is used by the application. Undo history is limited to the current session and notebook selection.

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
