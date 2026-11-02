# Design system

This is Salapiya's design system (Windows and Android, one Flutter codebase). Every UI change follows it, new features included. When a change needs a rule that isn't here, add it here first, then build it. Every screen, new or changed, builds to the [Section screen standard](#section-screen-standard-the-overviews-quality-bar): the Overview is the quality bar. I built every real-use screen to it during the UI redesign, which I finished on 2026-11-03; the decision log keeps that history.

The pre-redesign design system, including its research and history, is archived at [archive/DESIGN_SYSTEM_pre-redesign.md](archive/DESIGN_SYSTEM_pre-redesign.md). It is not a rule source.

**Scope.** It covers the real-use screens (the `production` code paths: `lib/app`, `lib/finance`, `lib/shared`, `lib/life`, `lib/local`, `lib/connected`, `lib/design_system`, `lib/profile`, `lib/onboarding`, and the section frames under `lib/features`, as `consistency_sweep_test` lists them). Demo and gallery screens (`lib/features/*` demo branches, `lib/gallery`, `lib/prototype`) must keep compiling and working, but they are not polished. Models, domain rules, calculations and data follow their own documents (DOMAIN_RULES, DATABASE, ARCHITECTURE); a screen that needs them changed waits for that change to be approved.

## Contents

1. [Design principles](#1-design-principles)
2. [Platform adaptation (Android vs Windows)](#2-platform-adaptation-android-vs-windows)
3. [Tokens](#3-tokens)
4. [Spacing and alignment rules](#4-spacing-and-alignment-rules)
5. [Component rules](#5-component-rules)
6. [Form help pattern](#6-form-help-pattern)
7. [Wording glossary](#7-wording-glossary)
8. [Dashboard data inventory](#8-dashboard-data-inventory)
9. [Decision log](#9-decision-log)

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
| Compact | < 600 | Android bottom dock; Windows: a menu button ("Go to") opens the destination chooser | 1 |
| Medium | 600–999 | Sidebar as a rail, `Space.railWidth` 64 (icons, tooltips, flyouts); it doesn't expand | 1–2 |
| Expanded | 1000–1439 | Sidebar, `Space.sidebarWidth` 224; collapsible to the rail for the session | 2–3 |
| Wide | ≥ 1440 | Same as Expanded | Up to 4; content max width 1280 (`Space.contentMaxWidth`) |

At text scale ≥ 150%, drop one column class.

| Concern | Windows | Android |
| --- | --- | --- |
| Window chrome | A custom title bar across the full window width, above the sidebar and the app bar ([below](#windows-title-bar)). The native caption is removed; the sides and bottom keep the native frame. | System status bar. Top app bar with the section title (the logo mark leads it on Overview), Go to, the bell and the profile button, then a status row with the sync pill and Hide amounts ([Android parity](#android-parity-with-the-windows-title-bar)). |
| Primary navigation | Sidebar panel flush with the window's left edge: logo, profile card, Go to, five destinations with their tabs, Needs attention, utilities ([App shell](#app-shell)) | Floating bottom dock with five labelled destinations ("Shared" is the short label for Shared Expenses); a separate + action above it |
| Back / forward | Title-bar buttons, Alt+← / Alt+→, mouse back/forward buttons | System back gesture or button; no forward |
| Location | Breadcrumb in the app bar, below the title bar (Section › Tab › Page) | Screen title in the app bar (the dock's names on phones); tabs below it |
| Create actions | "New" menu button in the shell header (Ctrl+N) | + button above the dock opens a bottom sheet |
| Info control ([§6](#6-form-help-pattern)) | A tooltip on hover and keyboard focus; a click pins it as a popover | Tap opens an anchored popover |
| Dialogs | Centered, width-bounded modal | Centered dialog for confirmations; bottom sheet for choices and short forms; full-screen page for long forms |
| Forms | Centered column, max width bounded | Full width, scrolls, keyboard insets respected |
| Row density | Single-line rows may be 40 px when pointer-only; hover state on rows | Rows at least 48 px; no hover |
| Hover | Required on every interactive element | Not used; pressed state only |
| Keyboard | Every action reachable; Esc closes the top overlay; Ctrl+N opens New; Ctrl+K opens Go to; Ctrl+H hides or shows amounts | Hardware keyboard works; not required to be optimized |
| Go to, bell, calculator | Title bar: the Go to field, the bell's menu, the calculator's popover | App bar: Go to's full-screen page and the bell's sheet; the calculator is the + sheet's last row |

### App shell

`lib/app/shell.dart` and `lib/app/shell_navigation.dart`, built from the kit.

- **Destinations:** Overview, Money, Debts, Shared Expenses and Life. Section tabs stay inside each section.
- **Profile and settings:** one entry, not a destination. It opens the existing profile page and its tabs (Profile, Connection, Devices, Backup & recovery, Help). Connected accounts are under Connection.
  - Windows: the profile card at the top of the sidebar opens a menu: Profile and settings, Connection, Devices, Backup & recovery.
  - Android, and Windows below 600: a button with the profile's initial in the header.
- **Shell header:**
  - **Windows with the sidebar: the app bar.** It is `Space.appBarHeight` (56) tall on `surface`, with a hairline divider below, and level with the sidebar's logo row.
    - Left: the breadcrumb (`ShellBreadcrumb`), with chevrons between segments. Earlier segments are muted and go back; the last one is the current place.
    - Right: New. Go to and the sync state are in the title bar. Hide amounts and the profile live in the sidebar.
    - Without the custom frame (an older runner, or tests that don't turn it on), the app bar keeps the original shell layout: the Go to field (224 wide; a search icon at Medium width) before New, and the sync line in the profile card.
  - **Android, and Windows below 600:** the app bar, then the status row ([Android parity](#android-parity-with-the-windows-title-bar)). Windows below 600 keeps its menu button for Go to and New, and the title bar has the bell, Hide amounts and the sync state, so the header adds neither the bell nor the status row; without the title bar it shows both.
  - A 12 bottom gap keeps the header clear of content scrolling under it.
- **Windows sidebar** (`ShellSidebar`), modelled on my reference images:
  - **Panel:** `surface` on the canvas, flush with the window's left, top and bottom edges. It has square corners and a hairline (`divider`, or `text` in high contrast) along its right edge. I deferred Mica when I built the title bar, so the panel stays solid.
  - **Collapse:** a panel icon button beside the logo; on the rail it sits under the logo mark. The glyph has two states: a panel outline whose chevron points in ("Collapse sidebar") or out ("Expand sidebar").
  - **Corners:** highlights, the profile card, the Go to field and the theme switch use `Radii.nav` (6).
  - **Metrics:** these are compact, like Windows 11 navigation.
    - Rows are `Space.navItem` 36, 4 apart; tab rows are `Space.navTab` 32.
    - Icons are `Space.navIcon` 16; the avatar is `Space.navAvatar` 28; the Go to box is `Space.navSearch` 32.
    - Labels use `NavType.label` (13 / 18, regular; medium when selected). Tabs use `bodySmall` (12 / 16). Eyebrows use `labelSmall`.
    - Horizontal padding is 12 and vertical padding 16.
  - **Top, fixed:** a logo row as tall as the app bar (56). The logo (32 tall) is on the left and the collapse button on the right.
  - **Then, scrolling when the window is short:**
    - **Profile card:** the initial and the name on one line. It opens the profile menu. The sync state is in the title bar; without the custom frame, the card shows it on a second line with its icon.
    - **The five destinations.** A separator (12 above and below) splits Overview, the dashboard, from the working sections. Money, Shared Expenses and Life show their tabs under them, joined by a crisp hairline tree. Only the current section is open (an accordion). Pressing it again folds its tabs. A tab row goes straight to that tab. The selected tab's fill stops short of the panel edge.
    - **Quick create** (with the title bar): the current section's first three New actions as rows, one click each, the Windows counterpart of Android's + button. Overview and Money: Log expense, Log income, Log a transfer. Debts: Log a debt payment, Add a debt, Log a new loan. Life: Add task, Add event, Add a learning goal. Shared Expenses: Add shared expense, Log a payment between members. Hidden on the rail.
    - **Needs attention** (without the title bar; with it, these rows are in the title bar's bell): rows built from existing counts, each going to where it's handled: "N payments to confirm" (Shared Expenses › Payments), "N waiting to sync" (Money, Life and group changes, as the sync status counts them), "Sync needs you to sign in" (signed out) and "Sync needs review" (Profile › Connection). With none, it shows "Nothing needs attention". Shared Expenses also shows the to-confirm count as a badge in both cases.
  - **Bottom, fixed:**
    - Settings (opens Profile and settings) and Help. Without the title bar, Hide amounts (a small switch) comes first; with it, Hide amounts is in the title bar.
    - Then a full-width Light | Dark switch, with an icon and a label on each segment. It shows the theme in use, including what System is giving. Choosing one sets the profile's theme. System stays available in Profile and settings.
  - **Selected item:** a `subtle` fill and a medium-weight `text` label. Only the icon is `primary`. High contrast adds a `text` outline.
  - **Rail:** 40 × 40 icon cells with tooltips. The profile initial opens its menu. Sections with tabs open a flyout beside the item. It has a header (the section's icon and name), then the tabs on the same tree line as the expanded sidebar, with the current tab highlighted. The flyout is level 2, with a `control` radius and a hairline border. The badge sits on the icon. The footer is icon cells: Hide amounts (only without the title bar), Settings, Help, and the theme (switches to the other one).
- **Go to (Ctrl+K):** a dialog near the top of the window on Windows, and a full-screen page on Android, from the same entries (`goToEntries`, filtered by `goToMatches`). Typing filters; Enter opens the first match of what's typed. It lists the sections, every tab ("Activity · Money"), the create actions (one per label) and the profile pages. It jumps to places; it doesn't search records. It opens from the title bar's Go to field (a search button at Medium width), from the header's menu button on Windows below 600, or from the app bar's search button on Android.
- **Pages:** they open on a navigator inside the content area.
  - Windows: the sidebar and header stay visible.
  - Android: the app bar and dock hide while a page is open.
  - Dialogs, sheets and pickers open on the root navigator; `showAppSheet` uses it, so sheets cover the dock.
- **Choosing a destination with a page open (Windows)** closes the pages first. A page that refuses, such as one with an unsaved draft, keeps the user where they are.
- **Overview links** go to the section and tab that hold the source, e.g. "View accounts" opens Money › Accounts. They no longer push a second copy of the section. Entity details (a debt, a bill, a transaction) still open as pages.
- **Back:**
  - System Back and Esc close the top page.
  - On Android, Back on any destination other than Overview goes to Overview, and Back on Overview leaves the app.
  - On Windows, Alt+← and the mouse back button go back through the history; Alt+→ and the mouse forward button go forward.
- **History:** it holds destination and tab changes plus open pages, up to 50 steps. Forward only redoes destination and tab changes; it never reopens a closed page or form. Opening a page clears Forward.
- **Create actions** use the glossary labels: "Log expense", "Log income", "Log a transfer", "Log a debt payment", "Add a debt", "Log a new loan", "Add task" and "Add event", per destination. The Windows menu opens with its first item focused, so Esc and the arrow keys reach it before an open page.
- **Navigation state for the title bar:** `ShellNavigation.of(context)` exposes:
  - `destination`, `tab` and `pages`;
  - `breadcrumb`, a list of `ShellCrumb(label, onSelected)`: `onSelected` goes back to that segment and is null for the current one;
  - `canGoBack`, `canGoForward`, `goBack()` and `goForward()`.

  Sections report their tab with `ShellNavigation.reportTab(context, tab)`, which does nothing outside the shell. A page's breadcrumb label is its title (passed as the route arguments by `openDemoPage`), or a name derived from its route.
- **Routes:** there is no route table, and the only deep link is the OAuth callback, so nothing breaks. Every `RouteSettings.name` is unchanged, including `action/<key>`, which keeps the old action keys while the labels change. The only change is that Overview no longer pushes its `<section>/<source>` pages.

### Windows title bar

`lib/app/title_bar.dart` (the bar and the runner bridge), `lib/app/title_bar_tools.dart` (the clock), `lib/app/shell_tools.dart` (the bell, the sync status and Hide amounts, which Android shares), the kit's `calculator.dart`, `lib/app/window_chrome.dart` (where it sits), and the runner in `apps/salapiya/windows/runner/`. The decision log has the history; this is the current design.

- **One custom bar across the full window width**, `Space.titleBarHeight` (40), on `titleBar` with a hairline below the content column. The sidebar and the app bar start under it; the sidebar's logo row (56) stays level with the app bar.
- **It frames every screen.** `WindowChrome` puts it above the app's navigator, so welcome, loading and recovery screens have window controls too. Outside the shell, it shows only drag space and the window controls.
- **No logo or app name.** The logo stays in the sidebar.
- **Contents, left to right:**
  - **Left segment (date and clock):** as wide as the sidebar (224, or 64 on the rail), on `surface` with the sidebar's right hairline. The bar's bottom line stops at it, so the sidebar runs unbroken from the window's top edge. The clock is centered in the segment: a 16 clock icon, then "2:45 PM · Fri, 30 Oct" (`NavType.label`, tabular; the time in `text`, medium; the date in `secondary`). It updates each minute, and the time follows the system's 12/24-hour setting. On the rail it shows the time only, centered (`bodySmall`); below 600 there is no segment. It opens a read-only month calendar with today marked and "Open Life › Calendar".
  - Back and Forward: kit `AppIconButton`s (32), `Space.xs` apart, `Space.sm` past the sidebar's edge (or from the window's edge without one). They are neutral navigation chrome: `text` when enabled, `secondary` when there is no history; the tools on the right keep the accent. Tooltips "Back (Alt+←)" and "Forward (Alt+→)".
  - **Go to**, moved from the app bar. From 1000 wide it is the `GoToField`, `Space.goToWidth` (320) wide and centered on the window. It narrows rather than overlap either side and keeps at least 48 of drag space beside it. At Medium width it is a search button after Forward. Below 600 the header's menu button stays, because there it is the way to navigate.
  - Drag space: everything else.
  - **Bell:** what needs the user, from the existing counts (payments to confirm, waiting to sync, signed out, sync needs review), with a `primary` count badge that counts the rows and keeps its size at large text. It opens a menu headed "Needs attention" whose rows go where each item is handled; with none it says "Nothing needs attention". It replaces the sidebar's Needs attention group.
  - **Calculator:** a popover with a keypad (C, Backspace, Copy, the four operators, digits, the decimal point, =). Typing works while it's open (digits, + − * / or x, Enter or =, Backspace, Delete or C, Ctrl+C, and the numpad); Esc closes it. Arithmetic is on exact fractions, left to right as in Windows' standard mode. A result that doesn't end within 10 decimals shows rounded to centavos and marked "≈" (DOMAIN_RULES §49: rounding is never silent); Copy puts the plain value (for example `416.67`) on the clipboard. It saves nothing. Hidden below 600.
  - **Hide amounts:** an eye button, "Hide amounts (Ctrl+H)" or "Show amounts (Ctrl+H)", reported as a toggle. It replaces the sidebar footer's row, the rail's cell and, below 600, the header's button.
  - **Sync status**, moved from the sidebar's profile card. It shows the connection's labels with an icon for each state: "On this device only" (lock), "Synced", "Syncing", "Waiting for connection", "Sync paused", "Signed out", "First download not finished" and "Needs review". The last two are in the warning tone. The demo says "Demo · " and the same words for the state its scenario shows. It opens Profile › Connection, or Profile and settings in the demo. Below 600 it is icon-only, with the label in its tooltip.
  - **Window controls:** minimize, maximize or restore, and close (`CaptionButtons`, 46 wide, full height).
- **Not in the bar:** the logo and app name (they stay in the sidebar) and the breadcrumb (it stays in the app bar).
- **Colors:** see [§3](#charts-title-bar-high-contrast-and-legacy-colors). Close uses the system red on hover, an allowed exception to the purple accent.
- **Mica:** deferred. Flutter's Windows engine draws an opaque surface, so Mica would need an unsupported transparent surface. Translucent sidebar text also can't be contrast-checked against a wallpaper tint. The bar and the sidebar stay solid.
- **Opening:** the window opens maximized on every launch, not full screen, so the taskbar stays. Nothing remembers a window size. Restore Down goes to 1280 × 720.
- **Native frame (runner):**
  - `WM_NCCALCSIZE` moves the client top to the window's top edge. The left, right and bottom frame stay native, which keeps the resize borders, the shadow, Windows 11's rounded corners, Aero Snap, Win+arrow keys and Alt+Space. A maximized window gets its hidden frame back as top padding, minus one pixel on an auto-hide taskbar's edge.
  - Hit testing: the Flutter view is subclassed to return `HTTRANSPARENT` over the bar's drag space, the top resize band and the maximize button. The window then answers `HTCAPTION` (drag, double-click to maximize, right-click for the system menu), `HTTOP`/`HTTOPLEFT`/`HTTOPRIGHT` (not when maximized), or `HTMAXBUTTON`, which brings up Snap Layouts.
  - The app sends its regions after each layout, in logical pixels: the bar height, the maximize button and the interactive areas. The runner scales them by the window's DPI at hit-test time, so DPI changes and monitor moves need no extra messages.
  - The runner owns the maximize button's pointer input. It reports hover and pressed to the app, and maximizes or restores on release. Minimize and close are ordinary app buttons; every window command is posted as a system command (`SC_MINIMIZE`, `SC_MAXIMIZE`, `SC_RESTORE`, `SC_CLOSE`).
  - The runner also reports maximized and active. Glyphs turn `secondary` while the window is inactive.
- **Opt-in:** `main.dart` calls `WindowFrame.enable()` before `runApp`, and the native caption stays until it does. An older runner, the debug component gallery (a separate app) and widget tests keep the native caption and the original shell layout.
- **Dialogs and sheets** open below the bar. While one is open, the clock, back, forward, Go to, the tools and the sync status are inert; drag and the window controls keep working. The clock, bell and calculator popovers are menus, which close on Esc or an outside click.
- **Keyboard and screen readers:**
  - Tab order, in reading order: the clock, Back, Forward, Go to, the bell, the calculator, Hide amounts, the sync status, then the app. The window controls aren't in the Tab order, as with native caption buttons; Alt+Space reaches them.
  - Screen readers get named buttons: "Minimize", "Maximize" or "Restore Down", "Close", "Sync status, ‹label›", the clock ("Fri, 30 Oct, 2:45 PM. Open the calendar") and "Notifications, N need attention". The calculator's display is a live region.
  - The app's navigator, and the shell's content navigator, sit in semantics containers. Without them, a route's modal barrier hid the title bar, the sidebar and the app bar from screen readers.
- **High contrast:** the app switches to its high-contrast theme and the native border uses the system colors. Flutter doesn't expose the user's high-contrast palette, so the bar itself uses the app's high-contrast roles.
- **Back/forward history is UI-layer state** over the existing navigation (destination switches and pushed pages). Routes and route names do not change.

### Android parity with the Windows title bar

I approved this on 2026-10-30 and built it after onboarding. Android gets the title bar's features in its own places; there is no title bar on Android. Each part reads the same source as Windows: `goToEntries`, `notices`, `status` and `syncDetails` in `shell.dart`, and `NotificationsButton`, `SyncStatusButton` and `HideAmountsButton` in `lib/app/shell_tools.dart`, which show as compact pointer controls in the title bar and at touch size here. Tested in `test/shell_parity_test.dart`.

- **Five-second questions.** App bar: where am I, and how do I get somewhere fast? Status row: is my data synced, and are my amounts hidden? Bell: does anything need me? Go to: where do I want to go? Calculator: can I work something out without leaving what I'm doing?
- **What the standard doesn't cover here.** This is chrome, not a section, so there are no tabs, KPI tiles, charts, tables, grid, Show values, shareable views or accent card, and no demo sample of its own: it reads the shell's counts. Tokens, 48 targets, nothing cut at 200%, both themes, every state, the glossary, no wasted space, `ListEnd` on Go to's list and the sweep all apply.
- **App bar** (`_AppBarRow`, at least 48 tall): the logo mark on Overview, the title, then Go to (search), the bell and the profile button, 48 each. Phones (Compact width) use the dock's names ("Shared"), so the bar keeps one row at normal text; wider screens use the full name. When the title doesn't fit beside the actions (at large text), it drops to its own line under them, with the logo staying on the actions' row. It never wraps inside a word or ends in "…".
- **Status row** (48 tall): the sync pill (`SyncStatusButton`) at the start, with a 48 hit area, wrapping at large text, and the Hide amounts eye (`HideAmountsButton`, a toggle to screen readers) at the end. The pill opens Profile › Connection, or Profile and settings in the demo. Its spare height under the pill is the header's bottom gap, and the page starts `Space.xs` below it, as pages do, instead of the page top (I changed this after a review: the date sat too far under the pill).
- **Go to:** the search button opens a full-screen page on the root navigator: a back arrow and the "Go to…" field, focused, then one card per group (Sections, Tabs, New, Profile and settings), the last closing with `ListEnd`. Typing filters inside the groups and empty ones go; with no match it says "Nothing matches" and that Go to finds places, not records. Enter or a row closes the page and opens the place. Back closes it and changes nothing.
- **Bell:** the same rows as Windows, with the count badge. It opens a "Needs attention" sheet whose rows (icons in their tone, `ListRow.leadingColor`) go where each item is handled, with Close. With none, the sheet says "Nothing needs attention" and what shows there.
- **Calculator:** the + sheet's last row, "Calculator", opens it as a sheet (`showCalculatorSheet`, the same one amount fields use, without Use result) with Copy and Close, the same exact engine and "≈" rule.
- **Date and calendar:** no clock (the status bar shows it). The date in Overview's header opens a calendar sheet with "Open Life › Calendar".
- **States:**
  - An unfinished first download: the pill reads "First download not finished" in the warning tone. Log expense, Log income, Log a transfer, Add shared expense and Log a payment between members open no form until it finishes, so the + sheet, Go to, the Windows New menu, Quick create and the quick actions don't offer them. Debt, card and Life actions stay.
  - Signed out: the pill says so and the bell adds "Sync needs you to sign in", which opens Connection.
  - Hidden amounts: the eye is crossed out and its tooltip reads "Show amounts".
  - A page open: the app bar, the status row and the dock hide, as before; pages have their own back row.
- **Windows below 600** uses the same header: with the title bar, its menu button, the title, New and the profile, and nothing the bar already has; without it, the bell and the status row too.
- **Unchanged:** system Back (no Forward), the + sheet as Quick create's counterpart, the dock. Amount fields have the calculator button with "Use result" (`AmountField`, §5); Career's salary fields don't, because a salary has its own currency.
- **Ideas needing approval later:** Android launcher shortcuts and the Windows taskbar jump list (native code), and the Android 14+ predictive-back animation.
- **Demo build:** shows the app bar, Go to, the bell (a payment to confirm, plus review or waiting in those scenarios), the calculator, Hide amounts and each scenario's pill. It can't show the real sync labels (Syncing, Signed out, Sync paused), the pill opening Connection, or the signed-out row.

```
│ 9:41                  ▴ ▮ 100% │  status bar
│ ◆ Overview        ⌕   🔔1  (A)  │  app bar
│ (☁ Synced)                 👁   │  status row
├────────────────────────────────┤
│ Fri, 30 October  ›             │  Overview header (opens the calendar)
```

### Overview dashboard

`lib/app/overview_dashboard.dart` (layout, tabs and sources), `overview_cards.dart` (cards), `overview_controls.dart` (compact controls and tiles), `kit/charts.dart` (charts, moved to the kit when I built Debts), `overview_data.dart` (display-only derivations) and `overview_demo.dart` (the demo sample); tested in `test/overview_dashboard_test.dart`. Goal: within five seconds, where your money stands, what is due and what changed. After my first review (2026-10-30) I reworked it to match my reference dashboards: compact sizes, KPI tiles with sparklines, mixed card widths, more widget types and tabs.

- **Header.**
  - Windows: a `PageHeader` with "Overview" and the long date ("Friday, 30 October 2026"). From 1104 wide the quick actions sit on the same row, right-aligned so they end at the content's right edge (the cards' and tab row's edge), centered on the title; they wrap from the end if needed. Narrower, they go under it.
  - Android: one compact row, 4 above the tabs: a calendar icon and the long date in `titleSmall`, 48 tall, opening a calendar sheet with "Open Life › Calendar"; at its end, a dues pill ("N overdue" in the overdue tone, else "N due this week") that opens the Debts & Dues tab, hidden when nothing is due or the download is incomplete. No quick actions: the + button above the dock already offers them.
  - **Quick actions** (Windows only): the shell's first four New items (Log expense, Log income, Log a transfer, Log a debt payment) as small outlined chips that open the same editors. On Windows with the title bar, the sidebar's Quick create repeats the first three.
- **Tabs** (`AppTabs`): Summary · Spending · Debts & Dues · Accounts & Activity. Summary is the five-second view. A tab change resets that tab's cards.
- **Notices**, under the tabs, only when they apply: "Your first download isn't finished" (warning); "N changes are waiting to sync" with available money including them (information, live region); "Sync needs review" with Review.
- **Summary:**
  - **KPI tiles** (`KpiTile`): an icon badge and label (every tile reserves the height of the tallest label in the set at its width, so values line up when one label wraps and another doesn't), the value (`MoneySize.tile`), a change line and a sparkline beside the value (under it when narrow). Captions stay ("Cash and bank · card credit excluded", "Refunds subtracted", "Borrowed money isn't income", "Debts through today · cards are separate").
    - **Available money** (the one accent card): sparkline of the closing balance of all accounts over the last 30 days; change since the end of last month.
    - **Spent this month:** sparkline of the running total; change against the same days of last month.
    - **Income this month:** sparkline of the running total; change against the same days of last month.
    - **What you owe:** sparkline of the last five month ends and today; change since the end of last month.
  - **Spending this month** (the wide hero): the total and its change, then a Daily | Running segmented control: a bar per day, or the running total (filled) against last month's (dashed) with a legend. Under the chart, a stat strip (`StatStrip`): Highest day, Days with spending ("23 of 30"), Top category and Last month by now. Exact values under "Show values".
  - **Due and overdue** (R1–R3), beside the hero: This week | This month and Calendar | List.
    - Calendar: the calendar, Overdue on top and the day filter. Summary shows 4 rows per group before "Show all N"; the Debts & Dues tab shows 6. Overdue days are tinted rose as well as marked with the icon.
    - Calendar or List is chosen from a settings icon (`AppIconButton`, tooltip "Layout: ‹current›") in the card's top-right corner, which opens a menu with both (the current one checked). This week | This month stays a segmented control.
    - List (added in my second review, for sharing a screenshot): "This month · 1–31 Oct · as of Fri, 30 Oct", the totals plus "Total due" when something is overdue, then every item of the period in one table (Due date with "N days overdue", Item, Type, Status, Amount), sorted by date, with no row limit. Narrow cards show the same items as rows.
  - **Recent activity** (5 rows, closing with "N more in Activity", the count Money's Activity holds) beside **At a glance**; then **Next up in Life** and **Shared Expenses**.
- **Spending:**
  - **Spending by category:** a donut (top five and "Other") with "Top category" in the hole, and a legend of each category's share and exact amount. Net-negative categories are left out of the shares.
    - Legend rows: the swatch and name are vertically centered beside the share and amount; the share sits over the amount, or beside it on one line when the legend is wide. Only under 192 × the text scale does the amount take its own line.
    - Hovering (Windows) or tapping (Android) a section selects it: it grows 4 outward, the hole shows its name, share and amount, and its legend row is highlighted. Legend rows select their section the same way (hover, tap, or Enter by keyboard). Leaving the chart or tapping its hole clears it.
  - **Budgets:** a half-circle gauge of the total used across budgets with a limit (warning tone when over), beside each budget's slim bar and line ("45.13% used", "₱X over", zero-limit). An empty state when there are none.
  - **Largest expenses this month:** the five largest, as a table, closing with "N more expenses in Activity".
- **Debts & Dues:** Due and overdue beside **What you owe over time** (filled line, then a stat strip: Today, Since end of ‹month› with Paid down / Added, Highest; then "By debt": each debt with what you owe on it and a slim bar of its share); then **Debt payoff** as a table: the name with its pill on the same line (under the name only when both don't fit), a bar with one step per scheduled payment (a continuous bar above 24), the progress line, and what you owe.
- **Accounts & Activity:** an account card per active account (type icon, balance, 30-day sparkline, "Last 30 days"), a Card debt card ("Available credit ₱X, not money you have"), then **Recent activity** (10 rows).
- **Uneven rows:** a card can center its content in the height its grid row gives it (`OverviewCard(centered: true)`): the header stays at the top and the space left is split above and below the content. The Spending tab's category and budgets cards use it, so whichever is shorter doesn't leave a gap at its bottom.
- **"Show values"** sits 16 below the figures above it.
- **Tables** (`ActivityCard`, the dues list, the payoff table): columns when the card is at least 528 × the text scale wide; a list of rows otherwise. The amount column has one width per table, measured from its widest amount (`moneyColumnWidth`), so every other column starts at the same x on every row.
- **Sizes (dashboard only):** card titles `titleSmall`, captions `bodySmall`; KPI and chart totals `MoneySize.tile`; card actions are small links (`CardLink`, `labelMedium` in `primary` with a chevron); segmented controls (`MiniSegmented`) and quick-action chips look 32 tall. On Android every one of them keeps a 48 × 48 hit area (`TouchArea` adds transparent space around it). The rest of the app keeps its sizes.
- **States:**
  - An incomplete download shows "Not available yet" in every money value, list and chart; changes and sparklines are hidden.
  - Hidden amounts hide charts, the donut and every change line and sparkline ("Amounts hidden"); other values show "Amount hidden". At a glance leaves the amounts out of its sentences ("1 payment is overdue.") rather than say "Amount hidden" inside one.
  - Each card has its own empty state.
- **Dates:** "Today" is `civilToday()` (Asia/Manila), with `debtDueStatus` for every row. "This week" is Monday to Sunday; "This month" is the calendar month. Period rows start today; anything earlier is only under Overdue. "Last month" covers the same days, stopping at its own last day.
- **Changes** (`ChangeLine`): an arrow and the change in whole basis points of the earlier value, shown with one decimal and rounded toward zero ("↑ 4.2%"), then what it compares with. Rises in available money and income use the success tone; rises in spending and what you owe use warning; no change is neutral; an earlier zero shows "New", and zero then and zero now is no change ("– 0.0%"). Screen readers hear "Up 4.2% vs 1–28 Sep".
- **Snapshots:** money values, charts and sparklines use accepted history. Dues and debt progress use the Debts screen's records, which include waiting work.
- **Layout** (`DashboardGrid`, a 12-column grid by content width; at 150% text the width counts as two-thirds):
  - From 1104: tiles 3 columns each; hero 8 + dues 4; Recent activity 8 + At a glance 4; Life 6 + Shared 6; category 5 + budgets 7; dues 6 + owed 6; account cards 3 each; tables full width.
  - From 688: tiles and account cards two to a row; everything else full width.
  - Narrower, and always on Android: one column in priority order (Summary: tiles, At a glance, dues, hero, activity, Life, Shared). Tiles and account cards pair up when the column is at least 336 wide.
  - Cards in a row match the tallest (`_EqualHeightRow`). The grid owns the gap.
  - **Narrow cards and large text:** row amounts, a card's header control and label amounts move below the text under 336 × the text scale, and a row's status pill moves to the end of the title's line, or below the text only if the title would have under 80 × the text scale left (640 for a header with a segmented control); the donut, gauge and tables switch to stacked layouts; segmented controls and the tab row scroll sideways rather than shrink text.
- **Demo build:** the same dashboard, filled by a sample profile replayed in memory through the real rules (`planLocal`), dated relative to today: three accounts that end today on the demo balances (₱29,300.75 in all, as Money shows), two months of spending and income, six debts (one due soon, one 3 days overdue, one paid off, one with no schedule, one closed by an early payoff, and one with varied amounts, a partial payment and a payment without a breakdown), a card statement due in 5 days and three budgets. Demo scenarios (empty, incomplete, waiting changes, review) and hidden amounts apply. Nothing is stored. The previous demo Overview layout and its files are removed.

### Debts

`lib/finance/debt_screen.dart` (the section, its pages and the local source), `debt_cards.dart` (cards), `debt_data.dart` (display-only derivations) and `debt_demo.dart` (the demo source); tested in `test/debt_data_test.dart` and `test/debts_dashboard_test.dart`. Five-second question: "What do I owe, what's next, and is anything late?"

- **Header.** Windows: a `PageHeader`, "As of ‹long date› · N debts", with the shell's three New items as chips at the right end. Android: one 48-tall row, the date and a pill ("N overdue", else "N due this week") that opens Schedule; the pill drops under the date when large text can't hold both.
- **Tabs** (`AppTabs`): Summary · Schedule · Payments · History. They also show in the sidebar, the rail flyout and Go to, and take part in back and forward.
- **Notices**, under the tabs, only when they apply: first download not finished; changes waiting to sync (Debts include them, so totals can differ from the Overview until they sync); sync needs review.
- **Summary:**
  - **KPI tiles:** What you owe (the one accent, with the change since last month end and a sparkline), Overdue ("N payments · oldest N days"), Next payment (amount, then the debt, date and "in N days"; "None" when nothing is scheduled, never ₱0.00; same-day payments are summed) and Due this month.
  - **Your debts** (8): every debt, most urgent first, then a finished schedule with money still owed, then Settled and Closed. A filter (All, Overdue, Upcoming, No schedule, Paid off; a debt is under exactly one besides All). Each row: the name with its pill on the same line (under the name only when both don't fit), the lender, `SegmentBar`, the progress line, the next payment, what you owe and a "Log payment" link.
  - **Due next** (4): overdue, then the next 5 rows, debts only, each with "Log payment". It closes with "N more on Schedule" or "That's everything".
  - **What you owe over time** (`OwedCard`, 7) beside **Needs your input** (5): set a schedule, check a varied amount, break down a payment. Hidden when there is nothing to do; the chart then takes the row.
- **Schedule:** **Due and overdue**, the Overview's card. Its corner menu picks Calendar or List, All dues or Debts only, and "Open as a page". Calendar sits at 7 beside **Upcoming by month** at 5; List takes the full width with the chart under it.
- **Shareable list:** the Overview's list view (`DuesList`): the period heading with "as of", the totals, every item with no row limit. "Open as a page" (`DuesListPage`) shows only that, so an Android screenshot has no tabs, dock or + button.
- **Payments:** **Paid over time** (7, a bar per month for six months with this month, last month and paid down) beside **Payments to break down** (5), then **Payment history** (date, debt, paid from, applied to, breakdown, amount; 25 rows, then "Show more").
- **History:** every debt record with its earlier versions; rows open the record page, which keeps Correct and Reverse.
- **Debt details** (`NativeDebtDetail`, a `SectionPage`): the name, pill and "Lender · Type", then "Log a payment" and a More menu (Edit or Set schedule, Update amounts, Break down a payment, Log a lender charge or waiver, Log an early payoff, View record). Below: **Payoff** (the page's accent, 8) beside **About this debt** (4), then **Payments**, one row per scheduled payment, and **Payment history**. Closed and settled debts offer no new payment.
- **Display states** (`DebtProgress`, also used by the Overview). Closed: a payoff is on record, with or without a schedule. Settled: nothing owed and nothing open. Schedule finished: every scheduled payment is logged but money is still owed. Otherwise the `DebtDueStatus` label.
- **Tables** (`AppTable`): as §2 Tables, and they also turn into rows when the fixed columns leave the flexible ones under 48 × the text scale per share.
- **States:** an incomplete download shows "Not available yet" and no ₱ anywhere. Hidden amounts show "Amount hidden", hide charts, change lines and sparklines, and stop the progress line at "4 of 6 payments logged".
- **Dates:** the Overview's. "Next" starts today, so overdue rows are never next. Upcoming by month is this month and the next five; this month starts today and overdue stays separate.
- **Editors:** every Debts form is on the compact scale (§3) with `DateField`, `AmountField`, errors in place and plain labels. Fields most people skip sit under "More details", and fields show only when they apply: Paid into for cash, Category for a purchase, charge and waiver fields by what happened. Negative balance consent appears only once the rules ask. Log a debt payment asks for the essentials and fills the rest of the same command from the answers; corrections keep every field. An early payoff fills the lender's amount from the payoff amount.
- **Demo build:** the same screens from the Overview's sample (`demoSample`), so both agree. Demo scenarios and hidden amounts apply. Editors open the demo's own forms, and saving there doesn't change the sample.

### Money: Accounts and Activity

`lib/features/finance/presentation/money_screen.dart` (the section and its tabs), `lib/finance/money_dashboard.dart` (header, Accounts, Activity), `money_cards.dart` (cards), `money_details.dart` (account and record pages, Categories, Saved drafts, the local source), `money_data.dart` (display-only derivations), `money_demo.dart` (the demo source) and `money_editor.dart` (the forms); tested in `test/money_data_test.dart`, `money_dashboard_test.dart` and `money_form_test.dart`. Five-second question: "How much do I have, where is it, what changed, and does anything need me?" This covers Accounts and Activity; Cards, Planning, Reports, Import and Files are in the next section, under the same header and tabs.

- **Header.** Windows: a `PageHeader`, "As of ‹long date› · N accounts", with Log expense, Log income and Log a transfer as chips at the right end, on Accounts and Activity only. Android: the 48-tall date row, with no action buttons.
- **Tabs** (`AppTabs`): the seven labels, unchanged. There is no third tab layer: Accounts has Active | Archived in its table, and Activity has search, type and period.
- **Notices**, under the tabs, only when they apply: first download not finished; changes waiting to sync (balances here include them, so they can differ from the Overview until they sync); sync needs review.
- **Balances include waiting changes,** as Debts does: something just logged moves the balance at once.
- **Accounts:**
  - **KPI tiles:** Available money (the one accent, with the change since last month end and a 30-day sparkline), Money in, Money out (each against the same days of last month) and Due this week (the Overview's figure, overdue left out; "N due · M overdue" counts both), opening Debts › Schedule). Money in and out are cash movements, so a transfer between accounts counts only its fee, card purchases aren't counted and opening balances aren't movement. Together they explain the balance's change, which is why they differ from the Overview's Income and Spending.
  - **Where your money is** (8, or 12 with nothing needing attention): a table of Account, Share, This month and Balance, largest first, closing with a total that adds up: Archived accounts (when they hold money), Available money, then Card debt, which isn't counted. Active | Archived shows when an account is archived. `CardLink` Add account; a corner menu has Categories, Saved drafts and Imported history.
  - **Needs your attention** (4): accounts below zero, each account's newest balance check if it's unresolved, and saved drafts, each row going where it's handled. Hidden when there's nothing.
  - **Balance over time** (7) beside **Recent activity** (5, six rows, "See all" switches tab).
  - **Android order:** Available money, Money in + Money out, Due this week, Needs your attention, Where your money is, Recent activity, Balance over time.
- **Activity:**
  - **Top band:** search, a period chip (This month, Last month, Last 90 days, All dates, Custom) and Filters (Account, Category, From, To; a dialog on Windows, a sheet on Android). Active filters are removable chips. Type sits below: All, Money out, Money in, Transfers, Cards, Debts, Adjustments.
  - **Search looks through every date,** whatever the period says: description, notes, reference, merchant, category, account and exact amount (no amounts while hidden). The period chip says "All dates" while searching.
  - **One row per record:** its newest version. A corrected record has a Corrected pill. A reversed one stays with a Reversed pill and is left out of totals. Earlier versions are in the record's Edit history. Budgets, schedules and other records that move no money aren't activity.
  - **Dated list:** Later ("not in your balance yet"), Today, Yesterday, then each day, with the day's change at the end of its header. Space sets the days apart: 24 above a day's header and 4 below it, with hairlines only between the rows of a day. Amounts are signed; a transfer is unsigned with ⇄, or signed when seen from one of its accounts; a balance check reads "No money moved". 50 rows, then "Show more · N left".
  - **Shareable list:** the corner menu picks By day or List and has "Open as a page". The List has the period, "as of", the totals and every item, oldest first, with no row limit. Filtered to one account it's a statement: starting balance, a Balance column and closing balance. Reversed records, balance checks and records dated later aren't listed.
- **Account details** (`AccountDetailView`, a `SectionPage`): the name, a pill (Archived, or Below zero) and "Bank · BPI · Since 14 Oct 2026", then Log expense and a More menu (Log income, Log a transfer, Check balance, Adjust account balance, Archive account), all prefilled. **Balance** (the page's accent, 8) beside **About this account** (4), then **Activity**, showing this account's own effect, with the statement in its corner menu. Archived accounts offer no new records.
- **Record details** (`RecordDetailView`): one page for every record, opened from Money, Debts History, Cards, Planning and Reports. The description, a pill and "Expense · 29 Oct 2026 · Cash wallet", then the actions. **What this did** (the accent, 8) in plain words, beside **About this record** (4), then **Edit history**: every version with its reason, related refunds and adjustments, attachments, and "View details" for technical ids. Other sections' records show their fields there with plain labels (`recordFacts`).
  - **What it offers** (`recordActions`, which reads what the rules will insist on, so nothing fails at Review): Correct transaction, Log a refund (only with a portion to refund) and Reverse transaction. A record with a refund or adjustment says to reverse that first. A Shared-linked record links to Shared Expenses. An earlier version links to the current one. A balance check offers Adjust balance to match, or Check balance when records changed since.
- **Display states:** an incomplete download shows "Not available yet" and no ₱ anywhere. Hidden amounts show "Amount hidden", hide charts, change lines, sparklines and shares, and never add a sign. Each card has its own empty state; no accounts shows one empty state with Add account.
- **Dates:** the Overview's. Records dated after today sit under Later and are left out of balances and totals, matching `balance(through: today)`. Balance over time is a closing balance per day for 30 days, or month ends then today for 12 months. "Last 90 days" is today and the 89 days before it. "This month" and "Last 90 days" have no end, so later records stay in view.
- **Forms** (`MoneyEditor`, on the compact scale, §3): Log expense, Log income, Log a transfer, Add account, Add category, Check a balance, Adjust account balance, Adjust balance to match, Archive account, Log a refund, Correct transaction and Reverse transaction. Fields most people skip are under More details; the below-zero choice shows only once the rules ask, under the account it's about, including a separate fee account. Only Actual balance and Change to balance take a minus sign. Reverse asks only why. A correction of an opening balance or a linked adjustment offers no date, because the rules accept no other. Values start from `c.defaults` and every key stays in the command, shown or not, and draft keys are unchanged. If a save's answer is lost, the form checks the same command and never submits a second one.
- **`FinancialEditor`** is the demo build's now. `openFinancialEditor` sends those forms on a real profile to `MoneyEditor`; the demo's Shared, Cards, Planning, debt and Money forms stay as they were.
- **Demo build:** the same screens from `demoSample`, so Money agrees with the Overview and Debts. Scenarios and hidden amounts apply. The sample gained a split purchase, a refund, a correction, a reversal, a transfer with a fee, a balance check with a difference, an adjustment, a record dated later and an archived account. The demo can't show any `MoneyEditor` form, because they need the encrypted store: Log expense, income and a transfer open the demo's own forms, and the rest open a placeholder. Saving there doesn't change the sample.

### Money: Cards, Planning, Reports, Import, Files

`lib/finance/card_*.dart`, `planning_*.dart`, `report_data.dart`, `report_tab.dart`, `forecast_page.dart`, `import_data.dart`, `import_flow.dart`, `import_tab.dart`, `import_review.dart`, `files_data.dart`, `file_access.dart`, `files_tab.dart`, `file_pages.dart`, `record_facts.dart`. No third tab layer: Planning's old tabs are gone, and each tab is one page of cards.

- **Header.** Windows: `PageHeader`, "As of ‹date› · ‹context›", with the tab's actions as chips: Cards (Log a card payment, Add a statement, Add a card), Planning (Add a budget, Add a goal, Add a recurring item), Reports (Export CSV), Import (Import a file), Files (Attach a file). Android: the 48-tall date row, with actions on their cards. The three notices show on every tab.
- **Cards** answers what's owed, what's due and what credit is left, and never reads as money you have.
  - **Tiles:** Card debt (accent, change since last month end, sparkline), Due next, Still due on statements (each card's newest, because a newer one usually includes the last), Available credit ("Not money you have").
  - **Cards:** Your cards (table, closing with a total; credit used is sum used ÷ sum limits, never an average), Due next (with Log payment; never adds a statement to an installment), Card debt over time, Needs your attention, Recent card activity.
  - **Pages:** card, statement (with a shareable list), installment plan, Due on your cards.
- **Planning** answers within budget, on track, what's coming up.
  - **Tiles:** Budgets, Set aside, Coming up (a count, no total, because amounts can overlap), Cash forecast.
  - **Cards:** Budgets, Coming up (30 days), Savings goals, Cash forecast, Recurring items. Archived budgets and goals sit in a corner menu.
  - **Pages:** budget, goal, recurring item, Coming up.
  - **Zero-limit budgets** read "Zero-limit budget" everywhere: on the card, its page, Reports and the Overview's insight. They have no limit to be within or over, so the tile doesn't count them (`BudgetProgress.overLimit`). The rule's own `over` figure is unchanged.
  - **Budget gauge:** only when all budgets share a period and basis. It centers in the card's height and the list keeps to the top.
- **Reports** answers where money went and how it compares.
  - **Band:** a period chip (This month, Last month, Last 90 days, This year, Custom, up to 366 days) and Filters (Account, Category, From, To). This month runs to today against the same days of last month, as on the Overview; other periods compare with the same number of days just before.
  - **Honest filters:** a figure a filter can't work out says which filter it needs ("All accounts only", "All categories only"), never ₱0.00. A card in that position names the filter, not "Not available yet".
  - **Cards:** Spending (accent), Income, Money in, Money out; Where it went beside By category; Spending over time (by day to 62 days, then by month, or Running against the earlier period, dashed) beside Debts and cards; Budgets in this period (each with its whole period, never cut or added up); Records (25 rows, then Show more). Reversed records stay in Activity only. A corner menu opens the shareable report.
- **Cash forecast** (`ForecastPage`, read-only and always labelled an estimate): the chart full width, What to count beside What if, then What's included (Leave out, except what you've logged) beside What's left out (Put back). Card payments are one radio group per card, so the forecast's two refusals can't happen.
- **Import** answers what's waiting and whether the last one worked.
  - **Tab:** Waiting for you (the open import, or Import a file), Last import, Import history, What can be imported. The tab only reports; the review is a page.
  - **Review page:** Match columns, Check rows, Import. Same commands in the same order as before. Check rows has Needs a look | All; a row with a problem starts left out and can't be included; a possible duplicate asks for a tick; the below-zero consent shows only once it's needed.
  - **Import step:** one button sends each group of up to 50 rows in turn, with progress and Stop. Every id is kept in the draft first, so a lost response sends the same command again and a closed page picks up where it stopped. When it ends, the draft goes.
  - **Import page:** a pill, each row's result, and the file's fingerprint under View details.
  - **Stored row notes** stay in the records and the server's SQL as they are; `importRowNote` changes them on screen only.
- **Files** answers what's attached and whether anything is missing or unverified.
  - **Tiles:** Attached files (accent, total size), On this device, Missing, Checked (tap to read each file through; read-only, with progress). They count linked files only.
  - **Cards:** Your files (All | Missing | Archived links), Needs your attention (missing, failed a check, a file picked and not attached, leftovers), What's in your backups ("N files listed, 0 files included. Keep your originals.").
  - **Preview** (`ImagePreview`, images only; "Not virus-scanned" stays on the file's page, shown before Preview, so it isn't repeated here): most of the window on Windows, the dialog's full width on Android. Zoom by pinch, wheel or buttons, from fitted to 800%, about the middle of the view. **Open in another app** is in the preview, and on the page for a PDF, which has no preview.
  - **File page:** what it offers depends on where the file stands. "Not virus-scanned" stays visible, because it's true. **Attach a file** is a page: find the record, pick the file, review in a dialog.
  - **`FileAccess`** is what the screens ask of a profile's files. `LocalFileAccess` reads the encrypted store; the demo's answers are fixed.
- **Record page:** `recordFacts` gives Cards, Planning and Files records plain labels, with ids resolved to names and hidden amounts hidden. View details keeps only the technical ids.
- **Forms:** every Cards and Planning form on `NativeFinanceEditor`, on the compact scale, with plain labels, More details, pickers limited to what applies and automatic names. Adding a recurring item also adds its next 90 days, as a second command. If that fails, the item stays saved and offers Add to Upcoming.
- **Demo build:** `demoSample` gained three cards' worth of activity, recurring items, goals, budgets, two imports (one done, one waiting) and three files (on this device, missing, archived link), all replayed through the rules. It shows every tab and detail page, including the forecast. It can't show the Cards and Planning forms, the Import review, Attach a file, or real file preview, check and restore, which need the encrypted store.

### Shared Expenses: groups, Bills, Payments

`lib/shared/shared_hub.dart` (what the section shows, kept outside its screen), `shared_data.dart` (the source and display-only derivations), `shared_header.dart` (header and switcher), `shared_cards.dart`, `shared_bills_tab.dart`, `shared_payments_tab.dart`, `shared_pages.dart` (pages and flows), `shared_bill_form.dart`, `shared_payment_form.dart`, `shared_group_forms.dart`, `shared_demo.dart`; tested in `test/shared_data_test.dart`, `shared_dashboard_test.dart` and `shared_form_test.dart`. `lib/features/finance/presentation/shared_screen.dart` is the frame on both builds. Balances, People, My Records, History and Manage Group have their own sections below.

Five-second questions. Groups: which group am I looking at, and where do I stand in it? Bills: what's been shared, what's my part, and does anything need me? Payments: who paid whom, and what's waiting to be confirmed?

- **`SharedHub`:** the shell creates it once. It holds the repository and the chosen group, so a change of tab keeps them. The shell keys each section's screen on its tab, so nothing that must survive can live in that screen.
- **Choosing a group.** With two or more active groups and no default, Shared Expenses opens on **Choose a group** (`SharedGroupChooser`), not on a group the app picked. Each active group is a card with where you stand, its people and bills, anything to confirm and whether it's the default; archived and left groups are listed under it; Create a group and Join with a code are in the header (below the groups on Android).
  - **What opens:** the group chosen this session, then a default that can still be used, then an only active group. Archived and left groups don't count, so one active group opens by itself. Otherwise the chooser. A choice lasts until the app closes, so leaving and coming back doesn't ask again.
  - **Default group:** "Make this my default" on a card's menu or the Group page's More menu. It's saved with the profile's settings on that device, through the same path as Hide amounts, because saving settings rewrites the whole set. If it's archived or left, the chooser opens instead. Profile and settings lists it too.
  - **Back to choosing:** See all groups in the switcher, or Shared Expenses in the breadcrumb, which reads Shared Expenses › Household › Bills with several groups.
  - **What skips it:** the bell, the Overview's links and linked Money records already know the group. A sidebar tab picked first opens after the group is chosen. New asks which group in the form, or with a short list for a payment.
- **Header.** The group is the page's title and opens the switcher; the breadcrumb and app bar already name the section. Windows: its name as `headlineMedium` with a chevron, "As of ‹long date› · 4 people · 12 bills", and the actions at the right end. Android: the 48-tall row with the group's initial, its name and a "1 to confirm" pill that opens Payments.
- **Switcher.** A menu on Windows, a sheet on Android. Current groups with each one's standing and a count badge, then Archived or left, then About this group, Create a group, Join with a code and See all groups.
- **Tabs and notices.** `AppTabs` with the seven labels. Under them, only when they apply: first download not finished; offline ("New bills and payments wait here. Other changes need a connection."); N changes waiting for the group; sync needs review; left or archived.
- **Bills.** Tiles: Where you stand (the accent, with what you'd stand at if waiting payments are confirmed, always labelled), Your part this month, Group spending, Needs you. Bills (8; 12 when nothing needs the user) by month, newest first, 25 rows then Show more. Needs your attention (4): refused, restored, linked records that changed, drafts, waiting work, with Who paid, whose part under it so a long list has nothing empty beside it, and Shared over time (12) below. With nothing needing attention: Shared over time (7) beside Who paid, whose part (5).
- **Android order:** Where you stand, Your part + Group spending, Needs your attention, Bills, Who paid, Shared over time.
- **Payments.** Tiles: To confirm (the accent), Waiting for others, Confirmed this month, If all are confirmed (always labelled). Waiting to be confirmed (7): payments still open, with Confirm in the row for whoever can answer, then disputed ones. Between you and others (5): who the user owes and who owes them, with Log payment prefilled and a link to Balances. Needs your attention (12, only when there's something). Payments (12): by month, newest first, with filters for To confirm, Waiting, Confirmed, Disputed, and Cancelled or reversed, 25 rows then Show more.
- **Android order (Payments):** To confirm, Waiting + Confirmed, If all are confirmed, Waiting to be confirmed, Needs your attention, Between you and others, Payments.
- **What a payment offers** (`paymentChoices`, which mirrors the server): the recipient, or the owner for someone who isn't registered, can confirm or dispute one that's waiting, and undo one that's confirmed. The sender can cancel one that's waiting or disputed. Anyone else only reads it. Nothing is offered and then refused.
- **Pages** (`SectionPage`). Bill: How it was split (the accent, 8) beside About this bill (4), then Payments on this bill, Refunds and Edit history. Correct and Log a refund show for the bill's creator, off with a reason when offline. The More menu holds only the private actions that apply. Group: Where everyone stands (Confirmed | If confirmed, also at the top of Balances) beside About this group, then Recent activity. Payment: What this does (the accent, 8), with what's owed now and if it's confirmed, always labelled, beside About this payment (4), then Applied to and History (each event, with its reason). Its More menu holds only the private actions that apply: Add to my Money, then Count it in my group balance once it's confirmed, then Take it out of my group balance if that's undone.
- **Shareable lists** (opened from each card's corner menu, or a bill's More menu): a group's bills and a group's payments, each with This month, Last month or All dates, "as of", the totals and every item, oldest first, with no row limit; and one bill's split. They have no tabs or actions, so one screenshot says it all. Between you and one person is under Balances, below.
- **Landing.** A count of payments to confirm covers every group, so the bell and the Overview open the group that has one. A record in Money linked to Shared Expenses opens its group, tab and bill or payment.
- **States.** Not connected: Connect. Loading: a skeleton, never the empty state. No groups: Create a group and Join with a code. Offline with no groups: a connect message, and drafts stay listed. One member: Add someone. A group the user left is a partial copy: totals read "Not available yet", and their earlier records stay listed. An incomplete download shows no ₱. Hidden amounts hide charts and every figure.
- **You owe** is `text` with ↗, and Owed to you is teal with ↙, always with the words.
- **Forms** (compact scale; every form in this section). Add shared expense and Correct: one payer by default with "Split between payers", Who's in with Equal or Exact amounts, and the extra centavo named. Each person in Who's in shows what the bill leaves them with: "Owes ₱150.00" or "Gets back ₱150.00", over "Part ₱250.00 · paid ₱100.00". Until Who paid adds up to the total, only the part shows, with a note saying why, because a figure from half-entered amounts would be wrong. Correct starts from the bill's own split and date. Log a refund: who got the money back and whose part goes down, each with what's left beside it. Log a payment between members: who to, then All of it, Part of it or Choose bills, with what's owed shown first; only people the rules allow are offered as the payer, and anything over what's owed asks first. Choose bills sends the sum of its bills as the amount. Share your saved purchase is the bill form with its amount, date and payer fixed. Confirm, Dispute, Cancel and Undo, Create a group and Join with a code are modals. The commands are the same as before: `paid` lists everyone, zeros included. New bills and payments queue offline; everything else needs a connection and says so before the form opens or before Save.
- **Ids** are made once per form and frozen after a lost answer, so "Check again" asks about the same command, and the server answers from its receipt. A refusal gets a new id. A form that would send a stale group version stops at Review, because a refused command stays on record.
- **Dates.** Bills and payments count by their own date. Group balances have no date, so a bill dated later still counts in standing and sits in its month, with no Later section. A bill's refunds subtract from that bill wherever they fall. "N days waiting" runs from when the payment was logged, on the Asia/Manila calendar.
- **Saved drafts.** Drafts get real titles from what was typed, and opening one never fails: if its group or bill is gone, it says so and offers Discard draft. A shared purchase's link row isn't a draft, so Money's Saved drafts leaves it out.
- **Demo build:** `shared_demo.dart` builds five groups dated relative to today with the real split and payment rules: Household (the Overview's "1 payment to confirm"), Boracay trip (you owe), Reunion 2025 (archived), Old apartment (left), New group (one member). Scenarios and hidden amounts apply. The new forms work there, and saving doesn't change the sample. One bill the user paid is linked to a record in `demoSample`, so the record page's link works. The demo can't show the private forms or a real join.

### Shared Expenses: Balances

`lib/shared/shared_people_data.dart` (display-only derivations), `shared_balances_tab.dart`, `shared_person_pages.dart`; tested in `test/shared_b_data_test.dart` and `shared_b_dashboard_test.dart`. People, My Records, History and Manage Group follow in 11b and 11c. Two tab labels changed: Private review is **My Records** and Lifecycle is **Manage Group**.

Five-second question: who owes whom, and why?

- **Balances.** Tiles: Where you stand (the accent, shared with Bills), You owe, Owed to you, Waiting. Who owes whom (7): every pair after netting, the user's own first, each row opening the pair page, with Log payment for whoever can log it. Where everyone stands (5), whose rows open a person's page. Suggested payments (7) beside What these balances count (5): bills, refunds and confirmed payments, then waiting and disputed as not counted.
- **Android order:** Where you stand, You owe + Owed to you, Waiting, Who owes whom, Suggested payments, Where everyone stands, What these balances count.
- **Suggested payments** read "A proposal. Nothing changes until someone logs a payment." They never claim to be the fewest payments (DOMAIN_RULES §21), and a dispute pauses them with a link to Payments. Each row says what it asks: "Nico owes Tala at least this", or, past what's owed directly, "More than the ₱X Nico owes Tala directly. Everyone involved needs to agree first." or "doesn't owe directly" (§22). Only a row within what's owed offers Log payment, to its sender or to the owner for someone who isn't registered.
- **Between two people** (`SharedPairPage`, DOMAIN_RULES §17–18): the net (the accent) with what it'd be if waiting payments are confirmed, then every bill and payment by date, with bills before payments on a day, a Change and a running So far. The list ends exactly on `due(a, b)`. Payments that aren't counted sit apart: waiting, disputed, cancelled, reversed. Refunds sit inside their bill. Opens from Who owes whom, Payments' Between you and others and a person's page.
- **A person** (`SharedPersonPage`, §47): how their balance adds up to `positions()[person]`, what they can do, their bills, their payments and their history in the group.
- **Shareable lists** (a corner menu's "Open as a list" or "Open as a page"): between two people, a person's breakdown and Who owes whom. Each has "as of" and every item, with no tabs or actions. A running net needs every row, so they have no period control.
- **States.** A group the user left, and an unfinished download, read "Not available yet" with no ₱. An archived group shows its balances with nothing to log. A group of one offers Add someone. Someone who left keeps their balance, with "Left" on their row. A deleted account reads "Deleted account", and the server's stored name stays as it is.
- **Demo build.** Every event names who did it, and people have membership history. Household has a member who left with a balance, a person who isn't registered and invitations; the user is a member, not the owner, in Boracay trip, which has a deleted account; Reunion 2025 has a change of owner.

### Shared Expenses: My Records

`lib/shared/shared_private_data.dart` (display-only derivations and what a private form works from), `shared_records_tab.dart`, `shared_record_page.dart`, `shared_private_form.dart`; tested in `test/shared_b_form_test.dart`, `shared_b_data_test.dart` and `shared_b_dashboard_test.dart`.

Five-second question: what do my own records say about this group, and does anything need me?

- **Privacy.** The tab reads only the profile's own store and the user's own reviews. Group documents hold no private fields, so nothing here can reach another member. The account on a record page comes from the user's own source. My Records has no shareable list.
- **Tiles:** Needs a look (the accent), In my Money, Not in my Money, My records say.
- **Cards:** Needs a look (7) beside This group and me (5), then **Check against my records** (12) with All, Needs a look, Not added, Added, 25 rows then Show more. Earlier checks (12) shows reviews that came back from a backup, which don't count.
- **Android order:** Needs a look, In my Money + Not in my Money, My records say, Needs a look, This group and me, Check against my records, Earlier checks.
- **What's listed:** bills, refunds and payments the user is part of, each with a state: Not in my Money, In my Money, Needs a look, Kept as it is, To count, Counted, To take out, Taken out. Bills the user isn't on are never offered. A group the user left lists only records already linked. A record whose source is gone stays listed. `paymentLinks` decides what a payment offers, so the tab and the payment page can't disagree.
- **This group and me:** "The group says" and "My records say", with no difference, and a line saying they can differ while something isn't in Money or isn't counted.
- **Record page** (`SharedRecordPage`): the group's figures beside the user's record (the accent, 8), About my record (4), and What you've checked. Actions show only what applies: Add to my Money, Review my record, Count it in my group balance, Take it out of my group balance, Keep my record as it is, and links to the bill or payment.
- **Forms** (`SharedPrivateForm`, compact scale, one Review with `FinancialReview`). They sync first, so they start from the latest records; offline they still open, and saving says it needs a connection. Only what applies shows: Is this already in Money? offers only what the rules accept and locks amount, date and account once chosen; Paid from only with an amount above zero; Category only with a part; Why you're changing this only with an existing record; below-zero and changed-funding consent only once the rules ask. Count it and Take it out show a fixed amount from the user's record. A refusal goes on its field through `privateRuleFields`. A refusal before the form can open shows on the form's page, not a dialog. Each form has one command id, and a lost save looks up the same command. These forms keep no drafts, as before. `PrivateContext.command` builds the same values as before, every key kept.
- **Keep my record as it is** is a modal with a required reason and one id per form. It needs a connection, because reviews follow the user to their other devices.
- **Demo build.** The tab and record pages show the sample: a bill to look at, a bill kept as it is, a payment to count, one counted, a refund not added and a check from a backup, replayed through the rules. Accounts still end on ₱29,300.75. It can't show the private forms or Keep my record, which need the encrypted store, so they open a placeholder.

### Shared Expenses: People, History, Manage Group

`lib/shared/shared_people_tab.dart`, `shared_history_tab.dart`, `shared_lifecycle_tab.dart` and `shared_change_forms.dart`; the derivations are in `shared_people_data.dart`; tested in `test/shared_b_people_test.dart`. `_SharedForm`, `NativeSharedScreen`, `group_lifecycle.dart` and the frame's old demo tab bodies are gone. `shared_screen.dart` holds only `sharePrivatePurchase` and the private forms' entry points. Every tab is the same on both builds.

Five-second questions. People: who's in this group, and what can each of them do? History: what happened in this group, and when? Manage Group: what can I do to this group as a whole, and what will that do?

- **What's offered** (`groupChoices`, `memberChoices`, which mirror the server's `apply`; it still decides). An archived group takes only leave, transfer and restore. The owner can't leave or be removed, so a group can't lose its owner by accident. Transfer lists active registered members, Remove lists active people but the owner. Someone who left has nothing to do here. Nothing is offered and then refused, except the one case under Invitations.
- **People.** Everyone in this group (8): a row per person with their role pill, joined or left date and where they stand, opening their page; Add a person and Invite someone at the header's end for the owner. What each can do (4), for the kinds of people in this group. Invitations and Waiting or refused below, when they apply. **Android order:** Waiting or refused, Everyone in this group, What each can do, Invitations.
- **A person's page** gains a More menu: Invite them to take this place, Make them the owner, Remove from group, each only when it applies.
- **Invitations** (`openInvitations`). The server keeps invitations to itself, so the app rules out only those past their seven days and those this device revoked; the email shows only on the device that sent it. One that was used elsewhere still lists, and revoking it is refused and stays in Needs review. That's a known limit (PRODUCT_AND_FEATURES §22) until the server can report an invitation's state.
- **History** (`historyRows`): full width, because a side card would leave empty space beside a long list. By month, newest first, on the day it happened, with who did what ("Tala added Groceries"), the reason and the amount; rows open their bill or payment. Filters for All, Bills, Payments, People, Group; 25 rows, then Show more. The corner menu opens the shareable page (This month, Last month, All dates) and copies the group's history, which is off while amounts are hidden, because the copy holds them. A group the user left has no history here and says so.
- **Manage Group.** What you can do (7): only what's allowed, each with a line on what it does, and a note saying why the owner can't leave, or that the owner's account was deleted. This group (5): status, owner, the user's role, people, when it started. Waiting or refused below, when it applies. A group the user left says how to come back.
- **Forms** (compact scale, modals). Add a person; Invite someone; Invite them to take this place, which says it stops working if the group changes first; Revoke; Leave; Remove; Make the owner; Archive; Restore. Consequential ones say what changes and what stays, with amounts that respect Hide amounts: leaving or being removed doesn't forgive a balance, and archiving doesn't clear one. Reasons are required, and say everyone in the group can see them. Each form has one command id, one person id and one token, frozen after a lost answer; a refusal gets a new id; a stale group stops before anything is sent; offline, the form says so before it opens. The invitation code shows once, with Copy. If a lost invitation is sent later from saved work, its code can't be shown again, and the app says so.
- **Saved work** shows on its own tab: bills on Bills, payments on Payments, people changes on People, group changes on Manage Group, and only the open group's.
- **Demo build.** All three tabs show the sample. The group forms work there, and saving doesn't change it. Boracay trip shows a member's view, Reunion 2025 an archived group and Old apartment a group the user left.

### Life: Calendar

`lib/life/life_data.dart` (display-only derivations, `LifeSource`, `LifeWriter`), `life_hub.dart` (what Life is showing, the real source and writer), `life_header.dart`, `life_cards.dart`, `calendar_tab.dart`, `agenda_page.dart`, `life_pages_detail.dart`, `life_forms.dart`, `life_demo.dart`; tested in `test/life_data_test.dart`, `life_dashboard_test.dart` and `life_form_test.dart`. `lib/features/life/presentation/life_screen.dart` is the frame.

Five-second question: what's coming up, what's today, and is anything late?

- **`LifeHub`:** one per session (`lifeHubOf`), because the shell keys the section's screen on its tab. It holds the chosen day, the month on show, Calendar or Agenda, the Show filter and the search. The title bar's calendar, Android's date sheet and the Android pill all land on it.
- **Header.** Windows: a `PageHeader`, "As of ‹long date› · N things this week", with Add task and Add event as chips. Android: the 48-tall date row with a pill ("N overdue", else "N today"), no action buttons. During an unfinished download the Calendar's tiles read "Not available yet", so its caption drops the count and the pill hides.
- **Tabs** (`AppTabs`): the shell's list. A tab hidden in Preferences while it's open goes back to the Calendar.
- **Notices,** under the tabs, only when they apply: first download not finished (for Life's records, and for money rows); changes waiting to sync, including that a reminder can still go off for something already logged until they sync; Life couldn't refresh.
- **Calendar:**
  - **Tiles:** Today (the accent, "1 event · 1 due"), This week (today to Sunday), Overdue ("Oldest N days"), Next up (the first thing that hasn't gone by). Counts only: statements and installments overlap, and tasks have no amount. An unfinished download reads "Not available yet", because the counts would leave money out.
  - **Month** (7) beside **the chosen day** and **Overdue** stacked (5, `SideStack`), then **Coming up** (12, the next seven days). With nothing overdue, Coming up takes Overdue's place and there's no third row. So nothing empty sits beside the month.
  - **Month:** `MonthGrid`, Previous, Next, Today, and a `StatStrip` (Events, Tasks and due dates, Bills, cards and debts). The corner menu picks Calendar or Agenda, Show (only what Preferences shows), Open as a page, Past and cancelled, Reminders, and Preferences & help.
  - **Agenda:** every row of the month by day, in `LifeTable`, with search, 25 then `ShowMore`. Overdue sits above it, because late rows may belong to another month.
  - **Android order:** Today, This week + Overdue, Next up, Overdue, Month, the day, Coming up.
- **Rows.** A row says what it is, when, and how late. An all-day event reads "All day", a due date reads "Due", and neither ever shows a time. An event in another timezone shows both: "8:00 AM · 9:00 AM in Tokyo".
- **Money rows** are reminders of records, never instructions. They read as the rest of the app does ("Debt · Due Tue, 3 Nov", the amount, a pill), with "Reminders of your records. Salapiya doesn't pay anything." once per card, and have no Log link. They read the same records as Debts, waiting work included, so the two agree; notifications stay on accepted records (`p5_agenda_test`). A row opens its own page: a debt's, a statement's, a plan's or a recurring item's. Recurring dates not added yet don't show.
- **What's late.** Tasks, due dates, follow-ups and money dues. An event that has gone by isn't: few people mark one done, so it only reads Past, and its page offers Mark as done (my call, 2026-11-01).
- **Today** is `civilToday()`, as on Debts and the Overview. Timed events sit on their date in the display timezone.
- **Event page** (`LifeEventPage`, a `SectionPage`): the title, a pill unless it's simply scheduled, and "Event · ‹date› · ‹time›", then Edit event and a More menu that offers only what applies: Mark as done, Cancel event, Archive event, Mark as not done, Restore event. **When** (the accent, 8), with both timezones and a clock-change note, beside **About this event** (4), then **Reminder** and **Edit history**: each version's reason, when, and what changed, with ids under View details. Cancelling asks why, and each confirmation says what changes and what stays. Life has no delete.
- **Shareable lists** (`LifeListPage`, on `ShareableList`): This week, This month or Next month; one day; Overdue. Each has "as of", counts by kind, and every item, with no tabs, actions or money total.
- **Past and cancelled** (`LifeRetiredPage`): events that left the Calendar, newest first.
- **Forms** (compact scale; `LifeFormSteps`). Add event and Edit event: Title, Date, All day, Time and, only when the time happens twice, Which one?. Under More details: Timezone (a searchable list of plain names), Location, Notes. Edit asks why. Status and Archive left the form for the page's actions. The keys and defaults are the same as before (09:00, Asia/Manila, Scheduled). A time that doesn't exist errors on Time as it's picked, using the rules' own words, and nothing is chosen for the user when a time happens twice. Each form has one command id. After a lost save it freezes, comes back frozen if closed, and Check again sends the same command, which the store recognizes. A record that changed while the form was open stops it and offers Discard draft.
- **Demo build.** Calendar, Agenda, the event page and the event forms all work there, from `demoLife`, replayed through the real rules and dated relative to today, with `demoSample`'s money, so it agrees with Debts, Cards, Planning and the Overview's Next up. Accounts still end on ₱29,300.75. `DemoLifeWriter` checks with the rules and keeps nothing. It can't show real notifications, permission prompts, a save surviving a restart, a lost save or waiting sync.

### Life: Tasks

`lib/life/tasks_tab.dart` (the tab, the task page and the shareable list), `life_reviews.dart` (Changes to check) and `LifeTaskForm` in `life_forms.dart`; the derivations are in `life_data.dart`.

Five-second question: what do I need to do, and what's next?

- **Header.** It counts what the tab counts: on Tasks, the caption says how many are left, and Android's pill counts tasks only.
- **Tiles:** To do (the accent, "N high priority"), Overdue ("Oldest N days"), Today, This week (today to Sunday, as the Calendar's). Open tasks only.
- **Next up** (7): five open tasks, overdue first, then by date, undated last, nothing on hold, each with a checkbox. It closes with a link to the whole list.
- **By priority** (5): High, Normal and Low with a `SlimBar`, then On hold and No due date.
- **Your tasks** (12): Task, Due, Priority and Status, under a header per group: Overdue, Today, This week, Later, No due date. Active, Completed, Archived, All, and search through titles and details. 25 rows, then Show more. The checkbox sits outside the row (`AppTableRow.lead`), so one tap completes a task and the row opens it.
- **Android order:** To do, Overdue + Today, This week, Next up, By priority, Your tasks.
- **One tap** sends the same command as the page's button: `status` Completed with the reason Completed, or In progress with Reopened. It has no form, so a refusal shows above the cards.
- **Task page** (`LifeTaskPage`): the title, a pill, "Task · High priority · Due ‹date›", then Complete task or Reopen task, and a More menu with Edit task, Archive task or Restore task. **About this task** beside **Reminder**, then **Edit history**. A task with no due date says to add one to get a reminder. An archived task offers only Restore. A completion date shows only while it's Completed, because a reopened task keeps its old date in its record.
- **Shareable list** (`LifeTaskListPage`): what's left, by group, with "as of" and counts. No tabs or actions.
- **Forms.** Add task and Edit task: Title, Due date, Priority. Under More details: Details, Status, Date finished (only while Completed), Notes. Edit asks why. The keys and defaults are the same as before. The form steps, lost-save handling and field errors are the event form's.
- **Saved drafts.** Life's drafts have real titles and show what was typed. Add task, Add event, and editing a task or event open their form. Anything else, or a draft whose record went, says it can't open there and offers Discard draft. A tap never fails.
- **Changes to check** (`LifeChecksPage`): each refused edit, with why in plain words and only the fields that differ, Now above Your edit. **Use my edit** asks why and saves a new version; **Keep what's there** closes it. Either way the refused edit stays on record. Use my edit makes its command once, so Check again after a lost answer can't save it twice. An edit to a record that's gone can only be kept. A notice under the tabs opens the page. Edits a backup brought back wait there until the connection has checked them.
- **The bell.** `LocalSession` counts Life's waiting and refused edits, so the bell matches the sync pill. With only Life's to look at, Sync needs review opens Changes to check. Refused Life edits can be closed, which Shared's refused commands can't yet.
- **Demo build.** Tasks, the task page and the forms work there, from the same sample, and the Review scenario shows one refused edit. A checkbox says nothing was saved.

### Life: Reminders and preferences

`lib/life/reminders_tab.dart` (the tab, the whole list and `ReminderCenter`, a thin page that Profile and settings opens), `reminder_page.dart` (one item's settings and `ReminderSummary`, which the event, task, learning, book and career pages show), `reminder_data.dart` (display-only derivations and `LifeReminders`), `life_settings.dart`. `reminder_widgets.dart` is gone. Scheduling stays in `device_reminders.dart`, which now records each item's `ReminderView` beside its text, so screens read a state and don't parse a sentence.

Five-second question: what will remind me, when, and how do I change that?

- **Tabs:** Calendar · Tasks · Reminders · Learning · Books · Career. Reminders can't be hidden. The header says how many are set on this device, with no actions or pill.
- **This device** (the accent, 12): on or off, what the device allows, what it can do, and Send a test. Turning off says how many are cancelled and that records, the Calendar and other devices don't change.
- **Coming reminders** (8): what, and when it fires, nearest first, eight rows, then a link to every reminder. An item with no time, because it's dismissed or off, stays in date order. An overdue item with reminders off isn't "coming".
- **Quiet hours** and **What may show** (4, `SideStack`): start, end and timezone, with times picked, not typed. The notification's real words are shown, with Include the date. Titles, amounts, company names, contacts and notes never show.
- **By type** (6) beside **What happened** (6). Stopping a type that has reminders set asks first. What happened says what became of each, and never claims one was seen: "Its time passed. Salapiya can't tell whether it showed."
- **Android order:** This device, Coming reminders, Quiet hours, What may show, By type, What happened.
- **Reminder settings** (`LifeReminderPage`): when it reminds you, Change reminder, and What you can do. Only what applies: Dismiss what can still fire; Snooze 1 hour only once it has fired, because earlier it would fire early and lose the real one; Bring back what's dismissed; Turn off (with a confirmation) or Turn on. All-day items offer no minutes before, unless one is already chosen. "Inherited" reads "Default (on the day)" or "Default (at the time)"; the stored value stays. A dismissal that came back because the item changed says so. Nothing here completes anything or marks anything as paid.
- **What each platform can do.**

  | | Windows | Android |
  | --- | --- | --- |
  | Permission | No prompt; Windows settings decide, and it can't always say | Asks once; can be refused |
  | Timing | Scheduled by Windows | Inexact; battery saving can delay it |
  | After a restart | Windows keeps the schedule | Set again at boot |
  | Limit | Nearest 128 within 90 days | The same |
  | Locked screen | Follows Windows settings | Private visibility |

  With permission refused, the switch stays on and says the device is blocking these, with where to change it.
- **Notifications.** "Salapiya reminder", then "You have something coming up. Open Salapiya to see it." With Include the date on, the date replaces "coming up". There's no reminder email in the app; V2-G's email rules are the web build's, and these meet the same default. Tapping one whose item changed opens the Calendar and says "This changed, so its reminder no longer applies."
- **Preferences** (`LifeSettings`): Show in Life and Timezone beside Show on Calendar. Hiding keeps everything, and Calendar and reminder switches are separate.
- **Demo build.** Reminders, a reminder's settings and Preferences all work there, with a sample of states, kept in memory. Nothing is delivered, and Send a test says so. It can't show a permission prompt, a real notification, a refusal or what the device does after a restart.

### Life: Learning and Books

`lib/life/progress_tab.dart` (both tabs), `progress_pages.dart` (the item page and shareable lists), `progress_forms.dart` (the forms); the derivations are in `life_data.dart`. Tested in `test/progress_data_test.dart`, `progress_dashboard_test.dart` and `progress_form_test.dart`.

Five-second questions. Learning: what am I learning, how far along am I, and what's next? Books: what am I reading, and what's next on my list?

- **Header.** Each tab counts itself: "3 in progress", "2 reading". Android's pill counts that tab's overdue items, else what's due today. Windows has one chip, Add a learning goal or Add a book. Android has none: both are in the + sheet and New, unless the tab is hidden in Preferences.
- **Learning:** tiles In progress (the accent), Next date, Not started, Finished. **Now learning** (7) beside **What's next** (5), then **All learning** (12). Android: In progress, Next date + Not started, Finished, What's next, Now learning, All learning.
- **Books:** tiles Reading (the accent), On your list, Finished ("N this year" from recorded dates, else "All time"), at 4 each. **Reading now** (7) beside **Up next** (5), then **Your books** (12), with Author and Rating columns. Android: Reading, On your list + Finished, Reading now, Up next, Your books.
- **Rows** in progress: the row, a bar, "5 of 12 lessons · 7 left" and Log progress, one tap from the list. The bar has a step per lesson or page up to 24, then is one bar, so a long book is never drawn as finished. An item with no total has no bar and offers Mark as finished instead.
- **What's next and Up next:** by due date, then in the order added. What's next is anything open with a date, then what hasn't started. Up next is what hasn't started. Nothing on hold. Start and Start reading move an item to In progress with no date, because a date is the user's to give.
- **Lists:** Active, Finished, Archived, All, and search through titles and the course or author. 25 rows, then Show more. Each tab keeps its own filter (`LifeHub`). Under Finished the date column reads Finished, newest first; otherwise it reads Due.
- **Counts only.** No rates, averages or page totals: the rules define none. "Pages read" across books would add unrelated things, so it isn't shown.
- **Item page** (`LifeEntryPage`): the title, a pill and "Book · Rob Walker · Due ‹date›", then Log progress, or Mark as finished with no total, and a More menu with Edit, Start or Pick it up again, Put on hold, and Archive. **Progress** (the accent, 8) beside **About** (4), then **Reminder** and **Edit history**, which now shows progress, totals, ratings and dates started. Archived offers only Restore. A date finished shows only while finished, because a reopened item keeps its old date in its record.
- **A total of one** is how the rules hold "I don't know": the least total they allow, and their own default. The form leaves Total blank and sends 1. The item then reads as having no total.
- **Forms** (compact scale; `LifeFormSteps`). Add a learning goal, Add a book and their Edit forms: Title, Course or resource or Author, Total, how far (only with a total), Due date. Under More details: Status, Date started, Date finished (only while finished), Rating (only finished books, or one that has a rating), Notes. Edit asks why. The old form's made-up totals of 12 and 240 are gone: a skipped total sends the rules' default. Status shows Finished; the stored value stays Completed. Operations are unchanged, so older drafts open.
- **Log progress** (`LifeProgressForm`): how far, Date finished (only at the total, optional and blank), Note. It sends what the old action sent, but under the form's one command id, frozen after a lost answer. Its reason is the note, or "Progress updated" as before. Drafts are `life:progress:‹id›`; an older `life:Log progress · ‹title›` draft still opens from the id kept inside it.
- **Shareable lists** (`LifeProgressListPage`): Reading list and Learning list. "As of", counts, then what's being read or learned and what's next, with title, author or resource, due date and progress. No notes, ratings, finished items or actions.
- **States.** Nothing started: an empty state with Add. On hold: a pill; left out of Next, kept in counts. Dropped: archive it, and it reads Archived. No due date: the page says to add one for a reminder. Finished or archived: no reminder. Incomplete Life download: tiles read "Not available yet". Hidden tab: pages, Calendar rows and links still work. Type off in Preferences: the tab is unchanged, because it reads records, not the Calendar's rows. Hide amounts: nothing here is an amount.
- **Links.** Calendar rows, Reminders, the Overview's Next up and notification taps open the item's page, on both builds.
- **Demo build.** Tabs, pages and forms all work there, from `demoLife`, replayed through the real rules, with every state above. `DemoLifeWriter` checks with the rules and keeps nothing. It can't show a lost save, waiting sync, or a draft surviving a restart.

### Life: Career

`lib/life/career_tab.dart` (the tab), `career_pages.dart` (the application page, the step page and the shareable list), `career_forms.dart` (the forms); the derivations are in `life_data.dart`. Tested in `test/career_data_test.dart`, `career_dashboard_test.dart` and `career_form_test.dart`. `life_screen.dart` is now only the frame, 315 lines.

Five-second question: where do my applications stand, and what's my next step?

- **What it counts.** Current records only: how many are active, at each stage, closed by each outcome, and what's next. No Career reporting exists in this app, and L05 is deferred, so there are no rates, no time in stage and no results by source.
- **Header.** "5 active". Android's pill counts overdue follow-ups, else what's due today. Windows has one chip, Add an application; on Android it's in the + sheet and New.
- **Tiles:** Active (the accent, "1 saved, not sent"), Interviewing (Interview, Technical assessment and Final interview), Next step (what comes after anything overdue), Follow-ups due ("Oldest N days").
- **Where they stand** (8): each open stage with its count and a `SlimBar`, then how many are closed, by outcome. **Next steps** (4): overdue follow-ups first, then by date. An interview that has gone by isn't next. **Your applications** (12): Company and role, Stage, Applied, Next step. Active, Closed, Archived, All; Stage in the corner menu; search through company and role only, because the rest is private. 25 rows, then Show more.
- **Android order:** Active, Interviewing + Next step, Follow-ups due, Next steps, Where they stand, Your applications.
- **Follow-ups are due dates.** A Follow-up step past its date is Overdue on Career, the Calendar and Reminders, like an application's follow-up date. Interviews and assessments stay Past. This narrows my earlier rule (past events aren't late) for this one kind (decision log).
- **Application page** (`LifeApplicationPage`): the position, a pill, "Company · Applied ‹date›" or "Not sent yet", then Add a step, Change stage and a More menu with Edit application, Record outcome, Mark follow-up done and Archive. A closed one offers Edit, Reopen and Archive; an archived one only Restore. **Where it stands** (the accent) over **Steps** (8), beside **About** (4), so nothing empty sits beside a long About. Then **Documents**, **Job description**, **Follow-up reminder** and **Edit history**, which shows stage, outcome and every field, with salary hidden as it should be, and stored reasons in plain words (`lifeReasonText`); what's stored doesn't change.
- **Step page** (`LifeStepPage`): the kind, a pill, then Edit step and a More menu with Mark as done, Cancel step, Mark as not done and Restore step, each only where it applies. **When** (the accent; `LifeWhenCard`, shared with events) beside **About**, then **Reminder** and **Edit history**. A step on a closed or archived application is read-only and says why, because the rules refuse any change. A step that records what happened (Submission, Response, Offer, No response, Note) is always done, so it offers neither Mark as done nor Reopen.
- **Shareable list** (`LifeApplicationsListPage`): active applications, with company, role, stage, date applied and the next date. No notes, contacts, salary, links or documents.
- **Private data.** Contact, notes, salary, the posting link and the job description show only on the application's own page and forms. Search never reads them. Notifications stay on the generic words: no title, company, contact, amount or note.
- **Expected salary** is a money figure in its own currency, and is never summed. `salaryLine` writes it ("₱60,000.00 to ₱80,000.00 a month", "USD 3,000.00 a month"); it doesn't use `amount`, because that's always pesos. With Hide amounts on it reads "Amount hidden" on the page, in Review, in Edit history and in Changes to check. Edit locks a salary already held and keeps it in the command; a lock is decided once, as the form opens, so it can't close on someone typing.
- **Forms** (compact scale; `LifeFormSteps`). Add an application: Company, Position, Stage, Date applied (only once sent), In this stage since (only past Applied), Next step, Follow up on. Under More details: Location, Work arrangement, Posting link, Found through, Expected salary (Currency and Paid per only once there's a figure), Technologies, Job description, Contact, Resume used, Notes. Accepted isn't a stage to choose: it comes with its outcome. A company and role already here shows a warning and This is a separate application, only then.
- **Change stage, Record outcome and Reopen application** (`LifeStageForm`): each asks only what it needs, then Why, and every other field goes along unchanged. Accepted sets its stage as well, so the two can't refuse each other. Leaving Saved asks for the date applied; going back to Saved says that date is cleared, because the rules insist. Review on Record outcome says what stops and what stays. Reopening after Accepted asks for a stage.
- **Add a step** (`LifeStepForm`): Type, Date, Time (All day only for a follow-up), Which one? when the clocks repeat a time. Under More details: Timezone, Location or link, Preparation notes, How it went (once done). A step that records what happened asks only when, and what happened, and saves as done, so the rules never refuse it. The time fields are shared with Add event (`LifeTimeInputs`).
- **Saved drafts.** Every form's draft has a real title and opens its form, including drafts the old forms left.
- **Changes to check.** Use my edit shows only when the rules would take it, so a step on an application that has since closed can only be kept.
- **Links.** A Calendar row or notification for a step opens its page; one for an application's follow-up date opens the application.
- **Sync.** Every record works offline and queues as before; saving refuses while a connection is unfinished, with the fields kept. A lost answer freezes the form. Check again recognizes the application it already saved, so it's never refused as a duplicate of itself.
- **Demo build.** Tab, pages and forms all work there, with every stage and outcome, a step in another timezone, an overdue follow-up and a salary in another currency. It can't show a lost save or waiting sync. Accounts stay on ₱29,300.75.

### Life: Documents

`lib/life/career_documents.dart` (`LocalLifeDocuments`, `LifeDocumentsCard`); the interface, `LifeDocuments`, is in `life_data.dart`. Preview and opening in another app are shared with Money's Files (`previewImage`, `openPlainCopy` in `lib/finance/file_access.dart`, same look). Tested in `test/career_documents_test.dart` and `p5_documents_test.dart`.

- **What's different about documents.** A document's details are a Life record, which syncs. The file is encrypted on the device that attached it, and backups hold no files. So the card says where each one is, and what's offered follows from that.
- **Rows:** the file's name, then type, size and "On this device" or "Not on this device", with a corner menu. Archived links sit behind Show archived.
- **Menu, only what can work:** Preview (images on this device), Open in another app, Save a copy, Remove from this device, Archive link. A file that isn't here offers Restore from your original and Archive link. An archived link offers Save a copy and Remove from this device if it's here, and Restore link.
- **Attaching** asks first, with the file's name, type, size, "Not virus-scanned" and what happens to it. Only then does it write the encrypted file, save a draft and link it, so saying no keeps nothing, and being interrupted leaves something to finish.
- **Not attached yet:** a file interrupted part-way shows on its application with Finish attaching and Let go. If the application changed in between, Finish attaching reads the kept file back and links it afresh, because a file's encryption is tied to the application's version. So nothing has to be chosen again and a draft can't get stuck. This goes further than the plan's Choose the file again.
- **Confirmations.** Remove from this device says Salapiya keeps the details but not the file, and that there's no cloud copy. Archive link says the file stays. Let go says it was never attached and that the original stays where it is.
- **Saved drafts:** a half-attached file reads Attach a document, with its file name, and opens its application. Discarding it takes its encrypted file too, because nothing else could ever reach it. A draft whose application has gone says it can't open, and a tap never fails.
- **Changes to check.** Use my edit shows only when the rules would take it, so a document's refused link can only be kept.
- **Sync.** Attaching works offline. Its details queue and sync as any Life record; the file never leaves the device. Another device shows Not on this device, as does a profile restored from a backup, and Restore from your original brings it back.
- **Privacy.** Files are private to the application's page. They're never in a list, shared view, notification or the bell.
- **Demo build.** The card shows a file here, one on another device and an archived link, built through the rules. Every action says "Files need the encrypted store, so the demo can't open or save them." It can't show the picker, preview, opening a file, a half-attached file or a restore: those need the real build.

### Profile and settings

`lib/profile/`: `profile_page.dart` (the frame), `profile_source.dart` (`ProfileSource`, which real and demo builds share), `profile_actions.dart` (`ProfileActions`, everything these tabs can ask for, and the real build's `LocalProfileActions`), `profile_data.dart` (display-only derivations), `profile_tab.dart`, `help_tab.dart`, `help_data.dart`, `connection_tab.dart`, `connection_pages.dart`, `devices_tab.dart`, `backup_tab.dart`, `backup_pages.dart`, `profile_demo.dart`.

- **Five-second questions.** Profile: who is this profile, and how is it set up? Connection: is my data on this device only or syncing, is it healthy, and does anything need me? Devices: which sign-ins have my profile, and is anything wrong with one? Backup & recovery: is my data safe, when was my last backup, has anything changed since, and how do I get it back? Help: how do I find the answer to what I'm stuck on?
- **Frame.** One page, "Profile and settings", with `AppTabs` and a caption that says what the tab is for. There's no status pill: At a glance and Connection say it. A link to another tab moves the open page there and never opens a second copy, because the shell holds the tab. A failed preference save shows on every tab.
- **Profile.** **This profile** (8, accent) beside **At a glance** (4), whose rows move to Connection, Devices and Backup & recovery. **Appearance** (6) beside **Hide amounts** (6, its switch in `toggle`). **Defaults and more settings** (12): Default group, Life preferences, Reminders. On a phone, in that order. The profile id is under View details, and the Google email doesn't show here.
- **Default group.** The same saved value as the chooser and the Group page (`sharedDefaultGroup`, through `SharedHub.setDefault`). It lists only with two or more active groups, because with fewer Shared Expenses never asks. A default that was archived or left reads Ask me each time, with a note.
- **Edit name** is a short form, a modal with its error on the field. A profile's name isn't synced, so on a connected profile the form says it changes the name on this device.
- **Decorative effects** left the real Profile tab, because no redesigned screen reads it. The saved value stays, and the demo keeps the switch.
- **Help.** Search filters every question on the page; it works offline and sends nothing. Six topic cards at 6, then About Salapiya with the version and Licenses. Questions open in place and link to their screen. The words live in `help_data.dart`.
- **Life.** Life preferences opens `LifeSettings`, which isn't rebuilt. Reminders goes to Life's tab. `ReminderCenter` stays as `openLifeReminders`' fallback and the demo's row.
- **Connection.** **Sync** (8, accent) says the state, why, Last synced and the Google account, with one main action. **Waiting and to check** (4) has Money, Shared Expenses and Life, each going where it's handled. **Needs review** (12) shows only when something does. **Sync on this device** (6, its switch in `toggle`, with Sign out) beside **What's shared with the service** (6). With no connection, Sync beside What's shared. On a phone: Sync, Needs review, Waiting and to check, Sync on this device, What's shared.
- **States** (`ConnectionPhase`, from `phaseOf`): On this device only, Can't connect in this build, Waiting for Google, Google account chosen, This account has a different profile, Connection not finished, First download not finished, Checking a restored backup, Signed out, Sync paused, Syncing, Can't reach the service, N changes waiting, Needs review, Synced, Connected account deleted. `offered` lists what each allows and nothing else, so nothing is offered and then refused. Transport comes from `store.db.currentStatus`, because `label` stops at Needs review.
- **Group refusals** say how many there are and link to Shared Expenses, on Connection only. They don't count towards Needs review, because nothing can clear them yet. The bell and pill don't change.
- **A change to check** (`ChangePage`) says why, what can be done, and what it was in plain labels. Reasons are shown through `changeReasons`; the stored words don't change. Amounts mask with Hide amounts, and other saved values under View details don't show while hidden. Send this change appears only when the service has no record of it, and goes under its original id.
- **Connecting.** Review connection looks the account up, then shows one disclosure. A different profile stops at the tab: Save a backup, then Use that profile, or Keep this profile. Don't connect signs out of Google with nothing uploaded. A saved backup lasts across tab changes. There's no disconnect for a connected profile, because no rule exists: pausing, signing out, removing the profile and deleting the account are the ways out.
- **Devices.** **Signed-in devices** (8) lists after the first frame: this device first, then active, then ended, with Revoke on each active row. **Lost a device?** (4). **Remove or delete** (12). A local-only profile, or one with its account deleted, has a This device card and Remove. Offline it says it needs a connection and offers Try again. Signed out, it says to sign in and doesn't reach for the list. Dates read in Manila, "Not recorded" when the server has none. Session ids never show.
- **Consequential actions.** Revoke, Delete account and Remove keep their typed phrases, through `showTypedConfirmation`. Delete has a step before it: Sign in with Google again, which opens it for five minutes. The server's own check is unchanged. After a refusal or a lost answer it starts from a fresh sign-in, and the server's recorded outcome answers the retry. After deletion, this session offers only Remove. Sign out has a plain confirmation with the waiting count. Pause needs none. Remove and Delete count what's waiting.
- **Backup & recovery.** **Your backups** (8, accent): the last backup and whether records changed since, Save a backup, Check a backup. **How to get it back** (4), by whether the profile is connected. **What's in a backup** (12). On a phone: Your backups, What's in a backup, How to get it back. "Changed since" compares counts; there's no day limit, because no rule defines one. A failed backup shows until the page closes.
- **The device note.** After a saved backup, `recordBackup` writes its date and counts to `life_device` under `backup:last`. It doesn't sync, isn't in a backup, and needs no migration. Failing to write it doesn't fail the backup.
- **Save a backup** (`BackupSavePage`): what it holds, New secret or One I have, the secret masked with Show and Copy, a tick, then Save backup. The secret masks again when the app leaves the foreground, takes no keyboard learning, has no draft, and goes with the page. Copy says the clipboard is the user's to clear. Screens aren't blocked from capture. During an unfinished first download it says the backup holds only what has downloaded.
- **Check a backup** (`BackupCheckPage`): the secret, then the file, then what's inside in plain words, and whether it's this profile's. A wrong secret errors on its field. Nothing on the device changes, and only what's shown is kept from the opened backup.
- **Restore** isn't offered with a profile in use, because the rules refuse it. The tab says where it happens.
- **Privacy.** The Google email shows on Connection only. Device names are platform names. Ids sit under View details. This section has no shareable views.
- **Offline.** Profile, Help, saving and checking a backup, removing the profile and pausing all work. Sync now, Devices, Revoke, Connect, Delete account and Send this change need a connection.
- **Demo build.** The same tabs from a sample, with Demo tools on Profile and a demo-only Show a state menu on Connection, Devices and Backup & recovery, covering each state above. Actions show their confirmation, then say nothing happened. It can't show real Google sign-in, sync, revoking, deleting, the system's save and open windows, a real secret or a real restore. `ProfileExperience` was retired in the consistency pass.

### Onboarding

`lib/onboarding/`: `records_map.dart` (the map, its views and their words), `onboarding_data.dart` (`DeviceStart`, `StartupProblem`, words for a device with no profile), `onboarding_actions.dart` (`OnboardingActions`, everything these screens can ask for, and the real build's `LocalOnboardingActions`), `startup_pages.dart`, `greeting_page.dart`, `greeting_preview.dart`, `welcome_page.dart`, `setup_page.dart`, `google_page.dart`, `restore_page.dart`, `onboarding_demo.dart`. `lib/design_system/welcome_frame.dart` is the frame; `LocalBootstrap` stays in `lib/local/local_profile_view.dart`. Tested in `test/onboarding_data_test.dart`, `onboarding_pages_test.dart`, `onboarding_form_test.dart` and `onboarding_restore_test.dart`.

- **Five-second questions.** Opening: is my data all right? Startup failure: what went wrong, what's safe, and what can I do? Greeting: what is this, and how do I begin? Welcome: how do I start, and which way is right for me? Local setup: what do you need from me, and what can wait? Google: what happens next, and what leaves this device? Restore: is this the right backup, what will I get back, and what won't I?
- **What the standard doesn't cover here.** These are single steps with no records yet, so there are no tabs, KPI tiles, charts, tables, amount columns, `ListEnd`, Show values, shareable lists, or hidden-amounts and incomplete states. Tokens, cards, compact forms, errors on their field, one main action, large text, hit areas, the sweep and the demo all apply.
- **Frame** (`WelcomeFrame`). On `canvas`: the logo, a Back row on a step, a step line where there is one, the title and a caption. `aside` sits beside the content at the same height on Windows from `DashboardGrid`'s medium width (7 + 5); otherwise, and always on Android, `lead` comes first and `stacked` follows in one column. With no `aside` it's one 640 column. Windows centers it in the window, and Android starts at the top.
- **Where your records live** (`RecordsMap`, `recordsCard`). This device, Salapiya's service, Google and a backup file, each saying what it holds. A lit place on a solid line holds records or is getting them; a quiet one on a dashed line doesn't. Views: `local`, `google`, `chosen`, `restore`, `restoreConnected`. Each box is as tall as its text, the lines take the card's spare height, and one line sits under it (`recordsCaption`). Screen readers hear the full sentence (`recordsWords`). A phone gets one row of circles; at 150% text and up, just the sentence, because the labels have no room.
- **Opening** (`OpeningScreen`). "Opening Salapiya · Checking what's on this device". After 5 seconds it adds that nothing is lost by closing, which is true because creating, restoring, removing and migrating all resume or roll back. It claims nothing else.
- **Startup failure** (`StartupFailurePage`). A title per problem (`StartupProblem`), then What happened, What's safe and What you can do, then Try again. Show details holds the rule's words and, on Windows, the folder. Try again is the only action: the rules refuse a restore once anything is saved, and offering one where the key can't be read could overwrite the only key if the OS credential comes back. An exception's own text never shows, because it could quote a key. A saved stage of `removing` or `restoring` decides the words, whatever went wrong under it. `startupMessages` holds the table to the rule files.
- **Greeting** (`GreetingPage`, `GreetingPreview`). The first screen with no profile open. On Windows from 1008 wide: the logo, a large headline ("Keep track of your money and plans in one place."), the four sections with a line each, Get started and that Salapiya never moves money, on the left (5), beside a sample of the app on the right (7). Otherwise, and always on Android, it stays simple, with no sample: the logo, the headline and the four sections, centered, with Get started pinned at the bottom. It fits one screen; only a very short screen or large text scrolls, and the button stays in reach.
- **The sample** (Windows only) is built from the real cards, tinted as the screen's one accent, and marked Sample. Its figures are made up and fixed, not the demo's records. It can't be pressed or focused, and screen readers hear only that it's a sample with made-up figures, so nobody can take it for a real balance.
- **The greeting** is the app's one introduction, so Welcome doesn't repeat it. There's nowhere to save that it was seen before a profile exists, so it shows each time the app opens with no profile. With work in progress (a sign-in, or a first run or restore that stopped part-way) it steps aside for Welcome, which has something to say. Someone who has just removed a profile goes straight to Welcome.
- **Welcome** (`WelcomePage`). "Set up Salapiya". Three rows with a "Best if" line, the privacy card under them (`SideStack`) and the map beside them. Hovering or focusing a row shows it on the map.
- **What Welcome reads** (`DeviceStart`, read only, after the first frame). The saved stage, whether a profile's files are there, and the kept profile's name. The key never leaves `readDeviceStart`, and a test on a real store holds it to what `create` does. An earlier profile's files turn Start on this device off, with why; Google and Restore stay. A first run or restore that stopped part-way leaves only Start on this device, which carries on. "The last profile on this device was removed" shows after a removal. A sign-in that survived a restart shows with Continue.
- **Local setup** (`ProfileSetupPage`). Display name and Theme, which shows as it's picked and goes back on leaving, because only a new profile keeps it. A note on pesos, Manila time, encryption and that no accounts are added. A refusal about the name goes on its field; anything else in a notice above the buttons. If a first try stops part-way, the name and theme are fixed, the button reads Try again, and it calls `reopen`, because creating again would be refused by the check the first try set. Leaving then doesn't ask, because nothing is lost.
- **Google** (`GooglePage`). One page by state, using Connection's `phaseOf` and `offered`: What happens next with Google's own button, Waiting for Google with Cancel sign-in, Google account chosen with Review connection and Don't connect. Android says the same: Google opens in the browser. Review connection looks the account up, then opens the disclosure with what this path does: a profile found downloads, and a new account names the profile it creates. Every fact of the disclosure stays. When the profile opens, the page closes and the shell shows the first download.
- **What leaves first.** Signing in tells Google nothing about records. Reviewing lists the device's type under the account's sign-ins, before the disclosure, because `boundary()` registers it. The steps and the map both say so.
- **Words without a profile** (`noProfileNote`, `noProfileError`). A device with no profile has no records to reassure anyone about, so these say nothing changed. An error left from opening the app waits until something is tried.
- **Restore** (`RestorePage`). Step 1: the file, then the secret, then Open backup, with What comes back under them. A wrong secret errors on its field and the file stays chosen. Step 2: the backup's name, when it was saved, what's in it, What doesn't come back and, for a connected backup, the Google account and what's checked after signing in. A dialog says what changes, what stays and how to undo it. Then a one-column finished page with only what applies.
- **What a restore checks first.** `$owner.sqlite` being there means the rules would refuse it after doing all the work, so the review says so and offers Choose another backup only.
- **The secret.** Masked, no keyboard learning, no draft, cleared the moment the backup opens. The opened backup goes after restoring, or with the page.
- **Interruption.** Back is off while restoring. A restore that stops before its checkpoint changed nothing; after it, startup finishes it. On the page, Try again calls `reopen`, with no second restore and no dialog.
- **Offline.** Opening, the failure screen, Welcome, local setup and Restore all work. Google sign-in, lookup, connecting and the first download need a connection.
- **Privacy.** No email or id on Opening, the failure screen, Welcome or setup. The Google page shows the chosen account's email. Restore's review and finished page show the email saved in a connected backup, only after its secret has opened it. The profile id and format number never show.
- **Demo build.** First-run preview opens these pages on `DemoOnboarding`, with a demo-only Show a state menu covering each state above. It can't show real sign-in, a browser, the system's file window, a real secret or restore, a real failure, or a restart. Saving says nothing happened.
- **PRODUCT §12's tutorial.** Not built here: the starting goal, the guided first steps, the Getting started checklist and the replayable tour. Empty states, in-place help, Help and the demo build are what exists.

### Section screen standard (the Overview's quality bar)

I approved this standard on 2026-10-30. The Overview (above) is the reference for every section screen. A section keeps its own content and features, chosen to answer its own questions, but builds them in the same design language, at the same level of finish. Don't copy Overview cards one for one. Pick the widgets that suit the section, and build them the same way.

- **Start from the user's question.** Write down the section's five-second question, e.g. "what do I owe and what's next?" for Debts. The first tab, or the top of the screen, answers it. Detail goes in the other tabs.
- **Page anatomy.**
  - **Windows:** a `PageHeader` (title, plus a caption with context such as the date or period). Page-level actions sit at the right end of the title row, ending at the content's edge, never floating mid-row.
  - **Android:** no page title, because the app bar has it. The context row is one compact row, 48 tall, with an optional status pill at its end, and sits 4 above the tabs. No action buttons that repeat the + button above the dock.
  - **Tabs** (`AppTabs`): used when a section has two or more views. Labels capitalize each main word ("Debts & Dues").
  - **Notices:** under the tabs, only when they apply.
- **Grid** (`DashboardGrid`, 12 columns; one column on Android, in priority order):
  - Mix card widths with purpose: a hero card at 8 with a side card at 4; pairs at 6 + 6 or 5 + 7; tables and long lists at full width. Small tiles pair up on phones (`PairCard`).
  - Cards in a row share one height. A chart or figures card that may end up shorter uses `OverviewCard(centered: true)`. A list always starts at the top, under its header, and closes with `ListEnd`, so the space below reads as the end of the list.
  - When a card is left with empty space, fill it with something useful, such as a `StatStrip` of figures or a per-item breakdown. Never fill it with decoration, and never leave a large gap.
- **Cards** (`OverviewCard`):
  - **Header:** a `titleSmall` title and a `bodySmall` caption. A header's link or control and its corner menu center on each other.
  - **View controls:** a small segmented control (`MiniSegmented`) at the header's end. It moves under the heading when the card is narrow.
  - **Layout or settings choices:** an icon menu in the corner (`AppIconButton` + `MenuAnchor`, `corner:`), not a second segmented control.
  - **Links:** small `CardLink`s, never full-size buttons, in a card header.
  - **Accent:** at most one accent card per screen.
  - **KPI tiles** (`KpiTile`): icon badge, label, a `MoneySize.tile` value, a `ChangeLine`, a `Sparkline` and a caption. Tiles in a set share a label height, so their values line up.
- **Data display:**
  - **Tables:** shown as columns at 528 × the text scale and wider, and as rows below that. The amount column has one measured width (`moneyColumnWidth`), so every column starts at the same x on every row. Headers use `labelMedium` in `secondary`, with hairline dividers.
  - **Charts:** use the `kit/charts.dart` wrappers and follow the §5 chart rules.
    - Put a `StatStrip` under a chart when it adds meaning.
    - "Show values" sits 16 below the content above it.
    - An interactive chart (hover or tap to select) shows the same detail elsewhere too, such as in its legend, by keyboard and to screen readers.
  - **Changes:** whole basis points through `ChangeLine`, with an arrow and words, so meaning never rests on color alone.
  - **Progress:** `SlimBar`, or `SegmentBar` (one step per payment or installment). The row carries the words in its semantics label.
  - **States:** every card has an empty state, a "Not available yet" state (incomplete download) and a hidden-amounts state ("Amounts hidden" for charts).
- **Sizes and touch:**
  - **Data screens** (dashboards, lists, tables, reports) use the compact Overview sizes.
  - **Forms, editors and dialogs** are scaled down too, but stay easy to read:
    - Controls look about one step smaller than today's 48 on Android: buttons and segmented controls around 40, fields as tight as their label and helper text allow.
    - Spacing between fields and groups tightens.
    - **Readability floor:** typed values and body text never go below `bodyMedium` (14 on Android, 13 on Windows). Labels, helper and error text never go below 12. Errors and help (§6) stay fully visible.
    - **Metrics:** §3's compact form scale (`CompactForm`), which I approved on a sample form while building Debts; every form uses it.
  - **Android:** every control keeps a 48 × 48 hit area (`TouchArea`).
  - **Large text:** nothing is truncated at 200% text. Controls scroll sideways or wrap rather than shrink their text.
- **Shareable views:** when users show a list to other people (dues, balances owed, statements, a group's bills), offer a List layout. It has a period heading with "as of ‹date›", the totals, and every item in one table with no row limit, so one screenshot says it all.
- **Demo data:** the section's demo build shows populated, realistic content. It follows `overview_demo.dart`: a sample replayed through the real rules, dated relative to today, and agreeing with the demo's other screens. I review screens populated, not empty.
- **Tests:**
  - **Sweep test:** every tab at Android 320, 360 and 412 and Windows 720, 1200 and 1440 wide, at 100% and 200% text, in light and dark, plus hidden amounts, incomplete and empty states. The test app sets `themeAnimationDuration: Duration.zero`, so each platform really renders.
  - **The app-level sweep** (`test/consistency_sweep_test.dart`): the shell and every section's first tab, plus Profile and settings, at the same widths and text sizes in light, dark and both high-contrast themes, with no exception or overflow, and every semantics button pressable. Its source checks fail on a §4 literal, a legacy color or an older-kit import in real-use code. A new section adds nothing there; a new real-use file is checked by its path.
  - **Alignment tests:** for tables, rows and tiles.
  - **Demo sample test:** the sample replays on week, month and year edges.
- **Reuse:**
  - **Where the parts live:** the shared ones are in the kit (§5 Dashboard kit). `DuesCard`, `DuesList`, `DueCalendar`, `DebtProgressCard`, `OwedCard` and `ActivityCard` stay in `lib/app/overview_cards.dart` because they use finance types. The donut, gauge and account cards stay in `lib/app` until another section needs them.
  - **Moving more to the kit:** the first screen that needs one moves it into `lib/design_system/kit/` without changing its look, then documents it in §5.
- **Lessons from my Overview reviews** (check these before calling a screen done):
  - empty space beside a taller card;
  - columns that shift with each row's amount;
  - values pushed down by a label that wraps;
  - controls stranded mid-row;
  - a disclosure crowding the content above it;
  - oversized buttons;
  - actions that repeat the Android + button;
  - two controls of the same kind side by side;
  - tab labels not in title case.

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

"You owe" uses neutral `text` with the words and an arrow, and has no role of its own: owing a friend isn't a problem state, and teal stays the only colored direction.

### Charts, title bar, high contrast and legacy colors

- **Chart series** (`chartSeries`, in order): violet `#6546A3` / `#CABDFA`, teal `#266C80` / `#79C4D2`, plum `#9A4C72` / `#E6BCD4`, ochre `#80631B` / `#E4C572`, blue `#395EB2` / `#A9BCFF`, neutral `#59616F` / `#B9B9C6` (light / dark).
- **Windows title bar:** `titleBar` (= `canvas`) with a `divider` hairline below, `text` glyphs, and `secondary` glyphs while the window is inactive. Minimize and maximize hover with `windowControlHover` (`text` at 6%) and press with `windowControlPressed` (`text` at 4%), Windows 11's subtle fills. Close hovers with `windowCloseHover` `#C42B1C` and a white glyph and presses with `windowClosePressed` (that red at 90%), following the OS convention. In high contrast all three fill with `text` and invert the glyph.
- **High contrast** (`CraftTheme(highContrast: true)`): `secondary`, `border` and `divider` become `text`, and tinted status surfaces become `surface`. Effects are already off in high contrast.
- **Legacy:** `Palette` (`mint`, `peach`, `lilac`, `ink`, `porcelain`, `midnight`, `violet`, `lavender`) and the craft accents (`warm`, `plum`, `blue`, `focalStart`/`focalEnd`, `latticeEdge`) remain only for the demo build and the gallery. Real-use code uses none of them, and `consistency_sweep_test` checks it; new code must not use them.

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

`displayLarge` (45 / 52) and `headlineLarge` (32 / 40) exist for completeness. The Windows sidebar's labels use `NavType.label` (13 / 18), a step between `bodySmall` and `bodyMedium`, as Windows 11 navigation does. Amounts outside the display roles add `FontFeature.tabularFigures()`. Button and segmented-control labels use 14 / 20 (`labelLarge` metrics); chip labels use 12 / 16 (`labelMedium`).

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
- **Widths and heights:** `formMaxWidth` 640, `reviewMaxWidth` 760, `contentMaxWidth` 1280 (the Wide content cap), `titleBarHeight` 40, `dialogMaxWidth` 560 (confirmations), `popoverMaxWidth` 320, `railWidth` 64 and `sidebarWidth` 224 (the Windows sidebar), and `navItem` 36, `navTab` 32, `navIcon` 16, `navAvatar` 28 and `navSearch` 32 (its rows and parts), `appBarHeight` 56 (the Windows app bar and the sidebar's logo row), `goToWidth` 320 (the title bar's Go to field), `dockMaxWidth` 480 (Android dock), `navRailButton` 40 (the rail's square buttons). `pointerTarget` 32 is the control height where input is pointer-only (Windows); touch uses `target` 48. `compactRow` 36 and `compactTwoLineRow` 48 are Windows list rows; `compactIcon` 18 and `compactControlIcon` 16 are Windows icons.
- **`WidthClass`:** compact < 600, medium 600–999, expanded 1000–1439, wide ≥ 1440. It drops one class at text scale ≥ 150%.

### Windows density (compact scale)

Windows uses a compact scale, one step below Android, so the whole app matches the sidebar. Android keeps the sizes above.

- **Applied by:** the "Windows density" stage (4b), through the theme and the kit.
  - `Density.of(context)` is true on pointer platforms. It reads the theme's platform, as `isDesktop` does.
  - `SalapiyaTheme.build(..., platform:)` builds the scale for a platform; it defaults to the running one.
  - Context-aware tokens: `Radii.controlOf`/`cardOf`/`overlayOf(context)`, `Space.cardPaddingOf`/`cardGapOf(context)` and `ListRow.leadingSize(context)`. `FocusRing` and `Pressable` default to `Radii.controlOf(context)`.
  - Screens built from the text theme, the stock Material themes and the kit shrink at once. Real-use code has no hard-coded size, spacing, radius or color left (§4's recount), and `consistency_sweep_test` keeps it that way.
  - The sidebar keeps its own approved metrics: its rail buttons stay 40 (`navRailButton`).
- **Rule for all new Windows UI:** take sizes from this table, never from the Android column.

| Role | Android | Windows |
| --- | --- | --- |
| `displayLarge` | 45 / 52 | 40 / 48 |
| `displayMedium` (focal value) | 36 / 44 | 32 / 40 |
| `displaySmall` (metric value) | 28 / 36 | 24 / 32 |
| `headlineLarge` | 32 / 40 | 28 / 36 |
| `headlineMedium` (page title) | 24 / 32 | 20 / 28 |
| `headlineSmall` (dialog title) | 20 / 28 | 18 / 24 |
| `titleLarge` (section title) | 18 / 26 | 16 / 22 |
| `titleMedium` (card title) | 16 / 24 | 14 / 20 |
| `titleSmall` (row title) | 14 / 20 | 13 / 18 |
| `bodyLarge` (field input) | 16 / 24 | 14 / 20 |
| `bodyMedium` (body) | 14 / 20 | 13 / 18 |
| `bodySmall` (captions, helpers) | 12 / 16 | 12 / 16 |
| `labelLarge` (buttons, labels) | 14 / 20 | 13 / 18 |
| `labelMedium`, `labelSmall` | 12 / 16, 11 / 16 | 12 / 16, 11 / 14 |
| Buttons, fields, segmented controls, icon buttons | 48 (fields 60) | 32 |
| Menu items | 48 | 36 |
| Icons | 24 | 18 standalone, 16 inside controls and rows |
| List row (one line / two lines) | 48 / 56 | 36 / 48 |
| Card padding | 16 / 20 | 16 |
| Card gap | 12 / 16 | 12 |
| Corners: controls / cards / overlays | 10 / 14 / 20 | 6 / 10 / 12 |

- **Targets:** on Windows, pointer controls are 32 tall. This meets WCAG 2.2's 24 px minimum and Windows 11's 32 px control height, and replaces the 40 `pointerTarget` there. Android keeps 48.
- **Unchanged on both platforms:** spacing gutters and the page rules in [§4](#4-spacing-and-alignment-rules), colors, and motion.

### Compact form scale (`CompactForm`)

Forms are one step smaller than the base sizes and stay easy to read. I approved it on a sample of Log a debt payment.

| Part | Android | Windows |
| --- | --- | --- |
| Typed value | `bodyMedium` 14 / 20 | `bodyMedium` 13 / 18 |
| Field height | looks 40 (`Space.formControl`), 48 hit area | 32 |
| Label | `labelMedium` 12 / 16, 4 above the field | same |
| Helper, error | `bodySmall` 12 / 16, 4 below, always visible | same |
| Gap between fields / groups / actions | 12 / 16 / 16 | same |
| Buttons | look 40, 48 hit area | 32 |
| Form column | full width | max 640 (`Space.formMaxWidth`), centered |

- **Scope:** a theme scope, not an app-wide change. `NativeFinanceEditor` (Debts, and Money's Cards, Planning and Files forms), `MoneyEditor` and Update payment amounts use it. Each later chat adopts it for its own forms.
- **Hit areas:** an Android field stays 48 tall with its border drawn 4 inside, so its whole height takes taps; buttons get transparent space from `MaterialTapTargetSize.padded`.
- **ⓘ:** a field with one keeps a label row one hit target tall, and the form leaves out the field gap above it (`CompactForm.gapBefore`).

### Radius (`Radii`)

`control` 10 (buttons, fields, chips, tooltips), `card` 14 and `overlay` 20 on Android; Windows uses `compactControl` 6, `compactCard` 10 and `compactOverlay` 12 (read them with `Radii.controlOf(context)` and so on). `nav` 6 (the Windows sidebar's highlights, profile card and theme switch, and the Go to field) equals `compactControl`. Overlays are dialogs, sheet top corners, menus and popovers. `pill` 999. `Space.cardRadius`, `controlRadius` and `floatingRadius` (28, the dock) are legacy aliases.

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

### Windows caption buttons (`CaptionButtons`)

OS values, in one place as [§4](#4-spacing-and-alignment-rules) allows: 46 wide and as tall as the title bar, with 10 px glyphs from Segoe Fluent Icons (Segoe MDL2 Assets on Windows 10): minimize `E921`, maximize `E922`, restore `E923`, close `E8BB`.

## 4. Spacing and alignment rules

These rules are checkable. "Token" means a named value from [§3](#3-tokens). The numbers below are the values; [§3](#3-tokens) names them.

### Tokens only

- No numeric literals for spacing, size, radius, font size or color in widget code. This covers `EdgeInsets.*`, `SizedBox(height|width:)`, `BorderRadius.circular`, `fontSize:`, `Color(0x…)`, `Colors.*` and direct `Palette.*`. Use tokens and `TextTheme` roles.
- **Allowed exceptions:** `0`, a 1-px hairline, layout math derived from tokens, and OS or provider-branding values (window controls, Google button) defined in one place.
- **Check:** `grep -rEn "EdgeInsets\.[a-zA-Z]+\([^)]*[0-9]|SizedBox\((height|width): [0-9]|BorderRadius\.circular\([0-9]|fontSize: [0-9]|Color\(0x" <changed files>` returns nothing outside `design_system/theme.dart`.
- **Baseline before the redesign** (all of `lib/`, approx.): 139 `EdgeInsets` literals, 353 `SizedBox` literals, 73 `fontSize` literals, 38 radius literals, 80 hex colors (21 outside theme, gallery and p0), 133 inline `TextStyle(`. Spacing tokens are used 6 times.
- **Recount after the consistency pass** (the check above on the nine production paths, plus `lib/features`): 125 and 112 hits before the sweep, 75 and 23 after retiring the old demo screens, 45 and 22 after moving the Review step to tokens. Real-use code has none left: 6 are the allowed exceptions (`0` in token insets, Google's branding) and the rest are in the demo editor, `DemoActionPage`, `FinancePage` and the gallery's older kit. Real-use code has no `fontSize` literal (about 70 before the Windows density work) and no radius literal.

### Page

| Rule | Compact | Medium / Expanded | Wide |
| --- | --- | --- | --- |
| Page gutter (left and right) | 16 | 24 | 32 |
| Page top padding (below the title bar or app bar) | 16; 4 on Android, below the status row | 24 | 24 |
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

### Review checklist (every screen change)

1. Spacing grep is clean on the changed files.
2. Card gaps are equal in both axes, and row heights are equal.
3. Every card has the same padding and no text touches a border.
4. Rows are vertically centered, amounts are right-aligned, and nothing is truncated at 200%.
5. Light, dark and high contrast all work.
6. The screen meets the [Section screen standard](#section-screen-standard-the-overviews-quality-bar), and none of its "Lessons from the Overview reviews" apply.
7. Tables keep their columns aligned, and tiles in a set keep their values aligned.
8. The demo build shows the section populated.
9. The section's sweep test covers both platforms, both text sizes, both themes and the hidden, incomplete and empty states.
10. `consistency_sweep_test` passes.

## 5. Component rules

The kit lives in `apps/salapiya/lib/design_system/kit/`; screens import `kit/kit.dart`. Every component reads tokens only, works in light, dark and high contrast, and follows the platform from `Theme.of(context).platform`. The older widgets in `components.dart`, `workspace.dart`, `editorial.dart` and `form_presentation.dart` stay only for what still uses them: the demo editor (`FinancialEditor`), `DemoActionPage`, `FinancePage` and the gallery. No real-use screen imports them. The consistency pass retired `form_presentation.dart` (its parts moved to [`kit/review.dart`](#review-step-kitreviewdart)), `floating_actions.dart` (`FloatingActionMenu`), `navigation.dart`, the gallery's Navigation studies section, `IconTile` and `workspace.dart`'s unused widgets.

### Shared interaction

- **States:** rest, hover (Windows only, `subtle` fill), pressed (`subtle` fill), focus, disabled, busy and error. No ripple.
- **Focus ring:** 2 px `focus`, drawn 2 px outside the component and following its radius (`FocusRing`). It shows for keyboard focus only. Stock buttons draw it as a 2 px border from the theme.
- **Targets:** at least 48×48 on Android. On Windows, 32 (`Space.pointerTarget`) for buttons, fields, segmented controls, icon buttons and the info control; rows are 36 ([§3 Windows density](#windows-density-compact-scale)).
- **Activation:** Enter and Space activate anything focusable. Esc closes the top overlay.
- **Screen readers:** a control read as one button (`Semantics(button: true, excludeSemantics: true)` over a `Pressable`) passes the same callback as `onTap` and sets `container: true`. Excluding the child drops the `Pressable`'s tap otherwise, so the button can be heard but not pressed. The consistency pass fixed this in `AppTabs`, `CardLink`, `MiniSegmented`, `ChipButton`, `MonthGrid`, `FormMoreDetails`, the calculator keys, the Google button, `AppTable` rows, the shell's rail buttons, profile card, Go to field and New, and the Overview, Debts, Planning, Shared, Life and Help rows that did the same.

### Buttons (`AppButton`, `AppIconButton`)

| Variant | Use | Built on |
| --- | --- | --- |
| Primary | The one main action in a view or modal | `FilledButton` |
| Secondary | Other actions next to a primary | `OutlinedButton` |
| Tertiary (quiet) | Low-emphasis actions, Cancel in dialogs, "View all" | `TextButton` |
| Destructive | Removing records; only as a modal's confirming action or after one | Filled, `error` fill |
| Icon | Compact actions with an obvious icon; `standard`, `filled` or `outlined` | `IconButton`; the tooltip is required |

- **Metrics:** label 14 / 20 semibold (13 / 18 on Windows), height 32 on Windows and 48 on Android (§3), control radius. In a compact form an Android button looks 40 with a 48 hit area.
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
- **Amount field:** `amount: true` adds a ₱ prefix, tabular figures and the decimal keyboard. Parsing stays with the existing rules (`parsePhp`). `AmountField` adds the calculator at the field's end: a popover on Windows, a sheet on Android. "Use result" fills the field; a result rounded to centavos says so until the value is edited.
- **What a field accepts (`FieldInput`, `InputGuard`):** a field for one kind of data refuses anything else as it's typed: amounts (digits, one point, two decimals), whole numbers, number lists and typed dates. A small note at the field says why ("Numbers only, like 1500.00.") and goes on the next valid keystroke or after 3 seconds (`Motion.note`). It sits below the field, or above it in the lower part of the screen, clear of the keyboard. A pasted amount loses its ₱, commas and spaces. Most amounts can't be negative; `AmountField(signed: true)` is for the few that can.
- **Account pickers:** each account shows its balance in the menu, and the chosen one's sits under the field. If the amount is more than that, the line adds "this takes it below zero". Hidden amounts stay hidden.
- **Changes that need the latest records:** on a connected profile the sync rule (ARCHITECTURE §8.2) needs a fresh sync before some changes, such as a schedule, a payoff or a correction. The form handles this itself: Review says so, and Save syncs first ("Checking your latest records…"). If the sync brought new records, the review is rebuilt and the user checks it again, because nothing saves on a stale review. If it can't sync, the form stays on Review with everything kept, explains why, and the button becomes "Sync and save". Ordinary records never wait.
- **More details (`FormMoreDetails`):** a quiet disclosure for fields most people skip. It opens by itself when a field inside it has an error.
- **Page:** a form's title and step line sit in the form's column (`SectionPage(maxWidth: Space.formMaxWidth)`), starting at the card's left edge: "Step 1 of 2 · Details · * Required".
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

### Time and long lists (`TimeField`, `SearchPickerField`)

- **`TimeField`:** a time is chosen with the system's picker, never typed. It shows the time as the device writes it and hands back a `TimeOfDay`. Its actions are "Choose time" and "Cancel".
- **`SearchPickerField`:** a choice from a list too long to scroll, such as a timezone. It opens a list with a search box: a dialog on Windows, a sheet on Android. Options show plain names, never ids.
- Both share `DateField`'s field, which didn't change.

### Option picker (`OptionPicker`)

Each option is a `PickerOption` with a short noun-phrase label and an optional one-line description. `PickerStyle.auto` applies this rule:

| Control | When | Descriptions |
| --- | --- | --- |
| Segmented control | 2–4 options, labels of at most 12 characters, that change only the *view* (period filter, list or chart). It is also the period filter. | None. Options that differ in effect may not use it, because the effect can't be seen before choosing. |
| Radio list | Up to 5 options that differ in effect | Always visible under each label. The whole row is the target. |
| Dropdown | 6 or more options, or long lists such as accounts and categories | Two-line menu items, visible in the open menu before choosing. The selected option's description becomes the helper text. |

Checkboxes are the stock widget, themed. Switches are `AppSwitch`: 20 tall on Windows and 24 on Android, in step with compact fields, with a 48 hit area on Android. `SwitchRow` is a label and its switch, read as one control and kept to a row's height. A switch for a whole card goes in `OverviewCard`'s `toggle`, level with the title: on Android its target lies over the card's padding, so it never pushes the content down. A switch with help goes inside a `HelpField`. Older screens keep the stock size until their chats.

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
- **Choice lists:** a modal whose rows make the choice (the destination chooser, the New sheet) passes `primary: null` and keeps only Cancel. Each row closes the modal with its value.
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
- **`PageHeader`**: a `headlineMedium` page title, an optional `bodyMedium` caption 4 below, and actions centered on the title. The parent owns the gap after it (`headerGap`).
- **Accent:** `SurfaceCard(accent: true)` and `MetricTile(accent: true)` use the `selection` fill. Use it for the one tinted focal card on a screen, never more.

### Tabs (`AppTabs`)

- Underline tabs that switch between views of one page: `labelLarge` text, `secondary` (medium weight) or `primary` (semibold) when selected, with a 2 px `primary` underline on the row's `divider` hairline. 12 between tabs.
- Each tab is `hitTarget` tall (32 on Windows, 48 on Android). The row scrolls sideways when it doesn't fit; text never shrinks.
- Screen readers hear each tab as a selected or unselected button in a group. Each tab's key is `ValueKey(value)`.
- Every section and Profile and settings use it.

### List rows (`ListRow`, `ListGroup`)

- **Height:** one line is at least 48, or 40 on Windows. Two lines are at least 56.
- **Padding:** 12 horizontal and 8 vertical.
- **Leading icon:** 24, in `secondary`, centered on the text block.
- **Text:** the title is `titleSmall` and the subtitle is `bodySmall` in `secondary`.
- **Trailing:** usually an amount or a status pill. It is centered vertically on the row, like the leading icon and the chevron.
- **Tappable rows:** they get a chevron and hover, pressed and focus states.
- **`stackTrailing`:** puts the trailing item under the text, end-aligned, for rows too narrow to hold both (the caller decides, because `ListRow` sits inside intrinsic-height layouts and can't measure itself).
- **`titleEnd`:** sits at the end of the title's first line, on the title's baseline, so the subtitle keeps the row's width. `AdaptiveRow` uses it for a status pill in a narrow row: pass the pill as `pill` beside an amount in `trailing`, or as `trailing` alone. Only the amount moves under the text, so it's never cut.
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
- **`SyncReviewNotice`**: "Sync needs review" in one sentence for every section, with Review when the section has somewhere to send it, or naming Profile › Connection when it doesn't. The sync label isn't its body, because it repeats the title.
- **Toast:** the stock `SnackBar` with the theme's `snackBarTheme`. Use it only for a short confirmation of an action the user just took, and never for errors (they are inline).

### Amounts (`MoneyAmount`)

- **Display only:** it shows the string the app already formats (`session.amount(value)`, which gives "Amount hidden" when amounts are hidden). It never formats or calculates.
- **Sizes:**
  - **Row:** `titleSmall`.
  - **Tile:** `headlineMedium`, stepping down to `headlineSmall` and `titleMedium` (the compact dashboard value; Overview only).
  - **Card:** `displaySmall`, stepping down to headline roles to fit.
  - **Focal:** `displayMedium`, stepping down. It scrolls sideways only as a last resort.
  - Figures are always tabular, and the line never wraps.
- **Kinds:**
  - **Neutral, Spent and You owe:** `text`, with no role of its own (§3).
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
  - **Files:** copied byte-for-byte into `assets/branding/providers/google/buttons/`. The rest of the zip isn't kept in the repo; download it again from the link above when the artwork needs updating.
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

### Charts (`OverviewBarChart`, `OverviewLineChart`, `Sparkline`, `OverviewDonut`, `BudgetGauge`, `ChartLegend`, `ChartValues`)

- **Library:** `fl_chart` 1.3.0 (MIT), pinned.
  - It is pure Dart, with no native code or bundled assets, so it works offline.
  - It is maintained, and every color and text style is passed in, so it follows light, dark and high contrast.
  - It is needed for the line charts.
  - The rejected alternatives: Syncfusion (a commercial license) and hand-drawn painters for lines with hover tooltips.
- **Look:**
  - Series colors come from `chartSeries`.
  - Grid lines are `divider` hairlines, horizontal only, and axis labels use `bodySmall` in `secondary`.
  - Tooltips are `raised` with a `divider` border and the control radius.
  - The plot is 144 tall (`Space.xxxl * 3`); the hero chart is 192 (`Space.xxxl * 4`).
  - Bars have rounded tops. Lines are curved without overshoot; a filled line fades from its color at 24% to nothing.
  - **Sparkline:** a decorative line with a soft fill, no axes or touch, 40 tall (96 wide beside a value). Screen readers skip it; its tile says the values.
  - **Donut:** 160 across, 16-wide sections 2 apart, starting at 12 o'clock; the hole holds a label that scales down rather than overflow.
  - **Gauge:** a half circle, 12 wide with round caps, `subtle` track and `primary` fill (warning when over).
- **Rules:**
  - Charts never animate (`duration: Duration.zero`).
  - No money appears on an axis, because axis labels would have to abbreviate it. Exact values appear in tooltips and in "Show values" (`ChartValues`, a disclosure of rows).
  - **Axis labels** never leave the chart or overlap: the edge ones stay inside the plot, the band is as tall as the labels at the current text size, and when they don't all fit the width every other one (or fewer) shows, counted back from the last, so the latest point keeps its label. Each label is keyed by its measured width, because fl_chart measures a label once and a text-size change would leave it stale.
  - Each chart has a screen-reader summary.
  - Series differ by more than color: solid against dashed, with a `ChartLegend`.
- **Progress bars** on the Overview are `SlimBar` (6 tall, pill ends) and `SegmentBar` (one 8-tall step per scheduled payment, 2 apart). Both are decorative; their row carries the words in its semantics label.
- **Charts are hidden while amounts are hidden.**

### Dashboard kit (moved from the Overview)

`CardMenu`, `FactRow`, `OverviewDonut` and `BudgetGauge` moved here when I built Money's Cards and Planning, same look. New: `CardLink(chevron: false)` for a link in a row with its own chevron, which then ends flush with its text; `ListEnd(onPressed:)` for a list cut short; `detailLine`, whose details break between themselves and never inside one (a sign stays on its amount, through a word joiner); `LabelAmount(stackBelow:)`; `OverviewCard(fill: true)`, which hands its child the height left under the header.

`kit/dashboard.dart` (`OverviewCard`, `AdaptiveRow`, `LabelAmount`, `NotAvailable`, `AmountsHidden`, `narrowAt`, `TouchArea`, `CardLink`, `MiniSegmented`, `ChipButton`, `QuickActions`, `IconBadge`, `ChangeLine`, `KpiTile`, `PairCard`, `SlimBar`, `SegmentBar`, `StatStrip`, `moneyColumnWidth`), `kit/dashboard_grid.dart` (`DashboardGrid`) and `kit/charts.dart` (`Sparkline`, `OverviewBarChart`, `OverviewLineChart`, `ChartLegend`, `ChartValues`). Their look is unchanged and they keep their names. Additions, all optional: `KpiTile.compactSpark` keeps the sparkline beside the value in a narrower tile; `SlimBar` and `SegmentBar` take a `track` color for the tinted focal card.

`LifeWhenCard` (`life_pages_detail.dart`) and `LifeTimeInputs` (`life_forms.dart`) moved out of the event page and form for Career steps, same look. `AdaptiveRow(narrowBelow:)` keeps a short link beside the text in a narrower row than an amount needs. `FieldInput.rating` takes a number from 0 to 5 with up to four decimals. `AppTabs` brings the selected tab into view when the row doesn't fit; it moves only the row, never the page.

### Tables with a leading control

`AppTable(leadWidth:)` reserves a column before the row, and `AppTableRow.lead` puts a control in it, outside the row's target. Tasks' checkbox uses it. Tables that don't pass it don't change.

### Calendar grid and side cards

`kit/month_grid.dart`: `MonthGrid`, split out of `DueCalendar` with no change in look, so Life's Calendar can use it; `DueCalendar` wraps it. `SideStack` in `kit/dashboard.dart` holds two cards in one grid cell, the second taking the height left, so nothing empty sits under them beside a taller card. `ShareableList` in `kit/section_page.dart` is Shared's shareable page without its group, same look.

### Tables (`AppTable`; moved from Debts)

`kit/app_table.dart`: `AppTable`, `AppTableRow`, `AppTableColumn`, `dateColumn` and `ShowMore`, moved from `lib/finance/debt_cards.dart` and renamed, because a debt-named class doesn't belong in the kit. The look is unchanged. Additions, both optional: `AppTableRow.header` starts a group of rows and takes no part in the columns, so every day of a dated list shares one set of widths; `dense` is for long lists of one-line rows. A group header has `groupGap` above it (`md` under the table's own header) and `xs` below it, with no hairline around it, as columns and as rows. `ActivityCard` gained an optional `footer`.

### Form fields without a store

`FormInputs` in `lib/finance/form_mechanics.dart` holds a compact form's fields, anchors and errors, split out of `FinanceFormFields` with no change in look, so forms with no `LocalFinancialController` can use them. `SharedFormSteps` adds the group forms' details, review and send.

### Form exits (`FormExitGuard`)

Leaving a form with changes asks first, in the kit's confirmation (`showAppDialog`), with Keep editing and one main action:

- **A form that keeps drafts** (`keepDraft`): "Keep this draft for later?", with Keep draft & close as the primary. The draft is written first; if that fails the form stays open and says so.
- **A form without drafts:** "Discard your changes?", with Discard changes as the destructive button, and focus starts on Keep editing so Enter never discards.
- A draft is discarded from Saved drafts (Money's page holds Money's and Life's; Shared Expenses has its own), not from this dialog, so it keeps §5's two actions.

### Review step (`kit/review.dart`)

`FormStatus`, `FormSyncStatus`, `ReviewRow`, `SectionHeading`, `FormEvidence`, `ReviewNotes` and `FormExitGuard` moved here from `form_presentation.dart` (now gone), `editorial.dart` and `workspace.dart`, same look on tokens. They are the Review step and saved state of the Money, Debts, Cards, Planning, Files and Shared private forms, and the exit guard of every form.
- **Tokens:** padding `Space.lg`, rows `Space.sm` apart, label to value `Space.lg`, gaps `Space.xs`/`Space.md`, the status badge `Space.xxl + Space.sm`, icons `Space.xl` (status) and `Space.compactIcon` (disclosure, notes). The status box uses `Radii.controlOf`, as `InlineNotice` does, and gets `InlineNotice`'s high-contrast border, so it doesn't disappear when its tint turns to `surface`. A row stacks under `Space.xxxl * 10` wide or above 150% text.
- `SectionHeading` lost its unused `trailing`.
- **Not exported from `kit.dart`:** Profile has its own `ReviewRow` model, so screens import `kit/review.dart` by name.

### Typed confirmation (`showTypedConfirmation`)

`kit/modals.dart`. For a consequential action behind a phrase: focus starts on Cancel, the destructive button stays off until the phrase is typed exactly, and the field's controller lasts through the closing animation. `ModalAction.ready`, optional, keeps any modal's primary off until it's true; other modals don't change. `HelpTextField` gains `secret` (no suggestions, autocorrect or keyboard learning) and `obscured`. `ProfileInitial(onAccent:)` uses `surface` on the tinted card, as `IconBadge` does.

### Secret field and modal paragraphs

`SecretField` in `kit/secret_field.dart` and `ModalParagraphs` in `kit/modals.dart`, moved from `backup_pages.dart` and `connection_tab.dart`, same look. `showConnectionDisclosure` and `WhatIsShared` moved to `connection_pages.dart`, same words, so every path that connects says the same; `lead` adds what a path does. `openBackup` in `profile_actions.dart` keeps a wrong secret's handling in one place. `HelpTextField` gains `textCapitalization`.

### Shell tools and the calculator sheet

`showCalculatorSheet` in `kit/calculator.dart` is the calculator as a bottom sheet with Close, for amount fields (`onUse`) and the + sheet. In a sheet the panel takes the sheet's padding, and the expression line shows only when there is one; the popover on Windows is unchanged. `ListRow.leadingColor`, optional, colors the leading icon, such as a status tone; rows that don't pass it don't change. The bell, the sync status and Hide amounts moved from the title bar to `lib/app/shell_tools.dart`, same look on Windows, so Android shares them.

### Section page (`SectionPage`)

A page opened from a section. Windows starts with the title; Android starts with a 48-tall back row, because the app bar hides on pages. `status` sits with the title and `actions` end the heading. `maxWidth` narrows the page's column, title included, so a form's title lines up with the form. `RouteEscape` moved here with it.

### Not built

- **Pager:** not needed; long lists use `ShowMore`.

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
- Errors appear inline, say what to fix, and name the field: "Enter a date on or after 2026-11-01." When there are several errors, a summary goes at the top of the form, linked to the fields. **No error dialogs.** The one small pop-up is the note at a field that refused a keystroke ([§5](#form-field-with-help-helpfield-helptextfield-infocontrol-formerrorsummary)): it blocks nothing, needs no answer and goes by itself.
- **Errors after submitting** go on the field they're about, in red, even when the rule names no field: not enough money marks the account. A problem no field can show sits in a notice above the form. Only a problem that's really about the whole record belongs there.

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
| Hypothetical | What-if | Cash forecast |
| Reservation | Money set aside | Goals |
| Stage, preview, decision, process | Save rows, Check rows, Confirm, Import | Import |
| Batch | Import | Import |
| Cancel remaining chunks | Stop remaining rows | Import |
| Checksum | Fingerprint | Under View details only |
| Private supporting file, bytes | File | Files |
| Unscanned | Not virus-scanned | Files |
| Detach | Archive link | Files |
| Orphan | Leftover file | Files |
| Posting, posting detail | Record, Records | Reports |
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
| Private review | Check against my records | Shared Expenses reconciliation. The tab is **My Records** |
| Lifecycle (group) | Manage Group | The tab's label |
| Add manual person, Manual participant | Add a person, Not registered | |
| Nominate a verified claim | Invite them to take this place | |
| Transfer ownership | Make someone else the owner | |
| Remove participant | Remove someone | |
| Retain accepted private evidence | Keep my record as it is | |
| Clearing, clear, unclear | Count it in my group balance, Take it out of my group balance | |
| Deleted participant | Deleted account | The server's stored name stays; `personName` changes it on screen |
| Settlement suggestion, Suggested settlements | Suggested payments | Always "a proposal" |
| Unavailable (unknown value) | Not available yet | Never `₱0.00` for an unknown value |
| Provider schedule | Payment schedule | Debts |
| Early settlement | Log an early payoff | "Early payoff" as a noun |
| Provider charge / waiver / residual | Log a lender charge or waiver | |
| Classify payment | Break down a payment | |
| Outstanding balance | What you owe | |
| Unresolved payment clearing | Payment without a breakdown | |
| Final scheduled installment | Last scheduled payment | Still labeled as not a payoff date |
| Installment | Payment | Stored row names ("Installment 3") stay as recorded |
| Add expense, Record income, Transfer money | Log expense, Log income, Log a transfer | |
| Create account, Create category, Record refund | Add account, Add category, Log a refund | |
| Reconcile account | Check balance | Title "Check a balance"; a saved one is a "Balance check" |
| Observed balance, Calculated balance | Actual balance, Balance in Salapiya | |
| Review explicit adjustment, Signed balance adjustment | Adjust balance to match, Change to balance | |
| Opening cutoff | Balance as of | Helper: "The day this balance was true. Log newer activity after it." |
| Amount arriving at destination | Amount received | |
| Paid additionally by source, Withheld from amount sent, Paid by another account | On top, from the same account; Taken out of the amount; From another account | How a transfer fee was paid |
| Fee-bearing account | Fee paid from | |
| Provider posting date | Date it posted | |
| Income classification | Type of income | |
| Reason / correction evidence | Why you're changing this | |
| Superseded · evidence retained, Reversed · evidence retained | Corrected, Reversed | Pills; earlier versions stay in Edit history |
| Provider (card context) | Card issuer | |
| Posted outstanding, Posted liability | What you owe on this card | |
| Remaining due | Still due | |
| Card credit | Card credit | Always with "not money you have" |
| Allocate payment / credit | Match a payment to a statement | |
| Link statement activity | Match activity to a statement | |
| Apply installment payment | Match a payment to an installment | |
| Card installment plan | Installment plan | Kept, because card issuers use it. Its rows are payments |
| Pending authorization | Pending charge | "Log a pending charge" as the action |
| Reservation, Reserve | Money set aside, Set money aside | Money stays in its account |
| Reallocate | Move to another goal | |
| Generate occurrences | Add to Upcoming | |
| Occurrence | Date | "Recurring date" where it needs context |
| Recurring expectation, Recurring activity | Recurring item | |
| Basis (net / gross) | What counts | Net subtracts refunds; gross doesn't |
| Consumed share | Part | "Your part" |
| Contributed | Paid | |
| Split method | How to split | Equal, Exact amounts |
| Canonical participant order | The extra centavo goes to ‹name› | |
| Allocation | Applied to | Payments between members |
| Advance | Paid ahead | |
| Over-net | More than what's owed | |
| Receivable, Payable | Owed to you, You owe | |
| Private adoption | Add to my Money | |
| Dispute receipt | Dispute | |
| Cancel my report | Cancel this payment | |
| Reverse confirmation | Undo confirmation | |
| Manual participant | Not registered | |
| Retained history | Earlier records | |
| Group acceptance | Reached the group | |
| Immutable revision | Edit history | |
| Source, authoritative source | Record | Life |
| Commitment | Item | Life |
| Personal event | Event | |
| Deadline | Due date | |
| Inherited | Default | Reminders; the stored value stays |
| Ambiguous time occurrence | Which one? | "The earlier one", "The later one" |
| IANA timezone | Timezone | |
| Retained edit | Your edit | Life |
| Snoozed 1 hour, Dismissed, Restored (buttons) | Snooze 1 hour, Dismiss, Bring back | The stored action values stay |
| Elapsed, suppressed, no automatic resend | Its time passed | Never says it was seen |
| OS permission denied | Your device is blocking these | |
| Quiet start, endpoints | Start, End | Quiet hours |
| Learning preset, goal units | Learning goal, Lessons | Life |
| Completed (Learning, Books) | Finished | The stored status stays "Completed" |
| Deadline (Learning, Books) | Due date | Life |
| Attempt, job application | Application | One attempt at one role |
| Career event, conversation, milestone | Step | Interviews, assessments, follow-ups and what happened |
| Submission date | Date applied | |
| Distinct outcome | Outcome | |
| Actual stage date | In this stage since, When this happened | |
| Employer-cancelled opening | Opening cancelled | The stored value stays |
| Application source | Found through | |
| Posting URL | Posting link | |
| Private document, bytes, original bytes | File | Career, as in Files |
| Export original bytes | Save a copy | |
| Recover from exact original | Restore from your original | |
| Keep retained selection, retained link | Not attached yet, Finish attaching, Let go | |
| Resume version used | Resume used | |
| Salary minimum, maximum | Lowest and highest expected salary | |
| Salary period | Paid per | |
| Display name (on Profile's card) | Name | The field's label stays Display name |
| Synchronizing, Synchronization paused | Syncing, Sync paused | Status labels |
| Session expired / reconnect required | Signed out | |
| Initial download incomplete | First download not finished | |
| Enable private synchronization | Turn on sync | |
| Authorized session | Sign-in | Devices |
| Reauthenticate | Sign in with Google again | Before deleting an account |
| Archive (backup file) | Backup | |
| Original command, original intent | Change | Needs review |
| Resume this original command | Send this change | |
| Cloud profile | The profile on this Google account | |
| Google identity | Google account | |
| Create a local offline profile | Start on this device | Welcome's row |
| Create local profile | Create profile | The setup form's button |
| Select Google account, Review selected Google account | Sign in with Google, Review connection | The button is Google's own artwork |
| Cancel connection (before any connection) | Don't connect | Signs out of Google on this device; nothing else changes |
| Recovery coverage, committed commands, Archive format | What comes back, What doesn't come back | Restore's review. The format and profile id never show |
| Private space | Salapiya, your profile | |
| Porcelain, Midnight | Light, Dark | Theme, as on Profile |
| Local only, Synced · ‹date›, effect awaiting acceptance, Initial download · incomplete, Review needed · private effect (the demo's sync pill) | Demo · On this device only, Synced, Waiting for connection, First download not finished, Needs review | The demo's other screens keep their scenario words |
| Waiting for synchronization, Accepted by the service, Synchronized, Server change needs review, Current authority needs review (a form's saved state) | Waiting to sync, Reached the service, Synced, Needs review | The messages say what happens next in plain words |
| Receivable, Payable, Private clearing (Review rows) | Owed to you, You owe, Not in your group balance yet | |
| Financial effects, Replacement effects, Effects being removed, Previous effects, New effects | What changes, What changes now, What's removed, Before, After | Review headings |
| ‹amount› · signed posting, Evidence / plan | Changes by ‹amount›, No money moves | Review rows |
| Reviewed details, Financial review amounts hidden | Details, Amounts hidden | |
| Original command, Revision, Previous (under View details) | Change, Version, Earlier version | The rules' own notes don't show there |
| Technical details, View financial evidence | View details | |
| Nothing has been posted, not a posted action | Nothing was saved, Nothing is logged until you save it | The exit dialog |
| Connected changes remain pending until server acceptance and complete downloaded reconciliation | On a connected profile, this waits to sync after you save | Review |
| ‹form title› saved (Debts, Cards, Planning, Files) | The record in the past tense: Debt payment logged, Debt added, Card added; Changes saved for an edit; Saved otherwise | As Money's forms do |
| The sync label as the body of Sync needs review | A change didn't go through. Review shows what happened and what you can do. | Overview, Money, Debts, Shared Expenses (`SyncReviewNotice`). Without a Review button: "…Profile › Connection shows what happened and what you can do." |
| My Money (a row label) | Money | Shared record page |

### Tone rules

- **Sentence case** for every label, title and button. Uppercase is allowed only for small eyebrow labels, and only via a type token.
- **Buttons** start with a verb and name the result: "Log expense", not "Submit" or "OK".
- **Short:** one idea per sentence. Captions fit on one line at expanded width.
- **No technical or accounting jargon** in the main reading path. Exact detail goes in disclosures.
- **Friendly, not cute:** no slogans as screen titles. "Overview", not "Your day, in balance."
- **Glossary maintenance:** a change that brings a new term adds a row here before changing strings.

### Rule messages

The rules' error messages are user-facing too. They follow this glossary, and what the rules allow never changes with the words.

- **Changing a message:** propose the wording in the glossary's terms and change only what I've approved. A message only a developer can reach (a wrong command id, an unsupported version) keeps its words.
- **Messages on their field:** a rule that names no field is matched by its words, first match first, through the form's table (`nativeRuleFields`, `moneyRuleFields`, `importRuleFields`, `privateRuleFields`, `lifeRuleFields`). Update the table with the message, and check a new phrase can't be caught by an older one. `test/rule_messages_test.dart` holds the tables to the rule files and runs the jargon check; a new rule file joins it.
- **Words the code reads:** below-zero refusals keep the word "negative", which the forms look for. `isSyncBlock` reads the start of the sync rule's message, so the two change together. Life's rules throw through `lifeReject`; the failure screen's words are held to the rules by `startupMessages`.
- **Stored words stay as stored:** import row notes, Shared's server reasons, Life's stored reasons and the reasons on a change to check are written by the rules or the server. Screens show them plainly through `importRowNote`, `sharedReason`, `lifeReason` and `lifeReasonText`, and `changeReasons`, without changing what's stored.

## 8. Dashboard data inventory

This inventory covers what the Overview can show without new domain logic. **Readable** means an existing getter or pure function returns the value as-is. **UI aggregation** means summing, grouping or filtering existing exact values inside the view; I approve each new aggregation before it is built. **New logic** is a domain change, approved on its own before a screen shows it.

| Data | Source | Status |
| --- | --- | --- |
| Available money (confirmed); projected available money with waiting work | `LocalSession.accepted`, `.projected` (`lib/local/local_runtime.dart`) | Readable |
| This month's spending and income; spending by category | Postings in `localFinance.acceptedSnapshot` (summed in `app/overview_data.dart`: `spendingByCategory`, `dailySpending`); `categoryName` | Readable (existing view aggregation) |
| Daily spending | Expense postings in `acceptedSnapshot`, grouped by date (`dailySpending` in `app/overview_data.dart`). `spendingOn(date)` reads the projected snapshot (it includes waiting work), so the Overview doesn't use it. | UI aggregation (approved) |
| Account balances | `snapshot.accounts`, `snapshot.balance(id, through:)` | Readable |
| Card debt and available credit | `LocalFinancialController.cardLiabilityAndCredit` | Readable |
| Total debt owed | `LocalFinancialController.debtTotal` | Readable |
| Per debt: next due date and amount, overdue installments and amount, status (Overdue / Due today / Due soon / Upcoming / Schedule not set), days until next, final scheduled due | `debtDueSummary`, `DebtDueSummary`, `compareDebtUrgency` (`lib/finance/debt_rules.dart`) | Readable |
| Everything due in a date range (debt installments, card statements, card installments, recurring bills) with dates and amounts | `financialReminderSources(snapshot, from, through)` (`lib/finance/planning_queries.dart`). Recurring bills appear only once their occurrences are generated. | Readable; the weekly/monthly calendar and overdue list come from this |
| Totals due this week or this month across all debts and bills | Sum of the rows above | UI aggregation (approved) |
| Recurring bills and their state | `recurringOccurrences` | Readable |
| Budget progress | `budgetSpending(snapshot, budget)` with the budget record | Readable |
| Savings set aside | `savingsReserved`, `eligibleSavings` (`lib/finance/planning_rules.dart`) | Readable |
| Balance forecast | `financialForecast` (as used by Reports) | Readable |
| Shared Expenses attention counts (to confirm, waiting for others, waiting for the group, rejected, changed sources) | `runtime.connected.needMyConfirmation`, `waitingForOthers`, `sharedPendingCount`, `sharedReviewCount`, `changedPrivateSources` | Readable |
| Who owes whom per group | `SharedRepository.groups` → `SharedGroup.positions()`. Loading the groups runs `store.reconcileShared()`, which writes, so the Overview doesn't use it. | Readable only by opening the repository (not on the Overview) |
| Life agenda (tasks, events, financial reminders) | `DurableLifeController.agendaWindow` (`lib/life/life_controller.dart`) | Readable |
| Sync state: label, waiting count, needs review, download complete, connected or on this device | `LocalSession.syncLabel`, `pendingCount`, `needsReview`, `complete`, `local` | Readable |
| Last synced time | `binding['last_sync']`, the saved time of the last check against the service. Connection shows it. Other sections don't | Readable (this row said new logic until Profile and settings was built) |
| Amount privacy | `session.hideAmounts` | Readable; every dashboard value must respect it |
| Month-over-month spending (same day span) and what you owe at each month end | Postings in `acceptedSnapshot` (`SpendingComparison`, `debtBalanceByMonth`) | UI aggregation (approved) |
| Per-debt payoff progress (payments logged, scheduled amount left) | `DebtDueSummary` plus the schedule rows (`DebtProgress`) | UI aggregation (approved) |
| Debts: total owed (per-debt balances, equal to `debtTotal`), next payment, debts-only overdue and period totals | `DebtsSummary` (`lib/finance/debt_data.dart`) | UI aggregation (approved) |
| Debts: dues by calendar month, payments per debt, paid per month, paid down, payment rows, record names, what needs the user | `dueByMonth`, `debtPaymentRows`, `paidByMonth`, `paidDownBetween`, `installmentRows`, `recordLabel`, `debtTasks` | UI aggregation (approved) |
| Money: one row per record (newest version, plain label, status, signed cash effect) | `moneyActivity` (`lib/finance/money_data.dart`) | UI aggregation (approved) |
| Money: money in and out from cash postings, netted per record; a transfer counts only its fee; opening balances are left out | `cashFlow` | UI aggregation (approved) |
| Money: per-account balance, share of the positive total, this month's change, last balance check | `accountRows`, `lastChecked` | UI aggregation (approved) |
| Money: closing balance after each row of a statement; balances at month ends | `statementFor`, `balanceByMonth` | UI aggregation (approved) |
| Money: what needs attention (below zero, balance checks to resolve, saved drafts) | `moneyTasks`, `balanceCheckState` | UI aggregation (approved) |
| Money: search, type, account, category and period filters | `ActivityFilter` | UI aggregation (approved) |
| Cards: per-card balance, what you owe, card credit, limit, available credit, credit used; totals across cards with a limit (sum used ÷ sum limits, never an average) | `CardRow`, `CardsSummary` (`lib/finance/card_data.dart`) | UI aggregation (approved) |
| Cards: what you owe at month ends, each card's positive balance | `cardDebtByMonth` | UI aggregation (approved) |
| Cards: paid, still due, status and difference from your records per statement; each card's newest statement | `StatementRow`, `newestStatements` | UI aggregation (approved) |
| Cards: payments per installment plan; unused pending charges; what needs the user; activity matched to a statement and activity posted in its period | `PlanRow`, `pendingCharges`, `cardTasks`, `matchedActivity`, `unmatchedActivity` | UI aggregation (approved) |
| Planning: budgets by when they apply, period labels, whether they share a period and basis | `BudgetProgress` (`lib/app/overview_data.dart`), `budgetPeriodLabel`, `lastDay`, `sameBudgetTerms` (`lib/finance/planning_data.dart`) | UI aggregation (approved) |
| Planning: funding per goal and per account, from `supportedSavings` | `GoalRow`, `goalAccounts` | UI aggregation (approved) |
| Planning: per item next date, dates and states; what's coming up in 30 days, with recurring dates not added yet | `RecurringRow`, `recurringDatesFor`, `upcomingRows` | UI aggregation (approved) |
| Reports: the dates a period covers, what it's compared with, and what a filter can't answer | `ReportFilter`, `reportSpan` (`lib/finance/report_data.dart`) | UI aggregation (approved) |
| Reports: spending and income for one category; spending by calendar month; each category against the earlier period | `spendingBetween`, `incomeBetween`, `dailySpending` (optional category), `monthlySpending`, `categoryChanges` | UI aggregation (approved) |
| Reports: card purchases, payments, fees and interest, refunds; movement in group balances; payments without a breakdown | `cardSummary` | UI aggregation (approved) |
| Reports: budgets touching a period, each with its whole period's spending, never cut or added up; one row per record, reversed ones left out | `reportBudgets`, `reportRecords` | UI aggregation (approved) |
| Import: where each import stands, each row's result, whether a choice of rows would go below zero | `ImportBatch`, `importBatches`, `ImportRow`, `importGoesBelowZero` (`lib/finance/import_data.dart`) | UI aggregation (approved) |
| Files: where each file stands, what it's attached to, what the tiles count | `FileRow`, `fileRows`, `FilesSummary` (`lib/finance/files_data.dart`) | UI aggregation (approved) |
| Record page: plain labels for Cards, Planning and Files records | `recordFacts` (`lib/finance/record_facts.dart`) | UI aggregation (approved) |
| Shared: where the user stands, confirmed and if waiting payments are confirmed | `SharedStanding`, `sharedStanding` (`lib/shared/shared_data.dart`), from `positions()` | UI aggregation (approved) |
| Shared: groups in order, with each one's standing and what's waiting | `sharedGroupRows` | UI aggregation (approved) |
| Shared: one row per bill, after refunds, with the user's part and what's left between them | `SharedBillRow`, `sharedBillRows`, `leftOnBills` (the sum of `due(me, other, bill:)`) | UI aggregation (approved) |
| Shared: who paid and whose part on a bill and across bills; who gets the extra centavo | `billSplit`, `peopleTotals`, `extraCentavo` | UI aggregation (approved) |
| Shared: totals by month, by bill date, refunds subtracted | `monthTotal`, `monthPart`, `sharedByMonth` | UI aggregation (approved) |
| Shared: one row per payment, its status for this user, and what the rules let them do | `SharedPaymentRow`, `sharedPaymentRows`, `billPayments`, `paymentChoices`, `canChangeBill` | UI aggregation (approved) |
| Shared: who the user owes and who owes them | `pairsWithMe`, from `reciprocalPairs` | UI aggregation (approved) |
| Shared: payments still open, filters, totals, what each is applied to; what's owed between two people now and if waiting payments are confirmed | `openPayments`, `PaymentFilter`, `paymentTotal`, `appliedLine`, `owedBetween`, `paymentProjection` | UI aggregation (approved) |
| Shared: what needs the user, and drafts and saved work in plain words | `sharedTasks`, `draftTitle`, `intentTitle`, `intentState`, `sharedReason` | UI aggregation (approved) |
| Shared: every bill and payment between two people, with a running net ending on `due(a, b)`; what isn't counted; the net if waiting payments are confirmed | `pairBreakdown`, `pairNet` (`lib/shared/shared_people_data.dart`), from `edges()` | UI aggregation |
| Shared: every pair after netting, the user's first; how many bills and payments stand behind each | `whoOwesRows`, `pairSources`, from `reciprocalPairs` and `edges()` | UI aggregation |
| Shared: what the user owes and is owed; together they are the user's position | `pairTotals`, from `pairsWithMe` | UI aggregation |
| Shared: suggested payments, with what the sender owes the recipient directly; paused, none or unavailable | `sharedSuggestions`, from `suggestions` and `due` | UI aggregation |
| Shared: totals of bills, refunds and confirmed, waiting and disputed payments | `balanceCounts` | UI aggregation |
| Shared: how a person's position adds up; their bills; role, dates and membership history | `personBreakdown`, `personBills`, `sharedMember`, `sharedMembers`, `memberHistory` | UI aggregation |
| Shared: each bill, payment and refund the user is part of, against their own record, with its state; what a payment's records allow; how many need the user | `privateRows`, `PrivateRow`, `PrivateState`, `paymentLinks`, `privateCounts` (`lib/shared/shared_private_data.dart`) | UI aggregation |
| Shared: what the user's own records say about a group: the sum of their `shared_receivable` and `shared_payable` postings, as Reports' group lines read. Never compared with the group's figure | `myGroupBalance` | UI aggregation |
| Shared: what the user can do to a group and to one person; who can be removed; who can become the owner | `groupChoices`, `memberChoices`, `removableMembers`, `ownerCandidates` | UI aggregation |
| Shared: invitations that may still be open: sent in the last seven days and not revoked on this device. Whether one was used isn't readable | `openInvitations` | UI aggregation |
| Shared: the group's history in plain words, with who did it, what it's about and its amount | `historyRows`, `HistoryFilter` | UI aggregation |
| Life: one row per agenda item or due, with its kind, date, display time, recorded time and state; what's late, today, this week and coming up; what's next | `LifeRow`, `LifeCalendar`, `LifeSource.rows` (`lib/life/life_data.dart`), from `lifeAgendaItems` and `financialReminderSources` | UI aggregation |
| Life: rows by day; how many of each kind, never a money total | `rowsByDay`, `rowCounts` | UI aggregation |
| Life: where an event stands, when it is in a timezone, what left the Calendar, what each saved version changed | `eventState`, `eventWhen`, `retiredEvents`, `lifeChanges` | UI aggregation |
| Life: one row per task, its group, the filters and search, and the counts on the tiles and By priority | `TaskRow`, `taskRows`, `filterTasks`, `TaskCounts` | UI aggregation |
| Life: refused edits nobody has dealt with, against what's there now, field by field | `LifeReviewRow`, `lifeReviewRows` | UI aggregation |
| Life: each item's reminder state and time on this device; what's coming, nearest first; how many are set; which choices apply | `ReminderView` (`device_reminders.dart`), `ReminderRow`, `comingReminders`, `setReminders`, `reminderChoices` (`reminder_data.dart`) | UI aggregation |
| Life: one row per learning item or book, its state, how far along and how much is left; the filters and search; counts by state; what's next, by date; how many were finished in a year, from recorded dates only. No rates, averages or page totals | `ProgressRow`, `progressRows`, `filterProgress`, `ProgressCounts` (`lib/life/life_data.dart`) | UI aggregation |
| Life: one row per application with its stage or outcome and next step; the filters and search; how many sit at each stage and each outcome; what's next, overdue follow-ups first, and how old the oldest is. Counts of current records only: no rates, time in stage or results by source (L05 is deferred) | `ApplicationRow`, `applicationRows`, `filterApplications`, `CareerCounts`, `careerRows`, `nextSteps` (`lib/life/life_data.dart`) | UI aggregation |
| Life: an application's documents, whether this device holds each file, and files not attached yet | `careerDocuments`, `PendingDocument`, `LifeDocuments.present`, `.pending` (`lib/life/life_data.dart`) | UI aggregation |
| Life: one row per Career step, where it stands, and whether it can change; expected salary in words, never from `amount` and never summed across currencies | `StepRow`, `CareerStepState`, `stepState`, `salaryLine` | UI aggregation |
| Profile: the default group's choices, what's chosen, and whether a saved default can still be used | `DefaultGroupChoices`, `defaultGroupChoices` (`lib/profile/profile_data.dart`), from `sharedGroupRows` | UI aggregation |
| Profile: where the connection stands, what it allows, and its words | `ConnectionFacts`, `phaseOf`, `offered`, `canManageSync`, `phaseWords` (`lib/profile/profile_data.dart`), from `ConnectedRuntime` and `store.db.currentStatus` | UI aggregation |
| Profile: one row per sign-in, in order, with plain dates | `DeviceRow`, `deviceRows`, `manilaWhen`, from `p7_devices` | UI aggregation |
| Profile: one row per change to check, in plain labels | `ReviewRow`, `reviewRow`, `changeReasons` | UI aggregation |
| Profile: when the last backup on this device was saved, and whether records changed since | `lastBackup`, from `life_device` | Readable (approved) |
| Profile: what's inside a backup | `BackupContents`, `filesLine` | UI aggregation |
| Onboarding: what an installation holds before a profile is open: its saved stage, whether a profile's files are there, the kept profile's name | `DeviceStart`, `readDeviceStart` (`lib/onboarding/onboarding_data.dart`), read only; the key never leaves it | UI aggregation (approved) |
| Onboarding: a backup's Google account, and how many changes it holds to check after signing in | `BackupContents.email`, `.toCheck`, from the opened backup | UI aggregation |
| Balance-based payoff progress, net position (available money minus what you owe) | Not defined | New logic (not built) |

## 9. Decision log

| Date | Decision | Status |
| --- | --- | --- |
| 2026-10-29 | The redesign covers real-use (production) screens only. Demo and gallery screens keep working but are not polished. | Approved |
| 2026-10-29 | Windows gets a custom integrated title bar. Native runner code may change, and a windowing package may be added. This supersedes the pre-redesign rule "native caption only, no window-management dependency". | Approved |
| 2026-10-29 | Section order in the roadmap, since retired (Debts first, Onboarding last; Money, Shared Expenses and Life each split in two). | Approved |
| 2026-10-29 | The pre-redesign design system moves to `docs/archive/DESIGN_SYSTEM_pre-redesign.md`. This document replaces it. | Done |
| 2026-10-29 | Carried over from the archive: the exact-money rules, the accessibility rules, the motion limits, Geist as the typeface, separate sync and business states, and the status color pairs as the starting palette. | Approved (with this spec) |
| 2026-10-29 | The spacing values in §4, and the Add/Log verb split and glossary in §7. | Approved |
| 2026-10-29 | Redesign work moves to its own branch, `redesign/ui`, created from `docs/normalize`. | Approved |
| 2026-10-29 | Tokens: purple-tinted neutrals, primary `#6546A3` / `#CABDFA` kept, archived status pairs kept, new `overdue` (rose) and `owedToYou` (teal) roles, chart series from the archive, and a high-contrast variant. | Approved |
| 2026-10-29 | Geist stays the only UI font (already bundled, OFL 1.1). The type scale is in §3. | Approved |
| 2026-10-29 | Radii are control 10, card 14, overlay 20 and pill. Elevation has two levels (hairline cards, shadowed overlays). Motion is 100 / 160 / 200 ms with ease-out. | Approved |
| 2026-10-29 | Wide content max width is 1280, and the Windows title bar height is 40. | Approved |
| 2026-10-29 | The existing System/Light/Dark profile setting stays the theme-mode control. | Approved |
| 2026-10-29 | Component kit in `lib/design_system/kit/`, with the API and rules in §5. Existing screens weren't migrated with the kit. | Approved |
| 2026-10-29 | The Android info control is an anchored popover only. The "bottom sheet if longer than 3 lines" fallback is dropped. | Approved |
| 2026-10-29 | Option picker rule: segmented only for view-only options without descriptions; a radio list for up to 5 options that differ in effect; a dropdown with two-line items for 6 or more. | Approved |
| 2026-10-29 | Modal rule: confirmations are centered dialogs on both platforms (this adds to §2 for Android). Choices and short forms are dialogs on Windows and bottom sheets on Android. Long forms are pages. A destructive modal starts with focus on Cancel. | Approved |
| 2026-10-29 | Required fields are marked ` *`, with "* Required" once at the top of the form. | Approved |
| 2026-10-29 | Button metrics: 14 / 20 labels, 40 tall on Windows and 48 on Android, 2 px focus border. Chip labels are 12 / 16. These apply app-wide through the theme. | Approved |
| 2026-10-29 | Table, pager, charts and tabs are deferred to the sections that first need them. The toast stays the themed stock `SnackBar`. | Approved |
| 2026-10-29 | Dates are always chosen with a date picker (`DateField`, calendar only), never typed. Each section's rebuild replaces the existing typed date inputs. | Approved |
| 2026-10-29 | The info control shows a focus ring only for keyboard focus. A click or tap never leaves a ring, and closing the popover releases focus. | Approved |
| 2026-10-29 | "Settled" is kept as a status-pill label (a past-tense state). | Approved |
| 2026-10-29 | The component gallery is debug-only, opened with `--dart-define=SALAPIYA_COMPONENTS=true`. | Approved |
| 2026-10-30 | List rows center their trailing content (amount, status pill) and chevron vertically, instead of aligning them with the first line. | Approved |
| 2026-10-30 | The Google button shows Google's official button PNGs, unmodified, from `signin-assets.zip`. The SVGs aren't used because Flutter can't render their gradient "G" faithfully. No font is bundled. | Done |
| 2026-10-30 | The Google button label becomes "Sign in with Google", the only label in the official artwork (the profile screen says "Continue with Google" today). | Approved |
| 2026-10-30 | Shell: the five destinations are unchanged; one "Profile and settings" entry (sidebar bottom on Windows, header button on Android); Hide amounts and a sync status pill stay in the shell. | Approved |
| 2026-10-30 | D1: Windows pages open inside the content area with the sidebar visible. Android pages are full screen, with the app bar and dock hidden. | Approved |
| 2026-10-30 | D2: Overview links switch to the section and tab instead of pushing a copy of the section. | Approved |
| 2026-10-30 | D3: Android Back from a destination other than Overview goes to Overview first. | Approved |
| 2026-10-30 | D4: Forward only redoes destination and tab changes, never pages. | Approved |
| 2026-10-30 | D5: the rail at 600–999 doesn't expand. The sidebar from 1000 up is collapsible, and the choice isn't saved after the app closes. | Approved |
| 2026-10-30 | D6: on a narrow Android screen (under 360 wide) or at 150% text and up, the dock keeps all five icons and hides the labels, instead of one "Navigation" button. | Approved |
| 2026-10-30 | D7: the + sheet on Android and the "New" menu on Windows use the glossary labels. Route names keep the old action keys. | Approved |
| 2026-10-30 | D8: the kit Tabs and page header components move to the first section I rebuild (the Overview). | Approved |
| 2026-10-30 | D9: the app shell adds Alt+←/→ and the mouse back and forward buttons. The title bar adds the on-screen back and forward buttons. | Approved |
| 2026-10-30 | D10: the logo stays in the sidebar for now; the title bar work decides whether it moves. | Approved |
| 2026-10-30 | A modal may have no primary action when its rows make the choice (Cancel only). Sheets open on the root navigator. | Done |
| 2026-10-30 | My review: the shell header gets a 12 bottom gap, and Windows header actions center on the title. | Approved |
| 2026-10-30 | The Windows sidebar is redesigned as a floating card (my references). The profile card moves to the top with the sync state and a profile menu. Go to (Ctrl+K) is added. Sections expand into their tabs (an accordion with tree lines; flyouts on the rail). A Needs attention group shows existing counts. Hide amounts, theme and Help move to the footer. | Approved |
| 2026-10-30 | Selected sidebar items use a neutral `subtle` fill and a semibold label; only the icon is purple. | Approved |
| 2026-10-30 | Glass behind the sidebar is the Windows Mica material, to be added with the title bar's runner work. Until then the card is solid. | Superseded (Mica deferred with the title bar) |
| 2026-10-30 | New stays in the shell header (Ctrl+N), not in the sidebar. | Approved |
| 2026-10-30 | A Needs attention row for overdue debts (a new UI count over `debtDueSummary`). | Rejected for the sidebar; overdue debts go on the Overview |
| 2026-10-30 | Second review: the sidebar matches the reference sizes. Labels are 13 / 18 and icons 16. Rows are 36 and tab rows 30, below the 40 pointer target, as Windows 11 navigation allows; this is an exception for the sidebar only, and it still meets WCAG 2.2's 24 px target minimum. Text stays 13 rather than the reference's 11 for legibility. | Approved |
| 2026-10-30 | The sidebar is flush with the window's left, top and bottom edges, rounded on the right only, and collapses with a round handle on its edge. | Superseded (next row) |
| 2026-10-30 | Third review: the sidebar has square corners with a right hairline. The logo is centered (kept, not removed, per the brand rule). A separator splits Overview from the sections. Rows are 4 apart and tab rows 32. Highlights and the profile card use `Radii.nav` 6. | Approved |
| 2026-10-30 | Title bar layout changes: no separate full-width title bar. The sidebar and content run to the window's top edge. The content's top row holds back/forward, the breadcrumb, drag space, New and the window controls. The sync pill moves to the sidebar's profile card. This replaces the "one bar across the full window width" rule. | Superseded |
| 2026-10-29 | Totals added up across debts and bills per week or month for the dashboard. | Approved (built into the Overview's dues card as period and overdue totals) |
| 2026-10-29 | Rewording user-facing messages that live in domain or rule files. | Needs approval (per section) |
| 2026-10-30 | Fourth review, after a reference: Windows gets an app bar (56, `surface`, divider below, level with the sidebar's logo row) with a chevron breadcrumb, the Go to field (moved from the sidebar) and New. The collapse control is a panel icon beside the logo (the round edge handle is removed). The sidebar footer adds Settings. Its theme control is a two-option Light \| Dark switch that reflects System; System stays in Profile and settings. | Approved |
| 2026-10-30 | The title bar's chrome is the app bar itself (56), with the window controls at its right end; the logo row and the app bar's empty space are the drag areas. | Superseded (next row) |
| 2026-10-30 | Title bar: a separate custom title bar across the full window width, above the sidebar and the app bar. It has back/forward, drag space and window controls, plus more (sync pill, Go to and toggles proposed; confirmed when I built it). It has no logo or app name; the logo stays in the sidebar. This also supersedes the earlier "sidebar and content run to the top edge" revision. | Approved |
| 2026-10-30 | Fifth review: the rail's section flyout is structured like the expanded sidebar (a header with the icon and name, then tabs on a tree line with the current tab highlighted). The collapse toggle has open and closed glyph states. | Approved |
| 2026-10-30 | The app bar's New button is compact (32 tall, a 16 icon, a 13 label, `Radii.nav`), matching the Go to field. | Approved |
| 2026-10-30 | Windows uses a compact scale one step below Android for type, controls, icons, rows and card padding, with tighter corners (controls 6, cards 10, overlays 12). It is applied app-wide through the theme and kit in its own step after the app shell. This changes the tokens rule "sizes are the same on Windows and Android" for Windows. | Approved |
| 2026-10-30 | Windows density implemented (4b): `Density`, `SalapiyaTheme.build(platform:)`, and context-aware radii, card padding and row sizes. The sidebar's rail buttons keep 40 (`navRailButton`). Menu items are 36 on Windows. Android is unchanged. Hard-coded literals in older screens wait for their sections' rebuilds. | Done |
| 2026-10-30 | Title bar, as recommended in the plan: a custom native frame in the runner (no windowing package; `window_manager` and `bitsdojo_window` can't route `HTMAXBUTTON` to a Flutter-drawn button, so Snap Layouts wouldn't appear). Go to moves into the title bar (centered, 320). The sync status moves from the profile card into the title bar and opens the sync details. Hide amounts stays out of the title bar. | Approved |
| 2026-10-30 | Mica is deferred: Flutter's Windows engine draws an opaque surface. The title bar and the sidebar stay solid. This supersedes "Mica added with the title bar". | Approved |
| 2026-10-30 | Title bar colors: `windowControlHover` becomes `text` at 6% (it was `subtle`, nearly invisible on the bar); new `windowControlPressed` (`text` at 4%), `windowClosePressed` (the close red at 90%), `Space.goToWidth` 320 and the `CaptionButtons` OS constants. | Approved |
| 2026-10-30 | The app's navigator and the shell's content navigator are wrapped in semantics containers, so a route's modal barrier no longer hides the title bar, the sidebar and the app bar from screen readers (found while testing the title bar; the sidebar issue dates from the app shell). | Done |
| 2026-10-30 | My review of the title bar (the left side felt empty). The bar's left segment, as wide as the sidebar, shows the date and clock and opens a month calendar; back/forward start the content column. Right of Go to: a notifications bell, a quick calculator and the Hide amounts toggle, then the sync status. | Done |
| 2026-10-30 | The bell takes over the sidebar's Needs attention group, and the title bar's toggle replaces the sidebar footer's Hide amounts row. Their old place in the sidebar becomes Quick create: the current section's first three create actions as a full list (the Windows counterpart of Android's + button). Ctrl+H toggles Hide amounts. | Done |
| 2026-10-30 | Rejected for the sidebar: Upcoming, Accounts at a glance, Recent places, Pinned places (dashboard content), and a Groups list (too busy with Quick create). A group switcher may suit the Shared Expenses page instead. | Rejected |
| 2026-10-30 | Second review of the title bar's left side: the sidebar's column runs unbroken to the window's top (the bar's line stops at it), the clock (centered in the column, at my request) shows the time emphasized and the date in `secondary`, and back/forward are neutral and sit just past the sidebar's edge. | Done |
| 2026-10-30 | Icon buttons use `secondary` when disabled, app-wide; the theme had painted them `primary` in every state, so disabled ones looked clickable. | Done |
| 2026-10-30 | Android parity plan for the title bar's features (§2): app bar with Go to, bell and profile; status row with a tappable sync pill and the Hide amounts eye; tappable Overview date with a calendar sheet; calculator in the + sheet, then in amount fields. Split across the Overview, the section rebuilds and a separate Android parity step. | Approved (planned) |
| 2026-10-30 | Overview widgets: the required dues card with its calendar, overdue rows and payoff progress, plus every optional widget proposed (Available money, this month's tiles, category bars, daily spending, compared with last month, what you owe over time, accounts, budgets, Shared Expenses counts, Life next up, recent activity, insights). Quick actions are left out, because Quick create, New and the + button already cover them. | Approved |
| 2026-10-30 | Date rules for the dashboard: "This week" runs Monday to Sunday (ISO, as the recurrence grammar), "This month" is the calendar month, and period lists start today, with anything earlier only under Overdue and no lookback limit. | Approved |
| 2026-10-30 | Dues and debt progress read the Debts screen's records (with waiting work), so both screens agree. Money values and charts stay on accepted history. | Approved |
| 2026-10-30 | The Due today and Due soon labels (`debtDueStatus`) apply to card statements, card installments and recurring bills too. | Approved |
| 2026-10-30 | Display derivations in `app/overview_data.dart`: dues grouping and day counts, payments logged and scheduled amount left, daily spending, month-over-month over the same day span, and month-end totals of what you owe. | Approved |
| 2026-10-30 | Charts use `fl_chart` 1.3.0 (offline, MIT, themable), with no animation, no money on axes, a spoken summary and exact values under "Show values". | Approved |
| 2026-10-30 | `PageHeader` is added to the kit. `SurfaceCard` and `MetricTile` gain `accent` for the one tinted focal card. The Tabs component moves to the Money rebuild. | Done |
| 2026-10-30 | Not built: balance-based payoff progress, net position, "last synced", and group balances on the Overview. Each needs logic or a side effect outside the UI. | Rejected for the Overview |
| 2026-10-30 | First review of the Overview (reference dashboards): the "Tiles + hero" layout on a 12-column grid (KPI tiles with sparklines and a vs-last-month change, a wide spending chart beside the dues, 2/3 + 1/3 pairs). | Approved |
| 2026-10-30 | The Overview gets underline tabs (Summary, Spending, Debts & Dues, Accounts & Activity), built as the kit's `AppTabs`. This reverses moving Tabs to the Money rebuild for the Overview; section screens still adopt it in their own rebuilds. | Approved |
| 2026-10-30 | Compact sizes on the Overview only: `titleSmall` card titles, `MoneySize.tile` values, small link actions, and 32-tall segmented controls and chips. Android keeps 48 hit areas through transparent space. The rest of the app keeps the approved sizes. | Approved |
| 2026-10-30 | New Overview widgets: quick actions (the shell's first four New items), a category donut, account cards with 30-day sparklines and a budget gauge. Also added: largest expenses this month, and payoff bars with a step per payment. | Approved |
| 2026-10-30 | Display derivations added to `overview_data.dart`: closing balance by day, income by day, change and share in whole basis points (rounded toward zero, shown with one decimal), the top-five-and-Other category shares, budget totals across limits, and the largest expenses. | Approved |
| 2026-10-30 | The demo build shows the new Overview, filled by a sample profile replayed in memory through `planLocal`, ending on the demo account balances. The previous demo Overview layout is retired; its files (`workspace_overview.dart`, `overview_wallet.dart`, `overview_agenda.dart`) are deleted with my approval. | Done |
| 2026-10-30 | Second review of the Overview: a stat strip under the spending and owed charts (they left empty space beside taller cards); "By debt" in What you owe over time; a Calendar | List view on Due and overdue, the list being a screenshot-ready table of the period's items with totals; table amount columns measured to one width, fixing misaligned Category and payoff columns; payoff bar steps were drawn 0 tall and now show. | Approved |
| 2026-10-30 | Third review of the Overview: quick actions right-aligned to the content edge on the title row; 16 above "Show values"; the Spending tab's category and budgets cards center their content when the other card is taller; the dues card's Calendar | List moves to a settings icon menu in its top-right corner. | Approved |
| 2026-10-30 | Fourth review: the category donut's sections and legend rows are selectable by hover or tap, showing the category's name, share and amount in the hole. | Approved |
| 2026-10-30 | Android drops the Overview's quick actions; the + button above the dock already has them. Windows keeps them. | Approved |
| 2026-10-30 | Tab names "Debts & Dues" and "Accounts & Activity" (capitalized at my request). KPI tiles reserve the tallest label's height so values line up. | Approved |
| 2026-10-30 | Android's Overview header is one compact row: the date (calendar icon, `titleSmall`) and a dues pill that opens Debts & Dues, with 4 to the tabs. | Approved |
| 2026-10-30 | Every section I rebuild from Debts on follows the Section screen standard (§2), taken from the Overview: the same page anatomy, grid, cards, data display, sizes, shareable list views, demo data and tests, with content chosen per section. Data screens use the compact Overview sizes. Forms, editors and dialogs are scaled down too (about one step), with a readability floor: values and body text at least `bodyMedium`, nothing below 12. The first section that rebuilds a form applies it through the theme and kit after I review a sample. Overview building blocks move to the kit when another section first needs them. | Approved |
| 2026-10-30 | Debts: tabs Summary · Schedule · Payments · History; Your debts as the hero beside Due next; the shareable list shows all dues with a Debts-only choice and can open as a page; Upcoming by month and Needs your input; Debts' tabs in the sidebar and Go to; debt details as one page. | Approved |
| 2026-10-30 | Log a debt payment asks for the essentials and fills the rest of the same command from the answers, with the rest under "More details". A row's "Log payment" prefills the debt, that payment and what's left on it, proposing "All of it lowers what I owe"; the user confirms at Review. Corrections keep every field. | Approved |
| 2026-10-30 | Prefilled forms keep their own draft: the draft key includes the debt and the proposed payment, because a saved draft replaced `initial` values. | Done |
| 2026-10-30 | The Debts display states (Closed without a schedule, Settled without a schedule, Schedule finished) live on `DebtProgress`, so the Overview shows them too. Due rows carry the debt's name, not its schedule record's. | Done |
| 2026-10-30 | The Android Overview header's pill drops under the date when large text can't hold both (an overflow at 320 wide and 200% text). | Done |
| 2026-10-30 | The compact form scale in §3, from my review of a sample: Android controls look 40 with a 48 hit area, typed values `bodyMedium`, labels 12. Applied as a scope on the shared editor and Update amounts, not app-wide, so Money's Log expense, income and transfer stay larger until the Money rebuild. | Approved |
| 2026-10-30 | A form's title and step line sit in the form's column, starting at the card's left edge (from my review of the sample). | Approved |
| 2026-10-30 | `NativeFinanceEditor` shows no popups: errors appear on their field, or in a notice above the form when no field can show them (§6). Every date in it is a `DateField`, so typed dates are gone from `finance_screen.dart`. | Done |
| 2026-10-30 | My review of the Debts cards: a list starts at the top of its card, under the header, and closes with `ListEnd` ("That's everything", or "N more on Schedule"). `OverviewCard(centered: true)` is for charts and figures, not lists. | Approved |
| 2026-10-30 | My review of form errors: fields for one kind of data refuse anything else as it's typed, with a small note at the field. This narrows §6's "No error pop-ups" to no error dialogs. Applied in the kit and in `FinancialEditor`. | Approved |
| 2026-10-30 | Errors after submitting go on the field they're about, in red. A table in the editor maps rules that name no field to theirs, so no rule file changes. Going below zero marks the account and says what it holds; the rest keep the rules' own wording until that's approved. | Approved |
| 2026-10-30 | Account pickers show each account's balance, and warn before saving when the amount is more than the account holds. | Approved |
| 2026-10-30 | Forms handle the sync rule themselves instead of showing it as an error: Save syncs first, a sync that brings new records asks for another look at Review, and a failed sync stays on Review with "Sync and save". A debt added with a schedule syncs before saving the schedule. The rule itself is unchanged. | Approved |
| 2026-10-30 | Money: Accounts is KPI tiles over one table of accounts with shares and a total that adds up, beside Needs your attention. Activity has search, a period chip, Filters and day groups, one row per record. A List layout and an account statement are the shareable views. | Approved |
| 2026-10-30 | Money's balances include waiting changes, as Debts does; a notice says they can differ from the Overview until they sync. | Approved |
| 2026-10-30 | Needs your attention shows accounts below zero, balance checks to resolve and saved drafts. "Not checked lately" was left out, so there's no 30-day rule. | Approved |
| 2026-10-30 | "Reconcile account" becomes Check balance (title "Check a balance", a saved one a "Balance check"). Stored titles stay; they're only reworded for the eye. | Approved |
| 2026-10-30 | Money's forms move to a new `MoneyEditor` that shares `FinanceFormFields` with `NativeFinanceEditor`. `FinancialEditor` is the demo build's, so the demo's other 24 forms don't change. The demo build can't show the new forms. | Approved |
| 2026-10-30 | One record page: `openFinanceDetail` opens `RecordDetailView`, so Debts History, Cards, Planning and Reports rows get it too. | Approved |
| 2026-10-30 | The real Overview's Recent activity uses Money's rows. It listed budgets, schedules and replaced versions. | Approved |
| 2026-10-30 | `DebtTable` moves to the kit as `AppTable`, with a group-header row and a dense option. | Done |
| 2026-10-30 | Records dated after today sit under Later and stay out of balances and totals. "Last 90 days" is today and the 89 days before it. | Done |
| 2026-10-30 | Search covers every date whatever the period says. One row per record: corrected records show their newest version and a pill, and reversed ones stay with a pill, out of totals. | Done |
| 2026-10-30 | Review shows Card only on card records and To only on transfers: a form's defaults put those values on every command, so a cash expense showed "Destination". Its dates read "21 Oct 2026". | Done |
| 2026-10-30 | My review of Activity: day headers were squeezed between hairlines. Space now sets the days apart: `groupGap` above a day's header, `xs` below it, hairlines only between the rows of a day, and the date in `text` with the day's change in `secondary`. Both platforms. | Approved |
| 2026-10-30 | Six rule messages reworded for Money, with no change to what the rules allow: the date after an account's starting balance, a duplicate account name, a split that doesn't leave a remainder, a fee taken out of the amount, a refund over what's left, and a record with a refund or adjustment. The forms' field table matches the new words, and Hide amounts drops the amount from the refund message. | Approved |
| 2026-10-31 | Debts' rule messages are reworded in the glossary's words, with the shared rule messages Debts forms show and the duplicate category message. What the rules allow is unchanged. Review notes under "View details" are reworded too. The forms' field tables are public, and a test holds them to the rules' words and keeps old jargon out of Debts' messages. | Approved |
| 2026-10-31 | `OverviewCard`'s trailing control and corner menu center on each other; they aligned to the top, so a link sat 4 px above the menu's center. | Done |
| 2026-10-31 | The remaining rule messages are reworded along with the screens that show them, with me approving the wording there. The roadmap (since retired; see §7's Rule messages) listed them by section. | Approved |
| 2026-10-31 | Money's Cards and Planning forms are approved on the real build, with Add a card, statements, installment plans, budgets, goals and recurring items on the compact scale. | Approved |
| 2026-10-31 | My review of Cards: a link inside a row that ends in its own chevron drops its chevron (`CardLink(chevron: false)`). | Approved |
| 2026-10-31 | My review of Cards: a row's details stay whole (`detailLine`), so a line breaks between them and never inside one. "In N days" shows only for what's within 7 days or overdue, so later rows stay on one line. | Approved |
| 2026-10-31 | Reports: a figure a filter can't work out says which filter it needs ("All accounts only", "All categories only") and never reads ₱0.00. A card in the same position names the filter instead of "Not available yet", which would suggest it's still loading. | Approved |
| 2026-10-31 | Reports: This month runs to today against the same days of last month, as on the Overview. Other periods compare with the same number of days just before. A chart draws by day up to 62 days and by month past that. Nothing in either period shows no change line, not "New". | Approved |
| 2026-10-31 | Cash forecast: a page of cards, with the chart full width, What to count beside What if, then What's included beside What's left out. Card payments are one radio group per card, so the forecast's two refusals can't happen. The forecast's messages and left-out notes are reworded in this step, because this page shows them. | Done |
| 2026-10-31 | My review of Reports: a list of figures stays at the top of its card and closes with `ListEnd`, as every list does, so a taller card's extra space reads as the end. `centered` stays for charts. | Approved |
| 2026-10-31 | My review of Reports: the category legend's amounts share one measured width, so the shares line up whatever each amount's length. Applies on the Overview too. | Approved |
| 2026-10-31 | My review of Planning: in a taller card, the budget gauge centers in the space under the header and the list keeps to the top. `OverviewCard(fill: true)` hands its child the height left. | Approved |
| 2026-10-31 | Import: the review is a page and the tab only reports. One button runs every group of rows, with Stop, and the draft goes when it ends. | Approved |
| 2026-10-31 | Import: an import keeps its file's name as its title. The field was already free text, and the server treats it as one. Older imports read "Cash activity file". | Done |
| 2026-10-31 | Import: the below-zero consent shows before the choices are confirmed, worked out group by group as the rule checks them, because it can't be added afterwards. | Done |
| 2026-10-31 | Files: a tab of tiles, a list and what needs attention. Check files reads each file on request; whether a file is on this device is looked up on opening. Attach a file is a page. | Approved |
| 2026-10-31 | The remaining Money rule messages are reworded as approved in the plan. `Enter $key` and `$key must be` now name their field, so they land on it. | Approved |
| 2026-10-31 | A zero-limit budget reads "Zero-limit budget" everywhere and isn't counted as within or over a limit. Display only: the rule's `over` figure is unchanged. | Approved |
| 2026-10-31 | "Not virus-scanned" shows on a file's page and not again in its preview window. | Approved |
| 2026-10-31 | My review of Files: image previews zoom and fill most of the window on Windows, and a file can be opened in another app. | Approved |
| 2026-10-31 | Opening a file in another app needs a plain copy outside the encrypted store, which ARCHITECTURE asks to protect. I asked for it, and Save a copy already writes one. Each copy goes in a private temporary folder and is removed after 10 minutes, or at the next start. Its extension comes from the checked file type, so a stored name never decides what runs. | Approved |
| 2026-10-31 | Android opens that copy through a small platform channel and `FileProvider`, limited to the one folder and read-only, rather than a new package. | Done |
| 2026-10-31 | My review of Cards: a list cut short closes with a link to the whole list (`ListEnd(onPressed:)`), on every card that has one: Due next and Coming up open a page, Debts' Due next opens Schedule, Recent activity opens Activity. A list that shows everything keeps "That's everything", which Recent activity used to say even when it showed only the newest rows. | Approved |
| 2026-10-31 | Shared Expenses: the group is the page's title and opens a switcher with each group's standing. No third tab layer. | Approved |
| 2026-10-31 | Bills: tiles, then Bills 8 beside Needs your attention 4, then Shared over time 7 beside Who paid, whose part 5. Payments: tiles, then Waiting to be confirmed 7 beside Between you and others 5, then every payment. | Approved |
| 2026-10-31 | Shareable lists: a group's bills, a group's payments and one bill's split. Between you and one person moves to the balances work, because it's the pair breakdown Balances needs anyway. | Approved |
| 2026-10-31 | Add shared expense asks Who paid and Who's in, with one payer by default. The command is unchanged. Log a payment starts from what's owed: All of it, Part of it, Choose bills. | Approved |
| 2026-10-31 | The private forms stay on `_SharedForm` until the balances work, with their rule messages. This step only shows them where they apply. | Approved |
| 2026-10-31 | "You owe" has no color role of its own. It stays `text`, with the words and an arrow. | Approved |
| 2026-10-31 | The demo's Bills and Payments use a new sample built with the real rules; its five later tabs keep their old fixture until then. | Approved |
| 2026-10-31 | Shared rule messages reworded as approved, with `shared_store.dart`'s identity message. Server reasons change on screen only. | Approved |
| 2026-10-31 | Correct starts from the bill's own split method, and from its date. Both used to be reset by the form. This is the one command value that changes. | Approved |
| 2026-10-31 | A shared draft can be discarded. A group the user left shows "Not available yet" for totals. `shared-purchase:` rows are left out of Money's Saved drafts, and `shared_attention.dart` is deleted. | Approved |
| 2026-10-31 | The old demo bill page (`SharedBillDetail`) is gone: Bills' rows open the new page on both builds. | Done |
| 2026-10-31 | Choose bills sends the sum of its bills as the amount, so there's no separate Amount field. The old form could send more than the bills held; Part of it covers that, with the same consent. | Done |
| 2026-10-31 | "Confirmed by the owner" is the pill for a payment the owner recorded for someone who isn't registered, and the payment's page says they didn't sign in. | Done |
| 2026-10-31 | My request: with two or more active groups and no default, Shared Expenses opens on Choose a group instead of a group the app picked. An only active group opens by itself; archived and left groups don't count. A choice lasts until the app closes. Links that already know the group skip it, and a sidebar tab picked first opens after the group is chosen. | Approved |
| 2026-10-31 | A default group, set from the chooser or the Group page, saved per profile on the device with the profile's settings. It falls back to the chooser if it's archived or left. Profile and settings lists it too. | Approved |
| 2026-10-31 | The Your groups page is replaced by the chooser. The breadcrumb reads Shared Expenses › Group › Tab with several groups, and its first segment goes back to choosing. | Done |
| 2026-10-31 | My review of the bill form: with several payers, a person's part alone read as what they owe. Who's in now shows what the bill leaves each person with (paid minus part, as `billPositions` does), with the part and what they paid beneath it. | Approved |
| 2026-10-31 | I left the open Shared Expenses calls to the recommendation: Correct keeps the bill's date; `SharedBillDetail` stays removed; Choose bills sends the sum of its bills; and on Bills, Who paid, whose part sits under Needs your attention so a long list has no empty space beside it. | Approved |
| 2026-10-31 | Shared Expenses: the Private review tab is My Records and the Lifecycle tab is Manage Group. Visible labels only. | Approved |
| 2026-10-31 | Balances: tiles, then Who owes whom 7 beside Where everyone stands 5, then Suggested payments 7 beside What these balances count 5. | Approved |
| 2026-10-31 | Suggestions: Log payment only on a row within what the sender owes directly. Past that, the row says everyone involved needs to agree first, and has no link. | Approved |
| 2026-10-31 | The pair and person pages and Who owes whom have shareable lists. A running net needs every row, so they have no period control. My Records never has one. | Approved |
| 2026-10-31 | The server's stored "Deleted participant" reads "Deleted account" on screen. | Approved |
| 2026-10-31 | My Records: tiles, then Needs a look 7 beside This group and me 5, then every item with filters. The group's figure and the user's records' figure sit side by side, with no difference: no rule defines one, and they differ for as long as something isn't in Money. | Approved |
| 2026-10-31 | The private forms are one compact page with one Review. Picking a saved purchase fills and locks its amount, date and account, because the rules insist on them. Count it and Take it out fix the amount from the user's own record. The command is unchanged. | Done |
| 2026-10-31 | `shared_private_domain.dart`'s 21 messages and 2 review notes are reworded as approved. What the rules allow is unchanged. | Approved |
| 2026-10-31 | Stored titles such as "Shared clear · Household" read "Counted in group balance · Household" on screen in Money. Stored values don't change. | Approved |
| 2026-10-31 | My review: Balances and My Records look good, including the private form's new structure, shown as a sample. | Approved |
| 2026-10-31 | People: Everyone in this group 8 beside What each can do 4, then Invitations and Waiting or refused. Remove and Make owner are on a person's page and on Manage Group. Invitations and Revoke are on People. | Approved |
| 2026-10-31 | Manage Group lists only what the server allows now, each with what it does. Confirmations say what changes and what stays. The owner can't leave, and the tab says why. | Done |
| 2026-10-31 | Invitations list those sent in the last seven days and not revoked on this device. A used one can still be refused, because the server doesn't report it. | Approved |
| 2026-10-31 | History is full width, so a long list has nothing empty beside it. Copy group history is off while amounts are hidden, because the copy holds them. | Done |
| 2026-10-31 | Saved work shows on its own tab. People and group changes left Bills' Needs your attention. | Approved |
| 2026-10-31 | `_SharedForm`, `NativeSharedScreen`, `group_lifecycle.dart` and the frame's old demo tab bodies are retired. The demo controller's group actions wait for the consistency pass. | Approved |
| 2026-11-02 | Consistency pass, my picks: stages in the order retire, tokens, glossary, sweep. Retire the old demo screens, the dead preview code, `FloatingActionMenu` with the gallery's navigation study, and the demo controller's group actions. One app-level sweep test with a tap-action check, and every confirmed hit fixed. The Review step's parts move to the kit on the nearest tokens. The Review and saved-state wording, the review notice's one sentence and the bell's single waiting row as proposed. The rules' own notes leave View details. The calculator's backspace becomes an icon. Career's salary fields keep no calculator. Rule messages are reworded only where a person can reach them, after approval. | Approved |
| 2026-11-02 | Consistency pass, step 1, retires the old demo screens (Credit, CardEvidence, CardLibrary, Planning, its forecast chart, Reports, Files, Import, `ProfileExperience`, `TransactionDetail` and `prototype_form.dart`), the dead preview code (`activity_view.dart`, `DestinationPreview`, `SourcePreviewPage`, `SourceLink`, `UpcomingView` and the shell's unreachable upcoming branch), `FloatingActionMenu`, `navigation.dart`, the gallery's Navigation studies section and the now unused `IconTile`, `FinancialLine`, `ValueBlock` and `ExactBar`. Their tests go with them: the d4 Planning, Profile and Supporting journeys, `d4_layout_test`, `floating_actions_test` (its editorial test moved to `widget_test`), `refinement_test` and its driver. The d4 Life journey stays, because it tests the real Life screen. | Done |
| 2026-11-02 | Consistency pass, step 2: the Review step's parts and `FormExitGuard` move to `kit/review.dart` on the nearest tokens, `form_presentation.dart` goes, and `workspace.dart` keeps only `WorkspacePanel`, `WorkspaceForm` and `WorkspaceSteps` for the demo editor. The status box gets `InlineNotice`'s high-contrast border. The calculator's backspace key shows the bundled backspace icon instead of "⌫", which Geist lacks. Rendered before and after with Geist. | Done |
| 2026-11-02 | Consistency pass, step 3: the glossary rows above are applied. The Review step, the saved state, the exit dialog and the connected Review notice use plain words. Debts', Cards' and Planning's saved titles are the record in the past tense (`savedTitles`). View details holds the change id and version, not the rules' notes. Review groups keep a group gap above their heading. The bell's waiting row counts group changes. "Profile › Connection" never breaks across lines. The four rule messages checked (import staging, the shared card contract, the daylight-saving choice, the upload connector) can't reach a person, so they stay. | Done |
| 2026-11-02 | Consistency pass, step 4: `test/consistency_sweep_test.dart` answers the sweep's five-second question: the shell and every first tab, and Profile and settings, on both platforms, at Android 320, 360 and 412 and Windows 720, 1200 and 1440, at 100% and 200%, in light, dark and both high-contrast themes, plus the source checks. It found 23 controls a screen reader could hear but not press (tabs, segmented controls, card links, quick actions, table rows, the calendar's days, the rail and more); each now passes its callback as `onTap` with `container: true`. The renders found Money's narrow account rows breaking inside a detail ("This month −" / "₱3,444.50"); they use `detailLine` now, which keeps a sign on its amount. | Done |
| 2026-11-02 | My review of the consistency pass: on Android the date sat too far under the sync pill: the status row's spare height, the page's top 16 and the date row's own height added up. The destinations now start `Space.xs` below the status row, as pages do; Windows keeps the page top. | Done |
| 2026-11-02 | The final review audits the redesign against its own five-second question: can a new user trust and use every screen without help? It found 8 real-use breaches and 0 demo-only ones, and fixes only those, in stages A, B1 to B4 and C. | Approved |
| 2026-11-02 | Final review, step A: Debts' "Sync needs review" notice gets Review, which opens Profile › Connection, as Overview, Money and Shared do. | Approved |
| 2026-11-02 | Final review, step A: the demo controller's group actions stay. Removing them would edit the real `LocalFinancialController`, and they're demo-only. Closed as demo debt. | Approved |
| 2026-11-02 | Final review, step A: the redesign's open items that need logic outside the UI stay deferred. They're recorded in PRODUCT_AND_FEATURES §22 as known limits, so they outlive the untracked handoff. | Approved |
| 2026-11-02 | Final review, step B1: zero then and zero now reads "– 0.0%", not "New" (`changeBasisPoints`), on every `ChangeLine`. With amounts hidden, At a glance drops each sentence's amount. Money's Due this week shows what's due this week, the Overview's figure, and counts overdue in its caption only. Debts' Next payment reads "None" when nothing is scheduled. | Approved |
| 2026-11-02 | Final review, step B2: the Overview's Recent activity and Largest expenses close with `ListEnd`, saying how many more Activity holds (the demo counts as Money does, so the two agree). A debt's status pill sits at the end of its name's line in Debts' Your debts and the Overview's Debt payoff (`DebtProgressCard.titleLine`), dropping under the name only when both don't fit. This replaces the Overview's and Debts' pill under the name, under the standing rule that a pill never sits under a row's text. | Approved |
| 2026-11-03 | Final review, step B3: during an unfinished download, Life's Calendar header drops its pill and its "N things this week", because those counts include money dues the download leaves out and the tiles under them read "Not available yet". Tasks, Learning, Books and Career keep theirs; their counts hold no money. | Approved |
| 2026-11-03 | Final review, step B4: `FormExitGuard` asks through the kit's confirmation instead of a stock `AlertDialog`: Keep editing plus Keep draft & close, or a destructive Discard changes with focus on Keep editing. Discard draft leaves the exit dialog in Money, Life and Shared's bill and payment forms (`discardDraft` is gone); drafts are discarded from Saved drafts. | Approved |
| 2026-11-03 | Final review, step C: this document matches the code again (chart and Overview file names, `BudgetProgress`, Windows button height, tabs everywhere). §9, the temporary roadmap, is retired; its lasting rules on rule messages are §7's Rule messages, and the decision log is §9. Lines that described work still to come now describe what's done. The intro, the Scope paragraph and CLAUDE.md's redesign block change only when I call the redesign finished. | Approved |
| 2026-11-03 | Final review, after step C (my go-ahead on both recommendations): chart axis labels follow §1 at 200% (kept inside the plot, thinned from the last when they don't fit, a band as tall as the labels). At 100% only the edge labels move, inside the plot. `p3_widgets_test`'s invitation is now sent on the day the test runs; it had a fixed date that expired after seven days. | Approved |
| 2026-11-03 | I called the UI redesign finished. This document stays the design system for every later change, including the coming feature update: new and changed screens build to the Section screen standard, follow §1 to §7 and record their decisions here. CLAUDE.md's redesign block became its permanent UI rules; the intro and Scope here no longer describe a redesign in progress. | Approved |
| 2026-11-02 | The demo controller's group actions stay for now: `LocalFinancialController`'s constructor resets the base controller and clears its group state, so removing that state changes the real controller. | Needs approval |
| 2026-11-02 | My review: Android parity looks good on the emulator, which finishes it. | Approved |
| 2026-11-02 | Android parity, my picks: phones use the dock's names in the app bar, and the title drops under the actions only when it doesn't fit (a wrapped title broke inside a word at 200%); Go to's page groups its entries in cards; one step. | Approved |
| 2026-11-02 | While the first download isn't finished, Log expense, Log income, Log a transfer, Add shared expense and Log a payment between members aren't offered anywhere, because they opened a demo page in the real build. Debt, card and Life actions stay. UI only. | Approved |
| 2026-11-02 | The sync status gets an icon per state, and "First download not finished" the warning tone, on both platforms. The demo's pill says its state in the real labels. | Approved |
| 2026-11-02 | The bell adds "Sync needs you to sign in" when signed out, opening Connection, read from the existing label. | Approved |
| 2026-11-02 | Screen readers can press the profile button, the sync status, the Windows clock and the Overview's date and dues pill; each had a button label with no tap action. The eye is a toggle on Android too. | Approved |
| 2026-11-02 | Found while building 15b: Go to listed "Log a debt payment" twice (Money's and Debts' keys share the label), and Enter could open the previous keystroke's match. Go to keeps one entry per label and matches what's submitted. | Done |
| 2026-11-02 | Windows below 600 keeps its menu button for Go to and New in the shared header; it gets no search button. | Done |
| 2026-11-02 | Onboarding's frame is "Where your records live": a live map of This device, Salapiya's service, Google and a backup file, beside the choices on Windows and slim above them on Android. It replaces the side panel and its slogans. A lit place on a solid line holds records; a quiet one on a dashed line doesn't, and every place says so in words. | Approved |
| 2026-11-02 | My review of the sample: no empty space. The choices sit tight at the top of their card with "Your profile and your privacy" under them (`SideStack`), the map fills its card, each box is as tall as its text, and the words under it are one line. Screen readers hear the full sentence. | Approved |
| 2026-11-02 | Welcome is three rows with a "Best if" line, and shows only what the rules allow: a read-only look at the saved stage and the profile's folder turns Start on this device off, with why, when an earlier profile's files are still there. It never holds the key. | Approved |
| 2026-11-02 | The startup failure screen says What happened, What's safe and What you can do, and offers only Try again. Restoring there is refused by the rules, and could overwrite the only key if the OS credential comes back. The words no longer promise it. An exception's own text never shows, because it could quote a key. | Approved |
| 2026-11-02 | A failed Create carries on with `reopen`, with its name and theme fixed, because creating again would be refused by the check the first try set. | Done |
| 2026-11-02 | `local_profiles.dart`'s startup, create, retrieve, restore and removal messages, and `local_store.dart`'s three that said to restore, are reworded as approved. Removal's were left by Profile and settings; they show on the failure screen too. | Approved |
| 2026-11-02 | My review: onboarding's second step and the greeting look good, which finishes onboarding. | Approved |
| 2026-11-02 | My review: onboarding's first step looks good. | Approved |
| 2026-11-02 | The Google step is one page by state, with the Connection tab's disclosure and a tailored title. The disclosure says whether a profile was found, or names the one it creates, and keeps every fact. | Approved |
| 2026-11-02 | Restore asks for the file, then the secret, so a wrong secret keeps the file. It reviews what comes back and what doesn't, confirms in a dialog, and ends on a short finished page. A connected backup's Google email shows on those pages. | Approved |
| 2026-11-02 | Restore's first step has What comes back under the form, and its finished page drops the map, because each left a large empty space. Review's buttons sit inside the card. | Done |
| 2026-11-02 | First-run preview opens the real pages with Show a state. `showUpcoming`, `FirstRunPage`, `LocalRecoveryView`, `LocalRecoveryBody`, `ConnectionBody` and `ConnectionPage`'s no-profile branch are retired. `UpcomingView` and `ProfileExperience` stay. | Approved |
| 2026-11-02 | A first run or restore that stopped part-way leaves only Start on this device on Welcome, which carries on, because Google and Restore would be refused. | Done |
| 2026-11-02 | The sign-in messages and `bounded_file_read.dart`'s three are reworded as approved. Messages that assume a profile read differently on these screens only (`noProfileErrors`). | Approved |
| 2026-11-02 | My request: a greeting before Welcome, with the logo and a button. Get started leads on. Welcome becomes "Set up Salapiya", and the greeting takes "It never moves money" and the app's introduction. | Approved |
| 2026-11-02 | My review: the first greeting was too plain and compact. It's now a live app preview: the words on the left and a Sample of the real cards on the right, which is the one accent. Phones get a shorter sample with the button pinned at the bottom. | Approved |
| 2026-11-02 | My review of the greeting: the sample's tiles have the real tiles' change line, so amounts start level with their sparklines. On Android it stays simple: no sample, one screen, and a `headlineSmall` headline. | Approved |
| 2026-11-02 | My request: Windows opens maximized, not full screen, so the taskbar stays. The runner shows the window with `SW_SHOWMAXIMIZED`. The app doesn't remember a window size, so this is every launch; Restore Down goes to the size the window was created with. | Approved |
| 2026-11-02 | The greeting steps aside when work is in progress, and after a removal in the same session, because Welcome then has something to say. | Done |
| 2026-11-02 | My review: setup's Theme shows as it's picked, and leaving puts it back. Only a new profile keeps it. | Done |
| 2026-11-02 | Android keeps the browser for Google sign-in for now. The system account sheet changes the auth flow, so it waits for its own step (PRODUCT_AND_FEATURES §22). | Approved |
| 2026-11-02 | My review: Connection, Devices and Backup look good, including Save a backup's new structure, which finishes Profile and settings. | Approved |
| 2026-11-02 | My review: Profile and Help look good. | Approved |
| 2026-11-02 | Connection is Sync 8 beside Waiting and to check 4, Needs review, then Sync on this device 6 beside What's shared 6. Devices is Signed-in devices 8 beside Lost a device? 4, then Remove or delete. Backup & recovery is Your backups 8 beside How to get it back 4, then What's in a backup. | Approved |
| 2026-11-02 | One row in `life_device` notes the last backup's date and counts, so the tab can say when it was and whether anything changed. No migration or sync, and it isn't in a backup. "Changed since" has no day limit. | Approved |
| 2026-11-02 | The recovery secret is masked until Show, masks again when the app leaves the foreground, takes no keyboard learning and goes with the page. Screens aren't blocked from capture. | Approved |
| 2026-11-02 | Connection shows `binding['last_sync']` as Last synced. Sign out has a confirmation with the waiting count; Pause doesn't. Delete account has a fresh sign-in before its typed phrase. A backup during an unfinished download says it's partial. | Approved |
| 2026-11-02 | Group refusals show on Connection only, as a count and a link. The bell, the pill and `needsReview` don't change, so a refusal nothing can clear doesn't keep the bell on. | Approved |
| 2026-11-02 | The demo's tabs come from a sample, with a demo-only Show a state menu. | Approved |
| 2026-11-02 | `connected_runtime.dart`, `connected_store.dart`, `local_store.dart`, Life's 7 and the status labels are reworded as approved. `isSyncBlock` reads the new start. Of `local_profiles.dart`, only what Check a backup reaches. | Approved |
| 2026-11-02 | Don't connect signs out of Google, because Cancel connection did nothing once signed in. Keep this profile does both. Existing actions, in order. | Done |
| 2026-11-02 | A connected profile that can't reach the service in this build offers nothing, because Sync now would be refused. | Done |
| 2026-11-02 | `lifecycle_view.dart` is gone. `LocalRecoveryBody` and `ConnectionBody` keep only the welcome screen's parts, for onboarding. | Done |
| 2026-11-02 | Profile and settings: Profile is This profile 8 beside At a glance 4, Appearance 6 beside Hide amounts 6, then Defaults and more settings. Help is search, then topics at 6, then About Salapiya. Two stages. | Approved |
| 2026-11-02 | The default group lists only with two or more active groups, because with fewer Shared Expenses never asks. This narrows the plan's one. | Done |
| 2026-11-02 | The frame has no status pill, because At a glance and Connection say it. A link to another tab moves the open page there, not a second copy. | Done |
| 2026-11-02 | Decorative effects leaves the real Profile tab: no redesigned screen reads it. The saved value stays and the demo keeps the switch. | Approved |
| 2026-11-02 | A profile's name isn't synced, so renaming a connected profile says it changes this device only. | Approved |
| 2026-11-02 | Life preferences and Reminders are links on Profile. `ReminderCenter` stays as `openLifeReminders`' fallback. | Approved |
| 2026-11-02 | My review: Documents looks good, which finishes Life's second half. | Approved |
| 2026-11-02 | My review: Career looks good. | Approved |
| 2026-11-02 | A finished task with no due date says finished tasks don't remind you, not to add a date. | Approved |
| 2026-11-02 | The tests tied to a date now work out what they expect, and were run pinned to the 1st, month end and year end. | Approved |
| 2026-11-02 | On the application page, Documents takes the full width under Where it stands, Steps and About, because a filled Documents card left a large empty space under Steps. | Done |
| 2026-11-02 | Career documents: Remove from this device, Preview and Open in another app, as in Money's Files. Preview is on tap only. Opening elsewhere uses the same private temporary copy, removed after 10 minutes. | Approved |
| 2026-11-02 | Attach asks before writing anything. A half-attached file whose application changed is read back and linked afresh, so nothing is chosen again. This goes further than the plan's Choose the file again. | Done |
| 2026-11-02 | `LifeForm`, `lifeReviewForm`, `lifeAction`, `LifeHistory`, `LifePages` and `LifeHeader.alwaysActions` are retired, with `life_form.dart`, `life_history.dart` and `life_pages.dart`. | Approved |
| 2026-11-01 | A Follow-up step past its date is Overdue everywhere, like an application's follow-up date, so Career and the Calendar agree. This narrows the earlier Life rule that events only go by, for this one kind. | Approved |
| 2026-11-01 | Career's stage and outcome change through short separate forms, not one long Edit. A Career step has its own page. | Approved |
| 2026-11-01 | With Hide amounts on, Edit locks a salary already held, reading Amount hidden, and keeps it in the command. | Approved |
| 2026-11-01 | On the application page each side stacks two cards, because a long About left a large empty space beside a centered accent card. | Done |
| 2026-11-01 | My review: Learning and Books look good. | Approved |
| 2026-11-01 | Life: Learning is tiles, Now learning 7 beside What's next 5, then every item. Books is three tiles, Reading now 7 beside Up next 5, then every book. Three stages. | Approved |
| 2026-11-01 | A total is optional. Left blank it sends the rules' default of 1, and that item shows no bar and offers Mark as finished. This changes what a skipped field sends: the old form saved a made-up 12 or 240. | Approved |
| 2026-11-01 | Log progress shows an optional, blank Date finished at the total. Start reading changes the status only. Dates stay the user's. | Approved |
| 2026-11-01 | All 28 of Life's second-half rule messages are approved as proposed. Five are in with 13a, the rest with the stages that show them. | Approved |
| 2026-11-01 | Shareable lists for Learning, Books and applications, with no notes, contacts, salary, links or documents. | Approved |
| 2026-11-01 | Retiring with Life's second half: the old form, history and pages, the old tabs, and the demo controller's Learning, Books and application seeds. Learning's and Books' seeds went with 13a. | Approved |
| 2026-11-01 | The Finished tile has no tap: it would change a filter that may be off screen on a phone. Rows with no total offer Mark as finished in one tap, as the page does. | Done |
| 2026-11-01 | My review: People, History and Manage Group look good, which finishes Shared Expenses. | Approved |
| 2026-11-01 | My review: Calendar looks good, including Add event's new arrangement, shown as a sample. | Approved |
| 2026-11-01 | My review after commit: a pill under a row's text reads as an afterthought. In a narrow row a lone status pill sits at the end of the title's line; amounts stay under the text. This changes the rule from the Overview work for pills only. | Done |
| 2026-11-01 | My review after commit: on Android, a card's switch left a gap under the title, because its 48 target set the header's height. `OverviewCard` gains `toggle`, whose target lies over the card's padding, and a switch ends flush with the content. | Done |
| 2026-11-01 | My review: Reminders looks good with the compact switches. Life's first half is approved. | Approved |
| 2026-11-01 | My review of Reminders: the stock switches were too big beside the compact controls. `AppSwitch` is 20 tall on Windows and 24 on Android, with a 48 hit area on Android, matching the sidebar's small switch. | Done |
| 2026-11-01 | My review: Tasks looks good. | Approved |
| 2026-11-01 | Coming reminders shows eight rows, then links to every reminder, because 25 left a large gap under the side cards. This narrows the plan's 25 then Show more, which the whole list keeps. | Done |
| 2026-11-01 | A radio list's label sits level with its radio when it has no description. | Done |
| 2026-11-01 | The old demo reminder code retires: ReminderControls, ReminderCenter's demo body, `reminder_widgets.dart` and the demo controller's reminder fields. The demo's `agenda` stays, because the d4 tests use it. | Done |
| 2026-11-01 | Life: Reminders is a Life tab, after Tasks (built with Reminders). Calendar is tiles, the month beside the chosen day, then what's overdue and coming up. Tasks is tiles, Next up beside By priority, then every task. Three stages. | Approved |
| 2026-11-01 | An event that has gone by doesn't count as late: it reads Past. Tasks, due dates and money dues do count. This is narrower than ARCHITECTURE §12.1 for events, because few people mark an event done. | Approved |
| 2026-11-01 | Calendar's money rows include waiting work, so they match Debts. Notifications stay on accepted records, so a reminder can still go off for a due the Calendar no longer shows, and a notice says so. | Approved |
| 2026-11-01 | Money rows open their record, with no Log link on the Calendar. | Approved |
| 2026-11-01 | Reminders: Snooze only once a reminder has fired; minutes-before hidden on all-day items; a plain status beside the text in `device_reminders.dart`; Inherited reads Default on screen. Built with Reminders. | Approved |
| 2026-11-01 | Shareable lists for a week or month, one day and the task list, with counts and no money total. | Approved |
| 2026-11-01 | `lifeAgendaItems` moved out of `agendaWindow` with the same results, and forms save through `LifeWriter`, so the demo replays real records and its forms work. Today counts by `civilToday()`. Life counts in the bell's waiting and review rows (built with Tasks). | Approved |
| 2026-11-01 | Life's first-half 18 rule messages are reworded as approved, with Life's stored reasons changed on screen only. | Approved |
| 2026-11-01 | Old Life demo code retires with Reminders. The demo controller's Learning, Books and Career data stays for Life's second half. | Approved |
