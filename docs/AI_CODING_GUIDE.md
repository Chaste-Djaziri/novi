# AI coding guide

Use this checklist for every AI-assisted change in Novi:

1. Read `AGENTS.md`, `docs/PROGRESS.md`, and `docs/CODE_ARCHITECTURE.md`.
2. Search for an existing widget, painter, model, controller, or tool before
   creating a new one.
3. Keep new Dart files in the 200–400 line range and below the 500-line soft
   ceiling. Extract a responsibility before extending a large legacy file.
4. Keep models, persistence, rendering, interaction, and UI in their own
   layers.
5. Put repeated UI in `lib/shared/widgets`; put tool-specific behavior in its
   `lib/features/editor/tools/<tool>` module.
6. Add or update focused tests for the behavior changed.
7. Run `dart run tool/check_file_lengths.dart`, `flutter analyze`, and the
   relevant Flutter/native tests.
8. Commit each coherent edit separately. After a verified step, update
   `docs/PROGRESS.md` and commit that documentation change separately.
9. End the work session with a concise Finished / Current / Next note.
