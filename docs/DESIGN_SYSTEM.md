# Design system

This is the spec for the Salapiya UI redesign (Windows and Android, one Flutter codebase). Every redesign chat follows it. When a chat needs a rule that isn't here, add it here first, then build it.

The pre-redesign design system, including its research and history, is archived at [archive/DESIGN_SYSTEM_pre-redesign.md](archive/DESIGN_SYSTEM_pre-redesign.md). It is not a rule source.

**Scope.** The redesign covers the UI layer of the real-use screens only (the `production` code paths: `lib/app`, `lib/finance`, `lib/shared`, `lib/life`, `lib/local`, `lib/connected`, `lib/design_system`). Demo and gallery screens (`lib/features/*` demo branches, `lib/gallery`, `lib/prototype`) must keep compiling and working, but they are not polished. Models, domain rules, calculations, the database, migrations, sync and auth flows do not change. A UI goal that seems to need such a change goes to the handoff under "Needs approval".

## Contents

1. [Design principles](#1-design-principles)
2. [Platform adaptation (Android vs Windows)](#2-platform-adaptation-android-vs-windows)
3. [Tokens](#3-tokens)
4. [Spacing and alignment rules](#4-spacing-and-alignment-rules)
5. [Component rules](#5-component-rules)
6. [Form help pattern](#6-form-help-pattern)
7. [Wording glossary](#7-wording-glossary)
8. [Dashboard data inventory](#8-dashboard-data-inventory)
9. [Redesign roadmap (temporary)](#9-redesign-roadmap-temporary)
10. [Decision log](#10-decision-log)

## 1. Design principles

1. **A tracker, not a bank.** Salapiya records money activity that happens elsewhere. No label, icon or flow may suggest that the app lends, borrows, pays, sends or holds money. See [§7](#7-wording-glossary).
2. **Calm canvas, purposeful surfaces.** One quiet canvas color. Cards sit on it at one surface level, and overlays (menus, dialogs, sheets) sit one level above. No card inside a card. Every card has one clear job and a title that names it.
3. **One focal value per card.** A card leads with one large value or one chart. Its label is small and muted, and its context line (period, what's included) sits below. Secondary values are smaller and grouped.
4. **Rhythm you can measure.** All spacing, radii, type sizes and colors come from tokens. Gaps between cards are equal. Edges line up across a page. Text is centered vertically in its container and never touches a border. See [§4](#4-spacing-and-alignment-rules).
5. **Color carries meaning.** Purple is the brand and primary-action accent. Status colors (success, warning, error, information) mean status only. Charts use a separate series palette. Meaning never depends on color alone: pair it with an icon, a label or a pattern.
6. **Plain words, help in place.** Say what a thing does in everyday language. When a field or option needs explaining, explain it next to that field ([§6](#6-form-help-pattern)), not in a manual or a pop-up wall of text.
7. **Exact and honest.** Money is shown exactly: full centavos, no `1.2K`-style abbreviation in balances, reviews or totals. Use tabular figures and right-align amounts in columns. Unknown is "Not available yet", never `₱0.00`. Sync state ("saved on this device", "synced") is kept separate from business state (e.g. "waiting for the recipient to confirm"). No fake success and no timer-based "Saved".
8. **Native on each platform, one system.** Windows and Android share components and tokens. Layout and input adapt to the platform ([§2](#2-platform-adaptation-android-vs-windows)).
9. **Accessible by default.** Touch targets are at least 48×48 where touch is possible. Layouts work at 200% text scale without truncating money. Everything works by keyboard with a visible focus ring. Focus is trapped in modals and returns to the trigger. Screen-reader labels are complete. Windows high contrast and reduced motion are respected. Contrast is at least 4.5:1 for text and 3:1 for essential non-text indicators.
10. **Restrained motion.** Hover and press feedback take 100–120 ms. Menus and disclosures take 120–160 ms. Panels take at most 220 ms with ease-out and no bounce. No decorative or looping animation, no animated money values, no shimmer. With reduced motion on, all of these are instant.
11. **Third-party brands follow their owner's rules.** Sign-in and other provider buttons (e.g. Google) follow the provider's official branding, not the Salapiya theme.
12. **Brand stays.** The Salapiya logo and name do not change. Purple stays the accent. Use existing logo assets only; never recolor or redraw them.

### What makes the reference designs feel premium

Distilled from `apps/salapiya/assets/references/` (principles only, not copies):

- **Surface hierarchy:** a soft neutral canvas, white (or near-black) cards with a hairline border or one soft shadow, and no heavy outlines.
- **Equal geometry:** cards in a row share height, padding and radius, and the gutters between them are identical.
- **Hierarchy through size and weight, not color:** large confident numbers, small muted labels, and very few bold weights.
- **Density with breathing room:** generous outer margins and page gutters, tight and consistent grouping inside cards.
- **Data is the decoration:** small bar or line charts, progress bars and status pills instead of illustrations or banners.
- **Table-like lists:** aligned columns, right-aligned amounts, a subtle divider between rows and a quiet hover state.
- **Pill controls:** segmented period filters (Week / Month / Year) and small status pills with an icon and a label.
- **Integrated chrome:** the top bar belongs to the app (brand, navigation context, actions), not to the OS.
- **One accent moment at most per screen:** a single tinted or gradient focal card, never several.

## 2. Platform adaptation (Android vs Windows)

Layout adapts to **available width and text scale**. Platform decides **input and chrome**.

| Width class | Range (logical px) | Navigation | Content columns |
| --- | --- | --- | --- |
| Compact | < 600 | Android bottom dock; Windows: menu button opens the destination chooser | 1 |
| Medium | 600–999 | Collapsed sidebar rail (icons and tooltips) | 1–2 |
| Expanded | 1000–1439 | Expanded sidebar | 2–3 |
| Wide | ≥ 1440 | Expanded sidebar | Up to 4; content max width 1280 (`Space.contentMaxWidth`) |

At text scale ≥ 150%, drop one column class.

| Concern | Windows | Android |
| --- | --- | --- |
| Window chrome | Custom integrated title bar (below). The native caption is removed. | System status bar. Top app bar with the section title, sync status and profile. |
| Primary navigation | Sidebar: logo, five destinations, profile at the bottom | Floating bottom dock with five labelled destinations; a separate + action |
| Back / forward | Title-bar buttons, Alt+← / Alt+→, mouse back/forward buttons | System back gesture or button; no forward |
| Location | Breadcrumb in the title bar (Section › Tab › Page) | Screen title in the app bar; tabs below it |
| Create actions | "New" menu button in the page header | + button above the dock opens a bottom sheet |
| Info control ([§6](#6-form-help-pattern)) | A tooltip on hover and keyboard focus; a click pins it as a popover | Tap opens an anchored popover |
| Dialogs | Centered, width-bounded modal | Centered dialog for confirmations; bottom sheet for choices and short forms; full-screen page for long forms |
| Forms | Centered column, max width bounded | Full width, scrolls, keyboard insets respected |
| Row density | Single-line rows may be 40 px when pointer-only; hover state on rows | Rows at least 48 px; no hover |
| Hover | Required on every interactive element | Not used; pressed state only |
| Keyboard | Every action reachable; Esc closes the top overlay; Ctrl+N opens New | Hardware keyboard works; not required to be optimized |

### Windows title bar (Chat 5)

- **One bar across the full window width**, with app canvas or surface colors from tokens, in light and dark themes. Its height is `Space.titleBarHeight` (40).
- **Left to right:** the logo mark and "Salapiya", then back and forward buttons (disabled when there is no history), then the breadcrumb (current section › tab › page, with each earlier segment clickable), then flexible drag space, then the sync status pill, then the window controls.
- **Sync status pill:** a short label and an icon, e.g. "On this device", "Synced · 2 min ago", "Syncing…", "3 waiting", "Needs review", "Offline". Clicking it opens the sync detail. The text comes from existing runtime state only.
- **Window controls:** minimize, maximize/restore and close, using Windows 11 geometry and glyphs. Close uses the system red on hover. These are OS conventions, so they are an allowed exception to the purple accent.
- **Native behavior must keep working:** drag to move, double-click to maximize, Snap Layouts flyout on maximize hover, Aero Snap, the system menu (Alt+Space), resize borders, DPI changes, multiple monitors, and high-contrast system colors.
- **Native changes are allowed** in `apps/salapiya/windows/runner/` (currently `win32_window.cpp`, `flutter_window.cpp`, `main.cpp`). A windowing package may be added if it is maintained and works offline; state why before adding it.
- **Back/forward history is UI-layer state** over the existing navigation (destination switches and pushed pages). Routes and route names do not change.

## 3. Tokens

All tokens live in `apps/salapiya/lib/design_system/theme.dart`. Widgets read them through the theme and never write literals:

- **Color:** `CraftTheme.of(context).<role>` (a `ThemeExtension`). The Material `ColorScheme` is built from the same roles, so stock widgets match.
- **Type:** `Theme.of(context).textTheme.<role>`.
- **Spacing, radius, motion:** `Space.*`, `Radii.*`, `Motion.*`. Width-dependent spacing takes a `WidthClass` from `WidthClass.of(context)`.

Theme mode follows the existing profile setting (System, Light or Dark; System is the default). High contrast is applied automatically when the OS reports it (`MaterialApp.highContrastTheme` / `highContrastDarkTheme`).

Every text pair below is at least 4.5:1, and borders and chart series are at least 3:1 (WCAG relative luminance). `test/widget_test.dart` ("semantic foreground pairs meet normal-text contrast") checks them in all four theme variants.

### Neutrals and brand

| Role (`CraftTheme`) | Light | Dark | Use |
| --- | --- | --- | --- |
| `canvas` | `#F4F4F7` | `#131318` | App background and title bar |
| `surface` | `#FFFFFF` | `#1C1C23` | Cards, fields, lists |
| `raised` | `#FFFFFF` | `#25242D` | Menus, dialogs, sheets, dock |
| `subtle` | `#EFEEF3` | `#2A2932` | Grouping, read-only and disabled fill |
| `text` | `#1D1B22` | `#F2F1F5` | Main text and amounts (17.0 / 15.1 on surface) |
| `secondary` | `#5E5C68` | `#B9B7C3` | Labels, captions, context lines, disabled text (6.6 / 8.6) |
| `border` | `#7A7886` | `#8D8B99` | Essential control outlines (4.3 / 5.1) |
| `divider` | `#E4E3EA` | `#35343E` | Hairlines and card edges (decorative) |
| `primary`, `focus` | `#6546A3` | `#CABDFA` | Primary action, links, focus ring, selected marker (7.1 / 9.8) |
| `onPrimary` | `#FFFFFF` | `#1E1730` | Text and icons on primary |
| `hover` / `pressed` | `#573A91` / `#4A2F7E` | `#D7CDFB` / `#BBABF3` | Primary fill states |
| `selection` / `onSelection` | `#EEE9F8` / `#4A2F7E` | `#30284A` / `#DDD3FC` | Selected row or chip; the one tinted focal card |
| `modalScrim` | black 44% | black 64% | Modal backdrop |

### Status pairs (foreground / tinted surface)

Status is always shown with an icon and a label too, never by color alone.

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| `tone(success)` | `#146C43` / `#EDF8F1` | `#75D5A5` / `#142B22` | A completed step: synced, confirmed |
| `tone(warning)` | `#8A4B0F` / `#FFF4DF` | `#F3C16B` / `#312716` | Needs review, due soon, incomplete |
| `tone(error)` | `#B42318` / `#FFF0ED` | `#FDA29B` / `#371D22` | Validation failure, destructive action |
| `tone(information)` | `#235EA7` / `#EDF4FF` | `#9AC5FF` / `#19283B` | Explanation, planned information |
| `tone(neutral)` | `secondary` / `subtle` | same | Ordinary information |
| `overdue` | `#A1173F` / `#FDEEF2` | `#FF9DB6` / `#3A1A26` | A debt or bill past due. Rose, so it doesn't read as a form error |
| `owedToYou` | `#0E6A63` / `#E6F5F2` | `#6FD3C7` / `#102E2B` | Money others owe you. Teal, so it doesn't read as "done" |

"You owe" uses neutral `text`; Chat 10 decides whether it needs a role.

### Charts, title bar, high contrast and legacy colors

- **Chart series** (`chartSeries`, in order): violet `#6546A3` / `#CABDFA`, teal `#266C80` / `#79C4D2`, plum `#9A4C72` / `#E6BCD4`, ochre `#80631B` / `#E4C572`, blue `#395EB2` / `#A9BCFF`, neutral `#59616F` / `#B9B9C6` (light / dark).
- **Windows title bar:** `titleBar` (= `canvas`) with `text` and `secondary`. Window controls hover with `windowControlHover` (= `subtle`). Close hovers with `windowCloseHover` `#C42B1C` and a white glyph, following the OS convention.
- **High contrast** (`CraftTheme(highContrast: true)`): `secondary`, `border` and `divider` become `text`, and tinted status surfaces become `surface`. Effects are already off in high contrast.
- **Legacy:** `Palette` (`mint`, `peach`, `lilac`, `ink`, `porcelain`, `midnight`, `violet`, `lavender`) and the craft accents (`warm`, `plum`, `blue`, `focalStart`/`focalEnd`, `latticeEdge`) remain only so existing screens compile. Section chats replace their uses with the roles above; new code must not use them.

### Type scale (Geist)

Geist is the bundled variable font (`assets/fonts/geist/`, OFL 1.1 with the license shipped). It works offline, and all its weights (100–900) render from the one file. Text scales with the system setting. Sizes are the same on Windows and Android.

| Role | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| `displayMedium` | 36 / 44 | 600, tabular | The one focal value on a screen |
| `displaySmall` | 28 / 36 | 600, tabular | Metric tile value |
| `headlineMedium` | 24 / 32 | 600 | Page title |
| `headlineSmall` | 20 / 28 | 600 | Dialog title |
| `titleLarge` | 18 / 26 | 600 | Section title |
| `titleMedium` | 16 / 24 | 600 | Card title |
| `titleSmall` | 14 / 20 | 600 | Row title, emphasis |
| `bodyLarge` | 16 / 24 | 400 | Long reading text, field input |
| `bodyMedium` | 14 / 20 | 400 | Default body |
| `bodySmall` | 12 / 16 | 400 | Captions, helper text, context lines |
| `labelLarge` | 14 / 20 | 600 | Prominent labels |
| `labelMedium` | 12 / 16 | 500 | Pills, tabs |
| `labelSmall` | 11 / 16 | 600, +0.6 tracking | Eyebrow labels, the only role that may be uppercase |

`displayLarge` (45 / 52) and `headlineLarge` (32 / 40) exist for completeness. Amounts outside the display roles add `FontFeature.tabularFigures()`. Button and segmented-control labels use 14 / 20 (`labelLarge` metrics); chip labels use 12 / 16 (`labelMedium`).

### Spacing (`Space`)

- **Scale:** `xxs` 2, `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `xxl` 32, `xxxl` 48. `target` 48 is the minimum touch target.
- **Page and card values** (from [§4](#4-spacing-and-alignment-rules), by `WidthClass`):

  | Token | Compact | Medium / Expanded | Wide |
  | --- | --- | --- | --- |
  | `pageGutter(w)` | 16 | 24 | 32 |
  | `pageTop(w)`, `headerGap(w)` | 16 | 24 | 24 |
  | `sectionGap(w)` | 24 | 32 | 32 |
  | `pageBottom(w)` | 24 + dock height | 32 | 32 |
  | `cardGap(w)` | 12 | 16 | 16 |
  | `cardPadding(w)` | 16 | 20 | 20 |

- **Fixed values:** `cardHeaderGap` 12, `captionGap` 4, `fieldGap` 16, `labelGap` 8, `helperGap` 4, `groupGap` 24, `actionsGap` 24, `dialogPadding` 24, `dialogTitleGap` 12, `pillPadding` 10 × 4.
- **Widths and heights:** `formMaxWidth` 640, `reviewMaxWidth` 760, `contentMaxWidth` 1280 (the Wide content cap), `titleBarHeight` 40, `dialogMaxWidth` 560 (confirmations), `popoverMaxWidth` 320. `pointerTarget` 40 is the control and row height where input is pointer-only (Windows); touch uses `target` 48.
- **`WidthClass`:** compact < 600, medium 600–999, expanded 1000–1439, wide ≥ 1440. It drops one class at text scale ≥ 150%.

### Radius (`Radii`)

`control` 10 (buttons, fields, chips, tooltips), `card` 14, `overlay` 20 (dialogs, sheet top corners, menus, popovers), `pill` 999. `Space.cardRadius`, `controlRadius` and `floatingRadius` (28, the dock) are legacy aliases.

### Elevation

Two levels only:

- **Level 1 (cards):** `surface` with a 1-px `divider` border and no shadow.
- **Level 2 (overlays):** `raised` with `overlayShadow`.
  - Light: black 8% at y4, blur 16, plus black 4% at y1, blur 3.
  - Dark: black 36% at y8, blur 24. In dark, the lighter surface carries most of the separation.

Modals add `modalScrim`.

### Motion (`Motion`)

- **Durations:** `quick` 100 ms (hover, press), `short` 160 ms (menus, disclosures, tooltips), `medium` 200 ms (panels, sheets, dialogs, page transitions).
- **Curves:** `enter` is `Curves.easeOutCubic` and `exit` is `Curves.easeInCubic`. Never bounce.
- **Reduced motion:** always wrap durations in `Motion.of(context, d)`. It returns zero when reduced motion is on, from either the system setting or the profile preference.

## 4. Spacing and alignment rules

These rules are checkable. "Token" means a named value from [§3](#3-tokens). The numbers below are the values; [§3](#3-tokens) names them.

### Tokens only

- No numeric literals for spacing, size, radius, font size or color in widget code. This covers `EdgeInsets.*`, `SizedBox(height|width:)`, `BorderRadius.circular`, `fontSize:`, `Color(0x…)`, `Colors.*` and direct `Palette.*`. Use tokens and `TextTheme` roles.
- **Allowed exceptions:** `0`, a 1-px hairline, layout math derived from tokens, and OS or provider-branding values (window controls, Google button) defined in one place.
- **Check:** `grep -rEn "EdgeInsets\.[a-zA-Z]+\([^)]*[0-9]|SizedBox\((height|width): [0-9]|BorderRadius\.circular\([0-9]|fontSize: [0-9]|Color\(0x" <changed files>` returns nothing outside `design_system/theme.dart`.
- **Baseline before the redesign** (all of `lib/`, approx.): 139 `EdgeInsets` literals, 353 `SizedBox` literals, 73 `fontSize` literals, 38 radius literals, 80 hex colors (21 outside theme, gallery and p0), 133 inline `TextStyle(`. Spacing tokens are used 6 times.

### Page

| Rule | Compact | Medium / Expanded | Wide |
| --- | --- | --- | --- |
| Page gutter (left and right) | 16 | 24 | 32 |
| Page top padding (below the title bar or app bar) | 16 | 24 | 24 |
| Page header (title and actions) to the first content | 16 | 24 | 24 |
| Gap between sections (groups of cards) | 24 | 32 | 32 |
| Bottom padding | dock height + 24 | 32 | 32 |

### Cards

- **Gap between cards:** one value per grid, the same horizontally and vertically: 12 compact, 16 otherwise. The grid owns the gap. Cards do not add their own outer margins, and there is no ad-hoc `SizedBox` between cards in a grid.
- **Card padding:** equal on all four sides: 16 compact, 20 otherwise.
- **Card header:** the title and the trailing action share one row and are centered on each other. Title to content: 12. A caption under the title: 4 below the title.
- **Equal heights:** cards in the same row stretch to the tallest card. No ragged bottoms and no empty gap below a shorter card.
- **No nesting:** inside a card, group with dividers or spacing, not with another bordered surface.
- **Radius:** cards use the card radius token. Controls use the control radius. Overlays use the overlay radius. No other radii.

### Rows and lists

- **Single-line row:** icon, text, amount and chevron are vertically centered. Height is at least 48 (40 is allowed on Windows when pointer-only).
- **Two-line row:** the leading icon or avatar, the amount or status, and the chevron are all centered vertically on the row. The amount is right-aligned. Height is at least 56.
- **Amounts:** tabular figures, right-aligned in their own column, with sign, currency and value kept together. An amount never floats mid-row.
- **Dividers:** dividers between rows are inset to the text start. There is no divider after the last row.
- **Text inset:** text keeps at least the card padding from any border.

### Text inside controls

- Buttons, chips, pills, tabs and fields use the theme's padding and line height. Widgets do not override vertical padding. Text and icon are optically centered: check at 100% and 200% text scale.
- **Pills and badges:** 4 vertical and 8–10 horizontal padding, from tokens.

### Forms and dialogs

- **Spacing:** fields 16 apart, label to field 8 (label above the field), helper or error 4 below the field, groups of fields 24 apart, form actions 24 below the last field.
- **Form column:** max width 640 for a single column, 760 for review layouts.
- **Dialogs:** 24 padding, 12 from title to content, 24 above the actions. Actions are right-aligned on Windows (primary rightmost). On Android they stack full width when they don't fit on one row.

### Review checklist (each section chat)

1. Spacing grep is clean on the changed files.
2. Card gaps are equal in both axes, and row heights are equal.
3. Every card has the same padding and no text touches a border.
4. Rows are vertically centered, amounts are right-aligned, and nothing is truncated at 200%.
5. Light, dark and high contrast all work.

## 5. Component rules

The kit lives in `apps/salapiya/lib/design_system/kit/`; screens import `kit/kit.dart`. Every component reads tokens only, works in light, dark and high contrast, and follows the platform from `Theme.of(context).platform`. The older widgets in `components.dart`, `workspace.dart`, `editorial.dart` and `form_presentation.dart` stay until each section chat replaces their uses.

### Shared interaction

- **States:** rest, hover (Windows only, `subtle` fill), pressed (`subtle` fill), focus, disabled, busy and error. No ripple.
- **Focus ring:** 2 px `focus`, drawn 2 px outside the component and following its radius (`FocusRing`). It shows for keyboard focus only. Stock buttons draw it as a 2 px border from the theme.
- **Targets:** at least 48×48 on Android. On Windows, 40 (`Space.pointerTarget`) is allowed for buttons, rows, segmented controls and the info control.
- **Activation:** Enter and Space activate anything focusable. Esc closes the top overlay.

### Buttons (`AppButton`, `AppIconButton`)

| Variant | Use | Built on |
| --- | --- | --- |
| Primary | The one main action in a view or modal | `FilledButton` |
| Secondary | Other actions next to a primary | `OutlinedButton` |
| Tertiary (quiet) | Low-emphasis actions, Cancel in dialogs, "View all" | `TextButton` |
| Destructive | Removing records; only as a modal's confirming action or after one | Filled, `error` fill |
| Icon | Compact actions with an obvious icon; `standard`, `filled` or `outlined` | `IconButton`; the tooltip is required |

- **Metrics:** label 14 / 20 semibold, height 40 on Windows and 48 on Android, control radius.
- **Busy:** a spinner replaces the icon and the button disables. A button that can be busy has an icon, so its width doesn't change.
- **Disabled with reason:** pass `disabledReason`. It shows as a tooltip on hover and is read by screen readers.

### Form field with help (`HelpField`, `HelpTextField`, `InfoControl`, `FormErrorSummary`)

- **Anatomy, top to bottom:**
  - the label (`labelLarge`), then ` *` if required, then the ⓘ info control;
  - the control;
  - one line of helper or error text (`bodySmall`).
- **Label row:** it is always one hit target tall. The label-to-control gap shrinks so the visible gap stays near 8, and fields with and without ⓘ keep the same rhythm.
- **Required:** ` *` in `secondary`, announced as "‹label›, required". A form that marks required fields says "* Required" once at the top.
- **Error:**
  - The message replaces the helper in the same place, with an error icon, as a live region.
  - The field border turns `error`.
  - The form owns validation; the component only displays `errorText`.
- **Error summary:** with two or more errors, `FormErrorSummary` sits at the top of the form and each entry moves focus to its field. No error pop-ups.
- **Disabled:** `subtle` fill and `divider` border, and the `disabledReason` replaces the helper. **Read-only:** `subtle` fill and a `divider` border; the text stays selectable.
- **Hover (Windows):** the border darkens to `text`.
- **Amount field:** `amount: true` adds a ₱ prefix, tabular figures and the decimal keyboard. Parsing stays with the existing rules (`parsePhp`).
- **Info control:** behavior is in [§6](#6-form-help-pattern).
  - The hover tooltip uses the tooltip style (`text` fill, control radius).
  - The pinned popover is level 2 (`raised`, `overlayShadow`, overlay radius), at most `popoverMaxWidth` wide, and kept inside the window.
  - It opens below the icon, or above it in the lower part of the screen.
  - It fades in over `Motion.short`.
  - Screen readers get the text as the control's tooltip without opening it.
  - **Focus:** a click or tap focuses it only so Esc closes the popover and not a dialog behind it. It never shows a focus ring after a click or tap, and closing it releases focus. The ring appears only for keyboard focus (Tab).

### Date field (`DateField`)

- **Dates are chosen, never typed.** Every date input is a `DateField`. It opens the calendar picker (`showDatePicker`, calendar only, with no switch to typed entry).
- **The field:**
  - It looks like a text field: a calendar icon at the end, and the date shown as "29 Oct 2026". With no date, it shows "Choose a date" in `secondary`.
  - It has the same label, info, helper, error, required and disabled states as `HelpField`.
- **The picker:** its title is the field label, and its actions are "Choose date" and "Cancel". Focus returns to the field when it closes.
- **Range:** 2000–2100 by default, as the existing forms use. A form can narrow it.
- **Clearing:** an optional date shows a "Clear ‹label›" button once it has a value. A required date can't be cleared.
- **Display only:** the field hands back a `DateTime`. Each form converts it to the format its rules store (`YYYY-MM-DD` today), so domain parsing is unchanged.

### Option picker (`OptionPicker`)

Each option is a `PickerOption` with a short noun-phrase label and an optional one-line description. `PickerStyle.auto` applies this rule:

| Control | When | Descriptions |
| --- | --- | --- |
| Segmented control | 2–4 options, labels of at most 12 characters, that change only the *view* (period filter, list or chart). It is also the period filter. | None. Options that differ in effect may not use it, because the effect can't be seen before choosing. |
| Radio list | Up to 5 options that differ in effect | Always visible under each label. The whole row is the target. |
| Dropdown | 6 or more options, or long lists such as accounts and categories | Two-line menu items, visible in the open menu before choosing. The selected option's description becomes the helper text. |

Switches and checkboxes are the stock widgets, themed. A switch with help goes inside a `HelpField`.

### Dialogs and sheets (`showAdaptiveModal`, `showAppDialog`, `showAppSheet`, `ModalScaffold`)

- **Structure:**
  - the title (`headlineSmall`), stating the question or consequence;
  - a short body, usually one sentence, that scrolls when it has to;
  - fixed actions.
- **Spacing:** padding 24, title to body 12, body to actions 24.
- **Actions:**
  - The primary is named with a verb, never "OK". Cancel is always present and safe.
  - **Windows dialogs:** actions are right-aligned, with the primary rightmost. Cancel is tertiary.
  - **Sheets:** actions stack full width, with the primary on top. Cancel is secondary.
- **Destructive:** the primary uses the destructive button. Initial focus is on Cancel, so Enter never confirms by accident.
- **Behavior:**
  - Esc, Back or the scrim closes the modal and returns `null`.
  - Focus is trapped inside it and returns to the trigger when it closes.
  - Motion is `Motion.medium`, or none with reduced motion.
  - `ModalAction.onPressed` can return `false` to keep the modal open, e.g. when a short form fails validation.

| Content | Windows | Android |
| --- | --- | --- |
| Confirmation (incl. destructive), at most 2 actions: `ModalPurpose.confirm` | Centered dialog, max 560 | Centered dialog |
| Choice or short form, about 3 fields: `ModalPurpose.choice` | Centered dialog, max 640 | Bottom sheet with drag handle, above the keyboard |
| Long form or review | Pushed page | Full-screen page |

### Cards and headers (`SurfaceCard`, `MetricTile`, `SectionHeader`)

- **`SurfaceCard`:**
  - level 1 (`surface`, 1 px `divider` border, card radius) with `cardPadding` on all sides;
  - an optional title (`titleMedium`), caption (`bodySmall`, 4 below) and trailing action, centered on each other, with 12 to the content;
  - no outer margin, and never nested;
  - with `onTap`, the whole card is one target with hover, pressed and focus states.
- **`MetricTile`:** a card with one focal value. It shows a muted label (`labelLarge`), the value 8 below, a context line 4 below that, and an optional trend or status.
- **`SectionHeader`:** a `titleLarge` header with an optional caption 4 below and a trailing action centered on it. The parent owns the gap after it (`headerGap`).

### List rows (`ListRow`, `ListGroup`)

- **Height:** one line is at least 48, or 40 on Windows. Two lines are at least 56.
- **Padding:** 12 horizontal and 8 vertical.
- **Leading icon:** 24, in `secondary`, centered on the text block.
- **Text:** the title is `titleSmall` and the subtitle is `bodySmall` in `secondary`.
- **Trailing:** usually an amount or a status pill. It is centered vertically on the row, like the leading icon and the chevron.
- **Tappable rows:** they get a chevron and hover, pressed and focus states.
- **`ListGroup`:** hairline dividers inset to the text start, with none after the last row.

### Status (`StatusPill`, `InlineNotice`)

- **`StatusPill`:**
  - not interactive;
  - an icon plus a `labelMedium` label, `pillPadding`, pill radius, and a tinted fill;
  - in high contrast, the fill becomes `surface` with a 1 px border in the status color.

  | Pill | Tone |
  | --- | --- |
  | Overdue | `overdue` (rose) |
  | Due today, Due soon | warning |
  | Upcoming, Schedule not set | neutral |
  | Paid off, Settled | success |

  Labels match `DebtDueStatus`. "Settled" is a past-tense state, which [§7](#7-wording-glossary) allows.
- **`InlineNotice`:** a tinted block with an icon, an optional title and the message. Use it for information, success, warning, error and neutral notes inside a page or form. A notice that reports a change is a live region.
- **Toast:** the stock `SnackBar` with the theme's `snackBarTheme`. Use it only for a short confirmation of an action the user just took, and never for errors (they are inline).

### Amounts (`MoneyAmount`)

- **Display only:** it shows the string the app already formats (`session.amount(value)`, which gives "Amount hidden" when amounts are hidden). It never formats or calculates.
- **Sizes:**
  - **Row:** `titleSmall`.
  - **Card:** `displaySmall`, stepping down to headline roles to fit.
  - **Focal:** `displayMedium`, stepping down. It scrolls sideways only as a last resort.
  - Figures are always tabular, and the line never wraps.
- **Kinds:**
  - **Neutral, Spent and You owe:** `text`. "You owe" may get its own role in Chat 10.
  - **Owed to you:** `owedToYou`. Pair it with a caption such as "Owed to you".
  - **Screen readers:** the kind is appended, e.g. "Philippine pesos 800.00, owed to you".
- **Unknown:** a null value shows "Not available yet" in `secondary`, never ₱0.00.

### Empty, loading and error states (`EmptyState`, `LoadingSkeleton`, `ErrorState`)

- **Empty:**
  - a 32 icon in `secondary`, a title, and a one-line message saying what will appear;
  - at most one action, which starts with a verb;
  - centered; it works bare or inside a card.
- **Loading:**
  - static `subtle` blocks (`.lines`, `.row`, `.card`) shaped like the content;
  - no shimmer or animation;
  - announced as "Loading ‹what›".
- **Error:**
  - an error icon, a calm title that states the fact ("Couldn't load your accounts"), and a message saying what is unaffected;
  - a "Try again" action;
  - technical detail behind "Show details".

### Provider sign-in (`ProviderSignInButton`, `GoogleSignInButton`)

- **Branding:** provider buttons follow the provider's own branding ([§1](#1-design-principles), principle 11). They show the provider's **official button artwork, unmodified**: nothing is redrawn, recolored or re-typeset.
- **Adding a provider:** add a `ProviderBrand` with the label, the artwork folder (`<theme>_<square|pill>.png` at 1x, with `2.0x/`, `3.0x/` and `4.0x/` variants), the artwork size and the state-layer colors. These values are the allowed literal exception in `provider_sign_in.dart`.
- **Google:** the source is the "Android + Web" PNGs (Show text = Yes) from Google's `signin-assets.zip`, per the [Google Identity branding guidelines](https://developers.google.com/identity/branding-guidelines), checked 2026-10-29.
  - **Files:** copied byte-for-byte into `assets/branding/providers/google/buttons/`. The unzipped bundle stays beside them as the source and is not bundled into the app.
  - **Label:** "Sign in with Google", which is the only label in the artwork. "Continue with" and "Sign up with" aren't offered.
  - **Variants:** light, dark and neutral themes, each square or pill.
  - **Theme:** it follows the app (light or dark) unless set.
  - **Size:** 180 × 40 logical, never scaled. On Android, the margin around it extends the target to 48.
  - **States:**
    - Hover and press add a 10% layer of the artwork's label color.
    - Keyboard focus shows the focus ring.
    - Disabled is shown at 38% opacity.
    - Busy shows a spinner beside the button.
  - **Why not the SVGs:** the SVG artwork draws the "G" with a CSS conic gradient and Gaussian blurs, which Flutter's SVG renderer can't reproduce. It would draw an approximation, so the PNGs are used.
  - **Accessibility:** it is announced as "Sign in with Google". Its text is part of the image, so it does not grow with the system text size.

### Deferred to section chats

- **Table and pager:** Chat 8 or 9.
- **Charts (bar, line, progress with an exact-value table):** Chat 6 or 9.
- **Tabs:** Chat 4.

### Component gallery (debug only)

- **Where:** `lib/design_system/kit/component_gallery.dart`. It runs only in debug builds started with `--dart-define=SALAPIYA_COMPONENTS=true`. `kDebugMode` is a constant `false` in release, so the gallery is compiled out and has no in-app entry.
- **What it shows:** every component above, with light and dark side by side on wide windows. A toolbar switches the platform behavior (Windows or Android), the theme (Both, Light, Dark or High contrast), text size (100% or 200%) and reduced motion.

## 6. Form help pattern

### When a field needs help

Add help when any of these is true:

- The label uses a domain term (e.g. "Statement", "Installment", "Split method").
- The field changes balances, schedules, sharing, or what other people see.
- The field has a format or limit (intervals, counts, decimals). Dates don't need format help, because they are always picked from a calendar.
- A choice can't be undone, or its effect isn't obvious from its label.
- Field options differ in consequence (e.g. split equally or by amount, payment amounts the same or different each time).

No help is needed for self-explanatory fields such as name, note, or a plain amount with a clear label. Don't add help just to fill space.

### Two layers

1. **Helper text:** always visible, under the field. One line (at most about 80 characters). It says *what to enter*, e.g. "The date on your lender's statement." When an error appears, it replaces the helper text in the same place.
2. **Info control:** an ⓘ icon button right after the label. It says *what the field or option does*, in one sentence (at most about 140 characters), e.g. "Each payment you log is matched to the earliest unpaid due date."
   - **Windows:** a tooltip on hover or keyboard focus; a click pins it as a popover until Esc or a click outside.
   - **Android:** tap opens an anchored popover; a tap outside or Back closes it. The ~140-character limit keeps it short enough for a popover even at 200% text, and it keeps the field and keyboard in view.
   - It has a 48×48 hit area (40 on Windows), the semantic label "About ‹field label›", and is reachable by keyboard.

### Option explanations

- In a dropdown or segmented control whose options differ in effect, each option shows a one-line description under its label in the menu (a two-line menu item).
- The selected option's description becomes the field's helper text.
- Format: the label is a short noun phrase. The description starts with a verb or with "Use when…". Example: **Same each time**: "Splits the total evenly across all payments." **Different each time**: "Use when your lender gave you a payment-by-payment schedule."

### Tone

- Plain, second person, present tense. Describe the effect on *your records*: "Counts toward this month's spending", not "Posts to the expense ledger".
- Use the "Use" column of [§7](#7-wording-glossary). Never imply that Salapiya moves money.
- No exclamation marks, "simply", "just" or blame. Overdue or error text states facts calmly.
- Errors appear inline, say what to fix, and name the field: "Enter a date on or after 2026-11-01." When there are several errors, a summary goes at the top of the form, linked to the fields. **No error pop-ups.**

## 7. Wording glossary

This glossary applies to **user-facing strings only**. Class, field, table, route and command identifiers never change. The meaning must stay exact: card credit is not cash, borrowed money is not income, and a payment between group members needs the recipient's confirmation. Section chats apply the glossary. Strings that live in domain or rule files (e.g. validation messages in `lib/finance/*_rules.dart`) need approval before they are changed.

### Verbs

- **Add** creates a thing you track: an account, a debt, a group, a task, a budget.
- **Log** records a money event that happened elsewhere: an expense, income, a payment or a transfer.
- **Edit** and **Correct** change records. Corrections keep the earlier version.
- Never use **Pay, Send, Transfer, Borrow, Lend, Settle, Request, Withdraw or Deposit** as the verb of a button, menu item or title. As nouns or past tense describing the real world, they are fine ("Paid from", "Payment", "Money you borrowed").

### Use / avoid

| Avoid (user-facing) | Use | Notes |
| --- | --- | --- |
| Record borrowing | Log a new loan | "A loan you took out elsewhere" in helper text |
| Add existing debt | Add a debt | Helper text: "A debt you already have, with its current balance." |
| Record debt payment / Record payment | Log a debt payment | |
| Pay credit card | Log a card payment | |
| Pay from | Paid from | Field label |
| Transfer money | Log a transfer | "Between your own accounts" in helper text |
| Report payment / Settlement | Log a payment between members | Shared Expenses |
| Settle together / Settle up | Track who owes whom | |
| Receipt confirmation | Confirm you received it | Recipient side of a payment between members |
| Liquid money | Available money | Cash and bank; card credit excluded |
| Debt liability | What you owe | |
| Card credit / available credit | Available credit | Never shown as money you have |
| Recognized income / spending | Income / Spending | Keep "Borrowed money isn't income" where it matters |
| Accepted history / accepted | Confirmed / synced records | Depending on whether the context is sync or business |
| Net recognized, net of offsets | Net spending (refunds subtracted) | |
| Coverage | What's included | |
| Evidence | Proof, or Attachments | |
| Ledger, journal, posting, revision | *(not user-facing)* | "Edit history" for revisions |
| Pending (sync) | Waiting to sync | |
| LOCAL ONLY | On this device only | |
| Synchronization | Sync | |
| Provider (debt context) | Lender | The user's real-world lender, never Salapiya |
| Private review | Check against my records | Shared Expenses reconciliation |
| Unavailable (unknown value) | Not available yet | Never `₱0.00` for an unknown value |

### Tone rules

- **Sentence case** for every label, title and button. Uppercase is allowed only for small eyebrow labels, and only via a type token.
- **Buttons** start with a verb and name the result: "Log expense", not "Submit" or "OK".
- **Short:** one idea per sentence. Captions fit on one line at expanded width.
- **No technical or accounting jargon** in the main reading path. Exact detail goes in disclosures.
- **Friendly, not cute:** no slogans as screen titles. "Overview", not "Your day, in balance."
- **Glossary maintenance:** when a section chat finds a new term, it adds a row here before changing strings.

## 8. Dashboard data inventory

This inventory covers what the Overview can show without new domain logic. **Readable** means an existing getter or pure function returns the value as-is. **UI aggregation** means summing, grouping or filtering existing exact values inside the view; each new aggregation is listed in the handoff under "Needs approval" before it is built. **New logic** is out of scope for the UI redesign.

| Data | Source | Status |
| --- | --- | --- |
| Available money (confirmed); projected available money with waiting work | `LocalSession.accepted`, `.projected` (`lib/local/local_runtime.dart`) | Readable |
| This month's spending and income; spending by category | Postings in `localFinance.acceptedSnapshot` (already summed in `app/workspace_overview.dart`); `categoryName` | Readable (existing view aggregation) |
| Daily spending (sparkline) | `LocalFinancialController.spendingOn(date)` | Readable |
| Account balances | `snapshot.accounts`, `snapshot.balance(id, through:)` | Readable |
| Card debt and available credit | `LocalFinancialController.cardLiabilityAndCredit` | Readable |
| Total debt owed | `LocalFinancialController.debtTotal` | Readable |
| Per debt: next due date and amount, overdue installments and amount, status (Overdue / Due today / Due soon / Upcoming / Schedule not set), days until next, final scheduled due | `debtDueSummary`, `DebtDueSummary`, `compareDebtUrgency` (`lib/finance/debt_rules.dart`) | Readable |
| Everything due in a date range (debt installments, card statements, card installments, recurring bills) with dates and amounts | `financialReminderSources(snapshot, from, through)` (`lib/finance/planning_queries.dart`) | Readable; the weekly/monthly calendar and overdue list come from this |
| Totals due this week or this month across all debts and bills | Sum of the rows above | UI aggregation (needs approval) |
| Recurring bills and their state | `recurringOccurrences` | Readable |
| Budget progress | `budgetSpending(snapshot, budget)` with the budget record | Readable |
| Savings set aside | `savingsReserved`, `eligibleSavings` (`lib/finance/planning_rules.dart`) | Readable |
| Balance forecast | `financialForecast` (as used by Reports) | Readable |
| Shared Expenses attention counts (to confirm, waiting for others, waiting for the group, rejected, changed sources) | `runtime.connected.needMyConfirmation`, `waitingForOthers`, `sharedPendingCount`, `sharedReviewCount`, `changedPrivateSources` | Readable |
| Who owes whom per group | `SharedRepository.groups` → `SharedGroup.positions()` | Readable |
| Life agenda (tasks, events, financial reminders) | `DurableLifeController.agendaWindow` (`lib/life/life_controller.dart`) | Readable |
| Sync state: label, waiting count, needs review, download complete, connected or on this device, last synced | `LocalSession.syncLabel`, `pendingCount`, `needsReview`, `complete`, `local`; `lastSyncedAt` (`lib/connected/connected_runtime.dart`) | Readable (check that `lastSyncedAt` is exposed to the UI in Chat 5 or 6) |
| Amount privacy | `session.hideAmounts` | Readable; every dashboard value must respect it |
| Month-over-month or longer trends outside Reports | Not available as a query | New logic, or UI aggregation over postings (needs approval) |

## 9. Redesign roadmap (temporary)

Remove this section when the redesign is finished.

| Chat | Stage | Status |
| --- | --- | --- |
| 1 | Audit and design spec (this document) | Done |
| 2 | Tokens: color, spacing, radii, type, elevation, motion; light and dark | Done |
| 3 | Components and the debug-only component gallery; form help; dialogs; Google button | Done |
| 4 | App shell: navigation, page header, profile entry | Next |
| 5 | Windows custom title bar | Planned |
| 6 | Overview dashboard | Planned |
| 7 | Debts | Planned |
| 8 | Money A: Accounts, Activity, transaction form | Planned |
| 9 | Money B: Cards, Planning, Reports, Import, Files | Planned |
| 10 | Shared Expenses A: groups, Bills, Payments | Planned |
| 11 | Shared Expenses B: Balances, People, Private review, History, Lifecycle | Planned |
| 12 | Life A: Calendar, Tasks, reminders | Planned |
| 13 | Life B: Learning, Books, Career | Planned |
| 14 | Profile and settings: connection, devices, backup and recovery, preferences, help | Planned |
| 15 | Onboarding: welcome, local setup, Google, restore | Planned |
| 16 | Consistency sweep (spacing grep, glossary, both themes, both platforms, 200% text) | Planned |
| 17 | Final review | Planned |

Each section chat:

1. Applies §4, §6 and §7.
2. Updates the tests whose text finders change.
3. Runs only targeted tests.
4. Ends with manual checks for the owner.

## 10. Decision log

| Date | Decision | Status |
| --- | --- | --- |
| 2026-10-29 | The redesign covers real-use (production) screens only. Demo and gallery screens keep working but are not polished. | Approved |
| 2026-10-29 | Windows gets a custom integrated title bar. Native runner code may change, and a windowing package may be added. This supersedes the pre-redesign rule "native caption only, no window-management dependency". | Approved |
| 2026-10-29 | Section chat order in §9 (Debts first, Onboarding last; Money, Shared Expenses and Life each split in two). | Approved |
| 2026-10-29 | The pre-redesign design system moves to `docs/archive/DESIGN_SYSTEM_pre-redesign.md`. This document replaces it. | Done |
| 2026-10-29 | Carried over from the archive: the exact-money rules, the accessibility rules, the motion limits, Geist as the typeface, separate sync and business states, and the status color pairs as the starting palette. | Approved (with this spec) |
| 2026-10-29 | The spacing values in §4, and the Add/Log verb split and glossary in §7. | Approved |
| 2026-10-29 | Redesign work moves to its own branch, `redesign/ui`, created from `docs/normalize`. | Approved |
| 2026-10-29 | Tokens (Chat 2): purple-tinted neutrals, primary `#6546A3` / `#CABDFA` kept, archived status pairs kept, new `overdue` (rose) and `owedToYou` (teal) roles, chart series from the archive, and a high-contrast variant. | Approved |
| 2026-10-29 | Geist stays the only UI font (already bundled, OFL 1.1). The type scale is in §3. | Approved |
| 2026-10-29 | Radii are control 10, card 14, overlay 20 and pill. Elevation has two levels (hairline cards, shadowed overlays). Motion is 100 / 160 / 200 ms with ease-out. | Approved |
| 2026-10-29 | Wide content max width is 1280, and the Windows title bar height is 40. | Approved |
| 2026-10-29 | The existing System/Light/Dark profile setting stays the theme-mode control. | Approved |
| 2026-10-29 | Component kit (Chat 3) in `lib/design_system/kit/`, with the API and rules in §5. Existing screens are not migrated in Chat 3. | Approved |
| 2026-10-29 | The Android info control is an anchored popover only. The "bottom sheet if longer than 3 lines" fallback is dropped. | Approved |
| 2026-10-29 | Option picker rule: segmented only for view-only options without descriptions; a radio list for up to 5 options that differ in effect; a dropdown with two-line items for 6 or more. | Approved |
| 2026-10-29 | Modal rule: confirmations are centered dialogs on both platforms (this adds to §2 for Android). Choices and short forms are dialogs on Windows and bottom sheets on Android. Long forms are pages. A destructive modal starts with focus on Cancel. | Approved |
| 2026-10-29 | Required fields are marked ` *`, with "* Required" once at the top of the form. | Approved |
| 2026-10-29 | Button metrics: 14 / 20 labels, 40 tall on Windows and 48 on Android, 2 px focus border. Chip labels are 12 / 16. These apply app-wide through the theme. | Approved |
| 2026-10-29 | Table, pager, charts and tabs are deferred to the section chats that first need them. The toast stays the themed stock `SnackBar`. | Approved |
| 2026-10-29 | Dates are always chosen with a date picker (`DateField`, calendar only), never typed. Section chats replace the existing typed date inputs. | Approved |
| 2026-10-29 | The info control shows a focus ring only for keyboard focus. A click or tap never leaves a ring, and closing the popover releases focus. | Approved |
| 2026-10-29 | "Settled" is kept as a status-pill label (a past-tense state). | Approved |
| 2026-10-29 | The component gallery is debug-only, opened with `--dart-define=SALAPIYA_COMPONENTS=true`. | Approved |
| 2026-10-30 | List rows center their trailing content (amount, status pill) and chevron vertically, instead of aligning them with the first line. | Approved |
| 2026-10-30 | The Google button shows Google's official button PNGs, unmodified, from `signin-assets.zip`. The SVGs aren't used because Flutter can't render their gradient "G" faithfully. No font is bundled. | Done |
| 2026-10-30 | The Google button label becomes "Sign in with Google", the only label in the official artwork (the profile screen says "Continue with Google" today). | Approved |
| 2026-10-29 | Totals added up across debts and bills per week or month for the dashboard. | Needs approval (Chat 6) |
| 2026-10-29 | Rewording user-facing messages that live in domain or rule files. | Needs approval (per section chat) |
