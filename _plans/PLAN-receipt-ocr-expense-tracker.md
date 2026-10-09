# Implementation Plan: Receipt OCR & Expense Tracker

Derived from `_specs/SPEC-receipt-ocr-expense-tracker.md`.

## Overview

Build the Flutter app in four phases following the brief's pipeline: parser first (pure Dart, testable without a phone), then storage, then the capture → OCR → review flow, then charts. Each phase leaves the app runnable.

## Architecture Decisions

- **Flat `lib/`, one file per concern**: `receipt_parser.dart`, `expense.dart` (model + `ExpenseDb`), `ocr.dart`, `main.dart` (home), `review_screen.dart`, `charts.dart`. The app is small; no layers/repositories/DI.
- **Parser is a pure function** of the OCR string, so it is unit-tested on desktop with sample receipt texts.
- **`setState` only.** Home reloads from SQLite after Review returns `true`.
- **Charts are `CustomPainter`s** fed by plain aggregate lists (`monthlyTotals`, `categoryTotals`) computed in Dart, which are tested separately from painting.

## Task List

### Phase 1: Foundation + Parser

- [x] **Task 1: Project scaffold**
  - `flutter create --org vn.edu.vku receipt_tracker` (android, ios); add `image_picker`, `google_mlkit_text_recognition`, `sqflite`, `path`.
  - **Acceptance:** `flutter analyze` clean.
- [x] **Task 2: Regex parser engine** — `lib/receipt_parser.dart`
  - Amount normalization, total keyword ranking, date formats, merchant heuristic (spec "Parser rules").
  - **Acceptance:** `test/receipt_parser_test.dart` covers VN supermarket, VN café, English receipt, receipt without keyword (fallback), invalid date, amount formats.
  - **Verification:** `flutter test`

### Checkpoint: parser tests green

### Phase 2: Storage

- [x] **Task 3: Expense model + SQLite** — `lib/expense.dart`
  - `Expense` with `toMap/fromMap`; `ExpenseDb` with `all()`, `save()` (upsert: insert/update/undo-restore), `delete()`.
  - **Acceptance:** data persists across app restarts (manual check on device).

### Phase 3: Capture → OCR → Review

- [x] **Task 4: OCR wrapper** — `lib/ocr.dart`: `recognizeText(path)` with `TextRecognizer(script: latin)`, closed after use. `joinRows()` rebuilds visual rows from line bounding boxes, because ML Kit returns the label column and the price column as separate blocks (tested in `test/ocr_test.dart`).
- [x] **Task 5: Home screen** — list, monthly total, swipe-to-delete + undo, FAB bottom sheet (Camera / Gallery / Manual).
- [x] **Task 6: Review screen** — photo, editable fields pre-filled from parser, raw text panel, validation, save/update.
  - **Acceptance:** scan → review → save → appears on home; edit existing works; cancel saves nothing.
- [x] **Task 7: Platform config** — iOS Podfile 15.5 + armv7 exclusion, Info.plist usage strings; Android minSdk check.

### Checkpoint: end-to-end flow on a physical phone

### Phase 4: Charts

- [x] **Task 8: Aggregations** — `monthlyTotals(expenses, months: 6)`, `categoryTotals(expenses, month)`; tested.
- [x] **Task 9: Canvas charts** — `BarChartPainter` (last 6 months, labels + values), `DonutChartPainter` (per category + legend), month selector.
  - **Acceptance:** charts redraw after adding/deleting an expense; empty state shown with no data.

### Checkpoint: release build

- [x] `flutter analyze` clean, `flutter test` green (12 tests)
- [x] `flutter build apk --release` succeeds (needed `android/app/proguard-rules.pro`: R8 failed on the plugin's references to the unbundled CJK/Devanagari recognizers)
- [ ] Install on a phone and scan a real receipt (manual)

## Risks

| Risk | Mitigation |
|---|---|
| OCR misreads Vietnamese diacritics (Latin model) | Keyword matching strips diacritics and tolerates common OCR swaps; user always confirms on Review |
| Wrong total picked (subtotal, cash given, change) | Exclusion list + keyword ranking + largest-amount fallback; tests per receipt style |
| `.`/`,` separator ambiguity | 3-digit-group rule documented and tested |
| iOS build needs Mac + Xcode 15.3+, 15.5 target | Podfile configured; Android is the primary demo device |
