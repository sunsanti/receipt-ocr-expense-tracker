# Spec: Receipt OCR & Expense Tracker (Mini-Project 3)

## Objective

VKU students and club managers handle cash receipts every day. Typing the numbers into a spreadsheet is slow and error-prone. The app lets them **photograph a receipt, have the total/date/merchant read automatically on the device, check the values on a review screen, and keep a history with charts**.

- **Primary users:** VKU students tracking their own spending; club managers tracking club spending.
- **Success looks like:**
  - Scanning a clear printed receipt fills in the Total correctly most of the time; Date and Merchant are pre-filled when present.
  - Nothing is saved without the user confirming it on the review screen (OCR is never trusted blindly).
  - All data stays on the phone and works with no network (ML Kit on-device + SQLite).
  - History and charts survive app restarts.
  - Runs on a physical Android phone (and iOS when built on a Mac with Xcode).

## Pipeline (from the brief)

```
Camera Capture  →  ML Kit Text      →  Dart Regex       →  Local SQLite
(image_picker)     Recognition         Parser Engine       (sqflite DB)
                   on-device OCR       Total/Date/Merchant  persistent history
```

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.38 (Dart 3.10), Material 3 |
| Capture | `image_picker` (camera, gallery as fallback) |
| OCR | `google_mlkit_text_recognition` (Latin script, on-device, offline) |
| Parsing | Pure Dart `RegExp` (`lib/receipt_parser.dart`), no packages |
| Storage | `sqflite` + `path` |
| Charts | `CustomPainter` on `Canvas`, no chart library |
| State | Riverpod `AsyncNotifierProvider` (v2, see `SPEC-pipeline-v2.md`) |
| Tests | `flutter_test` for the parser and chart data helpers |

## Screens

1. **Expenses (home)** – total spent this month at the top, list of saved expenses (newest first): merchant, date, category, amount. Tap → edit on the review screen. Swipe → delete (with undo snackbar).
   - FAB **Scan receipt** → bottom sheet: *Camera* / *Gallery* / *Enter manually*.
2. **Review** – receipt photo thumbnail (when scanned), editable fields **Merchant**, **Date** (date picker), **Total** (number), **Category** (dropdown), **Note**. Expandable *Recognized text* panel shows raw OCR so the user can see what was read. Save validates: total > 0, merchant not empty.
3. **Charts** (second tab) – two custom canvas charts:
   - **Bar chart**: spending per month, last 6 months.
   - **Donut chart**: spending per category for the selected month, with legend.

## Parser rules (`parseReceipt(String text) → ParsedReceipt`)

Input is the full OCR text (lines in reading order). Receipts are mostly Vietnamese (VND) but English ones must work too.

- **Total**
  1. Look for lines containing a total keyword (case/diacritic-insensitive): `tổng cộng`, `tổng tiền`, `tổng thanh toán`, `thanh toán`, `cộng tiền`, `thành tiền`, `total`, `grand total`, `amount due`, `amount`. Exclude `subtotal`, `tạm tính`, `tiền thừa`/`change`, `tiền khách đưa`/`cash`.
  2. Take the amount on that line, or on the next line if the keyword line has none. Prefer the strongest keyword (`grand total`/`tổng thanh toán`/`tổng cộng` over `total`/`thành tiền`); if several, prefer the last one on the receipt.
  3. Fallback: the largest amount in the whole text.
- **Amount format**: `125.000`, `125,000`, `1.250.000đ`, `125000 VND`, `$12.50`, `12,50`. A `.`/`,` followed by exactly 3 digits is a thousands separator; followed by 1–2 digits at the end is a decimal part. Stored as an integer amount (VND has no fractional unit; decimals are rounded).
- **Date**: `dd/mm/yyyy`, `dd-mm-yyyy`, `dd.mm.yyyy`, `dd/mm/yy`, `yyyy-mm-dd`, also `Ngày 12 tháng 3 năm 2025`. Invalid dates (e.g. 31/02) are ignored. Default: today.
- **Merchant**: first line among the top 5 that has ≥3 letters and is not a date, amount, phone, address (`đc`, `địa chỉ`, `address`, or a line starting with a house number), tax/invoice line (`mst`, `hóa đơn`, `invoice`, `receipt`, `tel`, `hotline`). Default: empty (user types it).

## Data Model (SQLite, table `expenses`)

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `merchant` | TEXT NOT NULL | |
| `amount` | INTEGER NOT NULL | VND, > 0 |
| `date` | TEXT NOT NULL | ISO `yyyy-mm-dd` (sortable, groupable by `substr(date,1,7)`) |
| `category` | TEXT NOT NULL | one of: Food, Transport, Study, Club, Other |
| `note` | TEXT | optional |
| `raw_text` | TEXT | OCR output, kept for re-checking |

DB file `expenses.db` in `getDatabasesPath()`, schema version 1.

## Platform setup

- **Android:** `minSdk` ≥ 21 (Flutter default is higher, OK). No camera permission declaration needed for `image_picker` (it uses the system camera intent). Release builds need `-dontwarn` rules in `android/app/proguard-rules.pro` for the unbundled ML Kit scripts.
- **iOS:** deployment target 15.5, `armv7` excluded in Podfile (ML Kit requirement); `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` in `Info.plist`.

## Commands

```bash
cd receipt_tracker
flutter pub get
flutter test                 # parser + chart data tests
flutter analyze
flutter run                  # on a connected phone (USB debugging on)
flutter build apk --release  # → build/app/outputs/flutter-apk/app-release.apk (~80 MB, all ABIs)
flutter build apk --release --split-per-abi  # smaller per-phone APKs
```

## Boundaries

- **Always:** keep everything on-device; require user confirmation before saving; keep the parser pure Dart and covered by tests.
- **Ask first:** adding a backend/cloud sync, login, a state-management or charting package, multi-currency.
- **Never:** send receipt images or text off the device; auto-save OCR output without review.

## Out of scope (add when needed)

- Storing the receipt photo permanently (only shown during review; add with `path_provider` copy if history needs photos).
- CSV/spreadsheet export, cloud sync, multiple users/clubs, budgets.
- Line-item extraction.

## Open questions

- Should club managers' expenses be separated from personal ones (a "wallet"/club field)? Currently one list, use Category `Club`.
- Export to CSV for the club treasurer? Not requested in the brief.
