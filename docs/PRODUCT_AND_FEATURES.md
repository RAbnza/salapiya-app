# Product and features

## Contents

- [Salapiya — Product Revision and Windows/Android Migration Blueprint](#salapiya--product-revision-and-windowsandroid-migration-blueprint) (from `docs/SALAPIYA_PRODUCT_AND_PLATFORM_BLUEPRINT.md`)
- [Project Vision and Feature Blueprint](#project-vision-and-feature-blueprint) (formerly `docs/reference/PROJECT_VISION_AND_FEATURE_BLUEPRINT.md`)
- [V1 user guide](#v1-user-guide) (formerly `docs/reference/V1_USER_GUIDE.md`)
- [Adaptable Trackers workflows](#adaptable-trackers-workflows) (formerly `docs/reference/V3_TRACKER_WORKFLOWS.md`)

## Salapiya — Product Revision and Windows/Android Migration Blueprint

**Tagline:** Your money, on your terms.  
**Name inspiration:** Salapi + Laya.  
**Repository:** `RAbnza/salapiya-app` (renamed from `RAbnza/Personal-Management-Platform` on 3 November 2026)  
**Document version:** 1.0  
**Decision/documentation date:** October 19, 2026 (Asia/Manila)  
**Current status (29 October 2026):** Salapiya `0.6.1+8` is **APPROVED FULL RELEASE** for a small private group of users; development **COMPLETE**. [Final release and project closure](OPERATIONS_AND_RELEASE.md#salapiya--final-release-and-project-closure) and section 26 override the older gate and release-blocker wording for that audience and scope. I've kept the earlier evidence and the tests I never ran.
**Inspected web baseline:** `b721b0c6ef4c102a351e30df107b8f9b86ede588`, the merged M6 redesign acceptance. Local HEAD and GitHub `main` matched when I checked them for this document.

### 1. Purpose, authority, and approval boundaries

This is the plan I approved for turning the existing app into Salapiya: a personal-management app for Windows and Android that's mostly about money. It works offline, can sync through a Google connection if you want, and has Shared Expenses and a useful Life area.

I settled the new scope after the discovery workshop and replaced the old working name with **Salapiya**. The tagline is **Your money, on your terms.** The earlier name, and my earlier idea of holding back the advanced Money features, are both dropped. Renaming the product doesn't rename the repository.

This document sets a direction. It doesn't by itself approve building anything, provisioning cloud services, spending money, deploying, destructive database work or deleting the existing app. Each later piece of engineering work should say which milestone it belongs to. A dependency gate means "produce the evidence before going further"; it doesn't mean the technology has already passed.

#### 1.1 Relationship to existing documentation

Read this together with:

- [Product vision and feature blueprint](#project-vision-and-feature-blueprint).
- [System architecture](ARCHITECTURE.md#system-architecture).
- [Database architecture](DATABASE.md#database-architecture).
- [Design system and visual guidelines](archive/DESIGN_SYSTEM_pre-redesign.md#design-system-and-visual-guidelines).
- [Original development handoff](archive/web/PROJECT_DEVELOPMENT_HANDOFF.md).
- [V2 development handoff](archive/web/V2_DEVELOPMENT_HANDOFF.md).
- [V3 development handoff](archive/web/V3_DEVELOPMENT_HANDOFF.md).
- [Platform-transition ADR 0005](adr/0005-v3-scope-and-platform-transition.md).
- [M6 redesign acceptance](archive/web/REDESIGN_M6_ACCEPTANCE.md).

This plan replaces the older documents only on these points: the product name, the move to a new platform, local and online identity, sync, navigation, what's in the launch and what's deferred, and the native adaptations I describe. Everything else stays as those documents say: what the financial records mean, who owns what, how corrections keep their evidence, and how reports come from source records. Only a later decision I record changes those.

The web app still follows its own implementation contracts. Nothing here makes its PostgreSQL security, Better Auth or server transaction boundaries optional before it's replaced.

Some older introductions still say the redesign milestones haven't started. The M2–M6 records and the merged code are what show the web app's real state. Old instructions to stop before a later milestone were about those earlier tasks; they aren't a reason to ignore the scope I've now approved.

#### 1.2 Decision vocabulary

| Label | Meaning |
| --- | --- |
| Approved requirement | Something I chose or accepted in the workshop. It stays unless I record a later decision that changes it. |
| Selected baseline, gated | A technology or architecture I picked for planning. It has to prove the named compatibility, correctness and cost conditions before I build much on it. |
| Proposed implementation detail | A concrete engineering starting point, not a product change I've approved on its own. Work it out through design and evidence inside the approved scope. |
| Deferred | Deliberately left out of the first release. Don't quietly move it into launch work. |
| Open gate | A technical or operational question that isn't settled yet, with a clear way to close it. Don't invent a passing result. |

### 2. Product definition and intended users

Salapiya helps people record and understand their money, manage debts and cards, plan what they've committed to and settle shared expenses, while keeping their personal information under their own control. Its Life area ties in personal commitments, tasks, learning, reading and job applications.

The first users are a small private group, maybe extended to a few friends, and the first distribution is private. It isn't a public SaaS launch, a payment service, a bank-connected aggregator or a general no-code platform.

#### 2.1 Approved product priorities

1. Every financial feature that already exists is part of the first complete release.
2. Expense tracking, Shared Expenses and Debts are the main use cases.
3. Most everyday work has to work with no internet connection.
4. When connected, the same person's Windows and Android installs sync their private records as well as shared ones.
5. Each install has one active local profile; I'm not planning a profile switcher.
6. Creating a local profile doesn't need Google or a cloud account.
7. Connecting Google gives you one identity across devices, sync and collaboration.
8. Life has to have useful non-financial workflows at launch.
9. Features mean the same thing and are reachable on both Windows and Android; layouts and interactions adapt to each.
10. I prefer maintained tools and operations a solo developer can handle. A small, trusted group is still no excuse for weak data isolation or inaccurate financial sync.

I can build in small vertical milestones and private test builds. An unfinished test build isn't the launch release, and sequencing milestones isn't a way to quietly drop advanced Money requirements.

#### 2.2 Explicit exclusions

The first release doesn't add bank connections, making payments, bank or provider credentials, full card numbers or CVVs, automatic provider interest or settlement calculations, investments, FX or multi-currency accounting, standalone lending, in-transit transfers, refinancing, general shared workspaces, receipt OCR, AI advice, external calendar sync, or a public store or web launch. The existing multiple-payer Shared Expenses feature is a different thing from the deferred idea of funding an arbitrary private transaction from several sources; don't mix them up.

### 3. Verified starting point and reuse strategy

The web app I inspected is a Next.js/React/TypeScript modular monolith on PostgreSQL, Drizzle, Better Auth, scoped server transactions, row-level security and background workers. Private startup depends on an authenticated server identity. Domain functions, services, repositories and presentation are separate layers, but a lot of behaviour also lives in PostgreSQL constraints, functions and triggers.

V1 core finance, Career and Calendar, V2 financial maturity and sharing, V3 trackers, and the M1–M6 visual redesign are all built. The V3 handoff records 125 declarative tables and 206 migrations through `0205`. The M6 record counts 71 page files, including the design-proof route I deliberately left out, and records acceptance with device and operational limits. These are facts about the old web app, not promises about the native app's capacity or correctness.

The code I looked at includes `src/shared/money.ts`, `src/platform/db/scoped-transaction.ts`, `src/app/_lib/private-app-bootstrap.ts`, `src/modules/sharing/services/groups.ts`, `src/modules/sharing/services/operations.ts`, `src/modules/sharing/services/invitations.ts`, the tracker presets, and the portability format and services. The sharing service only lets the creator correct a bill and checks expected revisions. Settlements tell reported and confirmed apart. Portable bundles leave attachment bytes out on purpose.

What carries over: the business definitions, worked examples, test fixtures, financial acceptance scenarios, source relationships and design principles. The TypeScript rules have to be ported to Dart, not run as they are. PostgreSQL constraints can't just be copied into SQLite, so every guarantee the old database gave needs an explicit replacement and new tests.

All current user records are throwaway test data (decision D17). Converting old production data, or importing old web exports, isn't needed for launch. I keep the existing app and its migration history as references; don't purge the test databases or rewrite old migration files automatically.

### 4. Launch feature inventory and disposition

Every financial row below is a launch requirement. Later work keeps a traceability checklist against the source documents and the current code, including the rejection rules and the advanced cases, instead of treating a screen's labels as the whole spec.

#### 4.1 Money, Debts, planning, and supporting workflows

| ID | Existing purpose/behavior | Approved disposition and required continuity |
| --- | --- | --- |
| M01 | Cash, wallet, checking, savings accounts; metadata, opening balances/cutoffs, archive/history | Keep. Easy local setup, exact balances, owned receiving accounts, and no balance you can edit on its own. |
| M02 | Income, expenses, category splits, completed transfers, fees, categories and activity/history | Keep. Quick everyday entry with optional extra detail; split totals add up exactly; a transfer isn't income or spending. |
| M03 | Corrections, refunds, reversals, negative-balance acknowledgements, reconciliation and adjustments | Keep. Show a preview and keep the evidence of every change; ask for acknowledgement where there's real uncertainty; never rewrite history or reset a balance quietly. |
| M04 | Existing-debt import/setup and borrowing/net proceeds | Keep. Tell apart the opening liability, money received, fees withheld, financed spending and income; a breakdown you don't know stays marked as unknown. |
| M05 | Debt payments, classifications, due allocations, schedule revisions and allocation mapping | Keep. Exact split between cash, principal, interest and fees; earlier revisions are kept, and records that depend on a change are resolved explicitly. |
| M06 | Provider-confirmed early debt settlement, residual closure and adjustments | Keep. No guessed payoff calculator and nothing zeroed out behind the scenes. Debt details and payment evidence stay viewable. |
| M07 | Credit-card metadata, purchases, payments, fees, interest, refunds, overpayment and utilization | Keep. Available credit isn't money you have; a purchase counts as spending and paying the card doesn't count it again. |
| M08 | Statements, statement revisions/reconciliation, payment allocations and installment plans/applications | Keep every built workflow. Don't assume the minimum payment was met, don't guess which statement a payment matches, and don't apply provider interest rules. |
| M09 | Recurring income/bills/subscriptions, rule versions, occurrences, overrides/skips and explicit links to actuals | Keep. Planning never posts money by itself; keep logical dates, exact links and partial completion. |
| M10 | Category budgets, explicit periods, net/gross bases, comparisons and history | Keep. Same-category overlap rules, zero-limit behaviour, labels for the full period and the definition of actual spending all stay. |
| M11 | Savings goals, reservations, release/reallocation, progress and supported-funding ranges | Keep. A reservation isn't an extra asset or a transfer, and it doesn't stop the cash from being spent. |
| M12 | Read-only forecasts, source coverage, recorded future cash and hypothetical scenarios | Keep. Actual, expected and hypothetical values stay apart, and recurring items and cards are never counted twice. |
| M13 | Financial Overview, reports, charts, exact drilldowns, coverage and CSV export | Keep. Worked out locally from complete data, with how fresh the sync is stated plainly and links back to the evidence. |
| M14 | Financial supporting files and links to source records | Keep. Private local files, controlled cloud upload and download, attachments fetched when needed, and covered by recovery. |
| M15 | Reviewed CSV cash-history import, duplicate warnings, cutoff-safe posting and bounded processing | Keep the supported formats, and keep the current limits and interpretation unless reviewed. Don't advertise generic bank, card or debt imports. |
| M16 | Financial reminders and Calendar projections | Keep what they mean; deliver them as local native notifications, with consent, cancelled when the source goes stale, and never changing a balance. |
| M17 | Export, backup, restore, account/profile lifecycle, settings and help | Redesign for local and connected modes: recovery that stands on its own, destructive actions kept apart, and guidance that actually helps. |

Reading, entering, reporting and managing local-only data all have to work offline. Connected actions that depend on another device's current state follow Section 8. A preview or draft can still be made offline even when saving it needs a connection.

#### 4.2 Shared Expenses

> **P6 private-release exception, approved on 28 October 2026:**
> For this private release, M14 can launch with encrypted **attachment bytes
> kept on the device only**. Their details can sync, but the original files need
> their own protected backup, and on another device the exact original has to
> be chosen again. Standard portable archives leave the original bytes out, and
> local files aren't scanned. Controlled cloud upload and download of the files,
> and production scanning, are still future work, not something I've certified.
> This exception doesn't waive the lifecycle, recovery, signing, native
> accessibility or other release gates. See
> [P6 acceptance](archive/salapiya/P6_PRIVATE_RELEASE_HANDOFF.md).

| ID | Existing capability | Launch treatment |
| --- | --- | --- |
| S01 | Groups, owner/member roles, manual/registered/deleted participants, invitations and membership intervals | Keep. Replace the web-account link with a Google-connected identity and deliberate claims. |
| S02 | Single/multiple payers, selected participants, equal/exact custom shares | Keep. The extra centavo goes to the same person every time, and the preview shows clearly who paid and whose part is what. |
| S03 | Creator-only finalized bill revisions/corrections and historical views | Keep. Conflicts are reviewed with a reason; the owner can't quietly rewrite someone else's bill. |
| S04 | Group refunds and changed private source evidence | Keep. Money received and credit for a consumed share stay separate and exact. |
| S05 | Full/custom/selected settlements, partial individual bills, multiple allocations and advances | Keep the whole financial scope that's built; put the advanced allocation controls behind a disclosure instead of deferring them. |
| S06 | Pending, confirmed, disputed, cancelled and reversed settlement history | Keep. The recipient's confirmation, and the limits of a manual confirmation, stay stated plainly. |
| S07 | Reciprocal netting, zero-sum balances, pairwise explanations and group suggestions | Keep. Suggestions don't post money, don't promise the fewest payments and don't let anyone redirect who owes whom. |
| S08 | Integrated Add Expense, existing-purchase conversion, cash/card/unpaid private adoption | Keep. You authorize the effect on your own private records explicitly, with no duplicate spending, cash movement or card liability. |
| S09 | Private settlement/refund clearing, reclassification, retained-evidence review and coverage | Keep. Sync never overwrites private facts you've already accepted. |
| S10 | Group history/export, former-member entitlements, ownership/lifecycle handling and attention | Keep the history and privacy rules; redesign online identity and native notifications as described below. |

Main domain references: [Shared Expenses implementation](archive/web/SHARED_EXPENSES_IMPLEMENTATION.md) and [Shared Expenses requirements](DOMAIN_RULES.md#v2-shared-expenses-and-settlements). The implementation record settles older notes that still call multiple payers or advanced settlements future work: they're built.

#### 4.3 Life and shared application foundations

| ID | Capability | Disposition |
| --- | --- | --- |
| L01 | Personal appointments/events, mixed Agenda/Calendar and reminders | Launch. Real non-financial events alongside the financial commitments the app generates. |
| L02 | Personal Tasks preset | Launch. Entries, statuses, deadlines, completing and reopening, archive and history, and reminders. |
| L03 | Learning and Books presets | Launch. Useful typed records, with basic current progress and list filters. |
| L04 | Career applications, stages, interviews/assessments, follow-ups, notes and history | Launch the essentials, including the supporting documents that matter and Calendar links. |
| L05 | Advanced Career analytics | Deferred. The essentials don't need the full historical analytics. |
| L06 | Custom tracker template editor, arbitrary supported fields and reviewed template migrations | The UI and workflows are deferred. Keep the preset identities stable and the history readable by version, so changing them later is safe. |
| L07 | Advanced tracker reports/customization | Deferred. Simple preset progress can launch without rebuilding all of V3's analysis. |
| F01 | Theme, navigation preferences, onboarding, search, help and accessibility | Launch, adapted to native input and local data. Hiding a module doesn't delete its data or quietly turn off its reminders. |
| F02 | Web registration/password verification/reset and web sessions | Replaced by an optional Google connection plus native device and session management; no separate Salapiya password at first. |
| F03 | Scheduled external email reminders and current web worker topology | The first reminder channel is on the device. External email or push delivery isn't needed for launch; the financial sources and reminder behaviour still are. |
| F04 | Web production deployment, hosted web readiness and disposable web-data conversion | Not part of this migration. The native app and cloud service still need their operational checks before real use. |

#### 4.4 Financial semantic details that must survive simplification

- The launch currency stays PHP. Keeping currency fields doesn't mean exchange rates or mixed-currency totals are built.
- Amounts are exact integers in minor units, and nothing loses precision at a boundary. No floating-point money maths and no lossy JSON numbers. Aggregate ranges and SQLite/driver conversion have to be proven, not assumed.
- An opening cutoff runs through the end of its accounting date, so later activity and historical imports must never count the starting balance twice.
- Budgets compare against actual recognized category spending; a recurring expectation doesn't use up a budget just by being scheduled.
- Savings reservations can't include credit limits, cash dated in the future, an expected salary, debt balances or forecast values. If goals are underfunded, that stays visible; the app doesn't pick one goal to win.
- Forecasts stay read-only. Their automatic sources don't grow to include every debt installment just because Debts is now prominent; the assumptions and source coverage still have to be explicit.
- Civil dates stay dates. Timed events keep their UTC instant and IANA timezone. DST ambiguity, month-end recurrence rules, exclusive period ends and backdated corrections all need explicit tests.
- Ordinary recurring records link to eligible actual income or purchases. They don't infer card payments, debt payments or settlement allocations on their own.
- Correction dependencies, unknown debt classifications, card facts confirmed by the provider and incomplete coverage all stay honest. A simpler screen is never a reason to invent a value.

### 5. Navigation and platform experience

The main destinations are **Overview, Money, Debts, Shared Expenses, and Life**. Settings, backup and sync status, and help are reachable without becoming competing destinations.

| Destination | Content and priority |
| --- | --- |
| Overview | Upcoming debt and card commitments, recent money activity, group confirmations and things to review, tasks and events, and how fresh the data is. Exact financial summaries link to their sources. |
| Money | Accounts, transactions, cards, statements and installments, recurring obligations, budgets, savings, forecasts and reports. |
| Debts | Its own prominent place in the navigation, leading into the existing finance domain: borrowing, imported debts, balances, schedules, payments and settlement. There's no second debt ledger. |
| Shared Expenses | Groups, people, bills, payments, explanations and review of private effects. Group scope and private scope look visibly different. |
| Life | Calendar and Agenda, Personal Tasks, Career essentials, Learning and Books. The name is for navigation; it isn't a generic data model that replaces the others. |

#### 5.1 Windows

Resizable layouts, keyboard shortcuts, a predictable Tab order, a visible focus ring, searchable lists, aligned number tables, list and detail views where they help, native file selection, and clear behaviour when closing unsaved work. Dense work like statements, allocation review and reports can use more of the screen. Nothing should need mouse-only hover. Whether it's a navigation rail, a sidebar or a dock is a design choice to prove out; the web app's dock layout doesn't bind the native app.

#### 5.2 Android

Compact main navigation, readable touch targets, system Back and predictive back where supported, safe areas and keyboard insets handled, accessible sheets and full-screen forms, share and file pickers, and quick expense capture. Complex debt, card and settlement features stay available through focused steps; a smaller screen isn't a reason to remove them.

#### 5.3 Shared experience requirements

- Match what each feature does and what records mean, not pixel-identical screens.
- Keep drafts safe through navigation, backgrounding and the process being killed, where that's practical. A draft isn't a posted action.
- Financial forms are focused on the task: the essential fields first, with advanced funding, splits and allocations when you ask for them.
- Show honest saved, synced and confirmed states, without technical queue words in everyday flows.
- Reports say which filters, dates and coverage they use, any local changes still pending, and when they last synced, where that matters.
- Light, dark and system theme, text scaling, screen-reader labels, reduced motion, and status cues that don't rely on color.
- Never show data that's still downloading as an empty account, a zero balance or a complete report.
### 6. Profiles, Google identity, and onboarding

#### 6.1 Identity model

These are separate things and stay separate: the local profile, the remote account, the device install, a financial account, a group, a group participant, and a membership. A Google identity is matched through the authenticated provider and Supabase identity, never by trusting an email someone typed or by matching display names.

One remote Salapiya account owns one private profile, and that profile can have several registered installs. One install has one active profile and no everyday profile switcher. Different OS users can have separate installs and data folders; an app profile doesn't replace the isolation the OS gives between accounts.

A purely local profile has a stable local id and needs no network request and no anonymous Supabase session. When it connects, its ownership is set up through a trusted, explicit enrollment transaction. Ids can be kept where they're valid, but the server checks the whole graph and who owns it; having some profile's UUID proves nothing.

#### 6.2 First-run choices

1. **Create a local profile:** pick a display name and starting preferences, the local database is created, and you start without the network. Modules and accounts are set up as you go.
2. **Continue with Google:** sign in online. If you already have a profile it's retrieved; otherwise a connected profile is created. Nobody is forced to make a throwaway local profile first.
3. **Restore from backup:** check a backup and preview whose it is, what it covers, its dates and what restoring will do, before it becomes active. A backup doesn't give you back current group membership by itself.

Google is the first online sign-in method I picked. Other providers, passkeys and a separate Salapiya password are deferred. Locking the app on the device is a separate security feature.

#### 6.3 Connect an existing local profile

You choose **Connect Google account** and the app shows the account, and says plainly that turning on sync uploads your private records to Salapiya's services. A successful Google sign-in only establishes who you are; it doesn't mean the data has moved.

Enrollment and import run as one operation that can resume and is safe to repeat. It checks source identities, references, money totals, versions, ownership and quotas, and stages incomplete data so other devices never see a half-valid financial graph. It keeps an enrollment receipt or checkpoint, so an interruption doesn't produce a second opening balance or duplicate actions. Either the affected writes freeze briefly while the final data is published, or a durable tail of local commands catches up afterwards; Gate G2 is where I pick one and prove it.

If the account already owns a cloud profile and this device has a different local profile with data in it, nothing merges or overwrites quietly. At first the app keeps or exports the local profile and, once you confirm, switches to the existing cloud profile. A full merge of two profiles' finances is deferred. Cancel leaves local records as they were. Two enrollments at the same time have to settle the one-profile-per-account rule safely.

#### 6.4 Retrieve a profile on another device

Sign in with the same Google account, which picks the existing profile for you, download a consistent dataset you can use, and see how far the first sync has got. There's no matching by name or email, and the two devices don't need to be online at the same time. Android has to upload a new record before Windows can receive it.

A full financial view only turns on once the snapshot it needs is there. Attachments can stay online-only, said plainly, until they're downloaded. Once set up, local access keeps working offline. An expired online token pauses sync; it never destroys or hides your private local records. You sign in again before remote access resumes.

#### 6.5 Google configuration

Use the supported Supabase and Google libraries and the browser or native flow each platform supports. That means setting up a Google Cloud project, OAuth clients, the consent and audience settings, the Android app and signing configuration, Supabase callback URLs and the allow-listed return-to-app URLs. Use the system browser or the right native sign-in, with PKCE where it applies; never collect Google passwords or ship OAuth client secrets inside the app. Handle cancelling, choosing the wrong account and interrupted callbacks.

Ask only for the basic identity scopes; Gmail, Drive and Calendar access aren't needed. Google identifies the user; it doesn't hold the Salapiya data or do the syncing. Branding and audience verification get checked during setup, and private distribution doesn't exempt the app from OAuth policies. [Supabase Google sign-in](https://supabase.com/docs/guides/auth/social-login/auth-google) and [Google OAuth app states](https://developers.google.com/identity/protocols/oauth2/production-readiness/overview) document basic identity support and platform setup.

#### 6.6 Sign-out, disconnect, device loss and account changes

These are separate actions: pausing sync, locking the app, signing out or removing a device, deleting local data, and deleting the cloud account. Before taking away local access, the app says what hasn't synced and offers a backup; an ordinary sign-out never quietly throws that work away. The private app lock can reopen an existing local profile without talking to Google.

Recovering a Google account gives you back the identity; downloading from Salapiya gives back only what synced successfully. Anything unsynced needs a surviving device or a backup. Revoking a device blocks its future cloud access, but it can't erase data from a device that's offline or a copy someone made. Don't promise a remote wipe.

Changing the connected Google account, or recovering into a different identity, isn't like editing a display name. Automatic reassignment is deferred; it needs an explicit recovery or transfer design that I've reviewed. Until then there's a documented backup route, and the app explains the limit before anyone relies on it.

### 9. Shared Expenses identity, permissions and lifecycle

#### 9.1 Group participation

Creating or joining a synced group needs an online-connected identity. Local-only users can keep private records, but they don't get shared membership through a display name. One person can be in several groups. Their devices all act as the same member, not as extra people or payers.

Group owners manage membership, not infrastructure. The service keeps working when the owner's phone or computer is off. Losing a device doesn't hand ownership to anyone; you recover the account or transfer ownership deliberately, online.

#### 9.2 Permission baseline

| Action | Authority |
| --- | --- |
| Read current group records | Active members, within the history rules |
| Create bill with one/multiple payers | Active members |
| Correct own bill | The creator, on the current revision, with a reason and the dependency checks that apply |
| Correct someone else's bill | Never quietly allowed. Ask for a correction or dispute it; any exceptional admin handling needs its own attributed workflow, designed separately |
| Report own settlement | An active payer, with valid recipient and source references |
| Confirm/dispute receipt | The registered recipient; never assumed because a sync succeeded |
| Manual recipient confirmation | The owner, clearly marked as manual and unverified; the historical evidence stays after the person later claims their identity |
| Invite/remove members, manage group, transfer ownership | The owner, online, with current permission and a reviewed action |
| Mutate another person's private ledger | No group role ever allows it |
| Delete published financial facts | Use the allowed versioned corrections and reversals; removing something through the lifecycle is reviewed separately |

The service checks bills submitted offline automatically; there's no new owner approval queue for every ordinary bill.

#### 9.3 Invitations and manual participants

Invitation tokens stay short-lived, single-use and revocable, stored only as hashes, and accepting one means explicitly accepting what history you'll see. Seven days is the starting lifetime I inherited, and it only changes through a deliberate policy change. Ideally a token is tied to a verified target identity or email that comes from signing in; just having an invitation URL must never quietly claim an existing participant. No searchable public user directory.

Links have to work through the installed app's callback, or through a clear manual invite-code path, including when the app wasn't installed at the first click. Deep-link routing is part of platform acceptance. No automatic invitation email service is needed; copying or sharing securely is enough at first.

Manual participants stay. Claiming one takes a nomination the owner approves explicitly, plus the recipient signing in and accepting or reviewing it. Never match by name automatically. Old manual-confirmation labels stay after a real person claims that participant.

#### 9.4 Settlements, corrections, refunds and private effects

What the payers put in and what the participants' shares come to each equal the bill total exactly. Confirmed positions of all participants add up to zero. Pending or disputed settlements only affect projections that say so. Suggestions don't create any money movement. Source caps, exact allocations to chosen bills, advances, and correction and refund history all stay.

A private financial action and the group accepting it remotely can't be one database transaction across devices. So the app keeps three things: the independent record of the actual money, a durable group intent, and an explicit link or review state. If the group doesn't accept it, the actual spending still stands; you can correct how it's shared or keep your private evidence. A group correction never quietly rewrites private costs or funding you've already taken on.

In the same way, reporting a private settlement can record the actual cash once, in clearing. The recipient's confirmation classifies what's covered; it never takes the cash out a second time. Reversing a group confirmation doesn't prove the money physically came back. New group refunds have to say who received the money and whose consumed share goes down.

#### 9.5 Exit, removal and owner loss

The existing difference between what you're entitled to historically and access as a new member stays. Former members can see the records they were entitled to when they left, later corrections that concern them and the settlement resolution they're allowed; they don't get unrelated bills from afterwards. Sync subscriptions have to do exactly this, not just fetch every record in every group someone once joined.

Removal stops new authorized group writes once the service processes it. Data already cached or downloaded can't be reliably recalled. Removing a member doesn't cancel their debt. Deleting an account pseudonymizes or detaches the identity as appropriate, while keeping the legitimate shared financial evidence under the declared policy.

Ownership can be transferred explicitly. A lost device on its own is solved by recovering the identity. If the owner is gone for good, owner-only administration freezes and the documented recovery or archive policy applies; members don't get to take over on their own say-so. If a deletion would leave a group without an owner, it ends in either a transfer or an archive, with access to entitled history kept. The exact admin recovery policy is an operational gate.
### 12. Files, imports, exports and backup/recovery

#### 12.1 Attachments

Private supporting files linked to their source stay. Being in a group doesn't make a privately linked receipt or funding account public. The first allowed formats and limits can carry over from the web app (PDF, JPEG, PNG and the reviewed limits), but I need to check them against local and cloud capacity before release. Having a file's details isn't the same as having its bytes.

Check the real size, type and checksum; authorize both upload and download; use opaque private object keys and bounded, resumable transfers; and keep the pending, available, rejected and deleting states. Decide the native preview and scanning approach deliberately. Don't quietly drop the existing upload safety controls, and never show an unscanned file as verified safe. Documents never execute anything. Prefer the platform's own viewers or sandboxed rendering of supported formats. A real scanner and storage path has to be validated before files are used in the shared cloud; local test adapters don't count as evidence.

Track local-only, uploading, available in the cloud, downloaded and failed. Cloud uploads survive restarting the app, and a failed file doesn't hold up unrelated transactions. Cloud-backed attachments can be downloaded when needed or marked to keep offline. The local bytes stay recoverable until the transfer's outcome is known. Deleting on purpose, and cleaning up orphans, must never remove another source's evidence.

#### 12.2 CSV and portable exports

The reviewed cash-history CSV contract that's built stays: explicit columns, date format, account, currency and cutoff; duplicate warnings; a preview; a confirmation; bounded batches; and permanent provenance for each recognized row. What's supported is income and expense cash history, not reading in any provider's format. Rebasing the historical opening and the chosen historical rows happens in one atomic step, with an exact coverage equation.

CSV reports are readable exports, not a full backup. Cells are safe from formula injection, and the period, source and freshness details are accurate. Group exports never expose private rows.

#### 12.3 New Salapiya backup contract

A versioned, encrypted, portable archive holding the private records and their history, the definitions needed to read them, a manifest with checksums, counts, currency and schema versions, and a clear statement of which attachments it covers. There's a self-contained backup that includes attachments; if an export leaves out files that weren't downloaded, it says exactly what's missing. A backup has to be recoverable on a different compatible device with a recovery secret the user controls, not a key that only existed on the lost device.

Never export reusable online credentials, OAuth tokens or private server secrets. Pending work only goes in under an explicit format that can't blindly replay commands already accepted. Command ids never change, and import provenance is kept. A backup's group snapshot is historical evidence; it's not current authority over the group and not permission to overwrite group data.

Rolling local snapshots for quick recovery, plus portable exports the user saves somewhere separate. The app explains that a backup on the same device you lose isn't enough. Cloud sync isn't a backup, because it can spread mistakes; hosted recovery and your own archives do different jobs. Retention and storage limits are operational decisions to write down before real use.

#### 12.4 Restore modes

- **Local recovery:** check, preview and restore private data into a safe local profile, saying exactly what happens to attachment coverage and pending work.
- **Connected-device recovery:** sign in, reconcile with what's already in the cloud and the original receipts, then restore only the supported missing private intent through reviewed commands. An older backup can't blindly replace newer accepted history.
- **Historical inspection/export:** where useful, let someone read an old private snapshot without making it the current connected data.

Rolling a whole connected profile back is destructive and needs its own design; nothing here implies a generic overwrite-the-cloud button. Test corrupted and truncated archives, wrong passphrases, unknown schemas, another owner's data, huge or deeply nested input, path traversal inside archives, missing bytes, and restoring after credentials are revoked or the account is deleted.

### 13. Calendar, reminders and background execution

Calendar entries from debts, cards, recurring obligations, Career and trackers are projections of the records they come from. Editing a projected deadline opens its source; there's no separate copy you can edit. Source ids, occurrence identity and a generation or version number handle updates, completion, archiving and reminders.

Launch uses local native notifications. Notification permission is optional and never blocks records. Reminder intent is stored durably; scheduled notifications are reconciled after a restart, reboot or timezone change where the platform allows; quiet hours are respected; and old generations are cancelled. Sensitive content is hidden on the lock screen by default. Dismissing a reminder doesn't pay a debt or complete a task.

Each device has its own delivery permissions and settings. A connected profile can get reminders on both devices unless you turn delivery off on one; I don't promise exactly-once notifications across devices while they're offline. Financial data and the reminder definitions that matter can sync, while local scheduling ids and permissions stay on each device.

Sync when the app opens or resumes and while it's in use, plus Sync now. Background attempts are best effort within what each platform allows, and they're never the only way forward. Android limits background work and WorkManager follows power and constraint scheduling; exact alarms would need their own justified design. [Android persistent work](https://developer.android.com/develop/background-work/background-tasks/persistent).

New group activity arrives through sync. Remote push or email alerts are deferred unless I choose them later. The opt-in email notifications from the web app don't become a required native service. Once a reminder has been shown, I don't assume it can be taken back.

### 22. Deferred decisions and what to do next

These don't stop this document from recording the product direction, but none of them should be guessed when the work comes to depend on them:

- Exact dependency versions, state, routing and chart packages, database encryption integration and schema layout.
- The minimum supported OS versions and architectures, and the list of physical devices to test on.
- The policy for finishing each connected command offline, how local and remote rules stay in step, and how durable checkpoints are built.
- Cloud regions, storage and scanner configuration, backup retention, sync-history retention and a clear paid budget ceiling.
- Native notification scheduling details, installer, signing and update tools, stable package ids and the private distribution channel.
- Administrative recovery when a group loses its owner, and exactly how account deletion and kept history work.
- The final logo and icon assets, and checking the brand is available before wider distribution.

**Known limits left by the native UI redesign (2026-11-02).** Each needs logic, a rule, a migration or server work outside the UI, so each stays deferred until I take it on as its own piece of work. The screens already say so where it matters.

- **Native Google account sheet on Android.** Sign-in opens the browser. The system account sheet needs a sign-in package, an Android OAuth client for each signing key, `signInWithIdToken`, and a retest of account deletion, whose server check expects a recent `oauth` sign-in.
- **Restore on a device that can't open its profile.** The rules refuse a restore unless the device holds no profile, so a missing or damaged profile can't be restored on that install. Offering it where the key can't be read could overwrite the only key.
- **A preserved profile can't be reached.** Nothing reopens it, and its own backup can't restore on that install while its file is there.
- **Leftover `.staging` files.** An interrupted restore or a same-profile refusal leaves one behind with its key gone. Nothing cleans them up.
- **The device is listed before the disclosure.** `boundary()` registers the device during review. The screens say so; moving it changes the flow.
- **A deleted account after a restart.** Nothing on the device records it, so the profile reads as signed out and paused. It needs a saved marker or a call to `p7_deletion_status`.
- **A renamed profile.** A connected profile's name isn't synced, so devices can differ. The form says so. It needs a rule and a command.
- **Reminders reset on any edit.** A reminder is tied to its record's version, so editing a note cancels a dismissal or snooze, which ARCHITECTURE §12.2 says an unrelated edit shouldn't.
- **Which invitations are open.** The server keeps invitations to itself, so the app can't tell one was used or revoked on another device, and revoking a used one is refused.
- **Rejected group commands stay in review.** Nothing moves them on, so one refusal keeps the sync status on Needs review. It needs a store state and a migration.
- **Editing or unarchiving an account, and changing a card's limit once it has activity.** No rule allows them, so they aren't offered.
- **Overview figures not built:** payoff progress by balance, net position, "last synced", and group balances on the Overview.
- **The sync rule for connected profiles** (`dependencySensitive`): relaxing the one-minute limit or allowing a first schedule offline.

Before starting the next piece of engineering work:

1. Read this plan and the current domain docs and code that apply.
2. Check where the repository actually is; don't assume the baseline SHA is still the latest.
3. Start with P0 and the gates I've assigned, not a full rewrite of the app in one change.
4. Keep the existing web files and published migrations unless I've said they can change.
5. Keep evidence, decisions and open issues as separate records. Never mark a gate passed because of documentation or a vendor's marketing.
6. Never quietly change the approved launch scope, bill permissions, what money means, privacy or anything I'm paying for.
7. Keep features traceable to their tests, and update this plan or the ADRs when a later decision replaces a detail.

## Project Vision and Feature Blueprint

> **Historical scope:** this is the original vision for the web app, V1 to V3. The Salapiya plan above replaces it for product direction; status notes below date from mid-October 2026.

**Working application identity:** Personal workspace, approved October 17, 2026; the repository name was still tentative and final branding deferred\
**Document version:** 1.5, approved redesign alignment, October 17, 2026\
**Created:** October 5, 2026  
**Purpose:** The founding product document, pulled together from the "Strengthen Tracker Project" brainstorm and shaped into one vision and a staged delivery plan.

This describes the product I meant to build: what it does at its core and where it stops. It's the starting point for requirements, interface design, data modelling and planning. The full vision is bigger than the first release; I wrote the later features down here so they could be added on purpose later without holding up a usable product.

**Current development direction:** V1 and V2-A through V2-I are complete under their documented acceptance scopes; [V3-A through V3-D are complete and locally accepted under approved targeted verification](archive/web/V3_DEVELOPMENT_HANDOFF.md). The [V3 impact matrix](OPERATIONS_AND_RELEASE.md#v3-change-impact-acceptance) records the local checks I chose; the broader automatic CI passed separately at implementation commit `239c360` ([run](https://github.com/RAbnza/salapiya-app/actions/runs/38911065106)). That doesn't imply any production, manual or hosted product acceptance.

I approved the [comprehensive UI/UX redesign](archive/web/COMPREHENSIVE_UI_UX_REDESIGN_PLAN.md), the [M1–M6 roadmap](archive/web/UI_UX_REDESIGN_MILESTONES.md) and the [current decisions](archive/web/UI_UX_REDESIGN_DECISIONS_REQUIRED.md) on October 17, 2026. M1 foundations were finished and approved on October 17, 2026 (Asia/Manila); M2 was ready to start on its own ([handoff](archive/web/REDESIGN_M1_HANDOFF.md)), and M2-M6 hadn't started. The order I approved is **completed V3 → UI/UX Redesign → Platform Architecture Planning → Windows/Android Development → Platform-Specific Acceptance**. The web app stayed the place to build and verify things through the redesign; finishing its production deployment and readiness was dropped under [ADR 0005](adr/0005-v3-scope-and-platform-transition.md). The direction stays mostly-offline personal use on Windows and Android, with private data on the device and some online collaboration; the replacement architecture and final branding were still deferred. Everything built in V1–V3 stays: the features, business rules, privacy, authorization, security and integrity.

### 1. Product vision

> A modular personal management platform that helps people understand their money, manage obligations, organize job applications, and see upcoming commitments through one dashboard, a connected calendar, and reusable trackers.

The app should help its user answer:

- Where is my money, and what changed it?
- How much did I spend, including interest and transaction fees?
- What do I owe, what's due next, and what have I already paid?
- Which applications need attention, and when is my next interview or assessment?
- What needs me today, this week or this month?
- How have my finances, job search or personal progress changed over time?

What sets it apart is how the modules connect. A debt installment shows up in the calendar, an interview links to its application, and a payment updates the account, the debt's history, the dashboard and the reports all at once.

### 2. Problem and target users

Personal information tends to be scattered across wallet apps, bank statements, notes, spreadsheets, calendars and job boards, and each one shows only part of the picture. That's how deadlines get forgotten, spending goes half-recorded, debt balances get fuzzy and application histories get lost.

The first target user is a recent graduate or early-career professional who's job hunting, uses several financial accounts and wants to get adult responsibilities in order. The first real user is me, the developer. The design should still work for other people and institutions, without my personal details hard-coded in.

People should be able to start with only the modules they need. Someone with no debts or credit cards should still find it useful.

The finished product has to support several users, like members of one family. From V1, each person has their own sign-in account and a private personal workspace. A sign-in account identifies a person; a financial account represents their bank, wallet or cash balance. Family members sign in as themselves rather than sharing one login.

Users can also join explicitly shared expense groups once that module is out. Being family, or being in a group, doesn't give anyone access to someone else's salary, private balances, lender debts, applications or trackers. A shared expense group is much narrower than a shared personal workspace. General shared workspaces, teams and delegated access stay later extensions.

Turning a module off hides it from the normal navigation without deleting its records, and the user can turn it back on. The app says whether its existing deadlines stay visible, and reminders are controlled separately.

### 3. Product principles

1. **Accuracy and traceability.** Every amount should have a source and a history you can explain.
2. **Manual entry first.** Actual amounts the user enters win over estimates and suggested rules.
3. **Connected modules.** Modules share identity, dates, reminders, tags and navigation, while each keeps its own business rules.
4. **Provider independence.** GCash, Maya, MariBank, GLoan, SLoan, SPayLater, banks and personal lenders are names you configure, not separate models in the app.
5. **Progressive setup.** Someone can get useful work done without filling in every settings screen.
6. **Clear distinctions.** Actual against planned, cash against credit, and an expense against a repayment are always shown apart.
7. **Practical scope.** Ship a useful release before building wide customization or integrations.
8. **User control.** Corrections, exports, notification preferences and a guide you can replay.

### 4. Product structure

| Area | Responsibilities | Connections |
| --- | --- | --- |
| Money | Accounts, transactions, expenses, fees, debts, credit cards, reconciliation, planning | Due dates, reminders, reports, activity |
| Shared expenses | Family/group bills, participant shares, amounts owed, settlements | Explicit links to private ledgers, group history, reminders |
| Career | Applications, stages, interviews, assessments, follow-ups | Calendar, reminders, reports, activity |
| Time | Agenda, calendar, recurring obligations, deadlines | Links back to source records |
| Trackers | Implemented presets and versioned custom templates/trackers | Dates, status, reminders, reports where applicable |
| Shared foundation | User settings, categories, tags, history, onboarding, navigation | Used by all modules |

Finance and career keep their own specialized records. Sharing common features doesn't mean forcing every record into one generic tracker schema; a financial balance needs far stricter checks than a reading list.

### 5. Dashboard

The home screen answers "What needs my attention?" before it shows detailed analysis.

Suggested sections:

- **Financial snapshot:** tracked liquid funds, spending in the chosen period, outstanding liabilities and upcoming payments.
- **Career snapshot:** active applications, interviews, assessments and follow-ups.
- **Upcoming agenda:** deadlines from every module in date order, with module filters.
- **Attention needed:** overdue obligations, incomplete records and reconciliation differences.
- **Recent activity:** payments, transfers, application changes and finished tracker items.
- **Quick actions:** add an expense, transfer money, record a payment, add an application and create an event.

Every summary says what it includes and links to the records behind it. Available credit is never counted as cash or liquid funds. Net position is labelled "tracked net position" until every relevant asset and liability is included.

### 6. Money module

#### 6.1 Financial accounts

An account is a place where money is held. The first types are cash, e-wallet, checking or bank, and savings; tracking investments is a later extension.

An account has a name, a type, an optional institution, a currency, an opening balance and date, a calculated balance, an active or archived state and notes. Examples: Cash Wallet, GCash Wallet, Maya Wallet, Maya Savings and MariBank.

The opening balance sets the starting point; it isn't income. From there the balance comes from the money movements you record. Archived accounts keep their history, and an account that transactions refer to can't be deleted.

Start with PHP and one currency per workspace. The design keeps currency information, but exchange rates and cross-currency transfers come later. Unrelated currencies never get added together without conversion.

#### 6.2 Transaction ledger

The ledger is where financial truth lives. Expense screens, account histories and reports are all views of these records, not copies of their own.

The financial actions supported should grow to cover income, expenses, internal transfers, borrowing, financed purchases, debt payments, credit-card purchases and payments, refunds, fees, rebates and balance adjustments.

Each action records the accounts or liabilities involved, the amount, currency, effective date, category, description, an optional reference, any linked fees or adjustments, and its history of creation and changes. Credit cards also tell the transaction date and the posting date apart.

##### Receiving money into a specific account

Every real receipt of money names the account it went into. Recording it updates that account's balance through the ledger; nobody should have to edit the balance separately. The sender or income source says where the money came from, and the receiving account says where it is now.

Examples, with account names that are only illustrations, not providers you need:

| Receipt | User-entered details | Result after saving |
| --- | --- | --- |
| Salary of PHP 10,000 received into BDO | Type: income; category: salary; source: employer; receiving account: user's BDO account; actual receipt date; amount: PHP 10,000 | If BDO held PHP 2,000, its balance becomes PHP 12,000. Other accounts don't change. Income for the receipt period goes up by PHP 10,000, and BDO's history shows the linked salary transaction. |
| Gift of PHP 500 received into GCash | Type: income; category: gift; source: another person; receiving account: user's GCash wallet; actual receipt date; amount: PHP 500 | If GCash held PHP 200, its balance becomes PHP 700. Other accounts don't change. The gift shows in income reports and in GCash's history. |

The user picks the real receiving account for each receipt. Salary isn't tied to BDO or any one bank for good. An optional saved default salary account can prefill the form, but it stays editable. If the receiving account doesn't exist yet, the app asks the user to add it before posting the receipt.

Getting money from another person isn't always income, so the app asks what it was: a gift is income, borrowed money also creates a debt, a purchase refund offsets spending, and a transfer from another account the user owns just moves money they already had. Being repaid money you lent uses the receivables workflow that comes later. Every supported kind of receipt raises the chosen account by the amount actually received; what it does to income, spending and liabilities follows its own rules.

If salary is split across accounts, V1 can record a separate receipt for each actual deposit, with an optional shared reference and amounts that add up to the salary actually received. A later split-destination form could capture them together without counting income twice. Record the amount actually deposited; gross salary, deductions and payslips are optional future extensions and must never inflate the cash received.

Before saving, the app shows a preview such as: "GCash decreases by PHP 5,015; MariBank increases by PHP 5,000; fee expense is PHP 15."

**Planned records do not change actual balances.** A due installment, an expected salary or a recurring bill only becomes an actual financial action when the user records it as received or paid. Pending entries are visibly left out of posted balances.

**Transfers may finish on different dates.** V1 assumes an internal transfer has completed and records both sides together. If money has really left the source but hasn't arrived yet, it mustn't be labelled an ordinary unposted plan or a completed transfer. A later transfer workflow should handle money in transit, completion, failure and return, with separate departure and arrival dates and explicit fee refunds. Money in transit is shown apart from spendable balances, and moving money between accounts you own and track isn't income or spending.

For manual tracking, an entry that would take a cash or wallet balance below zero shows a warning and lets you look into it. A real transaction never gets quietly thrown away because older records are missing. Accounts that genuinely allow overdrafts need their own explicit policy later. A negative liquid balance is never shown as money available.
#### 6.3 Expense tracking

Categories like food, transport, housing, utilities, subscriptions, shopping, healthcare, education, entertainment, interest, transaction fees and other. Users can manage categories and optional tags.

Search, date filters, account filters, category totals, spending comparisons and transaction details. A financed purchase counts as spending when it's recorded; paying off its principal later doesn't create the same expense again.

V1 supports splitting one purchase across expense categories: a PHP 1,000 receipt might be PHP 700 of groceries and PHP 300 of household supplies. The category parts have to equal the purchase amount, and adding splits never takes money from the account a second time. Fees that go with it stay identified separately. Splitting the funding across several payment accounts can come later and has to pass the same total checks.

Credit cards and shared expenses extend this purchase entry instead of creating their own duplicate purchase trackers. From V2 you can pick a credit card as the funding source for an expense. The purchase is still recorded once: spending is recognized when the purchase happens, and the funding effect is card liability rather than cash leaving an account. Paying the card later lowers cash and the liability without recording the purchase expense again.

A purchase can also be marked as shared with a group. The same real purchase shouldn't need entering once as a private expense and again as a shared one. The shared workflow records what the payers put in and each participant's share, while the private side records only the financial effects the current user has authorized for themselves. Eventually a purchase can be both paid by card and shared, without doubling the spending or the liability.

Advanced funding and sharing details stay tucked away until needed. An ordinary expense stays simple when there's no card, installment or sharing involved.

#### 6.4 Transfers and fees

Moving money between your own accounts isn't income or spending. Any fees on it are expenses.

Example: transfer PHP 5,000 from GCash to MariBank with a PHP 15 fee paid from GCash:

- GCash decreases by PHP 5,015.
- MariBank increases by PHP 5,000.
- Total liquid funds decrease by PHP 15.
- Expense reports show PHP 15 in transaction fees, not PHP 5,015 in spending.

A transfer can have several fee parts, each with a label, amount, date and the account or liability that bore it. Defaults can make entry quicker, but users have to be able to say a fee was paid separately or taken out of the amount received. The final preview reflects whichever they chose.

Fees are entered by hand by default. Saved rules could suggest values later, but they stay editable and never claim to be a provider's current policy.

#### 6.5 Debts and installment obligations

Personal loans, installment loans, buy-now-pay-later purchases and flexible credit. Provider and product names are just metadata, and their repayment rules can differ.

A debt record can include:

- Lender or provider, product name, debt type and notes.
- Original principal, start date and an optional linked disbursement or purchase.
- The opening outstanding liability when importing a debt you already have.
- Known posted interest, fees, penalties and adjustments.
- Scheduled amounts under the contract and the scheduled total remaining.
- Payment frequency, due dates, number of installments and an optional manual schedule.
- Actual payments and how they were allocated, where known.
- Status: active, settled, settled early or cancelled, where those apply.

Overdue status comes from unpaid due amounts and dates, and is kept separate from the debt's overall lifecycle state.

**Outstanding principal, recognized liability, and future scheduled payable are different figures.** Future interest built into a payment schedule isn't automatically a charge already owed in the ledger. If the provider doesn't give a principal and interest breakdown, the app says so instead of making one up.

For the first debt support, user-entered provider schedules and actual amounts come first. No universal interest calculator, and no assuming every installment is the same. Generated schedules are only for clearly supported terms, with a preview and a rounding adjustment.

Payments can be partial, late, extra, or spread across several installments. A payment and its ledger movement point to each other so the user doesn't enter the same payment twice. A partial payment leaves the rest of the due amount visible.

Loan proceeds and principal can differ. If a PHP 10,000 loan pays out PHP 9,800 after a confirmed PHP 200 upfront fee, record PHP 9,800 into the receiving account, PHP 10,000 of liability, and the PHP 200 fee separately. Borrowed cash isn't earned income. Fees added onto the debt instead of taken from the proceeds need a different preview; never deduct them twice.

When a lender changes a schedule, the old version, the payments, the reason and the effective date are kept. A corrected due date isn't the same thing as a renegotiated agreement. V1 can support explicit manual revisions with a before-and-after preview; refinancing and complex restructuring are later workflows. Replacing an old loan with a new one will eventually record the settlement and the new borrowing, never erase the old debt.

#### 6.6 Early settlement and adjustments

You can settle a 12-month obligation in month 6, or at any other point. The app records the settlement date, the actual payment, the payoff amount the provider confirmed, any known rebate or waiver, extra fees and an optional reference.

An example, assuming the whole PHP 6,400 is already recorded as a liability:

| Item | Liability effect | Cash effect |
| --- | ---: | ---: |
| Balance before settlement | PHP 6,400 outstanding | — |
| Settlement payment | Decrease PHP 6,000 | Decrease PHP 6,000 |
| Confirmed interest waiver | Decrease PHP 400 | No cash movement |
| Balance after settlement | PHP 0 | — |

If the PHP 6,400 is only the remaining schedule, including future interest that was never posted, the original schedule is kept and the app records that PHP 400 of future charges were avoided. It doesn't reverse an expense that was never recorded.

Once confirmed and reconciled, the debt is marked settled early, and its remaining due events and reminders are cancelled. The original schedule and the settlement history stay visible. Any mismatch is resolved with an explicit charge, waiver, allocation or correction; the balance is never forced to zero behind the scenes.

These are different things:

- **Liability waiver/rebate:** lowers an amount already owed, without necessarily adding cash.
- **Cashback received:** raises a named account when it actually arrives.
- **Purchase refund:** reverses or reduces the original spending and updates the account or liability involved.
- **Expected cashback:** stays pending until it arrives.
- **Correction:** fixes a record, with a reason and its history kept.

The same benefit is never recorded both as a debt reduction and as cash received, unless both really happened.

A purchase can have partial refunds and several refund events linked to it. Gross spending, refunds and net spending are shown separately. By default the actual-period report records a refund when it happens, even if the purchase was in an earlier period; an optional effective-cost view per purchase can put the linked records together. Cashback is either a linked spending offset or separately labelled reward income, depending on what it is, and that choice is applied consistently. The same cashback is never treated as both.

#### 6.7 Credit cards

Credit cards are liability accounts with their own billing cycle, but a card purchase is still a purchase. It goes through the ordinary expense entry, not a separate card tracker where you'd enter it twice.

From V2 you can pick a credit card as the funding source for an expense. A posted purchase raises spending and card liability without touching liquid cash. A later card payment lowers the chosen cash account and the card liability, without creating the purchase expense again.

These events stay separate:

Credit-card purchase: recognizes the purchase expense and the card liability.

Installment plan: records the scheduling the provider confirmed for a purchase that's already recognized; it never repeats the purchase expense every month.

Credit-card payment: moves actual cash to lower the card liability, and doesn't create another purchase expense.

Track the issuer and name, credit limit, outstanding posted balance, an estimate of available credit, statement cycles, statement balance, the remaining statement amount due, minimum due, due date, payments, fees, interest, refunds, card credits and overpayments, and optional installment plans.

These ideas stay distinct:

Transaction date: when a purchase happened.

Posting date: when the provider posted it.

Statement period/date: which verified billing cycle includes it.

Outstanding posted balance: all the recognized, unpaid, posted card activity.

Statement balance: the fixed balance from the provider, recorded for a closed cycle.

Remaining statement amount due: what's still unpaid on that cycle after the payments and credits that apply.

Card credit: an overpayment or extra credit on the card; it isn't liquid cash.

Pending authorizations are for information only until they become recognized posted activity. A pending authorization is never treated as a finished purchase or a statement entry.

The ordinary expense form stays the main place to enter purchases. Choosing a card can reveal card-specific details as needed, like the posting state and date, the provider's reference or installment information. A dedicated Credit Cards area still manages what's specific to cards: liability, statements, reconciliation, payments, utilization, fees, interest, refunds, installment plans and history. It's not a second expense tracker.

Statement values are verified by hand at first. Closing or recording a statement creates evidence from the provider, not another purchase or liability posting. Statement corrections keep their versions. The remaining statement due comes from the verified statement and the payment and credit allocations that apply; it can't be edited on its own.

Don't assume payment allocation, interest, minimum payments, which statement a charge belongs to, installment maths or available-credit rules are the same across issuers. What the provider confirms, and the evidence the user gives, win over any guessed formula.

A card installment plan links the original recognized purchase to the obligations the provider confirmed. Just choosing a number of installments must never make the app invent interest, fees, a total repayment or the provider's due-date rules.

Refunds lower the spending and card liability they apply to, or create or raise a card credit where that's right. Link them to the original purchase where possible. Card fees and recognized interest are separate expenses.

Utilization can be shown as the eligible outstanding balance divided by the eligible credit limit, with the date of that balance stated. A missing or zero limit is handled without dividing by zero. Across cards, utilization is total eligible outstanding balances divided by total eligible limits, not the average of each card's percentage. Credit balances don't count towards credit used. Available credit stays an estimate and is never cash.

A purchase can also be part of Shared Expenses. For example, someone pays a restaurant bill by card and splits it with friends. The purchase, the card liability, their own share and the group receivable stay linked, without entering anything twice and without showing their private card details to the rest of the group.
#### 6.8 Reconciliation and corrections

Users can compare the app's balance with a real account or provider statement on a date they pick. The app shows the difference and helps look for missing entries or duplicates.

If the user chooses a balance adjustment, it needs an amount, a date and a reason. Adjustments are shown separately in reports; an unexplained correction isn't automatically income or an expense.

Posted financial records are corrected with traceable revisions or reversals. A simple audit trail is enough at first; a complex event-sourcing system isn't needed. Backdated corrections update every affected balance and report consistently.

#### 6.9 Planning and recurring obligations

Later planning features: category budgets, expected cash flow, recurring income and bills, subscriptions, and savings goals or sinking funds.

A recurring definition creates expected occurrences. Completing one records or links an actual transaction; reaching its due date never assumes it was paid. Skipping an occurrence is supported, and so is changing just one occurrence or all future ones.

A savings goal sets aside part of your tracked money on paper. It never creates a second asset or copies the account balance. Goal allocations are shown apart from the real account balances, and the same money can't be allocated beyond the allowed total.

Cash-flow projections state their assumptions and expected dates, and stay separate from actual reports.

For a monthly recurrence on the 29th, 30th or 31st, there's an explicit rule to choose, like using the last valid day in shorter months. A provider's due date never moves for weekends or holidays without a confirmed rule. Before saving a recurrence you see its next few occurrences.

#### 6.10 Optional future financial extensions

Money you've lent someone is a receivable, not the same as money you owe a lender. A future lending tracker would record the cash given, the outstanding receivable, repayments and any explicit write-off. Being repaid principal you lent isn't earned income. Untracked or uncertain receivables never count as available cash, and the app says whether they're in the tracked net position.

Other later extensions could include employer reimbursements and noncash assets tracked by hand. Each needs its own reporting rules first. Group shared expenses are a required module of the finished product, described below.

#### 6.11 Shared expenses and settlements: Splitwise / Settle Up reference

A shared-expense and settlement system inspired by **Splitwise** and **Settle Up**: record who paid, split costs between participants, show who owes or is owed, and record repayments. It's a separate way of managing debts from lender loans, interest-bearing installments and credit-card statements.

Product references: [Splitwise](https://secure.splitwise.com/), [Settle Up](https://settleup.io/), and [Splitwise's debt simplification explanation](https://kb.splitwise.com/balances-and-expenses/what-is-simplify-debts). These are where the idea came from; the requirements below are how this project should behave, not a promise to match either service feature for feature.

##### Groups and privacy

- Create groups like Family Household, Brothers, Vacation or Shared Apartment. A two-person group covers a one-to-one shared bill.
- Invite registered users through a controlled invitation they accept. Being in a group doesn't expose unrelated private data.
- Optionally add someone who isn't registered, by display name. They have no private ledger and get no automatic notifications, and their entries are clearly marked as recorded by hand. Linking them to a real user later takes acceptance and a balance review, not a match on name alone.
- Owner and member roles. Owners manage membership and settings; members record and review the group activity they're allowed to. Group owners can't look at private accounts and aren't platform administrators.
- Members see the group's expense and settlement history, and the app explains that when they join. Shared receipts and comments should only hold what's appropriate for the group.
- Leaving or being removed keeps the history and doesn't forgive balances. Former members get read-only access to history, and no new activity under their membership. Finished groups are archived, not erased.

##### Bills and allocations

A shared expense has a group, description, date, currency, total, what each payer put in, the participants chosen, each person's share, a category, notes, an optional receipt, who created it and its change history.

V2 supports one payer or several for the same shared expense. One payer stays the simple default, and more payers can be added when needed. Each payer has an exact amount they put in.

What payers put in and what participants' shares are measure different things:

a payer can put in more or less than their own share;

a payer might have no share at all;

a participant can have a share without paying anything;

only some of the group's members might be in a given bill.

For every finalized bill:

sum(payer contributions) = expense total
sum(participant shares) = expense total

Both have to hold, each on its own, exactly.

V2 starts with equal and exact (custom) splits between participants. Percentage, weighted and detailed itemized splits can follow later unless I pull them into scope.

Exact centavos, with the rounding previewed. PHP 100 split three ways becomes PHP 33.34, PHP 33.33 and PHP 33.33, and who gets the extra centavo is shown and kept.

Groups start PHP-only. Bill fees can be shared or given to one person explicitly.

Shared expenses aren't separate little debts that each have to be settled on their own. Each participant's current position comes from all the bills in effect, refunds and confirmed settlements together. Every bill is kept as source evidence, while the group and participant balances are worked out continuously from them.

Debts in opposite directions cancel out in the current balance. If one bill means A owes B PHP 1,000 and another means B owes A PHP 800, then right now A owes B PHP 200. Both original bills stay visible and explainable.

For each person: what they paid, the shares they had, refunds, confirmed settlements, pending settlements and their current net position. Confirmed net positions in a group add up to zero.

Splitting a purchase across categories is different from splitting it between people.

##### Shared-expense example and private financial integration

You pay PHP 1,200 from GCash for dinner with two brothers, split equally:

1. Your share is PHP 400, and each brother's share is PHP 400.
2. When you link the bill to your GCash account, cash goes down by PHP 1,200, your personal spending is PHP 400, and a group receivable of PHP 800 is recorded.
3. Each brother has a PHP 400 group payable. If they accept their part into their own ledger, their personal spending goes up by PHP 400, but their cash doesn't change until they pay.
4. When one brother pays you PHP 400 and the settlement is confirmed and linked, his chosen payment account goes down by PHP 400 and your chosen receiving account goes up by PHP 400. His payable and your receivable both go down; neither of you records another dinner expense, or salary or gift income.
5. The other brother still owes PHP 400. If he pays PHP 150, he has PHP 250 left.

Group records never show anyone's personal balances or bank details. Each user picks their own accounts privately. Adding a group bill never writes into another user's ledger on its own: they accept their part, or use the group module without it touching their personal tracking. Reports say when allocations are pending or unlinked, instead of implying personal records are complete.

Link an existing private purchase or payment instead of taking the money out again. If the whole bill was already personal spending, turning it into a shared bill reclassifies the others' shares as receivables, explicitly, with a preview and history. Group payables and receivables are never duplicated as standalone personal loans. Cash you fronted for the group isn't your own spending, and receivables aren't cash you can spend.

##### Settlements and disputes

A settlement records the payer, recipient, amount, date, group, an optional reference, allocations and a state: proposed or pending, confirmed, disputed, cancelled or reversed. The app records payments made somewhere else; it doesn't move money between banks or wallets.

V2 supports:

settling a current balance in full;

a custom partial amount the user enters;

settling chosen shared expenses;

partly settling one shared expense;

one settlement spread across several shared expenses;

handling an overpayment or advance explicitly, instead of quietly cutting off the extra.

Settlement allocations explain which obligations were cleared. Paying one participant never quietly clears an amount owed to someone else, unless there's an explicitly supported, agreed path for redirecting the payment.

With registered participants, a reported payment stays pending until the recipient confirms they got it. Pending and disputed settlements don't lower the confirmed group balance.

The interface clearly separates:

the confirmed current balance;

outgoing settlements waiting on someone else;

incoming settlements waiting for the current user to confirm;

the projected balance if pending settlements are confirmed.

Someone who already reported a payment can see that it exists and is waiting for acknowledgement. The recipient can confirm or dispute it. Pending settlements keep their allocations to source expenses, their age and their status.

The payer can record the actual cash they sent privately before the recipient confirms, through the supported private clearing path, so confirming doesn't take the cash out again. The recipient likewise controls their own private receipt and linking. Group confirmation never picks or shows anyone else's private account.

A manual confirmation for someone who isn't registered says who recorded it and states clearly that a signed-in confirmation from the recipient wasn't possible.

Partial repayments are allowed. An overpayment previews the reverse balance or advance it creates, instead of quietly zeroing the obligation. A transfer fee on a settlement is the payer's own expense, unless the group separately agreed to share it.

At first only the expense's creator revises their bill. Owners can flag disputes or propose corrections; they don't quietly rewrite someone else's bill. Edits keep their before and after versions, and the registered participants affected are told. Changing a settled bill takes an explicit correction.

Refunding a shared purchase reverses the participant shares and payer effects it applies to, without deleting earlier settlements. If people already settled, the refund can create new amounts owed back.

##### Netting and settlement suggestions

V2 includes settlement suggestions you can follow the reasoning of, based on participants' current confirmed net positions.

The real source stays the bills in effect, what payers put in, participants' shares, refunds and confirmed settlements. Suggestions are a derived view and never rewrite those records.

For example, if:

A owes B PHP 300;

B owes C PHP 300;

the app might suggest:

A pays C PHP 300.

The suggestion keeps everyone's final net position the same while possibly needing fewer payments.

A suggestion isn't a payment and doesn't change any balance until real settlements are recorded and confirmed.

Don't promise the mathematically fewest payments unless the algorithm actually guarantees it. Present the result as a suggested way to settle.

Netting debts that run directly in both directions is part of working out balances normally. Routing a payment through people who don't owe each other directly right now needs those people's explicit agreement or confirmation. Never simplify across unrelated groups, currencies, private loans or disputed amounts.

Keep the allocations that explain which source obligations a redirected settlement clears.

What matters most: balances you can explain, seeing pending payments, confirmation, linking to private ledgers, exact payer amounts, explicit fee allocation, guidance in context, group reports and reminders each member controls.

The Dashboard keeps lender debt, card balances, group payables, group receivables and pending shared settlements apart. Being in a group never implies owning money together or seeing each other's private money.

### 7. Financial accuracy rules and examples

These are acceptance rules for the product that every later implementation has to keep:

| Action | Spending effect | Cash/liquid-fund effect | Liability effect |
| --- | --- | --- | --- |
| Receive salary PHP 25,000 | None; income PHP 25,000 | +25,000 | None |
| Spend PHP 250 from wallet | +250 | −250 | None |
| Transfer PHP 5,000 with PHP 15 fee | +15 | −15 overall | None |
| Borrow PHP 10,000 into bank | None; borrowing is not earned income | +10,000 | +10,000 |
| Buy PHP 6,000 using credit | +6,000 | No immediate cash movement | +6,000 |
| Pay PHP 1,000 principal plus PHP 100 newly recorded interest and PHP 10 fee | +110 | −1,110 | −1,000 net |
| Repay PHP 1,100 of liability whose interest was already recorded, plus PHP 10 fee | +10 | −1,110 | −1,100 |

A debt-payment summary can show principal and interest so you can see them, but report totals never add the whole payment to expenses again. Report labels make any overlap obvious.

Money maths is exact, like integer centavos or fixed decimals, with defined rounding. All the parts of a financial action save together or not at all. Submitting twice never creates a duplicate transfer or payment. Every linked account, debt and transaction is checked for ownership.

An existing loan imported during setup adds an opening liability, not new income, spending or borrowing in the reporting period. Installments already paid in the past never turn into new payments or reminders.

### 8. Career module: job applications

Company, role, posting URL, where you found it, application date, location, work arrangement, an optional salary range and currency, technologies, contact details, resume version, notes, and the next action and its date. Saved opportunities are kept apart from submitted applications.

Suggested stages: Saved, Applied, Screening, Interview, Technical Assessment, Final Interview, Offer and Accepted. Rejected and Withdrawn are final outcomes. Stages can be skipped, interviews repeated, and changes are kept in history; companies don't all follow one fixed pipeline.

A searchable table, and later a board view. Each application has a timeline of submissions, responses, stage changes, interviews, assessments, follow-ups and outcomes. Stage history keeps both the date of the event and when it was entered.

Interviews and assessments have a scheduled time, a location or link, preparation notes and an outcome once done. Follow-up suggestions are configurable. "No response" is an observation with a date, not an automatic rejection.

Keep a snapshot of the role description or key requirements as the user typed it, since a posting URL can expire. Resume versions record the exact version used, not just the latest resume. A later application to the same company and role can be a separate attempt; the app warns about a possible duplicate without assuming it's a mistake. Declining an offer, an offer expiring and the employer cancelling the opening are separate outcomes. Save the actual dates instead of inferring them from the current stage.

Analytics could include applications submitted, responses, applications that reach interviews, offers, rejections, time in each stage and results by source. The number of interview events is kept apart from the number of applications that got interviews.

Conversion reports define their cohort: for example, applications submitted in September that had a response by October 5. Don't divide this month's offers by this month's interviews if they belong to different applications. An empty denominator reads "not applicable".

### 9. Calendar, timeline, and reminders

#### Calendar and agenda

Debt due dates, card due dates, bills, interviews, assessments, follow-ups, tracker deadlines and personal events you add yourself, all in one place. Start with an agenda, then add month and week views and filters.

Every generated event links to its source. Moving an interview or installment updates its place on the calendar without creating a duplicate. Editing a generated event goes through its source's workflow. Completed, cancelled and overdue events have clear states.

All-day due dates are dates, not midnight timestamps that shift between time zones. Timed events use the user's timezone, Asia/Manila at first. History timelines show what happened; the calendar mainly shows what's scheduled.

#### Reminders

Reminders per event, optional defaults per module, and settings like seven days before, one day before or on the due date. Start with due and overdue indicators inside the app. Scheduled email or push delivery is a later phase, with explicit opt-in and delivery status.

Reminders can be dismissed, snoozed and turned off. Changing the source reschedules or cancels them. Retried deliveries never send a notification twice. An overdue debt reminder stops once the unpaid obligation is sorted out.

Notification settings cover the timezone, quiet hours for external delivery, and whether amounts or company names can appear in a notification on the device. Dismissing a reminder doesn't mark a debt paid or an interview done. Timed events that clash can be flagged, but the app never reschedules them by itself.

Syncing with external calendar providers is outside V3, and deferred until later platform architecture planning designs and approves its permissions, sync direction, conflict handling and deletions. V3 has the internal Calendar and Agenda driven by source records, and the existing reminder behaviour that fits; it doesn't need external calendar providers.

### 10. Generic tracker templates

Templates stretch the platform to learning, books, personal tasks, goals and other structured activities. A template defines the fields; a tracker is one user's copy of a template; entries hold its records.

V3 starts with preset Learning, Books and Personal Tasks templates, then adds templates and custom fields users create themselves. Supported field types are text, number, date, checkbox and single-select. A template can mark fields as required and name a main title, status and deadline field for shared views. Definitions are versioned; entries keep a history that never changes, with validation and explicit safe migrations between versions.

Examples:

| Template | Example fields | Behavior |
| --- | --- | --- |
| Learning | Topic, technology, status, started/completed dates, notes | Progress and deadline view |
| Books | Title, author, rating, finished, completion date | Reading list and completed count |
| Personal tasks | Title, priority, status, due date | Calendar and reminders |
| Habits, later | Habit, frequency, target, dated check-ins | Needs actual check-in history for streaks |

Financial subscriptions belong with recurring obligations. A template could link to them later, but never keeps a competing financial balance of its own. In the same way, the specialized application tracker stays the real record for job pipelines.

Templates and custom fields users create are part of V3; richer relations and sharing templates stay later extensions. Editing a template keeps existing entries or offers an explicit migration, and removing a field never quietly throws data away. V3 also includes tracker reports and statistics, internal Calendar and Agenda deadlines and reminders, and the onboarding, navigation, exports, lifecycle, accessibility and security work that goes with them. Arbitrary formulas, scripting, a general page builder and habit streaks are outside V3.

### 11. Reports

One period-based reporting system for **weekly, monthly, quarterly, yearly, and custom date ranges**. At first, calendar quarters, a configurable start of the week and the user's timezone.

#### Financial reports

Income, recognized expenses, category breakdowns, fees, interest and penalties, refunds and rebates, external cash in and out, borrowing, debt payments, opening and closing tracked liquid funds, liability changes and tracked net position. Later: budget comparisons, card utilization, savings-goal progress and forecasts.

Spending and cash flow stay separate: a card purchase is spending today but cash later, and borrowing is cash but not income. Internal transfers are shown for reference and left out of combined cash-flow totals.

The reconciliation identity for tracked liquid funds:

`Closing funds = Opening funds + External cash inflows − External cash outflows + Explicit balance adjustments`

Internal transfers cancel out in the combined total. Fees stay external outflows. "Income minus expenses" is never labelled cash flow when there are financed purchases, borrowing or principal repayments.

An example cash-flow report, with the categories deliberately kept apart:

| Item | Amount |
| --- | ---: |
| Opening liquid funds | PHP 24,500 |
| Salary received | +PHP 30,000 |
| Cash spending excluding debt costs and fees below | −PHP 12,400 |
| Debt principal repaid | −PHP 4,500 |
| Debt interest paid and newly recognized | −PHP 500 |
| Transaction fees | −PHP 185 |
| Net cash change | +PHP 12,415 |
| Closing liquid funds | PHP 36,915 |

In this example, recognized expenses come to PHP 13,085; the principal repaid isn't one of them. Real reports also have to account for any credit purchases, borrowing, noncash changes and adjustments there are.

#### Career and tracker reports

Application activity, cohort conversion rates, upcoming actions, finished learning topics and the tracker counts that apply. A yearly personal review can bring together financial trends, career milestones and goals without pretending unrelated measures share one score.

Reports show the date range, filters, currency, how much data they cover, how they're calculated and an "as of" time. Missing history is called out. Totals link to the records behind them. Start with on-screen reports and CSV export; printable or PDF reports can follow.

### 12. Onboarding and tutorial experience

The finished app should teach people how to use it, starting from what they want to do rather than a tour of every button.

#### First-use setup

1. **Choose a starting goal.** Track money, organize job applications, or both. The app explains other modules can be turned on later.
2. **Confirm preferences.** Timezone, currency, start of the week and optional reminder settings.
3. **Add the first account, if using Money.** Enter its current balance and the date that balance is from. The app explains why this is an opening balance and not income.
4. **Record one real transaction.** Enter an expense or income and look at the balance before and after. A transfer with a fee is offered as the next lesson.
5. **Add existing debt, optionally.** Enter what's left to pay, the schedule if known and the next unpaid due date. No need to rebuild the full history.
6. **Add a credit card, when supported and applicable.** The app explains outstanding balance against statement balance, and records the latest verified statement.
7. **Add one job application, if using Career.** Company, role, stage and the next action. Add an interview or follow-up date.
8. **Review the agenda.** See how records turn into deadlines by themselves, and how to open the original record.
9. **Choose reminders.** The difference between in-app alerts and optional external notifications.
10. **Review the dashboard and first report.** Reports get more useful as real records build up.
11. **Explore optional trackers and planning tools.** Only once the core workflow makes sense.

When shared expenses come out, there's a guided flow: create or join a group → review privacy → record a bill → choose payers and participants → preview shares → review balances → record or confirm a settlement → optionally link your own account. Joining a group never means sharing your personal workspace.

People can skip optional steps, save their progress and come back later. Career-only users skip the financial setup. Features that aren't out yet never appear as required onboarding steps.

#### Ongoing guidance

- A "Getting started" checklist stays available until it's done or dismissed.
- Empty states show the next useful thing to do and a short example.
- Help in context explains fees, transfers, partial payments, statements and reconciliation.
- A Help/Guide area has short task-based instructions and a tour you can replay.
- An optional demo workspace uses separate sample data, clearly labelled, with a safe reset that only touches demo records.
- Destructive or consequential actions explain what they'll do before you submit, especially settlements and financial corrections.

#### Suggested routine

**Daily:** record spending, update applications and check upcoming commitments.  
**Weekly:** reconcile accounts, review follow-ups and check the weekly report.  
**Monthly:** check obligations and statements, and review financial and career trends.  
**Quarterly/yearly:** review progress and adjust goals using the history you have.

### 13. Main screens

The [approved redesign frame](archive/web/COMPREHENSIVE_UI_UX_REDESIGN_PLAN.md#6-application-frame-navigation-and-shared-interaction-contracts) uses **Home** (the current Dashboard route), an integrated module switcher, contextual actions and local section navigation instead of a permanent global sidebar. The directory lists Money, Career, Calendar, Trackers, Shared expenses when it's turned on, and Reports; More/Account has Getting started, Settings and Help. On mobile, labelled Home / Calendar / Modules / More navigation. Current routes, capability flags and contextual source links all stay.

Shared expenses has its own directory entry and navigation inside each group for the group list, details, bill entry, member balances, settlement history, invitations and settings that are built. Money still owns the private financial side; where something sits in the navigation doesn't change group or private authority. Group reports show total bills, each person's share, advances, confirmed repayments and remaining balances; personal reports include only that user's own posted private-ledger effects. Group and personal totals are never added together as if they were separate spending.

The Money pages built are accounts, the ledger, transaction details and entry, debts and schedules, reconciliation, cards, budgets, goals, recurring obligations and forecasts. Career has the application list, application details and timeline, and analytics. Reports share the same period and filter controls.

The redesign reorganizes how things look and where they sit, without changing what modules can do or their business rules. Its approved visual spec covers colours, typography, density and adaptive list and detail layouts; this document doesn't repeat that system or approve new features or a native architecture. Put a responsive interface first, good enough to enter an expense or update an application on a phone. Readable labels, keyboard-accessible forms, visible validation and status indicators that don't rely only on colour.

Saving, saved and failed states are visible, and form input you can recover survives an error. The web development and verification environment stays online through V3 and the redesign. If a connection fails, the app shows that the action wasn't confirmed; it never implies it's safely stored. Mostly-offline Windows and Android behaviour, syncing between devices and packaging need their own approved platform architecture later; they aren't V3 work and aren't a decision to build a PWA.

### 14. Scope and delivery sequence

The full vision is a roadmap, not a promise to build every later idea. The first usable slice and the V1, V2 and V3 stages below are finished under their documented acceptance scopes, and the historical handoffs keep that evidence. M1 foundations are finished, with final visual approval on October 17, 2026 (Asia/Manila). M2 is ready to start on its own and hasn't started. Later stages need their own pieces of work; the current web environment stays through the redesign, and releasing it to production is no longer planned.

| Stage | Deliverable | Release boundary |
| --- | --- | --- |
| First usable slice | Sign-in, settings, accounts, income/expense/transfer with fees, account history, basic application list/stages, agenda, short onboarding | Reliable daily tracking for money and job search |
| V1: coherent core | Debts with manual schedules, partial payments and explicit settlement/adjustments, reconciliation, connected dashboard, period reports for all requested intervals, in-app due indicators, history, CSV export | Complete core workflows with financial accuracy and user separation |
| V2: financial maturity | Credit cards/statements, recurring obligations, budgets, savings goals, forecasts, richer career analytics, scheduled opted-in notifications | Card and planning workflows verified with realistic cases |
| V2: shared expenses and settlements | Groups for family/friends/roommates/trips, registered/manual participants, one or multiple payers, equal/exact splits, net balances, partial/full/selected-expense settlements, pending confirmation, settlement suggestions, private ledger links | Participants can record and settle realistic shared spending without exposing private data or duplicating financial effects |
| V3: adaptable trackers | Learning, Books and Personal Tasks presets; versioned custom templates/fields, validated entries/history and safe migrations; reporting/statistics; internal Calendar/Agenda, reminders and relevant cross-domain integration | Existing records survive customization; external calendar synchronization, offline support and platform packaging are excluded |
| Comprehensive UI/UX Redesign | M1 completed and finally approved October 17, 2026; M2 ready to start as its own piece of work; M2-M6 not started | Preserve all V1–V3 behavior; targeted change-impact checks and final redesign-wide acceptance, unchanged CI |
| Platform Architecture Planning | Reassess features, infrastructure and architecture for Windows/Android, mostly offline personal use and selected online synchronization/collaboration | Approve the replacement architecture before implementation; no binding technology selection yet |
| Windows/Android Development → Platform-Specific Acceptance | Implement and verify the subsequently approved platform plan | Separate assignments and acceptance criteria; no current web production-readiness prerequisite |
| Later, selectively | Receipt OCR, suggested categorization, import integrations, investments, multiple currencies, shared workspaces, annual-review exports | Added only for a demonstrated user need and supportable accuracy |

Tutorials and contextual guidance grow with each release. They're part of the product, not a last task after every feature is built.

The finished V3 had four internal milestones: **V3-A — Tracker Foundation and Presets; V3-B — Custom Templates and Versioned Migrations; V3-C — Reporting, Calendar, and Cross-Domain Integration; V3-D — Consolidated Acceptance and Documentation**. I delivered them in two pieces of work. The second one explicitly swapped the big verification campaign I'd first proposed for approved change-impact verification; the [handoff](archive/web/V3_DEVELOPMENT_HANDOFF.md) and the [targeted acceptance matrix](OPERATIONS_AND_RELEASE.md#v3-change-impact-acceptance) are where the actual results are. The historical V1–V3 evidence supports behaviour that didn't change; it doesn't certify future redesigned screens. M1–M5 verify the UI and contracts that changed or were affected; M6 covers the whole redesign: screens, navigation, themes, responsiveness, accessibility, consequential workflows and changed performance. Only widen testing for changed shared contracts, failures or serious security or financial risks, and keep the mandatory assertions and the existing CI.

Deferred to start with: automatic provider fee lookup, bank connections, making payments, automatic loan settlement calculations, credit scoring, AI financial advice, collaborative editing and a fully general no-code builder. The app records and organizes information; actually making bank payments would be a separate product decision for the future.

More release boundaries: V1 has separate sign-in accounts and private workspaces for several users, category splits, entering a loan's net disbursement, manual schedule revisions, recovery, and controls over the account and data lifecycle. V2 can add supporting-file uploads, CSV imports and portable workspace export and restore. Credit-card purchases fit into the existing expense entry, while card-specific statements, payments and liability stay specialized. Shared Expenses and Settlements support family, friends, roommates, trips and other groups: group receivables and payables, one or more payers per bill, equal or exact shares, netting debts in both directions, partial, full and selected-expense settlements, pending recipient confirmation and settlement suggestions you can follow. Percentage, weighted and itemized splits, general standalone lending, mathematically optimal settlement minimization, money in transit, refinancing, funding a split from several private payment accounts, and offline sync stay for later unless I pull them in. The core refund and correction rules apply once the matching transaction type is out.

### 15. Conceptual model and engineering boundaries

Possible concepts, to be refined in a separate data-model document:

- **Shared:** User, Preferences, Category, Tag, Activity, Reminder.
- **Group expenses:** ExpenseGroup, Membership, Invitation, Participant, SharedExpense, PayerContribution, ParticipantShare, GroupSettlement, SettlementAllocation, PrivateLedgerLink, Dispute.
- **Money:** Account, FinancialAction, LedgerEntry, Adjustment, Reconciliation.
- **Debt:** Debt, ScheduledInstallment, PaymentAllocation, Settlement.
- **Cards:** CreditAccount, Statement, StatementEntry, PaymentAllocation.
- **Planning:** RecurringObligation, ExpectedOccurrence, Budget, SavingsGoal, GoalAllocation.
- **Career:** JobApplication, StageHistory, ApplicationEvent.
- **Time:** PersonalEvent and calendar projections from source records.
- **Trackers:** TrackerTemplate, FieldDefinition, Tracker, TrackerEntry.

A debt payment is one financial action linked to its allocations, not two separate records both taken out of cash. The calendar projects dates from their sources instead of owning its own copy of each deadline. Financial history and general activity history are related but do different jobs.

Start with one app split into clear modules and one transactional database. A modular monolith is enough; microservices aren't needed at this size. The current web stack is set out in [System Architecture](ARCHITECTURE.md#system-architecture) and stays through the redesign. No native replacement stack gets picked until the separately approved platform architecture phase after the redesign.

### 16. Quality, privacy, and trust

- Each user's data is isolated, and access to linked records, reports and exports is checked.
- Group membership and role permissions are checked separately from who owns private records, including files, notification recipients, exports and invitations. Changes to membership take away access that's no longer right.
- Secure authentication and session handling. Never ask for bank passwords, wallet PINs or full card credentials for manual tracking.
- Sensitive data is protected in transit and in storage, and private financial and contact data stays out of ordinary logs and public demo data.
- A correction history you can explain, while still supporting deleting your data on purpose under a defined retention policy.
- Data is backed up and restores are verified; practical exports, with a clear explanation of what they cover.
- Amounts, required fields, dates, currencies, allocation totals and duplicate requests are validated.
- Missing provider details are shown as missing, not guessed.
- Consequential actions get confirmations, and ordinary mistakes have clear ways back.

#### Account lifecycle and data ownership

Registration, sign-in, sign-out and a secure recovery path that fits the sign-in method chosen. Users can update their profile and revoke active sessions. The authentication details can be decided later, but losing access needs a defined way back.

Archiving and deleting are different. Archived applications and trackers keep their history. Financial corrections keep their linked evidence, and removing an ordinary record never leaves orphaned calendar events or reminders. Deleting a whole workspace needs a preview of exactly what goes, a confirmation, and a stated policy for backups that are kept and when they expire. Don't promise instant removal from every backup if that's not how the product works.

#### Imports, exports, and restoration

V1 CSV exports say clearly which records and fields they contain. A report export isn't a complete backup. A later portable workspace export would cover the supported records, relationships, template definitions and version information needed to restore, and say clearly how attachments are handled.

CSV import starts with supported formats and a preview showing field mappings, how dates and currency are read, totals, invalid rows and likely duplicates. Ambiguous date formats are never guessed and existing data is never overwritten quietly. Imported, skipped and failed counts are shown, and retrying the same import never duplicates confirmed records. Starting from opening balances and importing history also needs a cutoff rule so past transactions aren't counted twice.

Restoring a workspace previews whether it makes a separate workspace or replaces existing data. Restores the user controls and disaster recovery on the service side are different workflows, and both need verifying.

#### Supporting records and attachments

V1 can store notes and reference links. Later, receipts, provider statements, settlement confirmations, resume versions and assessment documents can attach to their source record. File types and sizes are limited, access is private, and retention and export behaviour is defined. A private file is never exposed through a public link by default. Uploaded files are evidence; they don't change balances or application stages by themselves.

#### Operational expectations

The existing production and manual-configuration checklists stay as historical, conditional operational requirements. They don't require setting up external services or finishing a launch of the current web app. Local verification and every integrity, privacy, authorization, security and recovery guarantee that applies carry on; operational requirements for the future platform get designed during architecture planning.

Set measurable performance and storage limits before launch, using a realistic dataset covering several years of personal use. Large histories need search, filtering and pagination. Failure messages say what to do, and there's a way to get support or give feedback. Failures in report generation and reminders have to be detectable without logging sensitive contents. Agree on how often to back up and what recovery to expect before storing real user data.

### 17. Acceptance scenarios

Before calling the coherent V1 complete, check that a user can:

1. Start with two accounts, record a transfer with a fee, and see balances that agree and spending that's only the fee.
2. Record income and expenses, then reconcile the app against a real balance with a correction they can explain.
3. Import an existing debt without duplicating past borrowing or payments.
4. Record partial and full debt payments without counting principal as spending twice.
5. Settle a debt early, keep its schedule and history, handle a confirmed waiver properly, and clear future unpaid reminders.
6. Follow an application through several interviews and create calendar events without duplicating source records.
7. See weekly, monthly, quarterly and yearly reports that use the same definitions, and inspect the details behind them.
8. Finish or skip onboarding, come back to it, and replay the relevant help without creating data by accident.
9. Correct a backdated entry and see every affected balance and report update together.
10. Reach only their own records, including when trying to point at someone else's account or application.

11. Split a purchase between categories while keeping one financial deduction and correct report totals.
12. Record loan proceeds net of an upfront fee without calling the borrowing income or doubling the fee.
13. Revise a debt schedule while keeping the earlier terms and payment history, and updating future reminders.
14. Get access back through the supported sign-in recovery and revoke an existing session.
15. Turn a module off and on again without losing its records, and review exactly what goes before deleting the workspace.
16. Hit a failed save without being told it succeeded, and without the action being duplicated on retry.
17. Record PHP 10,000 salary into a chosen BDO account with an opening balance of PHP 2,000, and see PHP 12,000 in that account, PHP 10,000 more income for the period, and no change to other accounts.
18. Record a PHP 500 gift into a chosen GCash wallet holding PHP 200 and see PHP 700 there, with a linked gift income record. Recording it as borrowed money instead has to raise that wallet and the debt without raising earned or gift income.

For the credit-card release, also check purchases, closing a statement, partial payments, refunds, fees, overpayments and installments. For generic trackers, check field validation and that existing entries survive template changes.

For later imports and portability, check how ambiguous dates are handled, duplicate detection, historical balance cutoffs and restoring relationships. For supported refunds, check that a partial refund in a later period changes that period's refund totals while keeping the original purchase's history.

For the family shared-expense release, check that:

1. Two family users have their own logins, and neither can read the other's private data even when they share a group.
2. The PHP 1,200 dinner example gives PHP 400 shares, a PHP 800 receivable for the payer, and consistent cash and spending without duplicate ledger records.
3. Partial, pending, confirmed, disputed, reversed and overpaid settlements all leave balances you can explain.
4. People who aren't registered have clearly marked manual history and can't be quietly merged into a real user's identity.
5. Rounding, refunds, corrected settled bills and leaving a group keep the history and keep group net balances at zero overall.
6. Once simplification is out, suggestions keep each person's net position and the original bills, and don't apply without agreement.

### 18. Success and portfolio value

Success means the main user can use the app in daily life, explain balances and reports, see what to do next, and keep using it without falling back on scattered notes for the same jobs. Measure finished onboarding, repeat use, reconciliation differences and whether due items get resolved; set number targets after a first period of use.

As a portfolio piece it should show coherent business rules, relational data modelling, transactional consistency, authorization, validation, date handling, reporting and a useful interface. A small deployed product with realistic demo data and workflows that are verified is worth more than a long list of half-done modules.

Build in focused sessions alongside job applications. Each session should end with something concrete: a workflow, a fixed rule, a reviewed screen or a meaningful check. Put a feature off if it's blocking the next usable release.

### 19. Decisions to make next

**Current next step — October 17, 2026:** start M1 on its own, using the approved redesign documents. D01/D03/D04 and the working identity are settled; final branding and F01–F07 stay deferred and don't block anything. I've kept the initial planning checklist and the table of proposed choices below as the historical reasoning behind the product, not as open prerequisites for M1. The contracts built in V1–V3 and the accepted handoffs replace their original tentative wording; don't reopen them or read new features into this list.

1. Choose the first usable slice and its exact user stories.
2. Define report terminology and how known and unposted interest are treated.
3. Decide which debt types and schedule behaviours V1 supports explicitly.
4. Design the account, transaction, debt-payment, application and agenda screens.
5. Create the data model and financial invariants before building balances.
6. Choose the stack, hosting, authentication approach and backup strategy.
7. Write a development backlog with acceptance criteria and a small release boundary.

#### Historical initial product decisions

These were the first questions for the releases they affected. For how things work now, use the accepted implementation evidence, and scope any genuinely new extension on its own:

| Decision | Proposed starting position | What must be confirmed |
| --- | --- | --- |
| Expense recognition and reports | Record spending at purchase/charge; report actual cash movement separately | Detailed rules for interest recognition, cashback, and corrections |
| Debt coverage | Manual provider amounts/schedules with known allocations; explicitly show unknown breakdowns | Supported debt types and handling of payments without a breakdown |
| Financial changes | Traceable corrections with reasons | Which posted fields can be revised directly versus reversed |
| Reminder delivery | In-app indicators first; external delivery opt-in later | Channels, overdue cadence, quiet hours, and delivery expectations |
| Historical setup/import | Opening balances as of a chosen cutoff date | Whether earlier history is imported and how it avoids duplication |
| Account/data lifecycle | Separate sign-in and private workspace per family user; explicit group sharing only | Recovery method, deletion retention, backup/restore scope, preservation or anonymization of shared history on user deletion |
| Shared expenses | One payer, equal/exact splits, confirmed settlements, explicit private-ledger linking | Invitation/role policies, historical access, disputes, and private-ledger correction behavior when group records change |
| Uploads and growth | Notes/links first, private uploads later | Supported formats, file limits, dataset targets, and costs |

This historical table doesn't override rules that are built, and doesn't promise every option. New changes need an explicit scope and updated requirements before they're built; it doesn't approve any native-platform choices.

What I'm aiming for is one connected personal workspace that grows with the person using it, from job hunting and everyday spending to managing credit, recurring responsibilities and long-term goals.

## V1 user guide

After registering, use the verification email and then sign in. Password recovery uses a short-lived link and signs out existing sessions once the reset succeeds. Settings → Sessions shows the current session and the others, and can revoke them one at a time or on all devices.

Onboarding can be skipped, picked up again from the Dashboard, or replayed from Help. Replaying the guidance doesn't recreate records. Theme, timezone, start of the week and modules are in Settings. Hiding a module keeps its records, and bringing it back restores access. Sources from hidden modules still appear in Agenda as their source contract says, and can offer to restore the module.

Open accounts with a confirmed opening cutoff and balance. Record salary and gifts as income into the account you choose. Borrowing raises cash and debt and isn't income. A transfer moves money between accounts; only its recognized fees count as spending. An expense can have several category allocations while taking cash out once. Check the exact effects before confirming. A transaction that takes an account below zero needs an explicit acknowledgement, recorded with its evidence.

Import existing debts using the recognized opening liability and only the dates and history you give. The import doesn't create past cash payments or expenses. The accounting parts of a payment and the contractual due allocations answer different questions. Confirm the allocation shown when you record a payment; don't guess accounting parts you don't know. External fees don't count towards installments. An accounting payment you're unsure of goes to clearing until it's sorted out.

Schedule revisions keep the old schedules and historical allocations. Settling a debt needs an explicit payoff, confirmed waiver or charge information, and the accounting resolved. Avoided future charges aren't the same as reversing a recognized expense. No reminder control pays or settles a debt.

Reconciliation compares the tracked balance at a cutoff with a balance you observed. A difference doesn't change the account by itself. Explicit unexplained adjustments use adjustment equity, not income. Later or backdated financial changes can mean a comparison needs reviewing again. Correct what a posted record means with a reason, through a reversal and a replacement; the original evidence stays. A real later refund of a purchase keeps the purchase and uses the refund's date, without becoming income.

Career applications keep their stage and event history. Repeated interviews, assessments and follow-ups are each their own occurrence. Agenda shows the real deadlines; it doesn't copy them into editable Calendar events. Dismissing or snoozing a reminder is separate from completing its source. Reports use shared period definitions, exact posting classifications and drill-downs to the details. CSV export descriptions say what they cover and the dates; an export isn't a workspace backup.

If a save isn't confirmed, keep the form open and retry the same save. If your sign-in has expired, sign in again in another tab before retrying. Don't create the action again while the first attempt might already have gone through.

Settings → Data lifecycle previews everything that deleting the account and workspace would remove. Deleting needs a recent password check, an explicit acknowledgement and the exact confirmation text. A seven-day grace period lets you cancel. The separate lifecycle operator removes live records in steps that can resume. Backups that are kept may still hold older records until their configured retention period actually runs out; deleting isn't a promise of instant erasure from backups. Help has guidance and the configured support or feedback destination.

## Adaptable Trackers workflows

Open **Trackers** from the main navigation. Start with Learning, Books or Personal Tasks, or publish a template of your own. Every template and entry belongs to the current private workspace. Settings can hide Trackers without deleting records; Calendar visibility and reminders are separate preferences.

### Templates and entries

Custom fields can be text, exact decimal numbers, civil dates, checkboxes or one select choice. Set the title, the optional status and deadline, and the completion mappings. Review a version before publishing it. Stable ids keep the history when labels change; removed fields and options are retired. Published definitions and entry revisions never change. Edits create a successor with a reason and reject stale concurrent changes. Archiving and restoring keep the history.

A changed definition never quietly transforms an existing tracker. Open its migration section, choose mappings, defaults and conversions, and review the counts, samples and links to invalid entries. Confirm the reviewed plan, which then runs in batches of at most 50. Confirmed work pauses ordinary edits. Cancelling keeps the batches already committed; resume the same partial plan to finish it. The tracker only moves to the new version once every entry is resolved.

### Reports and Calendar

**Reports and statistics** covers week, month, quarter, year and custom ranges (366 days at most). Current entries and progress are a snapshot taken when you ask. Activity in a period comes from the recorded revisions, which never change, in the workspace's timezone. A completion date typed in by hand is a field value, not an event timestamp. Creating an entry that's already complete counts as a creation; completing or reopening it later counts once per recorded change. Migration revisions use their command evidence and are reported separately from user activity.

Completion progress leaves out definitions with no compatible completion mapping. Version coverage shows which definitions current records and activity use. Choosing archived items uses the current archive state of the entry or tracker; the report doesn't rebuild what was archived at the end of a past period. Current details and historical activity link to the entry and history pages you own. CSV exports the chosen current and activity rows with period, timezone and version details and formula-safe text; it isn't a backup. Narrow a selection that's above 10,000 entries or 20,000 activity revisions.

Mapped, incomplete, active deadlines appear once each as date-only sources in the Calendar. The entry stays the real record; edit its linked source to move the deadline. Completing or archiving removes the source, and reopening or restoring creates a current generation. Template mappings can remove or change a source. The workspace's civil dates are kept the same across timezone display boundaries, and nothing syncs with external calendars.

Open **Deadline reminders** on an entry for inherited, override or off settings, dismissing, restoring or snoozing. Hiding something from navigation doesn't turn its reminders off. Delivery still follows the module's reminder settings, explicit notification consent, quiet hours, a verified identity and the source's current generation. Messages leave out private entry titles. Completing or archiving, and stale generations, cancel pending work; history restored from a provider never justifies sending something again.

### Export, replacement and account deletion

Settings → Portability includes all nine tracker tables: templates, versions, identities, field definitions and options, tracker instances, entries, revisions and migration evidence. The existing 10,000-row and 10-MiB graph limits cover every domain. Strict typed validation checks definitions, normalized values, current and predecessor relationships, migration evidence and evolution rules before the preview and again before replacing. Literal dynamic field values don't change while owners and UUIDs are remapped.

Original V2-H and V2-I graph fingerprints stay supported, with their exact original provenance; a graph with no trackers means replacing them with an empty set. Existing financial balance checks, the requirements for trusted shared history in your own workspace, attachment bytes being left out, and external effects being kept are all still enforced. A privileged replacement keeps a 24-hour recovery graph and resets notification consent. Migrations that were running or had failed in a restore become cancelled; a partial migration keeps its editing locks until it's explicitly resumed. Plans that were only previewed can be reviewed fresh after remapping.

The account deletion preview includes tracker records. The existing lifecycle guard blocks writes once deletion starts, and the controlled purge removes all nine private tracker tables while keeping other owners' data and shared group evidence. Full environment backup drills are separate from these verified graph replacement and recovery paths.

See [targeted acceptance](OPERATIONS_AND_RELEASE.md#v3-change-impact-acceptance) and [deferred gates](OPERATIONS_AND_RELEASE.md#v3-manual-actions-and-deferred-gates) for the evidence and its limits.
