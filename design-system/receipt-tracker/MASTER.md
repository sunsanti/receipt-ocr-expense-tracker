# Design System — Receipt Tracker (MASTER)

Source of truth for the UI. Implemented in `receipt_tracker/lib/theme.dart`.
Derived with the ui-ux-pro-max skill (product: *Personal Finance Tracker*), then filtered:
the generated "landing page / glassmorphism / Caveat handwriting" suggestions were rejected —
this is a mobile utility app where numbers must be read fast and blur hurts contrast.

## Style
- **Minimalism / Swiss + flat** (skill's secondary style for finance trackers). No blur, no gradients, no shadows on cards — 1px borders instead.
- One accent per screen: the trust-blue primary. Green only means "found / OK".

## Color tokens (semantic, per theme)
| Token | Light | Dark |
|---|---|---|
| primary | `#1E40AF` | `#60A5FA` (lifted: `#1E40AF` fails contrast on dark) |
| primaryContainer / on | `#DBEAFE` / `#1E3A8A` | `#1E3A8A` / `#DBEAFE` |
| tertiary (success) | `#059669` | `#34D399` |
| error | `#DC2626` | `#F87171` |
| surface (page bg) | `#F8FAFC` (no pure white) | `#0F172A` |
| card (surfaceContainerLowest) | `#FFFFFF` | `#192134` |
| onSurface / onSurfaceVariant | `#0F172A` / `#475569` | `#F8FAFC` / `#94A3B8` |
| outlineVariant (borders) | `#E2E8F0` | `#334155` |

Category identity = **color + icon** (never color alone): Food `#EA580C` restaurant · Study `#7C3AED` school · Travel `#0891B2` commute · Gear `#65A30D` devices · Entertainment `#DB2777` activity. Lifted 35% toward white in dark mode.

OCR box roles = **color + text tag**: Total `#059669` · Date `#2563EB` · Merchant `#7C3AED` · other text `#D97706`.

## Typography
- **Lexend** (headings, titles, big amounts) + **Source Sans 3** (body/labels) — skill pairing "Corporate Trust": readable, finance-appropriate, both cover Vietnamese.
- Bundled variable TTFs in `assets/fonts/` (offline app — no runtime font fetching). Weight set via `FontWeight` **and** `FontVariation.weight` (`weight()` helper).
- Body 16/1.5, small 13, labels 600. Amounts use **tabular figures**.

## Spacing, shape, motion
- 4/8 rhythm: `Space.xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32`.
- Radius: cards 16, inputs/buttons 12, sheets 24 (top), summary card 20.
- Touch targets ≥ 48dp (`MaterialTapTargetSize.padded`, buttons 52 high).
- Motion: `fast 150ms · medium 300ms · chart 700ms easeOutCubic`; `Motion.of()` returns zero when the OS asks for reduced motion.
- Content width capped at 640 (`ContentWidth`) for tablets.

## Screens
- **Expenses:** summary card (month total, receipt count, % vs last month with trend icon) → list grouped by day with day totals; swipe to delete + Undo, also a Delete button on the edit screen (swipe is not the only path).
- **Review & verify:** "Scanned receipt" card (photo + tappable OCR boxes with tags, legend, show/hide, zoom, *Verification* chips found/missing) → "Details" card (icon-prefixed fields, category chips) → "Recognized text" (editable + Parse again) → sticky full-width **Save** bar (safe-area aware). Nothing is written to SQLite before Save.
- **Camera:** full-bleed viewfinder, dimmed outside a receipt-shaped frame with corner brackets, yellow focus ring on tap, flash mode as icon + text label, 76 dp shutter with a 'Take photo' label.
- **Charts:** stat tiles (this week, 8-week avg) → weekly bar chart (tap a bar to choose the week; selected bar highlighted, others muted) → donut ≤5 slices, largest at 12 o'clock, center total, legend rows with icon, amount, % and share bar (the accessible fallback for the donut).

## Pre-delivery checklist (status)
- [x] No emoji icons; one Material *outlined* family
- [x] Color never the only cue (icons on categories, tags on OCR boxes, check/warning icons on verification chips)
- [x] Light and dark both screenshotted (`screenshots/light-*`, `dark-*`, incl. camera)
- [x] Reduced motion respected for charts
- [x] Icon buttons have tooltips (accessible names); OCR boxes have semantics labels
- [x] Safe areas: bottom Save bar in `SafeArea`; list bottom padding clears the FAB
- [ ] Largest system text size and tablet landscape not yet screenshotted
