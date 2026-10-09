# TODO — Mini-Project 3 v2 (Connecting the System Pipeline)

Screenshots: `screenshots/`

## 0. Spec & plan
- [x] Write spec v2
- [x] Check spec against the brief (table in spec)
- [x] Write plan + this todo

## 1. Screenshot harness
- [x] Generate sample receipt image (`integration_test/assets/receipt.png`, embedded as `receipt_jpg.dart`)
- [x] `integration_test/screenshots_test.dart` + `test_driver/integration_test.dart`
- [x] ~~iOS simulator~~ → ML Kit has no arm64-simulator slice and iOS 26 sims refuse x86_64 apps. **Using Android emulator `Pixel_8` (API 36)** — real ML Kit OCR runs there.
- [x] Take "before" screenshots (removed later; superseded by the final set)
  - Found: OCR'd date came back as today instead of 08/10/2026 (parser is fine on clean text → OCR noise). Check raw text in step 4.

## 2. Riverpod state
- [x] Add `flutter_riverpod` 3.3, wrap app in `ProviderScope`
- [x] `expensesProvider` (`AsyncNotifierProvider`) with `save` / `delete` (`lib/expense.dart`)
- [x] Home + Charts watch provider; Review saves via notifier; removed `_reload`
- [x] analyze + test green (no visual change → no separate screenshots)

## 3. OCR boxes + ReceiptParser
- [x] `ReceiptParser.parse` / `totalIn` / `dateIn` (+ callers/tests updated)
- [x] `recognizeText` → `OcrResult` (text, lines with boxes, EXIF-correct image size)

## 4. Review & Verification screen
- [x] Bounding-box overlay, color-coded Total/Date/Merchant + legend + hide toggle + zoom
- [x] Tap box → sheet: editable text, `x,y,w,h`, Use as Total/Date/Merchant
- [x] Editable recognized text + "Parse again"
- [x] Unit test `fieldOf` (box ↔ field matching)
- [x] Screenshots of the review screen (removed later; superseded)
- [x] Raw text revealed the date bug: ML Kit read `08/1 0/2026` → parser retries without stray spaces (+ test)

## 5. Animated charts
- [x] `progress` in both painters, `TweenAnimationBuilder` keyed by data (`animatedPaint`)
- [x] Widget test: painters mid-animation + settle
- [x] Screenshots mid-animation (`light-02-charts-animating`) + final

## 6. Final
- [x] `flutter analyze` clean, `flutter test` green (14 tests), integration tour green on emulator
- [x] Full screenshot set (superseded by the redesign set)

## 7. UI redesign (ui-ux-pro-max)
- [x] Design system → `design-system/receipt-tracker/MASTER.md` (Swiss/flat, finance palette, Lexend + Source Sans 3 bundled)
- [x] `lib/theme.dart`: light/dark tokens, spacing/motion tokens, `ContentWidth`, `CategoryBadge`
- [x] Home: summary card + day-grouped list + richer add sheet + empty state
- [x] Review: sectioned cards, tagged OCR boxes, verification chips, category chips, sticky Save bar, Delete on edit
- [x] Charts: stat tiles, tappable highlighted bars, donut + share-bar legend, reduced motion
- [x] analyze clean, 14 tests green, tour green in light + dark → `screenshots/light-*`, `dark-*`
- [x] Old screenshot sets deleted; current set re-shot on the final code: `screenshots/light-*` (12) + `screenshots/dark-*` (12)

## 8. Core spec gaps (camera, thumbnails, categories, weekly chart, OCR timing)
- [x] In-app camera (`camera`): live viewfinder, flash toggle (off/auto/on/torch), tap-to-focus + exposure with focus ring, receipt frame overlay → photo cropped to the frame (`receipt_image.dart`, isolate) before OCR
- [x] Receipt thumbnails cached in app documents `thumbs/` (480 px), `thumb_path` column (file name only), DB schema v2 migration, orphan cleanup at startup
- [x] Categories → Food / Study / Travel / Gear / Entertainment (migration: Transport→Travel, Club/Other→Entertainment; tested on an in-memory SQLite)
- [x] Weekly spending bar chart (last 8 weeks, Monday-start, tap a bar → donut for that week)
- [x] OCR time measured and shown on the review screen; single long-lived recognizer
- [x] RECORD_AUDIO removed from the merged Android manifest (camera plugin declares it, app never records)
- [x] 19 unit tests green; tour (incl. camera capture + crop) green in light + dark → 28 screenshots
- [x] Release v1.1.0 (APKs) + GitHub Pages redeployed
