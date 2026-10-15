# Novi — Complete Product & Development Roadmap

# novi.

One workspace. Every way of thinking.

Open source

Offline first

No account required

Novi will be a universal note-taking and knowledge application for students, developers, artists, professionals, and anyone who wants more than a traditional digital notebook.

It will combine the handwriting experience of Goodnotes, everyday writing and organization tools, mathematical calculation, programming utilities, drawing, and optional specialized workspaces.

The most important product decision is this:

Novi will be a complete application even without an internet connection, an account, a subscription, or an AI model.

Everything essential should run locally.

## 1. Core product principles

These should become non-negotiable requirements for Novi.

| Principle               | Product requirement                                                           |
| ----------------------- | ----------------------------------------------------------------------------- |
| Local ownership         | Notes and attachments live on the user's device.                              |
| No registration         | Users launch Novi and immediately start writing.                              |
| Open formats            | Documents can be backed up, imported, and exported.                           |
| Universal input         | Keyboard, mouse, touch, trackpad, and stylus.                                 |
| Non-destructive editing | Original strokes and source content remain recoverable.                       |
| Modular capabilities    | Scientific, developer, and creative tools are optional, not separate apps.    |
| Privacy                 | No telemetry or network requests without meaningful user control.             |
| Open-source development | Public repository, documented architecture, and contributor-friendly modules. |

### Supported platforms

macOS

First release

Windows

First release

Linux

First release

Android tablets

Following releases

iPadOS / iOS

Following releases

Web

Optional later

Desktop comes first because it makes external graphics-tablet support, keyboard productivity, and advanced calculation workflows easier to validate. We should build the architecture so it can later support native-feeling mobile and tablet interfaces without rewriting the document engine.

## 2. Recommended technology stack

After comparing the available frameworks, I recommend Flutter + Dart, with native platform integrations where necessary.

Flutter officially supports macOS, Windows, Linux, Android, and iOS. Its pointer-event system provides device type, pressure, stylus tilt, and orientation data when available from the underlying platform. Existing open-source handwriting applications such as Saber demonstrate that Flutter is a viable foundation for this category.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://docs.flutter.dev\&sz=32)

Flutter Documentation

+2



| Component           | Technology                       | Responsibility                               |
| ------------------- | -------------------------------- | -------------------------------------------- |
| UI and application  | Flutter / Dart                   | All platform interfaces                      |
| Rendering           | Flutter CustomPainter            | Handwriting and document canvas              |
| Local database      | SQLite + Drift                   | Notebooks, metadata, search, undo history    |
| Asset storage       | Local filesystem                 | Images, PDFs, audio, attachments             |
| Native integrations | Swift, C++, Kotlin               | Advanced tablet input and platform features  |
| PDF engine          | PDFium through `pdfrx`           | PDF viewing and annotation foundations       |
| Math engine         | Embedded local math engine       | Scientific calculations and equation solving |
| State management    | Riverpod                         | Application and workspace state              |
| Import/export       | ZIP + JSON + document converters | Portable backups                             |
| Distribution        | GitHub Actions                   | Desktop builds and release packages          |

Drift supports native SQLite on desktop and mobile, including background database execution. The `pdfrx` project provides cross-platform PDFium-based PDF functionality, though export and annotation capabilities will still need integration work.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://drift.simonbinder.eu\&sz=32)

drift.simonbinder.eu

+2



I would avoid making cloud services, Firebase, Supabase, or a hosted AI API part of Novi's core architecture.

That is a key differentiator from products that require accounts just to create or access notes.

## 3. How the actual notebook should work

Novi should have a unified document system, rather than forcing users to choose between incompatible handwriting, text, math, or programming documents.

A single page could contain all of these together:

Physics — Chapter 2

Newton's Second Law

Calculation

\\[ F = 5\\,\mathrm{kg}\times 3\\,\mathrm{m/s^2} \\]

## 15 N

Handwriting + structured math + editable text on one page

This is a conceptual preview of a hybrid Novi page.

### Document structure

Every page should support independent editable objects such as ink strokes, text blocks, equations, code blocks, images, graphs, PDF backgrounds, shapes, and attachments.

The same underlying document model works in every mode. Switching to Developer Mode, for example, changes the available tools and panel layout but does not convert or replace the note.

This avoids a common design problem: forcing users to maintain separate types of notebooks for different subjects.

## 4. Local storage, backups, and imports

Your no-account requirement is absolutely feasible.

I recommend using a local SQLite database for indexing and organization, with original assets stored as local files.

Novi editor

Local files

.novi

One editable document

.novibackup

Full library backup

These would be open, versioned formats, not proprietary locked-down files.

The `.novi` format could be a ZIP archive containing JSON document data, editable vector strokes, images, attachments, and a manifest describing its version.

The `.novibackup` format would contain the user's notebooks, folder structure, page data, and local preferences, with optional encryption.

The export menu should eventually offer PDF, PNG, SVG where appropriate, Markdown, and plain text.

Import should support `.novi`, `.novibackup`, PDF, images, Markdown, and text. Importing another app's PDF export would preserve the visible content, but not automatically reconstruct editable handwriting or text objects.

