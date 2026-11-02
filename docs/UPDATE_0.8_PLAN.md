# Salapiya 0.8 update plan

Branch: `update/0.8` (from `main` at the `0.7.0` release, 3 November 2026).

This is the working document for the next big update. Right now it holds my ideas and what I already know about each one. A planning session turns them into a design and a build order (the milestone list in §5). Each milestone is then built in its own session. This document stays the source of truth for the update until it ships. After that, its decisions move into the main docs and this file goes to `docs/archive/`, the same way the redesign roadmap did.

The ideas below aren't final. The planning session can solidify them, push back on them, and suggest things I haven't thought of.

## Contents

- [1. Goals](#1-goals)
- [2. Ground rules](#2-ground-rules)
- [3. Ideas](#3-ideas)
- [4. Open for suggestions](#4-open-for-suggestions)
- [5. Milestones](#5-milestones)
- [6. Decision log](#6-decision-log)

## 1. Goals

- Make the things I already do every month less of a chore: recurring budgets, groceries, meal prep.
- Turn a Shared Expenses group into a real shared space for a household or any group doing something together, not just a place to split bills. Right now my brothers and I plan our house renovation in Google Sheets; I want that to live in the app.
- Clean up the parts of the app that grew awkward: quick actions on Android, where Profile and Settings live, where reminders live, landscape on Android, moving between tabs, and editing records after they exist.
- Make signing in and opening the app feel safer and more like one app: Google sign-in inside the app, "Continue to Salapiya", and an optional app lock.
- Make updating easy: the app tells me about new releases and, if possible, installs them itself.
- Keep everything consistent with the design system, so the new parts look like they were always there.

## 2. Ground rules

These come from the existing docs and still apply to everything in this update:

- [CLAUDE.md](../CLAUDE.md) working rules: targeted tests only, minimal changes, no commits without my approval, manual checks at the end of UI work.
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) for every screen and component: theme tokens only; light, dark and high contrast; Windows and Android share components. New components go into the kit and the component gallery.
- The glossary in DESIGN_SYSTEM §7: Salapiya **tracks** money activity that happens elsewhere. It never lends, borrows, pays or moves money. That matters for group budgets and contributions; they're plans and records, not payments.
- [DOMAIN_RULES.md](DOMAIN_RULES.md): exact money in centavos, corrections that keep history, no guessing. Where an idea here conflicts with a rule, the plan says so and proposes the rule change for my approval. Rules don't change quietly.
- Offline first, profile isolation, and non-destructive migrations ([DATABASE.md](DATABASE.md)). Anything shared with a group also needs server-side changes (Supabase tables, RLS, PowerSync streams in `services/salapiya/p0/`), and the hosted backend is on a free tier ([ARCHITECTURE.md](ARCHITECTURE.md), [OPERATIONS_AND_RELEASE.md](OPERATIONS_AND_RELEASE.md)).
- Milestones are named by what they build ("Recurring budgets", "Groceries"), never by session number.

## 3. Ideas

They're in no particular order. Working out the order is part of the plan (§5).

### 3.1 Recurring budgets

**What I want.** When I create or edit a budget, I can make it repeat every month, every week, or on a schedule I set, for example every payday. My "Food Allowance" should reset each month (or when my pay comes in) without me creating a new budget every time.

**What's there now.** A budget has a category, a limit and one period, from a start date to an end date (stored as `endExclusive`). See `lib/finance/planning_*.dart` and `lib/features/planning/`. DOMAIN_RULES V2-C rejects any overlap for the same category, including archived budgets, and says there's no rollover.

**To settle.**
- How a repeating budget relates to the one-period form: a schedule replacing the end date, or a series of periods made from one definition.
- Whether "when my paycheck comes" ties to a recurring income from Planning, or stays a simple custom interval.
- How it fits the overlap rule (consecutive periods are fine, overlapping ones aren't) and whether unspent money ever rolls over. Rollover would be a rule change.
- What history looks like: each past period keeps its own result.

### 3.2 More detailed notifications on Windows

**What I want.** The notifications on Windows should show much more detail.

**What's there now.** Reminders show as Windows toasts (`lib/life/native_notifications.dart`), and the app has its own attention items and bell in the shell (`lib/app/shell_tools.dart`, `title_bar_tools.dart`).

**To settle.** Which one I mean, or both: the Windows toasts (more text, what it's about, actions such as opening the item or snoozing), and/or the in-app notification panel. Keep the privacy rule that notifications don't expose sensitive amounts unless I allow it.

### 3.3 Group admins in Shared Expenses

**What I want.** The person who created a group is its main admin. They can make other members admins too. Admins can confirm a payment on behalf of the person who received it. In my household, one brother says "yes, I got it" but never taps confirm, and it blocks everything.

**What's there now.** Groups have an owner and members (`lib/shared/`, `lib/features/finance/`, server SQL in `services/salapiya/p0/supabase/`). A reported payment stays pending until the recipient confirms it (DOMAIN_RULES Shared Expenses §28–30). The owner can only record a receipt for a manual (unregistered) participant, and that record notes it wasn't confirmed by the recipient (§36).

**To settle.**
- This changes a core rule, so it needs a clear design: a separate kind of confirmation, "confirmed by an admin for Brother 1", that shows who confirmed it and that the recipient didn't, can be disputed by the recipient, and appears in history.
- Roles and permissions: main admin vs admin, who can promote or remove admins, and what happens when the main admin leaves (the existing owner-handoff rules).
- Server authorization: the check must happen in the database, not just the app.

### 3.4 Groceries (Life)

**What I want.** A Groceries area in Life: shopping lists I can tick off as I buy things, so I can see what's bought and what isn't, plus anything else that helps when I'm going grocery shopping.

**To settle.** Lists and items (name, quantity and unit, category or aisle, notes, an estimated price), checking items off, reusing a list or a "usual items" list, and whether finishing a trip can log the expense in Money. If it does, that has to go through the normal expense form, never a silent posting.

### 3.5 Meals, meal prep and calories (Life)

**What I want.** A calorie tracker and meal prep plans. For example, I make a meal prep plan for a diet dish, list its ingredients with amounts (1 kg of something) and other useful notes, and when I'm ready there's a quick way to add those ingredients to a groceries list.

This idea isn't solid yet. The planning session should design how it works and how it connects to Groceries and the rest of the app:
- recipes or dishes with ingredients;
- meal prep plans (which dishes, how many portions, which days);
- a calorie and nutrition log;
- "add ingredients to a grocery list", which merges amounts that are already on the list;
- where nutrition numbers come from. They'd be entered by hand, since the app has no online food database and stays offline.

### 3.6 Groups as a shared space

**What I want.** Groups do more than split bills. Shared Expenses keeps everything it does today, but probably moves under something bigger. For our renovation we need:
- a shared budget and a plan for how much each person contributes, separate from personal budgets;
- shared lists or tasks of what we want: appliances, furniture and so on, with prices and who's handling it;
- whatever else a household or a group with a project needs.

It isn't only for renovations. It should work for any group project or household.

**To settle.**
- Where this lives in the app (see 3.8) and what Shared Expenses becomes inside it.
- Shared budgets and contribution plans that track what people put in, without the app paying or holding money.
- Shared lists and tasks, and how they link to bills when something is actually bought.
- Which parts sync to the group. That means new server tables, RLS, streams, and free-tier limits.
- Suggestions for other group tools that are actually useful.

### 3.7 Android quick actions

**What I want.** The Android + button should offer what each section actually has. In Money, for example: add a budget, add a savings goal, add a card, import a file, and the rest. If that's too many, group them into categories that open their own choices, or suggest a better pattern if that would be clumsy for a normal user.

**What's there now.** The + sheet in the Android shell (`lib/app/shell.dart` and the Overview quick actions), with the calculator added during the redesign.

### 3.8 How the app is organized

**What I want.** With this much new, the top-level sections might need to change. The plan should decide whether and how: for example where Groceries, meals and groups sit, and whether Overview needs another tab for them.

**What's there now.** Five sections: Overview, Money, Debts, Shared Expenses, Life (`AppDestination` in `lib/prototype/scenarios.dart`). Overview has Summary, Spending, Debts & Dues, Accounts & Activity.

### 3.9 Android landscape

**What I want.** In landscape, the + button sits next to the floating navigation bar, and the two are centred together as one group, not with the + pushed to the edge.

### 3.10 Profile picture

**What I want.** I can set a profile picture, with sensible limits on file size, type and dimensions.

**To settle.** Where it's stored (local only, like attachments today, or synced), what other group members see, and how it's included in backups.

### 3.11 Profile and Settings

**What I want.** Settings is in the sidebar, and there's also "Profile and settings" when I click my profile name on Windows. Sort this out so there's one clear place for each thing.

### 3.12 Swiping between tabs on Android

**What I want.** Inside a section such as Money, I can swipe left or right to move between its tabs. Swiping doesn't move between sections.

**What's there now.** Section tabs are the app's own (no `TabBarView`), so swiping has to be added to that, and it mustn't fight with horizontal scrolling inside a tab (charts, tables, the week strip).

### 3.13 One-time debt payments

**What I want.** When I schedule a debt, I can say it's paid back in one go, for example in a month, instead of setting it up as monthly with a single payment. I'm not sure a separate option is better than "monthly, 1 payment", so the plan should decide.

**What's there now.** A debt schedule's frequency is weekly, monthly, yearly or custom (every N days), in `debtScheduleFrequencies` and `validateDebtCadence` in `lib/finance/debt_rules.dart`. The explicit schedule rows are the real record; the frequency only describes them.

**To settle.** A "one payment" choice (a single due date and amount) vs keeping the existing options and making the one-payment case easier to pick. Either way, nothing about how payments and dues work changes.

### 3.14 Where reminders live

**What I want.** Reminders sit in Life right now, but they cover more than events and tasks: debt dues, card payments and other money things. They might belong somewhere else.

**What's there now.** Life has a Reminders tab (`lib/life/reminders_tab.dart`, `reminder_page.dart`), and Calendar and Career link to it. Money and debt reminders show there too.

**To settle.** Where reminders go (their own place, the bell or notification panel from 3.2, or Overview), how each section still shows its own upcoming items, and how this fits the new organization in 3.8.

### 3.15 Google sign-in that feels like part of the app

**What I want.**
- On Android, signing in with Google happens inside the app instead of switching to the browser.
- On Windows, if it's possible, the browser tab closes itself after I pick an account. If it can't, leave it.

**What's there now.** Sign-in uses Supabase's OAuth flow in the external browser (`signInWithOAuth` with `LaunchMode.externalApplication` in `lib/p0/auth_runtime.dart`), and the browser comes back to the app through the `dev.salapiya.p0://auth/callback` link.

**To settle.**
- **Android:** the native Google account picker (Credential Manager or Google Sign-In handing an ID token to Supabase) vs an in-app browser tab. The native picker likely needs a new package and an Android OAuth client in Google Cloud.
- **Windows:** whether the page the browser lands on can close itself (browsers usually only let a script close a tab it opened), or at least say "You can close this tab now".
- Both keep the existing PKCE and session protections, and the existing accounts keep working.

### 3.16 "Continue to Salapiya" on Google's sign-in screen

**What I want.** Google's screen says "continue to uxnyxhwqshqpvinvopiv.supabase.co". It should say "Continue to Salapiya", but only if I don't have to pay for it. If it needs a paid plan, leave it.

**To settle.** Find the free way, if there is one. A custom domain on Supabase is a paid add-on. Signing in with Google's own ID token (the native picker in 3.15) usually shows the app name from the Google Cloud consent screen instead of the Supabase domain, which might solve this for free at least on Android. Check what Windows would show, and what the consent screen needs (app name, logo, possibly Google's verification).

### 3.17 Editing debts and other records

**What I want.** After creating a debt, I can change its name or its type. If that's already possible, it's too hidden; it should be easy to find, for example in the ⋯ menu. The same goes for other records that are hard to edit.

**What's there now.** The debt's ⋯ menu (`debt-more` in `lib/finance/debt_screen.dart`) has Update amounts, Break down a payment, Log a lender charge or waiver, Log an early payoff and View record. It has no rename and no type change. Financial records change through corrections that keep history (DOMAIN_RULES), so an edit here has to be a correction, not an overwrite.

**To settle.** Which details of a debt can change after it's created (name, lender, type, notes) and which can't without a full correction. Put Edit in the ⋯ menu of each record type. List the other records (accounts, cards, budgets, goals, groups, Life items) that are hard to edit today.

### 3.18 App lock

**What I want.** I can turn on a PIN to lock the app, so it's more secure.

**To settle.**
- When it locks (on launch, after time in the background) and what's hidden until it's unlocked, including the preview in the app switcher.
- How the PIN is stored safely (never in plain text, with limits on attempts).
- What happens if I forget it, without weakening the existing encrypted profile and recovery rules.
- Whether Windows Hello or fingerprint can unlock it too. That would probably need a package such as `local_auth`, which follows the UI package rule.

### 3.19 Check for updates inside the app

**What I want.** Starting with the release after this update, the app checks GitHub Releases for a newer version and tells me when there is one. If it's possible, I can also download and install the update from inside the app, so publishing a release on GitHub is all I have to do. I don't know yet how this should work, so the plan should work it out.

**What's there now.** Updates are manual: download the new Windows installer or APK from the release and install it over the old one. The installers are on [GitHub Releases](https://github.com/RAbnza/salapiya-app/releases) (from `0.7.0`), with `SHA256SUMS.txt`. The Windows installer is unsigned. The APK is signed with my existing release key, so a newer versionCode updates in place. OPERATIONS_AND_RELEASE §16 says "do not build a custom updater before demonstrating a need", and the accepted limitations list a custom updater as out of scope. This idea changes that decision.

**To settle.**
- **Checking:** where the app reads the latest release from (the public GitHub API, which has rate limits without sign-in), how often it checks (on launch, once a day, manually from Help), and that it only checks when online and never sends anything about me or my data. It needs a setting to turn it off.
- **Telling me:** where the notice shows, what it says (version and the release notes), and that it never interrupts something I'm in the middle of.
- **Android:** downloading the APK and handing it to Android's installer. That needs the "install unknown apps" permission. Android checks that the signature matches, so only my signed builds can update it.
- **Windows:** downloading the installer, checking it against `SHA256SUMS.txt` before running it, then closing the app and running setup over the existing install. Check whether an unsigned installer makes this awkward, and what SmartScreen does.
- **Safety:** only downloads from this repository's releases, over HTTPS, with the hash checked. It never downgrades, and it suggests a backup before installing. If anything fails, the current install stays as it is.
- **Releases:** the naming and version conventions the checker relies on (tag `salapiya-vX.Y.Z`, asset names, versionCode), written down so future releases follow them.
- Whether it can be built entirely in this update, or the check ships first and in-app install later.

## 4. Open for suggestions

The planning session should add ideas that fit the goals in §1, mark them as suggestions, and leave them for my approval. Good places to look: groceries and meals, group tools, and anything that makes everyday logging faster.

## 5. Milestones

*To be written by the planning session.*

Each milestone gets a name for what it builds and a short scope, and is built in one working session, in stages if it's big. The table keeps the order and the status:

| Milestone | Scope | Depends on | Status |
| --- | --- | --- | --- |
| | | | |

Each milestone's section below the table covers:
- what it builds and why it comes at that point;
- the screens, components and files involved;
- local data and migrations, and server changes if anything is shared;
- rule changes that need my approval;
- the targeted tests and the manual checks for me.

## 6. Decision log

| Date | Decision |
| --- | --- |
| 2026-11-03 | Started the 0.8 update on `update/0.8`. Ideas captured in §3; the plan comes next. |
| 2026-11-03 | Added ideas 3.13–3.18: one-time debt payments, where reminders live, in-app Google sign-in, "Continue to Salapiya", editing debts and other records, app lock. |
| 2026-11-03 | Added idea 3.19: check for updates (and, if possible, install them) from GitHub Releases inside the app. This reverses the "no custom updater" decision in OPERATIONS_AND_RELEASE §16 once the plan is approved. |
