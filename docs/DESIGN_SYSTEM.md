# Design system

This is the spec for the Salapiya UI redesign (Windows and Android, one Flutter codebase). Every redesign chat follows it. When a chat needs a rule that isn't here, add it here first, then build it. Every section chat builds to the [Section screen standard](#section-screen-standard-the-overviews-quality-bar): the Overview is the quality bar.

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
| Compact | < 600 | Android bottom dock; Windows: a menu button ("Go to") opens the destination chooser | 1 |
| Medium | 600–999 | Sidebar as a rail, `Space.railWidth` 64 (icons, tooltips, flyouts); it doesn't expand | 1–2 |
| Expanded | 1000–1439 | Sidebar, `Space.sidebarWidth` 224; collapsible to the rail for the session | 2–3 |
| Wide | ≥ 1440 | Same as Expanded | Up to 4; content max width 1280 (`Space.contentMaxWidth`) |

At text scale ≥ 150%, drop one column class.

| Concern | Windows | Android |
| --- | --- | --- |
| Window chrome | A custom title bar across the full window width, above the sidebar and the app bar ([below](#windows-title-bar-chat-5)). The native caption is removed; the sides and bottom keep the native frame. | System status bar. Top app bar with the section title (the logo mark leads it on Overview), Hide amounts and the profile button, with the sync status pill under the title. |
| Primary navigation | Sidebar panel flush with the window's left edge: logo, profile card, Go to, five destinations with their tabs, Needs attention, utilities ([App shell](#app-shell-chat-4)) | Floating bottom dock with five labelled destinations ("Shared" is the short label for Shared Expenses); a separate + action above it |
| Back / forward | Title-bar buttons, Alt+← / Alt+→, mouse back/forward buttons | System back gesture or button; no forward |
| Location | Breadcrumb in the app bar, below the title bar (Section › Tab › Page) | Screen title in the app bar; tabs below it |
| Create actions | "New" menu button in the shell header (Ctrl+N) | + button above the dock opens a bottom sheet |
| Info control ([§6](#6-form-help-pattern)) | A tooltip on hover and keyboard focus; a click pins it as a popover | Tap opens an anchored popover |
| Dialogs | Centered, width-bounded modal | Centered dialog for confirmations; bottom sheet for choices and short forms; full-screen page for long forms |
| Forms | Centered column, max width bounded | Full width, scrolls, keyboard insets respected |
| Row density | Single-line rows may be 40 px when pointer-only; hover state on rows | Rows at least 48 px; no hover |
| Hover | Required on every interactive element | Not used; pressed state only |
| Keyboard | Every action reachable; Esc closes the top overlay; Ctrl+N opens New; Ctrl+K opens Go to; Ctrl+H hides or shows amounts | Hardware keyboard works; not required to be optimized |

### App shell (Chat 4)

`lib/app/shell.dart` and `lib/app/shell_navigation.dart`, built from the kit.

- **Destinations:** Overview, Money, Debts, Shared Expenses and Life. Section tabs stay inside each section.
- **Profile and settings:** one entry, not a destination. It opens the existing profile page and its tabs (Profile, Connection, Devices, Backup & recovery, Help). Connected accounts are under Connection.
  - Windows: the profile card at the top of the sidebar opens a menu: Profile and settings, Connection, Devices, Backup & recovery.
  - Android, and Windows below 600: a button with the profile's initial in the header.
- **Shell header:**
  - **Windows with the sidebar: the app bar.** It is `Space.appBarHeight` (56) tall on `surface`, with a hairline divider below, and level with the sidebar's logo row.
    - Left: the breadcrumb (`ShellBreadcrumb`), with chevrons between segments. Earlier segments are muted and go back; the last one is the current place.
    - Right: New. Go to and the sync state are in the title bar. Hide amounts and the profile live in the sidebar.
    - Without the custom frame (an older runner, or tests that don't turn it on), the app bar keeps the Chat 4 layout: the Go to field (224 wide; a search icon at Medium width) before New, and the sync line in the profile card.
  - **Android, and Windows below 600:** the title or location, Hide amounts, the profile button, and the sync `StatusPill` on its own row. On Windows the title bar shows the sync state instead, so that row is dropped.
  - A 12 bottom gap keeps the header clear of content scrolling under it.
- **Windows sidebar** (`ShellSidebar`), after the owner's reference images:
  - **Panel:** `surface` on the canvas, flush with the window's left, top and bottom edges. It has square corners and a hairline (`divider`, or `text` in high contrast) along its right edge. Mica was deferred in Chat 5, so the panel stays solid.
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
    - **Quick create** (with the title bar): the current section's first three New actions as rows, one click each, the Windows counterpart of Android's + button. Overview and Money: Log expense, Log income, Log a transfer. Debts: Log a debt payment, Add a debt, Log a new loan. Life: Add task, Add event. Hidden when the section has none (Shared Expenses in production) and on the rail.
    - **Needs attention** (without the title bar; with it, these rows are in the title bar's bell): rows built from existing counts, each going to where it's handled: "N payments to confirm" (Shared Expenses › Payments), "N waiting to sync" and "Sync needs review" (Profile › Connection). With none, it shows "Nothing needs attention". Shared Expenses also shows the to-confirm count as a badge in both cases.
  - **Bottom, fixed:**
    - Settings (opens Profile and settings) and Help. Without the title bar, Hide amounts (a small switch) comes first; with it, Hide amounts is in the title bar.
    - Then a full-width Light | Dark switch, with an icon and a label on each segment. It shows the theme in use, including what System is giving. Choosing one sets the profile's theme. System stays available in Profile and settings.
  - **Selected item:** a `subtle` fill and a medium-weight `text` label. Only the icon is `primary`. High contrast adds a `text` outline.
  - **Rail:** 40 × 40 icon cells with tooltips. The profile initial opens its menu. Sections with tabs open a flyout beside the item. It has a header (the section's icon and name), then the tabs on the same tree line as the expanded sidebar, with the current tab highlighted. The flyout is level 2, with a `control` radius and a hairline border. The badge sits on the icon. The footer is icon cells: Hide amounts (only without the title bar), Settings, Help, and the theme (switches to the other one).
- **Go to (Ctrl+K):** a dialog near the top of the window. Typing filters; Enter opens the first match. It lists the sections, every tab ("Activity · Money"), the create actions and the profile pages. It jumps to places; it doesn't search records. It opens from the title bar's Go to field (a search button at Medium width), or from the header's menu button on Windows below 600.
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

### Windows title bar (Chat 5)

`lib/app/title_bar.dart` (the bar and the runner bridge), `lib/app/title_bar_tools.dart` (clock, bell, calculator), `lib/app/window_chrome.dart` (where it sits), and the runner in `apps/salapiya/windows/runner/`. The decision log has the history; this is the current design.

- **One custom bar across the full window width**, `Space.titleBarHeight` (40), on `titleBar` with a hairline below the content column. The sidebar and the app bar start under it; the sidebar's logo row (56) stays level with the app bar.
- **It frames every screen.** `WindowChrome` puts it above the app's navigator, so welcome, loading and recovery screens have window controls too. Outside the shell, it shows only drag space and the window controls.
- **No logo or app name.** The logo stays in the sidebar.
- **Contents, left to right:**
  - **Left segment (date and clock):** as wide as the sidebar (224, or 64 on the rail), on `surface` with the sidebar's right hairline. The bar's bottom line stops at it, so the sidebar runs unbroken from the window's top edge. The clock is centered in the segment: a 16 clock icon, then "2:45 PM · Fri, 30 Oct" (`NavType.label`, tabular; the time in `text`, medium; the date in `secondary`). It updates each minute, and the time follows the system's 12/24-hour setting. On the rail it shows the time only, centered (`bodySmall`); below 600 there is no segment. It opens a read-only month calendar with today marked and "Open Life › Calendar".
  - Back and Forward: kit `AppIconButton`s (32), `Space.xs` apart, `Space.sm` past the sidebar's edge (or from the window's edge without one). They are neutral navigation chrome: `text` when enabled, `secondary` when there is no history; the tools on the right keep the accent. Tooltips "Back (Alt+←)" and "Forward (Alt+→)".
  - **Go to**, moved from the app bar. From 1000 wide it is the `GoToField`, `Space.goToWidth` (320) wide and centered on the window. It narrows rather than overlap either side and keeps at least 48 of drag space beside it. At Medium width it is a search button after Forward. Below 600 the header's menu button stays, because there it is the way to navigate.
  - Drag space: everything else.
  - **Bell:** what needs the user, from the existing counts (payments to confirm, waiting to sync, sync needs review), with a `primary` count badge. It opens a menu headed "Needs attention" whose rows go where each item is handled; with none it says "Nothing needs attention". It replaces the sidebar's Needs attention group.
  - **Calculator:** a popover with a keypad (C, Backspace, Copy, the four operators, digits, the decimal point, =). Typing works while it's open (digits, + − * / or x, Enter or =, Backspace, Delete or C, Ctrl+C, and the numpad); Esc closes it. Arithmetic is on exact fractions, left to right as in Windows' standard mode. A result that doesn't end within 10 decimals shows rounded to centavos and marked "≈" (DOMAIN_RULES §49: rounding is never silent); Copy puts the plain value (for example `416.67`) on the clipboard. It saves nothing. Hidden below 600.
  - **Hide amounts:** an eye button, "Hide amounts (Ctrl+H)" or "Show amounts (Ctrl+H)", reported as a toggle. It replaces the sidebar footer's row, the rail's cell and, below 600, the header's button.
  - **Sync status**, moved from the sidebar's profile card. It shows the shell's existing status labels ("On this device only", "Synced", "Synchronizing", "Waiting for connection", or "Demo · …"), in warning tone when sync needs review. It opens Profile › Connection, or Profile and settings in the demo. Below 600 it is icon-only, with the label in its tooltip.
  - **Window controls:** minimize, maximize or restore, and close (`CaptionButtons`, 46 wide, full height).
- **Not in the bar:** the logo and app name (they stay in the sidebar) and the breadcrumb (it stays in the app bar).
- **Colors:** see [§3](#charts-title-bar-high-contrast-and-legacy-colors). Close uses the system red on hover, an allowed exception to the purple accent.
- **Mica:** deferred. Flutter's Windows engine draws an opaque surface, so Mica would need an unsupported transparent surface. Translucent sidebar text also can't be contrast-checked against a wallpaper tint. The bar and the sidebar stay solid.
- **Native frame (runner):**
  - `WM_NCCALCSIZE` moves the client top to the window's top edge. The left, right and bottom frame stay native, which keeps the resize borders, the shadow, Windows 11's rounded corners, Aero Snap, Win+arrow keys and Alt+Space. A maximized window gets its hidden frame back as top padding, minus one pixel on an auto-hide taskbar's edge.
  - Hit testing: the Flutter view is subclassed to return `HTTRANSPARENT` over the bar's drag space, the top resize band and the maximize button. The window then answers `HTCAPTION` (drag, double-click to maximize, right-click for the system menu), `HTTOP`/`HTTOPLEFT`/`HTTOPRIGHT` (not when maximized), or `HTMAXBUTTON`, which brings up Snap Layouts.
  - The app sends its regions after each layout, in logical pixels: the bar height, the maximize button and the interactive areas. The runner scales them by the window's DPI at hit-test time, so DPI changes and monitor moves need no extra messages.
  - The runner owns the maximize button's pointer input. It reports hover and pressed to the app, and maximizes or restores on release. Minimize and close are ordinary app buttons; every window command is posted as a system command (`SC_MINIMIZE`, `SC_MAXIMIZE`, `SC_RESTORE`, `SC_CLOSE`).
  - The runner also reports maximized and active. Glyphs turn `secondary` while the window is inactive.
- **Opt-in:** `main.dart` calls `WindowFrame.enable()` before `runApp`, and the native caption stays until it does. An older runner, the debug component gallery (a separate app) and widget tests keep the native caption and the Chat 4 shell layout.
- **Dialogs and sheets** open below the bar. While one is open, the clock, back, forward, Go to, the tools and the sync status are inert; drag and the window controls keep working. The clock, bell and calculator popovers are menus, which close on Esc or an outside click.
- **Keyboard and screen readers:**
  - Tab order, in reading order: the clock, Back, Forward, Go to, the bell, the calculator, Hide amounts, the sync status, then the app. The window controls aren't in the Tab order, as with native caption buttons; Alt+Space reaches them.
  - Screen readers get named buttons: "Minimize", "Maximize" or "Restore Down", "Close", "Sync status, ‹label›", the clock ("Fri, 30 Oct, 2:45 PM. Open the calendar") and "Notifications, N need attention". The calculator's display is a live region.
  - The app's navigator, and the shell's content navigator, sit in semantics containers. Without them, a route's modal barrier hid the title bar, the sidebar and the app bar from screen readers.
- **High contrast:** the app switches to its high-contrast theme and the native border uses the system colors. Flutter doesn't expose the user's high-contrast palette, so the bar itself uses the app's high-contrast roles.
- **Back/forward history is UI-layer state** over the existing navigation (destination switches and pushed pages). Routes and route names do not change.

### Android parity with the Windows title bar (planned)

Approved 2026-10-30. Android gets the title bar's features in its own places; there is no title bar on Android. Built across stages (see [§9](#9-redesign-roadmap-temporary)), from the same sources as Windows.

- **App bar:** the title (the logo mark leads it on Overview), then three actions: Go to (search), the bell and the profile button.
- **Status row** (today's sync pill row): the sync pill on the left, now tappable (opens Profile › Connection, as on Windows), and the Hide amounts eye on the right, moved from the app bar.
- **Go to:** the search icon opens a full-screen Go to page with the same `GoToEntry` list (sections, tabs, create actions, profile pages), filtered as you type.
- **Bell:** a count badge; it opens a bottom sheet with the same Needs attention rows as the Windows bell, each going where the item is handled.
- **Date and calendar:** no clock (the status bar shows it). The date in Overview's header is tappable and opens a calendar sheet with "Open Life › Calendar".
- **Calculator:** a "Calculator" row at the bottom of the + sheet opens it as a bottom sheet with Copy (the same exact engine and "≈" rule). As each form is redesigned, amount fields get a calculator button whose "Use result" fills the field, on both platforms (`AmountField`, §5).
- **Unchanged:** system Back (no Forward), the + sheet as Quick create's counterpart, the dock.
- **Ideas needing approval later:** Android launcher shortcuts and the Windows taskbar jump list (native code), and the Android 14+ predictive-back animation.

```
│ 9:41                  ▴ ▮ 100% │  status bar
│ ◆ Overview        ⌕   🔔1  (A)  │  app bar
│ (☁ Synced ›)              👁   │  status row
├────────────────────────────────┤
│ Fri, 30 October  ›             │  Overview header (opens the calendar)
```

### Overview dashboard (Chat 6)

`lib/app/overview_dashboard.dart` (layout, tabs and sources), `overview_cards.dart` (cards), `overview_controls.dart` (compact controls and tiles), `overview_charts.dart` (charts), `overview_data.dart` (display-only derivations) and `overview_demo.dart` (the demo sample); tested in `test/overview_dashboard_test.dart`. Goal: within five seconds, where your money stands, what is due and what changed. Owner review 1 (2026-10-30) reworked it after the owner's reference dashboards: compact sizes, KPI tiles with sparklines, mixed card widths, more widget types and tabs.

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
    - List (owner review 2, for sharing a screenshot): "This month · 1–31 Oct · as of Fri, 30 Oct", the totals plus "Total due" when something is overdue, then every item of the period in one table (Due date with "N days overdue", Item, Type, Status, Amount), sorted by date, with no row limit. Narrow cards show the same items as rows.
  - **Recent activity** (5 rows) beside **At a glance**; then **Next up in Life** and **Shared Expenses**.
- **Spending:**
  - **Spending by category:** a donut (top five and "Other") with "Top category" in the hole, and a legend of each category's share and exact amount. Net-negative categories are left out of the shares.
    - Legend rows: the swatch and name are vertically centered beside the share and amount; the share sits over the amount, or beside it on one line when the legend is wide. Only under 192 × the text scale does the amount take its own line.
    - Hovering (Windows) or tapping (Android) a section selects it: it grows 4 outward, the hole shows its name, share and amount, and its legend row is highlighted. Legend rows select their section the same way (hover, tap, or Enter by keyboard). Leaving the chart or tapping its hole clears it.
  - **Budgets:** a half-circle gauge of the total used across budgets with a limit (warning tone when over), beside each budget's slim bar and line ("45.13% used", "₱X over", zero-limit). An empty state when there are none.
  - **Largest expenses this month:** the five largest, as a table.
- **Debts & Dues:** Due and overdue beside **What you owe over time** (filled line, then a stat strip: Today, Since end of ‹month› with Paid down / Added, Highest; then "By debt": each debt with what you owe on it and a slim bar of its share); then **Debt payoff** as a table: name and pill, a bar with one step per scheduled payment (a continuous bar above 24), the progress line, and what you owe.
- **Accounts & Activity:** an account card per active account (type icon, balance, 30-day sparkline, "Last 30 days"), a Card debt card ("Available credit ₱X, not money you have"), then **Recent activity** (10 rows).
- **Uneven rows:** a card can center its content in the height its grid row gives it (`OverviewCard(centered: true)`): the header stays at the top and the space left is split above and below the content. The Spending tab's category and budgets cards use it, so whichever is shorter doesn't leave a gap at its bottom.
- **"Show values"** sits 16 below the figures above it.
- **Tables** (`ActivityCard`, the dues list, the payoff table): columns when the card is at least 528 × the text scale wide; a list of rows otherwise. The amount column has one width per table, measured from its widest amount (`moneyColumnWidth`), so every other column starts at the same x on every row.
- **Sizes (dashboard only):** card titles `titleSmall`, captions `bodySmall`; KPI and chart totals `MoneySize.tile`; card actions are small links (`CardLink`, `labelMedium` in `primary` with a chevron); segmented controls (`MiniSegmented`) and quick-action chips look 32 tall. On Android every one of them keeps a 48 × 48 hit area (`TouchArea` adds transparent space around it). The rest of the app keeps its sizes.
- **States:**
  - An incomplete download shows "Not available yet" in every money value, list and chart; changes and sparklines are hidden.
  - Hidden amounts hide charts, the donut and every change line and sparkline ("Amounts hidden"); other values show "Amount hidden".
  - Each card has its own empty state.
- **Dates:** "Today" is `civilToday()` (Asia/Manila), with `debtDueStatus` for every row. "This week" is Monday to Sunday; "This month" is the calendar month. Period rows start today; anything earlier is only under Overdue. "Last month" covers the same days, stopping at its own last day.
- **Changes** (`ChangeLine`): an arrow and the change in whole basis points of the earlier value, shown with one decimal and rounded toward zero ("↑ 4.2%"), then what it compares with. Rises in available money and income use the success tone; rises in spending and what you owe use warning; no change is neutral; an earlier zero shows "New". Screen readers hear "Up 4.2% vs 1–28 Sep".
- **Snapshots:** money values, charts and sparklines use accepted history. Dues and debt progress use the Debts screen's records, which include waiting work.
- **Layout** (`DashboardGrid`, a 12-column grid by content width; at 150% text the width counts as two-thirds):
  - From 1104: tiles 3 columns each; hero 8 + dues 4; Recent activity 8 + At a glance 4; Life 6 + Shared 6; category 5 + budgets 7; dues 6 + owed 6; account cards 3 each; tables full width.
  - From 688: tiles and account cards two to a row; everything else full width.
  - Narrower, and always on Android: one column in priority order (Summary: tiles, At a glance, dues, hero, activity, Life, Shared). Tiles and account cards pair up when the column is at least 336 wide.
  - Cards in a row match the tallest (`_EqualHeightRow`). The grid owns the gap.
  - **Narrow cards and large text:** row amounts and pills, a card's header control and label amounts move below the text under 336 × the text scale (640 for a header with a segmented control); the donut, gauge and tables switch to stacked layouts; segmented controls and the tab row scroll sideways rather than shrink text.
- **Demo build:** the same dashboard, filled by a sample profile replayed in memory through the real rules (`planLocal`), dated relative to today: three accounts that end today on the demo balances (₱29,300.75 in all, as Money shows), two months of spending and income, six debts (one due soon, one 3 days overdue, one paid off, one with no schedule, one closed by an early payoff, and one with varied amounts, a partial payment and a payment without a breakdown), a card statement due in 5 days and three budgets. Demo scenarios (empty, incomplete, waiting changes, review) and hidden amounts apply. Nothing is stored. The previous demo Overview layout and its files are removed.

### Debts (Chat 7)

`lib/finance/debt_screen.dart` (the section, its pages and the local source), `debt_cards.dart` (cards and `DebtTable`), `debt_data.dart` (display-only derivations) and `debt_demo.dart` (the demo source); tested in `test/debt_data_test.dart` and `test/debts_dashboard_test.dart`. Five-second question: "What do I owe, what's next, and is anything late?"

- **Header.** Windows: a `PageHeader`, "As of ‹long date› · N debts", with the shell's three New items as chips at the right end. Android: one 48-tall row, the date and a pill ("N overdue", else "N due this week") that opens Schedule; the pill drops under the date when large text can't hold both.
- **Tabs** (`AppTabs`): Summary · Schedule · Payments · History. They also show in the sidebar, the rail flyout and Go to, and take part in back and forward.
- **Notices**, under the tabs, only when they apply: first download not finished; changes waiting to sync (Debts include them, so totals can differ from the Overview until they sync); sync needs review.
- **Summary:**
  - **KPI tiles:** What you owe (the one accent, with the change since last month end and a sparkline), Overdue ("N payments · oldest N days"), Next payment (amount, then the debt, date and "in N days"; same-day payments are summed) and Due this month.
  - **Your debts** (8): every debt, most urgent first, then a finished schedule with money still owed, then Settled and Closed. A filter (All, Overdue, Upcoming, No schedule, Paid off; a debt is under exactly one besides All). Each row: name and lender, pill, `SegmentBar`, the progress line, the next payment, what you owe and a "Log payment" link.
  - **Due next** (4): overdue, then the next 5 rows, debts only, each with "Log payment". It closes with "N more on Schedule" or "That's everything".
  - **What you owe over time** (`OwedCard`, 7) beside **Needs your input** (5): set a schedule, check a varied amount, break down a payment. Hidden when there is nothing to do; the chart then takes the row.
- **Schedule:** **Due and overdue**, the Overview's card. Its corner menu picks Calendar or List, All dues or Debts only, and "Open as a page". Calendar sits at 7 beside **Upcoming by month** at 5; List takes the full width with the chart under it.
- **Shareable list:** the Overview's list view (`DuesList`): the period heading with "as of", the totals, every item with no row limit. "Open as a page" (`DuesListPage`) shows only that, so an Android screenshot has no tabs, dock or + button.
- **Payments:** **Paid over time** (7, a bar per month for six months with this month, last month and paid down) beside **Payments to break down** (5), then **Payment history** (date, debt, paid from, applied to, breakdown, amount; 25 rows, then "Show more").
- **History:** every debt record with its earlier versions; rows open the record page, which keeps Correct and Reverse.
- **Debt details** (`NativeDebtDetail`, a `SectionPage`): the name, pill and "Lender · Type", then "Log a payment" and a More menu (Edit or Set schedule, Update amounts, Break down a payment, Log a lender charge or waiver, Log an early payoff, View record). Below: **Payoff** (the page's accent, 8) beside **About this debt** (4), then **Payments**, one row per scheduled payment, and **Payment history**. Closed and settled debts offer no new payment.
- **Display states** (`DebtProgress`, also used by the Overview). Closed: a payoff is on record, with or without a schedule. Settled: nothing owed and nothing open. Schedule finished: every scheduled payment is logged but money is still owed. Otherwise the `DebtDueStatus` label.
- **Tables** (`DebtTable`): as §2 Tables, and they also turn into rows when the fixed columns leave the flexible ones under 48 × the text scale per share.
- **States:** an incomplete download shows "Not available yet" and no ₱ anywhere. Hidden amounts show "Amount hidden", hide charts, change lines and sparklines, and stop the progress line at "4 of 6 payments logged".
- **Dates:** the Overview's. "Next" starts today, so overdue rows are never next. Upcoming by month is this month and the next five; this month starts today and overdue stays separate.
- **Editors:** every Debts form is on the compact scale (§3) with `DateField`, `AmountField`, errors in place and plain labels. Fields most people skip sit under "More details", and fields show only when they apply: Paid into for cash, Category for a purchase, charge and waiver fields by what happened. Negative balance consent appears only once the rules ask. Log a debt payment asks for the essentials and fills the rest of the same command from the answers; corrections keep every field. An early payoff fills the lender's amount from the payoff amount.
- **Demo build:** the same screens from the Overview's sample (`demoSample`), so both agree. Demo scenarios and hidden amounts apply. Editors open the demo's own forms, and saving there doesn't change the sample.

### Section screen standard (the Overview's quality bar)

Approved by the owner on 2026-10-30. The Overview (above) is the reference for every section chat from Chat 7 on. A section keeps its own content and features, chosen to answer its own questions, but builds them in the same design language, at the same level of finish. Don't copy Overview cards one for one. Pick the widgets that suit the section, and build them the same way.

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
  - **Header:** a `titleSmall` title and a `bodySmall` caption.
  - **View controls:** a small segmented control (`MiniSegmented`) at the header's end. It moves under the heading when the card is narrow.
  - **Layout or settings choices:** an icon menu in the corner (`AppIconButton` + `MenuAnchor`, `corner:`), not a second segmented control.
  - **Links:** small `CardLink`s, never full-size buttons, in a card header.
  - **Accent:** at most one accent card per screen.
  - **KPI tiles** (`KpiTile`): icon badge, label, a `MoneySize.tile` value, a `ChangeLine`, a `Sparkline` and a caption. Tiles in a set share a label height, so their values line up.
- **Data display:**
  - **Tables:** shown as columns at 528 × the text scale and wider, and as rows below that. The amount column has one measured width (`moneyColumnWidth`), so every column starts at the same x on every row. Headers use `labelMedium` in `secondary`, with hairline dividers.
  - **Charts:** use the `overview_charts.dart` wrappers and follow the §5 chart rules.
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
    - **Rollout:** the first section chat that redesigns a form applies this through the theme and kit, shows the owner a sample form before rolling it out, then records the metrics in §3 and §5.
  - **Android:** every control keeps a 48 × 48 hit area (`TouchArea`).
  - **Large text:** nothing is truncated at 200% text. Controls scroll sideways or wrap rather than shrink their text.
- **Shareable views:** when users show a list to other people (dues, balances owed, statements, a group's bills), offer a List layout. It has a period heading with "as of ‹date›", the totals, and every item in one table with no row limit, so one screenshot says it all.
- **Demo data:** the section's demo build shows populated, realistic content. It follows `overview_demo.dart`: a sample replayed through the real rules, dated relative to today, and agreeing with the demo's other screens. The owner reviews populated screens.
- **Tests:**
  - **Sweep test:** every tab at Android 320, 360 and 412 and Windows 720, 1200 and 1440 wide, at 100% and 200% text, in light and dark, plus hidden amounts, incomplete and empty states. The test app sets `themeAnimationDuration: Duration.zero`, so each platform really renders.
  - **Alignment tests:** for tables, rows and tiles.
  - **Demo sample test:** the sample replays on week, month and year edges.
- **Reuse:**
  - **Where the parts live:** the shared ones are in the kit (§5 Dashboard kit). `DuesCard`, `DuesList`, `DueCalendar`, `DebtProgressCard` and `OwedCard` stay in `lib/app/overview_cards.dart` because they use finance types. The donut, gauge and account cards stay in `lib/app` until another section needs them.
  - **Moving more to the kit:** the first section chat that needs one moves it into `lib/design_system/kit/` without changing its look, then documents it in §5.
- **Lessons from the Overview reviews** (check them before showing the owner):
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

"You owe" uses neutral `text`; Chat 10 decides whether it needs a role.

### Charts, title bar, high contrast and legacy colors

- **Chart series** (`chartSeries`, in order): violet `#6546A3` / `#CABDFA`, teal `#266C80` / `#79C4D2`, plum `#9A4C72` / `#E6BCD4`, ochre `#80631B` / `#E4C572`, blue `#395EB2` / `#A9BCFF`, neutral `#59616F` / `#B9B9C6` (light / dark).
- **Windows title bar:** `titleBar` (= `canvas`) with a `divider` hairline below, `text` glyphs, and `secondary` glyphs while the window is inactive. Minimize and maximize hover with `windowControlHover` (`text` at 6%) and press with `windowControlPressed` (`text` at 4%), Windows 11's subtle fills. Close hovers with `windowCloseHover` `#C42B1C` and a white glyph and presses with `windowClosePressed` (that red at 90%), following the OS convention. In high contrast all three fill with `text` and invert the glyph.
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
  - Screens built from the text theme, the stock Material themes and the kit shrink at once. Section chats replace the remaining hard-coded literals (about 70 font sizes, plus radii) as they redesign each screen.
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

### Compact form scale (`CompactForm`; Chat 7)

Forms are one step smaller than the base sizes and stay easy to read. Approved by the owner on a sample of Log a debt payment.

| Part | Android | Windows |
| --- | --- | --- |
| Typed value | `bodyMedium` 14 / 20 | `bodyMedium` 13 / 18 |
| Field height | looks 40 (`Space.formControl`), 48 hit area | 32 |
| Label | `labelMedium` 12 / 16, 4 above the field | same |
| Helper, error | `bodySmall` 12 / 16, 4 below, always visible | same |
| Gap between fields / groups / actions | 12 / 16 / 16 | same |
| Buttons | look 40, 48 hit area | 32 |
| Form column | full width | max 640 (`Space.formMaxWidth`), centered |

- **Scope:** a theme scope, not an app-wide change. `NativeFinanceEditor` (Debts, and Money's Cards, Planning, Files and Correct/Reverse forms) and Update payment amounts use it. Log expense, income and transfer adopt it in Chat 8, and each later chat adopts it for its own forms.
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
6. The screen meets the [Section screen standard](#section-screen-standard-the-overviews-quality-bar), and none of its "Lessons from the Overview reviews" apply.
7. Tables keep their columns aligned, and tiles in a set keep their values aligned.
8. The demo build shows the section populated.
9. The section's sweep test covers both platforms, both text sizes, both themes and the hidden, incomplete and empty states.

## 5. Component rules

The kit lives in `apps/salapiya/lib/design_system/kit/`; screens import `kit/kit.dart`. Every component reads tokens only, works in light, dark and high contrast, and follows the platform from `Theme.of(context).platform`. The older widgets in `components.dart`, `workspace.dart`, `editorial.dart` and `form_presentation.dart` stay until each section chat replaces their uses.

### Shared interaction

- **States:** rest, hover (Windows only, `subtle` fill), pressed (`subtle` fill), focus, disabled, busy and error. No ripple.
- **Focus ring:** 2 px `focus`, drawn 2 px outside the component and following its radius (`FocusRing`). It shows for keyboard focus only. Stock buttons draw it as a 2 px border from the theme.
- **Targets:** at least 48×48 on Android. On Windows, 32 (`Space.pointerTarget`) for buttons, fields, segmented controls, icon buttons and the info control; rows are 36 ([§3 Windows density](#windows-density-compact-scale)).
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
- **`PageHeader`** (Chat 6): a `headlineMedium` page title, an optional `bodyMedium` caption 4 below, and actions centered on the title. The parent owns the gap after it (`headerGap`).
- **Accent:** `SurfaceCard(accent: true)` and `MetricTile(accent: true)` use the `selection` fill. Use it for the one tinted focal card on a screen, never more.

### Tabs (`AppTabs`; Chat 6 owner review)

- Underline tabs that switch between views of one page: `labelLarge` text, `secondary` (medium weight) or `primary` (semibold) when selected, with a 2 px `primary` underline on the row's `divider` hairline. 12 between tabs.
- Each tab is `hitTarget` tall (32 on Windows, 48 on Android). The row scrolls sideways when it doesn't fit; text never shrinks.
- Screen readers hear each tab as a selected or unselected button in a group. Each tab's key is `ValueKey(value)`.
- First used by the Overview. Section screens adopt it in their own chats.

### List rows (`ListRow`, `ListGroup`)

- **Height:** one line is at least 48, or 40 on Windows. Two lines are at least 56.
- **Padding:** 12 horizontal and 8 vertical.
- **Leading icon:** 24, in `secondary`, centered on the text block.
- **Text:** the title is `titleSmall` and the subtitle is `bodySmall` in `secondary`.
- **Trailing:** usually an amount or a status pill. It is centered vertically on the row, like the leading icon and the chevron.
- **Tappable rows:** they get a chevron and hover, pressed and focus states.
- **`stackTrailing`:** puts the trailing item under the text, end-aligned, for rows too narrow to hold both (the caller decides, because `ListRow` sits inside intrinsic-height layouts and can't measure itself).
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
  - **Tile:** `headlineMedium`, stepping down to `headlineSmall` and `titleMedium` (the compact dashboard value; Overview only).
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

### Charts (`OverviewBarChart`, `OverviewLineChart`, `Sparkline`, `OverviewDonut`, `BudgetGauge`, `ChartLegend`, `ChartValues`; Chat 6)

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
  - Each chart has a screen-reader summary.
  - Series differ by more than color: solid against dashed, with a `ChartLegend`.
- **Progress bars** on the Overview are `SlimBar` (6 tall, pill ends) and `SegmentBar` (one 8-tall step per scheduled payment, 2 apart). Both are decorative; their row carries the words in its semantics label.
- **Charts are hidden while amounts are hidden.**

### Dashboard kit (moved from the Overview, Chat 7)

`kit/dashboard.dart` (`OverviewCard`, `AdaptiveRow`, `LabelAmount`, `NotAvailable`, `AmountsHidden`, `narrowAt`, `TouchArea`, `CardLink`, `MiniSegmented`, `ChipButton`, `QuickActions`, `IconBadge`, `ChangeLine`, `KpiTile`, `PairCard`, `SlimBar`, `SegmentBar`, `StatStrip`, `moneyColumnWidth`), `kit/dashboard_grid.dart` (`DashboardGrid`) and `kit/charts.dart` (`Sparkline`, `OverviewBarChart`, `OverviewLineChart`, `ChartLegend`, `ChartValues`). Their look is unchanged and they keep their names. Additions, all optional: `KpiTile.compactSpark` keeps the sparkline beside the value in a narrower tile; `SlimBar` and `SegmentBar` take a `track` color for the tinted focal card.

### Section page (`SectionPage`; Chat 7)

A page opened from a section. Windows starts with the title; Android starts with a 48-tall back row, because the app bar hides on pages. `status` sits with the title and `actions` end the heading. `maxWidth` narrows the page's column, title included, so a form's title lines up with the form. `RouteEscape` moved here with it.

### Deferred to section chats

- **Table and pager:** Chat 8 or 9.
- **Tabs:** built in Chat 6's owner review (`AppTabs`, above) for the Overview. Section screens keep their existing tab controls until their own chats adopt it.

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
| Provider schedule | Payment schedule | Debts |
| Early settlement | Log an early payoff | "Early payoff" as a noun |
| Provider charge / waiver / residual | Log a lender charge or waiver | |
| Classify payment | Break down a payment | |
| Outstanding balance | What you owe | |
| Unresolved payment clearing | Payment without a breakdown | |
| Final scheduled installment | Last scheduled payment | Still labeled as not a payoff date |
| Installment | Payment | Stored row names ("Installment 3") stay as recorded |

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
| Daily spending | Expense postings in `acceptedSnapshot`, grouped by date (`dailySpending` in `app/overview_data.dart`). `spendingOn(date)` reads the projected snapshot (it includes waiting work), so the Overview doesn't use it. | UI aggregation (approved, Chat 6) |
| Account balances | `snapshot.accounts`, `snapshot.balance(id, through:)` | Readable |
| Card debt and available credit | `LocalFinancialController.cardLiabilityAndCredit` | Readable |
| Total debt owed | `LocalFinancialController.debtTotal` | Readable |
| Per debt: next due date and amount, overdue installments and amount, status (Overdue / Due today / Due soon / Upcoming / Schedule not set), days until next, final scheduled due | `debtDueSummary`, `DebtDueSummary`, `compareDebtUrgency` (`lib/finance/debt_rules.dart`) | Readable |
| Everything due in a date range (debt installments, card statements, card installments, recurring bills) with dates and amounts | `financialReminderSources(snapshot, from, through)` (`lib/finance/planning_queries.dart`). Recurring bills appear only once their occurrences are generated. | Readable; the weekly/monthly calendar and overdue list come from this |
| Totals due this week or this month across all debts and bills | Sum of the rows above | UI aggregation (approved, Chat 6) |
| Recurring bills and their state | `recurringOccurrences` | Readable |
| Budget progress | `budgetSpending(snapshot, budget)` with the budget record | Readable |
| Savings set aside | `savingsReserved`, `eligibleSavings` (`lib/finance/planning_rules.dart`) | Readable |
| Balance forecast | `financialForecast` (as used by Reports) | Readable |
| Shared Expenses attention counts (to confirm, waiting for others, waiting for the group, rejected, changed sources) | `runtime.connected.needMyConfirmation`, `waitingForOthers`, `sharedPendingCount`, `sharedReviewCount`, `changedPrivateSources` | Readable |
| Who owes whom per group | `SharedRepository.groups` → `SharedGroup.positions()`. Loading the groups runs `store.reconcileShared()`, which writes, so the Overview doesn't use it. | Readable only by opening the repository (not on the Overview) |
| Life agenda (tasks, events, financial reminders) | `DurableLifeController.agendaWindow` (`lib/life/life_controller.dart`) | Readable |
| Sync state: label, waiting count, needs review, download complete, connected or on this device | `LocalSession.syncLabel`, `pendingCount`, `needsReview`, `complete`, `local` | Readable |
| Last synced time | `lastSyncedAt` is read only inside `connected_store.dart`; the UI can't reach it | New logic (sync layer; not built) |
| Amount privacy | `session.hideAmounts` | Readable; every dashboard value must respect it |
| Month-over-month spending (same day span) and what you owe at each month end | Postings in `acceptedSnapshot` (`SpendingComparison`, `debtBalanceByMonth`) | UI aggregation (approved, Chat 6) |
| Per-debt payoff progress (payments logged, scheduled amount left) | `DebtDueSummary` plus the schedule rows (`DebtProgress`) | UI aggregation (approved, Chat 6) |
| Debts: total owed (per-debt balances, equal to `debtTotal`), next payment, debts-only overdue and period totals | `DebtsSummary` (`lib/finance/debt_data.dart`) | UI aggregation (approved, Chat 7) |
| Debts: dues by calendar month, payments per debt, paid per month, paid down, payment rows, record names, what needs the user | `dueByMonth`, `debtPaymentRows`, `paidByMonth`, `paidDownBetween`, `installmentRows`, `recordLabel`, `debtTasks` | UI aggregation (approved, Chat 7) |
| Balance-based payoff progress, net position (available money minus what you owe) | Not defined | New logic (not built) |

## 9. Redesign roadmap (temporary)

Remove this section when the redesign is finished.

| Chat | Stage | Status |
| --- | --- | --- |
| 1 | Audit and design spec (this document) | Done |
| 2 | Tokens: color, spacing, radii, type, elevation, motion; light and dark | Done |
| 3 | Components and the debug-only component gallery; form help; dialogs; Google button | Done |
| 4 | App shell: navigation, profile entry, navigation state for the title bar | Done |
| 4b | Windows density: the compact scale in the theme and kit (§3) | Done |
| 5 | Windows custom title bar | Done |
| 6 | Overview dashboard (with Android's tappable date and calendar sheet, §2) | Done |
| 7 | Debts | Done |
| 8 | Money A: Accounts, Activity, transaction form | Planned |
| 9 | Money B: Cards, Planning, Reports, Import, Files | Planned |
| 10 | Shared Expenses A: groups, Bills, Payments | Planned |
| 11 | Shared Expenses B: Balances, People, Private review, History, Lifecycle | Planned |
| 12 | Life A: Calendar, Tasks, reminders | Planned |
| 13 | Life B: Learning, Books, Career | Planned |
| 14 | Profile and settings: connection, devices, backup and recovery, preferences, help | Planned |
| 15 | Onboarding: welcome, local setup, Google, restore | Planned |
| 15b | Android parity: app bar actions (Go to, bell), status row (tappable sync pill, Hide amounts), calculator in the + sheet (§2) | Planned |
| 16 | Consistency sweep (spacing grep, glossary, both themes, both platforms, 200% text) | Planned |
| 17 | Final review | Planned |

Each section chat:

1. Applies §4, §6 and §7.
2. Updates the tests whose text finders change.
3. Runs only targeted tests.
4. Ends with manual checks for the owner.
5. Gives its amount fields the calculator button with "Use result" (Android parity, §2).

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
| 2026-10-30 | Shell: the five destinations are unchanged; one "Profile and settings" entry (sidebar bottom on Windows, header button on Android); Hide amounts and a sync status pill stay in the shell. | Approved |
| 2026-10-30 | D1: Windows pages open inside the content area with the sidebar visible. Android pages are full screen, with the app bar and dock hidden. | Approved |
| 2026-10-30 | D2: Overview links switch to the section and tab instead of pushing a copy of the section. | Approved |
| 2026-10-30 | D3: Android Back from a destination other than Overview goes to Overview first. | Approved |
| 2026-10-30 | D4: Forward only redoes destination and tab changes, never pages. | Approved |
| 2026-10-30 | D5: the rail at 600–999 doesn't expand. The sidebar from 1000 up is collapsible, and the choice isn't saved after the app closes. | Approved |
| 2026-10-30 | D6: on a narrow Android screen (under 360 wide) or at 150% text and up, the dock keeps all five icons and hides the labels, instead of one "Navigation" button. | Approved |
| 2026-10-30 | D7: the + sheet on Android and the "New" menu on Windows use the glossary labels. Route names keep the old action keys. | Approved |
| 2026-10-30 | D8: the kit Tabs and page header components move to the first section chat (Chat 6). | Approved |
| 2026-10-30 | D9: Chat 4 adds Alt+←/→ and the mouse back and forward buttons. Chat 5 adds the on-screen back and forward buttons. | Approved |
| 2026-10-30 | D10: the logo stays in the sidebar for now; Chat 5 decides whether it moves to the title bar. | Approved |
| 2026-10-30 | A modal may have no primary action when its rows make the choice (Cancel only). Sheets open on the root navigator. | Done |
| 2026-10-30 | Owner review: the shell header gets a 12 bottom gap, and Windows header actions center on the title. | Approved |
| 2026-10-30 | The Windows sidebar is redesigned as a floating card (owner references). The profile card moves to the top with the sync state and a profile menu. Go to (Ctrl+K) is added. Sections expand into their tabs (an accordion with tree lines; flyouts on the rail). A Needs attention group shows existing counts. Hide amounts, theme and Help move to the footer. | Approved |
| 2026-10-30 | Selected sidebar items use a neutral `subtle` fill and a semibold label; only the icon is purple. | Approved |
| 2026-10-30 | Glass behind the sidebar is the Windows Mica material, added in Chat 5 with the runner work. Until then the card is solid. | Superseded (Chat 5: Mica deferred) |
| 2026-10-30 | New stays in the shell header (Ctrl+N), not in the sidebar. | Approved |
| 2026-10-30 | A Needs attention row for overdue debts (a new UI count over `debtDueSummary`). | Rejected for the sidebar; overdue debts go on the dashboard (Chat 6) |
| 2026-10-30 | Owner review 2: the sidebar matches the reference sizes. Labels are 13 / 18 and icons 16. Rows are 36 and tab rows 30, below the 40 pointer target, as Windows 11 navigation allows; this is an exception for the sidebar only, and it still meets WCAG 2.2's 24 px target minimum. Text stays 13 rather than the reference's 11 for legibility. | Approved |
| 2026-10-30 | The sidebar is flush with the window's left, top and bottom edges, rounded on the right only, and collapses with a round handle on its edge. | Superseded (next row) |
| 2026-10-30 | Owner review 3: the sidebar has square corners with a right hairline. The logo is centered (kept, not removed, per the brand rule). A separator splits Overview from the sections. Rows are 4 apart and tab rows 32. Highlights and the profile card use `Radii.nav` 6. | Approved |
| 2026-10-30 | Chat 5 layout changes: no separate full-width title bar. The sidebar and content run to the window's top edge. The content's top row holds back/forward, the breadcrumb, drag space, New and the window controls. The sync pill moves to the sidebar's profile card. This replaces the "one bar across the full window width" rule. | Superseded |
| 2026-10-29 | Totals added up across debts and bills per week or month for the dashboard. | Approved (Chat 6: period and overdue totals on the dues card) |
| 2026-10-29 | Rewording user-facing messages that live in domain or rule files. | Needs approval (per section chat) |
| 2026-10-30 | Owner review 4, after a reference: Windows gets an app bar (56, `surface`, divider below, level with the sidebar's logo row) with a chevron breadcrumb, the Go to field (moved from the sidebar) and New. The collapse control is a panel icon beside the logo (the round edge handle is removed). The sidebar footer adds Settings. Its theme control is a two-option Light \| Dark switch that reflects System; System stays in Profile and settings. | Approved |
| 2026-10-30 | Chat 5's chrome is the app bar itself (56), with the window controls at its right end; the logo row and the app bar's empty space are the drag areas. | Superseded (next row) |
| 2026-10-30 | Chat 5: a separate custom title bar across the full window width, above the sidebar and the app bar. It has back/forward, drag space and window controls, plus more (sync pill, Go to and toggles proposed; confirmed in Chat 5). It has no logo or app name; the logo stays in the sidebar. This also supersedes the earlier "sidebar and content run to the top edge" revision. | Approved |
| 2026-10-30 | Owner review 5: the rail's section flyout is structured like the expanded sidebar (a header with the icon and name, then tabs on a tree line with the current tab highlighted). The collapse toggle has open and closed glyph states. | Approved |
| 2026-10-30 | The app bar's New button is compact (32 tall, a 16 icon, a 13 label, `Radii.nav`), matching the Go to field. | Approved |
| 2026-10-30 | Windows uses a compact scale one step below Android for type, controls, icons, rows and card padding, with tighter corners (controls 6, cards 10, overlays 12). It is applied app-wide through the theme and kit in its own stage after Chat 4. This changes the Chat 2 rule "sizes are the same on Windows and Android" for Windows. | Approved |
| 2026-10-30 | Windows density implemented (4b): `Density`, `SalapiyaTheme.build(platform:)`, and context-aware radii, card padding and row sizes. The sidebar's rail buttons keep 40 (`navRailButton`). Menu items are 36 on Windows. Android is unchanged. Hard-coded literals in older screens wait for their section chats. | Done |
| 2026-10-30 | Chat 5 title bar, as recommended in the plan: a custom native frame in the runner (no windowing package; `window_manager` and `bitsdojo_window` can't route `HTMAXBUTTON` to a Flutter-drawn button, so Snap Layouts wouldn't appear). Go to moves into the title bar (centered, 320). The sync status moves from the profile card into the title bar and opens the sync details. Hide amounts stays out of the title bar. | Approved |
| 2026-10-30 | Mica is deferred: Flutter's Windows engine draws an opaque surface. The title bar and the sidebar stay solid. This supersedes "Mica added in Chat 5". | Approved |
| 2026-10-30 | Title bar colors: `windowControlHover` becomes `text` at 6% (it was `subtle`, nearly invisible on the bar); new `windowControlPressed` (`text` at 4%), `windowClosePressed` (the close red at 90%), `Space.goToWidth` 320 and the `CaptionButtons` OS constants. | Approved |
| 2026-10-30 | The app's navigator and the shell's content navigator are wrapped in semantics containers, so a route's modal barrier no longer hides the title bar, the sidebar and the app bar from screen readers (found while testing Chat 5; the sidebar issue dates from Chat 4). | Done |
| 2026-10-30 | Owner review of the Chat 5 title bar (the left side felt empty). The bar's left segment, as wide as the sidebar, shows the date and clock and opens a month calendar; back/forward start the content column. Right of Go to: a notifications bell, a quick calculator and the Hide amounts toggle, then the sync status. | Done |
| 2026-10-30 | The bell takes over the sidebar's Needs attention group, and the title bar's toggle replaces the sidebar footer's Hide amounts row. Their old place in the sidebar becomes Quick create: the current section's first three create actions as a full list (the Windows counterpart of Android's + button). Ctrl+H toggles Hide amounts. | Done |
| 2026-10-30 | Rejected for the sidebar: Upcoming, Accounts at a glance, Recent places, Pinned places (dashboard content), and a Groups list (too busy with Quick create). A group switcher may suit the Shared Expenses page (Chat 10). | Rejected |
| 2026-10-30 | Owner review 2 of the title bar's left side: the sidebar's column runs unbroken to the window's top (the bar's line stops at it), the clock (centered in the column, at the owner's request) shows the time emphasized and the date in `secondary`, and back/forward are neutral and sit just past the sidebar's edge. | Done |
| 2026-10-30 | Icon buttons use `secondary` when disabled, app-wide; the theme had painted them `primary` in every state, so disabled ones looked clickable. | Done |
| 2026-10-30 | Android parity plan for the title bar's features (§2): app bar with Go to, bell and profile; status row with a tappable sync pill and the Hide amounts eye; tappable Overview date with a calendar sheet; calculator in the + sheet, then in amount fields. Split across Chat 6, the section chats and a new 15b stage. | Approved (planned) |
| 2026-10-30 | Overview widgets (Chat 6): the required dues card with its calendar, overdue rows and payoff progress, plus every optional widget proposed (Available money, this month's tiles, category bars, daily spending, compared with last month, what you owe over time, accounts, budgets, Shared Expenses counts, Life next up, recent activity, insights). Quick actions are left out, because Quick create, New and the + button already cover them. | Approved |
| 2026-10-30 | Date rules for the dashboard: "This week" runs Monday to Sunday (ISO, as the recurrence grammar), "This month" is the calendar month, and period lists start today, with anything earlier only under Overdue and no lookback limit. | Approved |
| 2026-10-30 | Dues and debt progress read the Debts screen's records (with waiting work), so both screens agree. Money values and charts stay on accepted history. | Approved |
| 2026-10-30 | The Due today and Due soon labels (`debtDueStatus`) apply to card statements, card installments and recurring bills too. | Approved |
| 2026-10-30 | Display derivations in `app/overview_data.dart`: dues grouping and day counts, payments logged and scheduled amount left, daily spending, month-over-month over the same day span, and month-end totals of what you owe. | Approved |
| 2026-10-30 | Charts use `fl_chart` 1.3.0 (offline, MIT, themable), with no animation, no money on axes, a spoken summary and exact values under "Show values". | Approved |
| 2026-10-30 | `PageHeader` is added to the kit. `SurfaceCard` and `MetricTile` gain `accent` for the one tinted focal card. The Tabs component moves to Chat 8. | Done |
| 2026-10-30 | Not built: balance-based payoff progress, net position, "last synced", and group balances on the Overview. Each needs logic or a side effect outside the UI. | Rejected for Chat 6 |
| 2026-10-30 | Owner review 1 of the Overview (reference dashboards): the "Tiles + hero" layout on a 12-column grid (KPI tiles with sparklines and a vs-last-month change, a wide spending chart beside the dues, 2/3 + 1/3 pairs). | Approved |
| 2026-10-30 | The Overview gets underline tabs (Summary, Spending, Debts & Dues, Accounts & Activity), built as the kit's `AppTabs`. This reverses moving Tabs to Chat 8 for the Overview; section screens still adopt it in their chats. | Approved |
| 2026-10-30 | Compact sizes on the Overview only: `titleSmall` card titles, `MoneySize.tile` values, small link actions, and 32-tall segmented controls and chips. Android keeps 48 hit areas through transparent space. The rest of the app keeps the approved sizes. | Approved |
| 2026-10-30 | New Overview widgets: quick actions (the shell's first four New items), a category donut, account cards with 30-day sparklines and a budget gauge. Also added: largest expenses this month, and payoff bars with a step per payment. | Approved |
| 2026-10-30 | Display derivations added to `overview_data.dart`: closing balance by day, income by day, change and share in whole basis points (rounded toward zero, shown with one decimal), the top-five-and-Other category shares, budget totals across limits, and the largest expenses. | Approved |
| 2026-10-30 | The demo build shows the new Overview, filled by a sample profile replayed in memory through `planLocal`, ending on the demo account balances. The previous demo Overview layout is retired; its files (`workspace_overview.dart`, `overview_wallet.dart`, `overview_agenda.dart`) are deleted with the owner's approval. | Done |
| 2026-10-30 | Owner review 2 of the Overview: a stat strip under the spending and owed charts (they left empty space beside taller cards); "By debt" in What you owe over time; a Calendar | List view on Due and overdue, the list being a screenshot-ready table of the period's items with totals; table amount columns measured to one width, fixing misaligned Category and payoff columns; payoff bar steps were drawn 0 tall and now show. | Approved |
| 2026-10-30 | Owner review 3 of the Overview: quick actions right-aligned to the content edge on the title row; 16 above "Show values"; the Spending tab's category and budgets cards center their content when the other card is taller; the dues card's Calendar | List moves to a settings icon menu in its top-right corner. | Approved |
| 2026-10-30 | Owner review 4: the category donut's sections and legend rows are selectable by hover or tap, showing the category's name, share and amount in the hole. | Approved |
| 2026-10-30 | Android drops the Overview's quick actions; the + button above the dock already has them. Windows keeps them. | Approved |
| 2026-10-30 | Tab names "Debts & Dues" and "Accounts & Activity" (capitalized at the owner's request). KPI tiles reserve the tallest label's height so values line up. | Approved |
| 2026-10-30 | Android's Overview header is one compact row: the date (calendar icon, `titleSmall`) and a dues pill that opens Debts & Dues, with 4 to the tabs. | Approved |
| 2026-10-30 | Every section chat from Chat 7 follows the Section screen standard (§2), taken from the Overview: the same page anatomy, grid, cards, data display, sizes, shareable list views, demo data and tests, with content chosen per section. Data screens use the compact Overview sizes. Forms, editors and dialogs are scaled down too (about one step), with a readability floor: values and body text at least `bodyMedium`, nothing below 12. The first chat that redesigns a form applies it through the theme and kit after the owner reviews a sample. Overview building blocks move to the kit when another section first needs them. | Approved |
| 2026-10-30 | Debts (Chat 7): tabs Summary · Schedule · Payments · History; Your debts as the hero beside Due next; the shareable list shows all dues with a Debts-only choice and can open as a page; Upcoming by month and Needs your input; Debts' tabs in the sidebar and Go to; debt details as one page. | Approved |
| 2026-10-30 | Log a debt payment asks for the essentials and fills the rest of the same command from the answers, with the rest under "More details". A row's "Log payment" prefills the debt, that payment and what's left on it, proposing "All of it lowers what I owe"; the user confirms at Review. Corrections keep every field. | Approved |
| 2026-10-30 | Prefilled forms keep their own draft: the draft key includes the debt and the proposed payment, because a saved draft replaced `initial` values. | Done |
| 2026-10-30 | The Debts display states (Closed without a schedule, Settled without a schedule, Schedule finished) live on `DebtProgress`, so the Overview shows them too. Due rows carry the debt's name, not its schedule record's. | Done |
| 2026-10-30 | The Android Overview header's pill drops under the date when large text can't hold both (an overflow at 320 wide and 200% text). | Done |
| 2026-10-30 | The compact form scale in §3, from the owner's review of a sample: Android controls look 40 with a 48 hit area, typed values `bodyMedium`, labels 12. Applied as a scope on the shared editor and Update amounts, not app-wide, so Money's Log expense, income and transfer stay larger until Chat 8. | Approved |
| 2026-10-30 | A form's title and step line sit in the form's column, starting at the card's left edge (owner review of the sample). | Approved |
| 2026-10-30 | `NativeFinanceEditor` shows no popups: errors appear on their field, or in a notice above the form when no field can show them (§6). Every date in it is a `DateField`, so typed dates are gone from `finance_screen.dart`. | Done |
| 2026-10-30 | Owner review of the Debts cards: a list starts at the top of its card, under the header, and closes with `ListEnd` ("That's everything", or "N more on Schedule"). `OverviewCard(centered: true)` is for charts and figures, not lists. | Approved |
| 2026-10-30 | Owner review of form errors: fields for one kind of data refuse anything else as it's typed, with a small note at the field. This narrows §6's "No error pop-ups" to no error dialogs. Applied in the kit and in `FinancialEditor`. | Approved |
| 2026-10-30 | Errors after submitting go on the field they're about, in red. A table in the editor maps rules that name no field to theirs, so no rule file changes. Going below zero marks the account and says what it holds; the rest keep the rules' own wording until that's approved. | Approved |
| 2026-10-30 | Account pickers show each account's balance, and warn before saving when the amount is more than the account holds. | Approved |
| 2026-10-30 | Forms handle the sync rule themselves instead of showing it as an error: Save syncs first, a sync that brings new records asks for another look at Review, and a failed sync stays on Review with "Sync and save". A debt added with a schedule syncs before saving the schedule. The rule itself is unchanged. | Approved |