Most importantly, backup and restore must be implemented in the first usable release, not postponed until the product is popular.

## 5. External drawing tablets and stylus calibration

[Wacom Intuos S CTL-4100 (Màu Đen, Không Bluetooth) | Wacom Store](https://images.openai.com/static-rsc-4/7RcJck_8fgwyQBYi7bCOanxNjIdW9gbpqsAVXZA1j5oEDHEVrJMSKh1Z_3Sl5yf3-RqgiReD111EmcqVyhjdppZPelYQ5UxoV5WqoafMWAw-nz1vzTxosS7pEhcCgn0DTII4pLWyeiT1Yuk8yZ_Gyv8ulZpMiBkG0pIenwxKcTs?purpose=inline)

[Huion Kamvas Pro 16 (2.5K) - 15.8-Inch QHD Pen Display](https://images.openai.com/static-rsc-4/Z9hQGdNCEHVQPhYN5I-TYR-5fsgk7CyQs0W9-fcG9vzo7j0CIVv8chQTqI-7HQmT4itlmAJYvb75brTpks_RIZiHLe-1d-snUTkvRZS0D1fc-7qs7wxRtRMu7-zW52HkugHBa-CT-44Gx5balyBMXMpY1LgswoBcEIzOo1t2ptU?purpose=inline)

[XP-Pen Deco 03 Mesa Digitalizadora | PcComponentes.pt](https://images.openai.com/static-rsc-4/o5AIrsU28717P0VvK7-8OwofN2Rcd-Oq4fFFOXNS3W4MkPM8BJ6gyvN-_Maz_8iMRMmjH9F8Zk-pzaciuTmjPW3QCC01UtloaJCsGa1ahhuUEsoaou0EGTLybdMK_16cIaWXN1r5hoDZ29NLPv3cRe4ZZrx0oTpIN7basiEUcdY?purpose=inline)

8

Novi should support external devices from manufacturers such as Wacom, Huion, and XPPen, provided their drivers expose usable pointer or tablet events to the operating system.

The development approach will have three layers.

Layer 1 — Standard pen support: Listen for stylus events from Flutter, including position, pressure, tilt, pointer type, and button states when supplied.

Layer 2 — Native integrations: Add platform adapters when Flutter does not expose enough information. Windows has dedicated pen-event APIs; Linux's libinput exposes tablet pressure, tilt, and tool information.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://learn.microsoft.com\&sz=32)

Microsoft Learn

+1



Layer 3 — Novi Pen Studio: Provide user-adjustable pressure curves, stabilization, nib offset where feasible, pen-button mappings, and input diagnostics.

Hardware screen mapping and device-level calibration normally belong to the manufacturer's driver. Novi should guide users to those settings instead of claiming it can universally recalibrate every graphics tablet.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://www.xp-pen.com\&sz=32)

XPPen

+1



### Novi Pen Studio

Illustrative pen settings

Preview of the controls we could implement

Stroke stabilization

55%

Pressure responsiveness

85%

Writing profile

Natural — preserve every movement

Balanced — smooth without excessive delay

Clean — prioritize stable, polished strokes

Conceptual stroke preview

Actual output will depend on the pen, its driver, and available pressure data.

The physical-pressure curve and stabilization settings can improve writing substantially, especially when using inexpensive drawing tablets.

### Auto-beautify handwriting

This deserves its own feature, but we should distinguish two implementations.

Stroke beautification means smoothing shaky lines, correcting uneven curves, cleaning stroke endpoints, and adjusting spacing while keeping handwriting recognizable as the user's own. This is feasible without AI.

Character-level beautification means understanding letters and words, correcting their shapes, baselines, and proportions. That requires substantially more work in handwriting recognition and personalized transformation.

The first can ship early. The second should be developed experimentally, with previews and undo, because aggressive corrections can change what someone intended to write.

Novi should preserve the original pen strokes even after beautification, so users can always recover their own writing.

## 6. Release-by-release implementation plan

I've prepared a complete, GitHub-ready product specification with engineering tasks, release gates, testing requirements, storage architecture, and proposed directories.

Novi — Product Specification & Roadmap

Markdown document · 273 lines · Intended repository path: `docs/PRODUCT_ROADMAP.md`

&#x20;Download the roadmap

The following is the release sequence I would follow. Each version adds a usable capability rather than waiting to deliver everything at once.

| Release | Focus                | Main deliverable                                                        |
| ------- | -------------------- | ----------------------------------------------------------------------- |
| v0.0.x  | Technical validation | Cross-platform shell, pen-input and storage prototypes                  |
| v0.1.0  | Novi Core            | Local notes, handwriting, typing, automatic saving, backup/import       |
| v0.2.0  | Pen Studio           | Drawing tablets, pressure curves, stabilization, input diagnostics      |
| v0.3.0  | Documents            | PDF annotation, images, shapes, selection and rich text                 |
| v0.4.0  | Beautiful Ink        | Non-destructive automatic handwriting improvement                       |
| v0.5.0  | Calculator           | Complete core scientific calculator, history, variables and conversions |
| v0.6.0  | Advanced modes       | Equation solving, graphing, Developer Mode                              |
| v0.7.0  | Mobile/tablet alpha  | Android and iPad support, optional handwriting recognition              |
| v0.8.0  | Productivity         | Search, templates, flashcards, extensibility foundations                |
| v0.9.0  | Public beta          | Security, performance, accessibility, installation testing              |
| v1.0.0  | Stable desktop       | Reliable, documented, cross-platform release                            |

The v1.0 release should be determined by quality, not an arbitrary date. As an initial planning assumption, a focused desktop alpha could take 2–3 months, while a dependable v1.0 is more realistically a multi-quarter project for a solo developer.

## 7. Scientific and equation calculator

This should be one of Novi's signature capabilities.

I propose three layers of math functionality.

Basic and scientific calculator — v0.5

Illustrative calculator preview

5!

# 120

sin

cos

tan

√

log

ln

x²

xʸ

π

e

n!

1/x

TrigonometryFactorialLogarithm

The illustration previews the interface; it is not a live Novi calculator engine.

Equation calculator — v0.6

Support common linear and quadratic equations, simultaneous linear equations, symbolic simplification, factoring, and selected calculus operations.

Equation example

\\[ x^2-5x+6=0 \\]

Factor and solve

\\[ (x-2)(x-3)=0 \\]

Solutions: \\(x=2,\quad x=3\\)

Results should include verification, supported solution steps, and a button to insert the expression directly into the current note.

Interactive graphing — v0.6

-202400.511.522.533.54

Conceptual function graph

Graphs should support zooming, coordinate inspection, multiple functions, adjustable parameters, and insertion into documents.

For the computational backend, [math.js](https://mathjs.org/docs/) is a strong candidate for numeric calculations, units, matrices, and expression parsing. [Algebrite](https://algebrite.org/) provides symbolic mathematics, including supported derivatives, integrals, and algebraic transformations, without a hosted service. Both would require a bundled JavaScript execution layer inside Flutter.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://mathjs.org\&sz=32)

Math.js

+2



We should test that architecture before deciding on the final mathematical backend.

## 8. Developer and other optional modes

Novi's ordinary notebook must remain simple. Additional modes should expose contextual tools rather than overcrowding the default toolbar.

Everyday Mode

Writing, checklists, tables, handwriting, journaling, to-do lists, images, and meeting notes.

Scientific Mode

Scientific calculator, equation editor, graphs, formula templates, units, mathematical symbols, and interactive calculations.

Developer Mode

Syntax-highlighted code, Markdown, JSON formatting, regex tools, number-base conversion, technical diagrams, and code snippets. Actual code execution would be a separately secured later feature.

Creative Mode

Brushes, freehand illustrations, shapes, colors, layers, visual brainstorming, and an optional infinite canvas.

Study Mode

PDF annotation, flashcards, lecture notes, linked references, revision checklists, and later optional audio recordings.

## 9. Handwriting recognition without cloud accounts

There is also a realistic route to on-device recognition.

Google's ML Kit Digital Ink Recognition supports local handwriting recognition on Android and iOS. Models must first be downloaded, but recognition then runs on the device without sending handwriting to a recognition server.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://developers.google.com\&sz=32)

Google for Developers

+1



That could support a future feature where users write normally and optionally convert selected text into editable characters. It would not automatically give us identical functionality on Windows, macOS, and Linux; desktop recognition would need a separate model or platform-specific implementation.

I would ship stroke smoothing first, then experimental character beautification, and only then introduce broader handwriting recognition. This order avoids making the entire writing experience dependent on imperfect recognition.

## 10. What we should implement first

Before a polished UI, animations, or advanced AI integrations, I would build one end-to-end scenario:

A user opens Novi for the first time, creates a notebook, writes with a mouse or drawing tablet, adds typed text, closes the application, opens it again, and exports the document to another computer.

When that works reliably, we have the foundation of a real product.

Our first engineering sprint should deliver:

- A Flutter desktop project with macOS, Windows, and Linux targets.
- A minimal document canvas with freehand stroke capture and typing.
- A versioned document model and SQLite persistence.
- Local autosave, undo, and portable export/import.
- An initial hardware input test using an external drawing tablet.

After that, we build the handwriting engine, then PDF annotations, beautification, and mathematics.

## 11. How we'll make Novi contributor-friendly

The repository should be modular from day one. Developers should be able to improve a math solver or add a brush without needing to understand the complete application.

For example, someone could contribute a new handwriting smoothing algorithm, another developer could build a scientific calculator feature, and another could improve Linux stylus compatibility.

We should maintain public specifications for document formats, create a tested-device matrix, label beginner-friendly GitHub issues, and publish a short demonstration with each meaningful release.

The competitive positioning for Novi is clear: a reliable, account-free notebook whose handwritten, typed, mathematical, and programming capabilities work together without locking users into one ecosystem.

And the practical launch target is equally clear: make v0.1.0 genuinely useful before chasing every advanced feature.

Download Novi's complete product and implementation roadmap

That document is ready to serve as the starting product specification for our repository.