# Implementation Plan v2: Connecting the System Pipeline

Derived from `_specs/SPEC-pipeline-v2.md`. Progress is tracked in `todo.md`.

## Order and why

1. **Screenshot harness first** (integration test + sample receipt + `flutter drive` on the iOS simulator). Taking "before" shots proves the harness and that ML Kit runs on the simulator before any feature work depends on it.
2. **Riverpod state** — touches home, review and charts; doing it before the review/charts work means those are written once against the provider.
3. **OCR boxes + ReceiptParser API** — data the review screen needs.
4. **Review & Verification screen** — overlay, line sheet, parse-again.
5. **Animated charts.**
6. Final verification + full screenshot set.

Each step ends with `flutter analyze` + `flutter test` green and a screenshot run (`screenshots/<prefix>-*.png`; final set: `light-*`, `dark-*`).

## Architecture decisions

- Keep flat `lib/`; new code lives in the files that already own the concern (`ocr.dart`, `review_screen.dart`, `charts.dart`, `expense.dart` for the provider). No repository layer: the notifier calls `ExpenseDb` directly.
- `AsyncNotifierProvider` without code generation (no build_runner).
- Box ↔ field highlighting is computed in the review screen from the current field values (a box is "Total" if its text contains the total amount, etc.), so it stays correct after the user edits a field.
- Chart animation: `TweenAnimationBuilder` keyed by the data → no `AnimationController` boilerplate.
- Screenshots via `integration_test` + `flutter drive --driver test_driver/integration_test.dart`; the driver's `onScreenshot` writes into `../screenshots/`. The sample receipt image is generated once with Python/PIL into `integration_test/assets/` and embedded as base64 in `integration_test/receipt_jpg.dart` (the emulator can't read host paths).

## Risks

| Risk | Mitigation |
|---|---|
| ML Kit pods have no arm64-simulator slice | **Happened.** Rosetta route also failed (iOS 26 sims reject x86_64 apps) → switched to Android emulator `Pixel_8`, where real ML Kit runs |
| EXIF rotation makes boxes misaligned | Simulator image is generated upright; real phones: image_picker returns upright JPEGs on iOS; ponytail note in code |
| Integration test wipes the simulator DB | Only ever run on the simulator |
