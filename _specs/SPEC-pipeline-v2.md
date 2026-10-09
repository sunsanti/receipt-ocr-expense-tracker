# Spec v2: Connecting the System Pipeline (Mini-Project 3)

Extends `SPEC-receipt-ocr-expense-tracker.md`. Only the changes are listed here; everything else in v1 still holds.

## Brief (v2)

```
Camera Capture  →  ML Kit OCR       →  ReceiptParser
(image_picker)     TextRecognizer      (Regex Engine)
                                             ↓
Animated Charts ←  Riverpod State   ←  Local SQLite DB
(CustomPainter)    NotifierProvider    (sqflite CRUD)
```

**Key requirement:** OCR output is raw and noisy. The app must have a **Review & Verification Screen** where students can manually inspect the **bounding values** and correct OCR mistakes **before** committing records to SQLite.

## Changes

### 1. `ReceiptParser` (Regex Engine)
- Parser exposed as `ReceiptParser.parse(String text) → ParsedReceipt` (was a top-level `parseReceipt`). Rules unchanged.
- Small helpers used by the review screen are public: `amounts(line)`, `ReceiptParser.dateIn(line)`.

### 2. ML Kit OCR keeps the bounding boxes
- `recognizeText(path)` returns `OcrResult { String text; List<OcrLine> lines; Size imageSize }`.
  - `OcrLine = (String text, Rect box)` from `TextLine.boundingBox`, in image pixels.
  - `imageSize` = decoded image size, so boxes can be scaled onto the photo.
  - `text` is the row-joined text (v1 `joinRows`), fed to the parser.

### 3. Review & Verification Screen
Nothing reaches SQLite until the user taps **Save** on this screen (unchanged rule, now explicit).
- **Photo with bounding-box overlay**: every OCR line is drawn as a box (a positioned widget, so each box is tappable and has a semantics label) over the receipt photo.
  - Boxes that produced a field are color-coded: **Total**, **Date**, **Merchant** (legend under the photo).
  - Toggle to hide the overlay. Tap photo area → fullscreen zoom (v1) keeps working with the overlay.
- **Tap a box** → bottom sheet showing the line's text (editable, to fix OCR typos) and its bounding values (`x, y, w, h` in px), with actions **Use as Total / Date / Merchant**. Total/Date are parsed from the (corrected) text; a snackbar says so when nothing valid is found.
- **Recognized text** panel becomes editable, with a **Parse again** button that re-runs `ReceiptParser` on the corrected text and refills the fields.
- Form fields (Merchant, Total, Date, Category, Note) and validation as in v1.

### 4. State: Riverpod `AsyncNotifierProvider`
- Add `flutter_riverpod` (v1 boundary "ask first: state-management package" — now required by the brief).
- `expensesProvider = AsyncNotifierProvider<ExpensesNotifier, List<Expense>>`:
  - `build()` loads `ExpenseDb.all()`.
  - `save(Expense)`, `delete(Expense)` write to SQLite (CRUD) then refresh state.
- Home list, monthly total and Charts all `ref.watch(expensesProvider)`; the Review screen calls `ref.read(expensesProvider.notifier).save(...)`. No more manual `_reload()` / passing lists down.

### 5. Animated charts (`CustomPainter`)
- Bar chart: bars grow from the baseline (≈600 ms, ease-out) on first show and whenever the data changes.
- Donut: segments sweep in clockwise; replays when the selected month or data changes.
- Painters take a `progress` (0–1); `shouldRepaint` includes it.

## Testing
- Unit: parser (now via `ReceiptParser.parse`), `joinRows`, chart aggregations (existing 12 tests stay green).
- New unit: bounding-box helpers (which OCR line produced Total / Date / Merchant).
- `ExpensesNotifier` is exercised end-to-end by the integration test (seed via `save`, delete via swipe) on the simulator — no extra ffi test dependency.
- **Screenshots**: `integration_test/screenshots_test.dart` run with `flutter drive` on the Android emulator (ML Kit has no arm64 iOS-simulator build); it seeds demo expenses, runs real ML Kit OCR on a sample receipt image, and writes PNGs to `../screenshots/`.

## Boundaries
- **Always:** on-device only; user confirms on Review before any DB write.
- **Never:** auto-save OCR output; send images/text off the device.
- **Out of scope:** storing receipt photos, line-item extraction, CSV export.

## Spec ↔ brief check

| Brief item | Covered by | OK |
|---|---|---|
| Camera Capture (image_picker) | v1 home bottom sheet (camera / gallery / manual) | ✅ |
| ML Kit OCR TextRecognizer | §2 — `TextRecognizer(script: latin)`, now also returns boxes | ✅ |
| ReceiptParser (Regex Engine) | §1 — `ReceiptParser.parse`, pure Dart, tested | ✅ |
| Parser → Local SQLite DB (sqflite CRUD) | `ExpenseDb` create/read/update(upsert)/delete, called only from the notifier | ✅ |
| SQLite → Riverpod State NotifierProvider | §4 — `AsyncNotifierProvider` (the async `NotifierProvider`, since the DB read is async) | ✅ |
| Riverpod → Animated Charts (CustomPainter) | §5 — painters with `progress`, driven by the provider's data | ✅ |
| Review & Verification Screen: inspect bounding values | §3 — box overlay + per-line sheet with `x, y, w, h` | ✅ |
| …correct OCR mistakes | §3 — edit line text → use as field; edit raw text → Parse again; edit fields | ✅ |
| …before committing to SQLite | Save button is the only path to `save()`; scanning never writes | ✅ |

Gap found while checking: v1 drew no boxes and discarded `boundingBox` after `joinRows`, so "inspect the bounding values" was not met → §2 + §3 added. v1 charts were static → §5. v1 used `setState` → §4.
