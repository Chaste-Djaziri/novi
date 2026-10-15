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

1. Choose **New notebook**.
2. Use **Draw** to write with a mouse or stylus, or **Type** to edit text.
3. Undo and redo using the toolbar buttons.
4. Wait for **Saved locally**, then close and reopen Novi.
5. Use the top-right menu to export or import a notebook, back up the library, or restore a backup.

Each notebook currently has one fixed-size page with an editable text area and original ink strokes. Pressure affects stroke width when provided by the device. Pen calibration, advanced input handling, multiple pages, rich text, and attachments are later work.

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
