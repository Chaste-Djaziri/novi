# Novi code architecture

Novi is organized by responsibility and feature. New code should make the
smallest focused change possible and keep behavior easy to locate.

## File-size guide

- Prefer **200–400 lines** per Dart file.
- Treat **500 lines as a soft ceiling**. A file above it needs an extraction
  note in its header or in the progress log.
- Generated files and native platform files are exempt.
- This is a maintenance guide, not a build failure. Existing large files are
  reduced incrementally.

Run `dart run tool/check_file_lengths.dart` to report files over the ceiling.

## Responsibilities

- Models describe data and serialization only.
- Persistence owns SQLite and portable-file I/O.
- Controllers coordinate state and side effects.
- Renderers and painters draw; they do not save data.
- Widgets compose UI and emit user intent.
- Tool modules own one editor tool's state, pointer behavior, options UI,
  indicator, painter/style metadata, and focused tests.
- Reusable UI belongs in `lib/shared/widgets`; feature-only UI stays with its
  feature.

Before adding code, search for an existing component or controller. Split a
large file before adding an unrelated responsibility to it.

## Feature boundaries

`lib/core` contains reusable models, persistence, input, rendering, and layout.
`lib/features` contains user-facing library and editor behavior. The editor's
tools are isolated below `features/editor/tools`. `lib/shared` contains
cross-feature widgets, painters, constants, and extensions. Platform code
remains under `macos/`, `windows/`, and `linux/`.

## Adding an editor tool

Implement the `ToolDefinition` contract in a dedicated tool directory. The
tool must define its identifier and label, activation lifecycle, toolbar and
options UI, pointer lifecycle, paper indicator, serializable style metadata,
eraser classification, painter, and focused tests. The editor controller owns
which tool is active; the tool owns how it behaves.

Compatibility exports may point from the new structure to legacy files while an
incremental extraction is in progress. Do not duplicate model or persistence
implementations.
