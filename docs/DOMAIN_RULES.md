# Domain rules

## Contents

- [Debt payment scheduling and urgency](#debt-payment-scheduling-and-urgency) (from `docs/salapiya/DEBT_SCHEDULE_URGENCY_HANDOFF.md`)
- [V2 Credit Cards and Statements](#v2-credit-cards-and-statements) (formerly `docs/reference/v2/CREDIT_CARDS_AND_STATEMENTS.md`)
- [V2 Shared Expenses and Settlements](#v2-shared-expenses-and-settlements) (formerly `docs/reference/v2/SHARED_EXPENSES_AND_SETTLEMENTS.md`)
- [V2-B — Recurring Obligations](#v2-b--recurring-obligations) (formerly `docs/reference/v2/RECURRING_OBLIGATIONS.md`)
- [V2-C — Budgets](#v2-c--budgets) (formerly `docs/reference/v2/BUDGETS.md`)
- [V2-D — Savings Goals](#v2-d--savings-goals) (formerly `docs/reference/v2/SAVINGS_GOALS.md`)
- [V2-E — Forecasts](#v2-e--forecasts) (formerly `docs/reference/v2/FORECASTS.md`)
- [V2-F — Richer Career Analytics](#v2-f--richer-career-analytics) (formerly `docs/reference/v2/CAREER_ANALYTICS.md`)
- [V2-G — Scheduled Opted-In Notifications](#v2-g--scheduled-opted-in-notifications) (formerly `docs/reference/v2/SCHEDULED_NOTIFICATIONS.md`)
- [V2-H — Supporting Files, Imports and Portability](#v2-h--supporting-files-imports-and-portability) (formerly `docs/reference/v2/FILES_IMPORTS_AND_PORTABILITY.md`)

## Debt payment scheduling and urgency
### 1. Feature Overview

Debts previously recorded how much was owed but not when to pay. A debt can now
carry a payment schedule (how often, when the next payment is due, how many
payments, and how much each one is). The Debts screen computes from it which
debt to pay first, when it is due and how much to prepare.

Debts may stay unscheduled. They show "Schedule not set", get no invented date
and no default frequency.

### 2. Implementation Details

All logic is in `apps/salapiya/lib/finance/debt_rules.dart` (pure functions; the
screens only format their results).

**Frequencies and recurrence**
- Weekly: every 7 calendar days. Custom: every N days, N a whole number from
  1 to 3660.
- Monthly and Yearly: the same calendar date. When the month is shorter, the
  last valid day is used (31st → 30th or 28th/29th; Feb 29 → Feb 28 in
  non-leap years).
- Every occurrence is computed from the first due date, never from the previous
  result, so there is no drift (Jan 31 → Feb 28 → Mar 31 → Apr 30). Date-only
  arithmetic, no time zones; "today" is the app's existing `civilToday()`
  (Asia/Manila).

**Statuses** (`DebtDueStatus`, computed on every call, never stored):
Overdue, Due today, Due soon, Upcoming, Schedule not set. The repo has no
existing due-soon setting (the Overview's 30-day range is a display window), so
Due soon is 1 to 7 calendar days ahead (`debtDueSoonDays = 7`, a constant, not a
user setting). The UI also shows "Settled" or "Closed" for a debt with nothing
left to pay; these are display labels, not statuses.

**Payment handling** (no change to balance, interest, fee, cashback,
early-repayment or settlement logic; nothing posts money)
- An installment is settled only by an explicit allocation of a payment to it
  (the existing `allocations` field), and only when allocations plus any
  historical paid amount cover its full amount.
- Partial payments leave it as the next installment with a smaller remaining
  amount. Extra money recorded as "unapplied" and unrelated transactions
  satisfy no installment.
- Nothing is allocated automatically, so one payment cannot clear several
  overdue installments. Overdue installments stay listed until each is settled.
- Allocating to a later installment is still allowed (existing workflow); the
  earlier unpaid one stays next and Overdue.

**Schedule editing**
- Dates, frequency and first date: edited with the existing schedule correction.
  The existing rules keep historical paid amounts and every recorded allocation;
  tests confirm postings and payment records are unchanged after an edit.
- Amounts: "Update amounts" (`NativeScheduleAmounts`) changes unpaid payments
  through the same correction. Paid payments are read-only.

**Schedule creation rules (as built)**
- Frequency, next due date and number of payments are required; the "how are
  payments split" choice is disabled until a valid payment count (1 to 120) is
  entered.
- "Divide the debt evenly" takes the total from the debt itself: what is still
  owed on an existing debt, or the amount entered in the same form (borrowing
  includes a financed fee). Leftover centavos go on the last payment.
- "Different amount each time" needs one amount per payment, and the payments
  must add up to the debt exactly. A fixed "same amount each time" option was
  removed; older schedules using it still load.
- The Update amounts page requires the unpaid payments to add up to what is
  still owed.
- A debt and its first schedule are created in one form but saved as two
  records (debt first, then schedule).

**Incomplete or not done**
- Notifications and sync were out of scope and are not touched.
- There is no loan maturity or final-payoff date field in the app. The last row
  of the schedule is shown as "Last scheduled payment", labeled separately from
  the next payment and as not a lender payoff date.
- No "amount to be decided later" state: every payment needs an amount when
  saved. An estimate can be corrected later with Update amounts.
- The exact-total rule does not allow schedules whose total exceeds the debt
  (for example lender interest). There is no opt-in for that.

## V2 Credit Cards and Statements

**Phase:** V2-A  
**Domain:** Finance  
**Status:** Approved product direction before implementation

### 1. Purpose

This sets out the product and workflow requirements for V2 credit cards. It adds to the credit-card sections of `PROJECT_VISION_AND_FEATURE_BLUEPRINT.md`, `SYSTEM_ARCHITECTURE.md`, `DATABASE_ARCHITECTURE.md` and `DESIGN_SYSTEM_AND_VISUAL_GUIDELINES.md`. Every existing rule on financial integrity, ownership, audit, idempotency and exact money still applies. Where this is more specific about the V2 user experience, this wins.

### 2. Product principle

A credit card is a liability with a billing cycle. It's **not** a cash account. But a purchase made with a card is still a purchase, so:

> **Credit-card purchases must integrate with the ordinary expense-entry experience instead of forcing users to enter the same purchase into a separate card tracker.**

Inside, the system can use a card-specific financial command; on screen it's still one coherent purchase workflow.

### 3. User mental model

The app keeps these three things apart, and never presents them as interchangeable.

#### Purchase

You buy something with the card. Spending is recognized, card liability goes up, and no cash moves.

#### Card installment plan

The purchase is under a provider installment arrangement. Its expense is never recognized again every month.

#### Card payment

You move real money from a bank, wallet or cash account to the card provider. The paying cash goes down, card liability goes down, and spending isn't recognized again.

### 4. Unified expense-entry workflow

Add Expense grows so you choose a funding source. Roughly:

```text
Add Expense

Amount
PHP 3,000

Category
Groceries

Paid with
BPI Visa

Purchase date
October 10, 2026

Description
Weekly groceries
```

If the funding source is cash, a bank or a wallet, it's the existing cash expense behaviour; if it's a credit card, it's the card-purchase behaviour. Nobody enters the same transaction again in the Cards module.

### 5. Progressive card options

Choosing a credit card can reveal a collapsed section such as:

> Card details

Normal purchases don't ask for provider fields they don't need. The optional card fields, where they apply, are: the transaction date; the posting date; posted or pending state where supported; the provider's reference; regular or installment purchase; and which statement it's on, when that's known. Advanced details stay tucked away until needed.

### 6. Pending authorizations

A pending authorization isn't posted card activity. It doesn't create recognized posted card liability, never counts in posted statement totals, and is never shown as a finished purchase; if that's supported later, it can be shown for information. Once an authorization posts, the recognized card activity is recorded from the posting information the provider confirmed. Posting dates are never guessed.

### 7. Card purchase accounting

A normal posted card purchase raises its spending category, raises card liability, and doesn't take money out of any liquid account. For example:

```text
Groceries expense     +PHP 3,000
Card liability        +PHP 3,000
Cash movement              PHP 0
```

The financial journal is still the real record. Card activity is linked evidence and a read structure, not a balance anyone edits on its own.

### 8. Dedicated Credit Cards surface

Cards still need a place of their own to manage them, but that place is **not another expense tracker**. It answers questions only cards raise: What's my current posted outstanding balance? What was the latest verified statement balance? How much of that statement is still due? What's the minimum due, and when is payment due? What payments have I made? Which transactions are on this statement? What fees and interest have been recognized? Do I have card credit from an overpayment or refunds? What installment plans are there? What's my utilization estimate?

### 9. Card detail terminology

Card figures never get squashed into one vague "Balance". These are shown separately: the posted outstanding balance; the statement balance; the remaining statement due; the minimum due; the due date; the available credit estimate; utilization; and card credit or overpayment where it applies. Each value says what it's based on, and its date, where that matters.

### 10. Transaction date and posting date

The transaction date and posting date are stored and shown separately. The **transaction date** is when the user made the purchase; the **posting date** is when the provider recognized or posted it. Spending reports keep the documented transaction-date basis for recognized purchases unless an authoritative decision changes it. Which statement a charge belongs to follows the provider's verified posting and cycle information; it's never worked out from a guessed cycle calculation when the provider's evidence says otherwise.

### 11. Statements

A statement is evidence from the provider. Closing or recording one never creates another purchase or another liability. A statement keeps: the card; cycle start and end; the statement date; the due date; the statement balance; the minimum due; the provider's reference where given; verification metadata; and the recognized statement activity linked to it, where known.

Statement values are versioned evidence that doesn't change. A correction creates a new statement revision instead of editing historical evidence in place.

### 12. Statement reconciliation

A provider statement can show up missing or wrong records in the app. The app never invents financial actions just to make the statement match. Differences stay visible until they're resolved through one of: a missing purchase entry; a missing fee or interest; a refund; a payment allocation; opening or import evidence; a correction; or another supported reconciliation action. Provider lines nobody can explain stay visibly unresolved.

### 13. Remaining statement due

The remaining statement due comes from the verified statement and the allocations in effect. It can't be edited on its own, and a payment never changes the original historical statement balance. For example:

```text
Statement balance              PHP 20,000
Confirmed applicable payment   PHP  8,000
Remaining statement due        PHP 12,000
```

The original statement still shows PHP 20,000.

### 14. Card payments

A card payment records real cash moving out of an owned financial account you choose. For example:

```text
BDO cash                  -PHP 10,000
Card liability            -PHP 10,000
Additional spending             PHP 0
```

The original purchase already created the spending, so paying off card principal is never classed as another expense.

### 15. Payment allocations

Where the provider's allocation is known, card payments and credits can be allocated to the statement balances they apply to. Where the provider's rules aren't known, no allocation order is invented. A manual or provider-confirmed allocation keeps its evidence. Any part that's unallocated or uncertain stays visible instead of being quietly guessed.

### 16. Fees and interest

Recognized card fees and interest are separate expenses: an annual fee, a late fee, a finance charge, an installment fee, interest the provider confirmed, or other card fees. A fee or interest expense is never created just because a future installment schedule suggests one; a charge is recognized when there's real provider evidence or a record the user confirmed.

### 17. Refunds

A refund on a card purchase lowers the card liability or creates or adds to card credit, offsets the right spending classification under the established refund rules, links to the original purchase where possible, and keeps the purchase's history. A refund isn't ordinary income.

### 18. Card overpayment

If payments and credits come to more than the recognized card liability, the result shows as **card credit**. It's never shown as negative debt and never counted in liquid funds, and the app never suggests card credit is cash sitting in your bank account.

### 19. Credit limit and utilization

A credit limit is optional provider metadata, and it isn't cash. Utilization can be calculated as:

```text
eligible posted outstanding balance / eligible credit limit
```

Missing and zero limits are handled safely. Across several cards, utilization is:

```text
sum of eligible used credit / sum of eligible credit limits
```

It's never the average of each card's percentage, and card-credit balances are left out of the credit-used numerator.

### 20. Installment purchases

A card purchase can optionally be marked as a provider installment purchase. A regular purchase stays the simple default, and where it fits the user can expand:

> Installment details

Fields the provider might confirm: the number of installments; the expected installment amounts; the first due date; expected principal, interest and fee; the provider's plan reference; and notes. Provider interest and the total repayment are never inferred from the number of installments alone.

### 21. Installment accounting

Creating an installment plan never recognizes the purchase expense a second time. For example:

```text
Laptop purchase
PHP 30,000 spending recognized once

Installment plan
12 provider installments

Future installment records
Scheduling/evidence only

Monthly card payment
Cash/liability movement only,
except newly recognized interest/fees
```

Scheduled amounts don't create financial postings by themselves.

### 22. Integration with ordinary expense history

Card purchases show up in the ordinary expense, history and reporting views next to every other purchase, with filters where they help: payment source, card, category, transaction date, and posting date where appropriate. Nobody should have to open the Cards page to find out what they bought.

### 23. Integration with shared expenses

Once Shared Expenses is out, one real purchase can be both paid by card and a shared bill. For example:

```text
Restaurant bill
PHP 4,000

Paid using
BPI Visa

Split with
You + three brothers
```

The user never enters this twice. The linked domains keep: card liability for the amount actually charged to that user's card; the user's own share of the spending; their group receivable or payable position; the group participants' shares; no duplicate purchase expense; and no duplicate card liability. Other registered participants' private funding sources stay private.

### 24. UI simplicity requirements

Entering an ordinary purchase stays simple. Not every user should need to understand journal entries, statement allocations, liability ledgers, provider reconciliation or allocation formulas; advanced ideas only show up where they're needed. The backend can stay rigorous without making the normal form intimidating.

### 25. Card reporting

Card reporting covers, where they apply: spending by category; spending by card; posted outstanding liability; statement balances; the remaining statement due; payments; interest; fees; refunds; card credits; installment obligations; and utilization. Cash-flow reporting keeps card purchases apart from later card payments.

### 26. Security and ownership

Cards are private workspace data. Every card read and write keeps: the actor and workspace context the server owns; strict workspace ownership; RLS and runtime-role enforcement; rejection of foreign references; safe unavailable and authorization responses; and no ownership ids trusted from the browser.

### 27. Corrections

Posted card financial actions follow the existing correction model, where nothing changes in place and corrections reverse and replace. Statement evidence uses statement revisions. Original purchases, historical statements, allocations and payments are never quietly rewritten, and corrections keep their reason and before-and-after evidence.

### 28. Required acceptance scenarios

Before V2-A counts as complete, check at least:

1. Create a credit card.
2. Record a normal purchase through the ordinary Add Expense workflow.
3. Confirm spending increases and cash does not move.
4. Confirm card liability increases exactly once.
5. Record provider posting information.
6. Record/verify a statement.
7. Link recognized activity to the statement.
8. Record a partial card payment from a selected cash account.
9. Confirm the payment decreases cash and liability without increasing spending.
10. Confirm remaining statement due updates without changing original statement balance.
11. Record a card fee.
12. Record provider-confirmed interest.
13. Record a refund linked to a purchase.
14. Handle an overpayment/card credit.
15. Record an installment purchase without repeating the purchase expense.
16. Correct card activity while preserving history.
17. Reconcile a statement with missing/unknown provider information.
18. Reject foreign-card/reference access.
19. Verify same-command retry/idempotency behavior.
20. Verify reports do not double-count purchases and payments.
21. Verify responsive/browser/accessibility behavior.
22. Verify interaction with Shared Expenses once V2-I integration exists.

### 29. Suggested implementation milestones

These milestone names aren't set in stone; if looking at the repository shows a better boundary, use it.

#### V2-A1 — Card Integrity Foundation

Schema, binding to the liability, ownership, RLS, action kinds, database invariants, and the foundations of the read model.

#### V2-A2 — Card Purchases and Unified Expense Entry

The purchase financial recipe, card activity, the funding-source choice in expense entry, card activity history and reporting classification.

#### V2-A3 — Statements and Reconciliation

Statement snapshots, revisions, statement entries, working out the remaining due, and reconciliation.

#### V2-A4 — Payments, Fees, Interest and Refunds

Card payments, allocations, fees, interest, refunds, and overpayment or card credit.

#### V2-A5 — Installment Plans

Installment schedules the provider confirmed, no duplicate spending, projections of future dues, and revisions where needed.

#### V2-A6 — Integrated V2 Card Surface and Acceptance

The Dashboard, Reports, Agenda and reminders where they apply, full browser acceptance, Shared Expenses integration once that module exists, and regression and hardening.

### 30. Out of scope unless later approved

None of these get added on their own: aggregating bank or card accounts; making payments directly; storing card numbers beyond safe metadata the user defines; storing a full PAN or CVV; provider-specific interest calculators; automatic minimum-payment calculators; automatic credit scoring; provider login credentials; guessed statement allocation rules; universal rewards optimization. Work from what the provider and the user actually show, not assumptions.

## V2 Shared Expenses and Settlements

**Phase:** V2-I  
**Domain:** Sharing + private Finance integration  
**Status:** Approved product direction before implementation  
**Product references:** Splitwise / Settle Up style shared-expense management without requiring feature parity

### 1. Purpose

This sets out V2 Shared Expenses and Settlements. The module covers real shared spending between family, siblings, friends, couples, roommates, travel groups, temporary groups, other invited participants, and people who aren't registered and are recorded by hand. It's **not family-only**. Earlier wording like:

> Family shared expenses

is replaced, for V2, by:

> **Shared Expenses and Settlements**

### 2. Core principle

Shared Expenses answers: Who paid? Who took part? Whose share is what? How much has each person put in overall, and how much have they consumed overall? Who owes money right now, and who should get money? Which payments have been reported, and which of those are waiting to be confirmed? What's left after confirmed settlements? Which original expenses explain the current balance?

Each bill is kept as it was. Current balances are worked out across all the group activity in effect.

### 3. Groups

Shared expenses live inside an `ExpenseGroup`, for example:

- Brothers
- Family Household
- Weekend Friends
- Boracay Trip
- Apartment
- Couple Expenses
- Office Lunch Group

A two-person group covers one-to-one shared expenses. Groups are the boundary for authorization and history, and the group model is never replaced with unscoped, arbitrary person-to-person records.

### 4. Lightweight group UX

Groups are needed underneath, but creating one should stay light. When adding a shared expense, the user can pick an existing group or create a new one if they need to. A simple temporary group shouldn't drag anyone through administration it doesn't need. A future Quick Split workflow could create or reuse a lightweight group behind the scenes, as long as it keeps the same authorization and history rules.

### 5. Participants

A group can hold registered users, people who aren't registered and are recorded by hand, and historical or deleted participant identities. Manual participants are clearly labelled, for example:

> Not registered · recorded manually

A manual participant is never quietly matched to a newly registered user on display name alone. Linking or claiming one needs a verified identity, consent, and a review of the balance and history.

### 6. Privacy boundary

Being in a group only gives access to records the group owns. It gives no access to another participant's bank accounts, wallet balances, card balances, debts, salary, Career records, private notes, unrelated transactions or private workspace. The accounts someone picks privately are only visible to them. Group owners aren't admins of anyone else's private workspace.

### 7. Shared expense record

A shared expense records at least: the group; a description; the expense date; currency; the total; each payer's contribution; the participants chosen; each participant's share; the split method; a category or label where it applies; notes; optional supporting evidence once file support exists; who created it; and its version history.

A shared expense is one logical bill. Corrections create revisions that are kept, instead of quietly editing historical evidence.

### 8. One or multiple payers

V2 supports one payer or several payers for the same bill. That replaces earlier wording that pushed multiple payers past the first shared-expense release. One payer stays the simple default. The UI I have in mind:

```text
Who paid?

Brother 1       PHP 4,000

[ Add another payer ]
```

With another payer added:

```text
Who paid?

You             PHP 1,500
Brother 1       PHP 2,500

Total paid      PHP 4,000
Bill total      PHP 4,000
```

Nobody has to pick a separate "multiple payer expense type".

### 9. Payer contribution invariant

For every finalized shared expense:

```text
sum(payer contributions) = expense total
```

No amount is left unexplained. For example, this is valid:

```text
Expense total       PHP 4,000

You                 PHP 1,500
Brother 1           PHP 2,500
                    ---------
Total paid          PHP 4,000
```

This isn't:

```text
Expense total       PHP 4,000
Total contributions PHP 3,500
```

The missing PHP 500 has to be sorted out before saving.

### 10. Participant shares

Paying and taking part are separate ideas. A participant might pay and have a share, pay more than their share, pay less than their share, pay but have no share, or have a share without paying.

The split methods required at first are equal and exact (custom) amounts. Percentages, weights and detailed itemized allocation can come later, separately.

### 11. Share invariant

For every finalized shared expense:

```text
sum(participant shares) = expense total
```

What payers put in and what participants' shares come to each equal the total on their own; they don't have to match person by person.

### 12. Multiple-payer example

Four people share a meal that costs PHP 4,000. Who paid:

```text
You             PHP 1,500
Brother 1       PHP 2,500
Brother 2       PHP     0
Brother 3       PHP     0
```

Equal shares:

```text
You             PHP 1,000
Brother 1       PHP 1,000
Brother 2       PHP 1,000
Brother 3       PHP 1,000
```

Where each person stands on this bill:

| Participant | Paid | Share | Position |
| --- | ---: | ---: | ---: |
| You | PHP 1,500 | PHP 1,000 | +PHP 500 |
| Brother 1 | PHP 2,500 | PHP 1,000 | +PHP 1,500 |
| Brother 2 | PHP 0 | PHP 1,000 | -PHP 1,000 |
| Brother 3 | PHP 0 | PHP 1,000 | -PHP 1,000 |

Positive means they fronted money for others; negative means they consumed more than they put in.

### 13. Participants may differ by expense

Not every group member has to be in every expense. For example:

```text
Brothers group

Grab
PHP 900

Participants:
You             PHP 300
Brother 1       PHP 300
Brother 2       PHP 300

Brother 3 was not included.
```

Brother 3 gets no share of that expense.

### 14. Current group balance source

Current group balances come from the group records that are the real record. Roughly:

```text
participant current net position
 =
 current payer contributions
 - current consumed shares
 - effective refund-to-payer amounts
 + effective refund-of-share amounts
 + confirmed settlements paid
 - confirmed settlements received
```

However the database or report does it exactly, it keeps the accounting conventions already established. For each currency and group, the participants' current positions always add up to exactly:

```text
0
```

### 15. Expenses are not isolated debts

Shared Expense 1 and Shared Expense 2 never act as completely separate balances that each have to be paid back on their own. Every current expense that applies goes into the current group calculation, and the source expenses stay open to inspection for history and explanation.

### 16. Reciprocal netting

When the same participants owe each other, those amounts cancel in their current relationship balance. For example:

```text
Expense 1:
You owe Brother 1        PHP 1,000

Expense 2:
Brother 1 owes you       PHP   800
```

The current relationship:

```text
You owe Brother 1        PHP 200
```

Neither Expense 1 nor Expense 2 is deleted or rewritten. The PHP 200 is a current result worked out from them.

### 17. Pairwise relationship visibility

Where the source allocations support it, the group UI answers: how much you owe each participant right now; how much each participant owes you right now; how much other participants owe each other, where the group's visibility allows; and which expenses, refunds and settlements explain that relationship. The pairwise view is worked out from the group records that are the real record; it never becomes another source of truth someone can edit.

### 18. Explainable relationship breakdown

For example:

```text
You ↔ Brother 1

Dinner                     -PHP 1,000
Groceries                  +PHP   800
Confirmed settlement       +PHP   100
--------------------------------------
Current net                -PHP   100

You owe Brother 1           PHP   100
```

The user can always look at the source records behind the result.

### 19. Whole-group net positions

The main basis for settling is each participant's current net position across the whole group. For example:

| Person | Current position |
| --- | ---: |
| You | +PHP 100 |
| Brother 1 | +PHP 300 |
| Brother 2 | -PHP 400 |
| Brother 3 | PHP 0 |

The group balances because:

```text
+100 + 300 - 400 + 0 = 0
```

### 20. Suggested settlements

V2 has a **Suggested settlements** view that explains itself. It can cut down the number of payments by matching the people in the group who owe with the people who are owed. For example:

```text
Brother 2 → You
PHP 100

Brother 2 → Brother 1
PHP 300
```

A suggestion doesn't move money, doesn't change group balances, doesn't rewrite the original bills, and doesn't mark anything as paid. It's a proposed way to settle the current net positions.

### 21. No false optimality claim

The app doesn't have to guarantee the mathematically smallest number of payments, unless an algorithm we've built formally guarantees it. Wording like:

> Suggested way to settle

is used instead of:

> Minimum possible payments

unless it's been proven correct.

### 22. Redirected/indirect settlement

For example:

```text
A owes B PHP 300
B owes C PHP 300
```

One possible suggestion is:

```text
A → C PHP 300
```

A redirection like this keeps every participant's net position the same, and the original bills don't change. Where a redirected settlement clears indirect obligations, the people affected explicitly agree or confirm, following the settlement model once it's finalized. Obligations are never redirected quietly.

### 23. Settlement modes

The settlement workflow supports at least these:

#### Full balance

Pay everything currently owed to the chosen recipient, under the settlement scope picked.

#### Custom amount

Pay just part of the current amount. For example:

```text
You owe Brother 1        PHP 2,000
Pay now                  PHP 1,000
Expected remaining       PHP 1,000
```

#### Selected expenses

Pay only what's tied to particular shared expenses. For example:

```text
Dinner                    PHP 800
Groceries                 PHP 600
Gas                       PHP 600

Selected:
Dinner                    PHP 800
Groceries                 PHP 600

Settlement                PHP 1,400
Gas remains               PHP 600
```

### 24. Partial settlement of one expense

A shared expense picked for settling can itself be settled only partly. For example:

```text
Dinner outstanding        PHP 1,000
Pay now                   PHP   400
Remaining                 PHP   600
```

The original bill doesn't change; the settlement allocation explains the PHP 400 that was cleared.

### 25. One settlement across multiple expenses

One settlement can spread its amount across several source expenses. For example:

```text
Settlement to Brother 1
PHP 1,000

Applied to:

Dinner                    PHP 600
Groceries                 PHP 400
```

The allocations add up to the settlement amount that applies, apart from any advance or overpayment part that's modelled explicitly.

### 26. Recipient correctness

A settlement never quietly clears something owed to someone else. For example, if the user owes:

```text
Brother 1        PHP 1,000
Brother 2        PHP   500
```

a payment to Brother 1 doesn't automatically clear what's owed to Brother 2. Redirecting across recipients needs a settlement-simplification path that's explicitly supported and accepted.

### 27. Overpayment

If someone tries to settle more than they actually owe right now, the app doesn't quietly cut the payment down or force balances to zero. It previews what happens instead. For example:

```text
Current amount owed       PHP 1,000
Payment                   PHP 1,200
Advance/reverse balance   PHP   200
```

The user has to explicitly acknowledge the advance or reverse position that results.

### 28. Reported versus confirmed settlement

For registered participants, saying money was sent isn't the same as the recipient confirming it. A reported settlement stays pending until the recipient confirms they got it. A pending settlement stays visible, keeps its allocations, doesn't reduce confirmed group balances, and can affect a separately labelled projected balance.

### 29. Sender view for pending settlement

For example:

```text
Brother 1

Confirmed amount owed
PHP 2,000

You reported sending
PHP 1,000

Status
Awaiting Brother 1 confirmation

Projected remaining if confirmed
PHP 1,000
```

The confirmed balance isn't simply shown as PHP 1,000 before it's confirmed.

### 30. Recipient confirmation view

The recipient sees:

```text
Rendel reports sending you PHP 1,000

Group
Brothers

Date
October 10, 2026

Applied to:
Dinner                    PHP 600
Groceries                 PHP 400

[ Confirm receipt ]
[ Dispute ]
```

Confirming it changes the current confirmed balance that applies.

### 31. Pending settlement reporting

Seeing pending settlements is a first-class requirement. There's a settlement view with statuses or filters along the lines of:

- Needs my confirmation
- Waiting for others
- Confirmed
- Disputed
- Reversed/Cancelled
- All

For example:

| Participant | Amount | Status |
| --- | ---: | --- |
| Brother 1 | PHP 1,000 | Waiting for Brother 1 |
| Brother 2 | PHP 500 | Needs your confirmation |
| Brother 3 | PHP 700 | Confirmed |

### 32. Group-level pending summary

The group page keeps these apart: confirmed current balances; pending outgoing settlements; pending incoming settlements; and projected balances if the pending settlements are confirmed. Projected and confirmed numbers are never mixed without labels.

### 33. Dashboard attention

Pending settlements can show up in the Dashboard's global attention area. For example:

```text
PHP 500 from Brother 2
Needs your confirmation

PHP 1,000 sent to Brother 1
Waiting for confirmation
```

The Dashboard never shows group-sensitive information outside the view of a user who's allowed to see it.

### 34. Pending settlement aging

The UI can show:

> Awaiting confirmation · 3 days

That's just for information. Once reminder delivery exists, the user can be offered an in-app reminder or an external one they've opted into. Participants are never nagged automatically, and sensitive financial details never go out through notification channels.

### 35. Disputes

A recipient who disagrees with a reported settlement can dispute it. A disputed settlement stays visible, doesn't reduce confirmed group balances, keeps the original reported details, records a reason and evidence where that's supported, and has to be settled through an explicit correction or transition. The payment amount is never quietly edited after a dispute.

### 36. Manual/nonregistered settlement confirmation

A manual participant can't confirm with an authenticated account. A manual confirmation records who entered it, the type of confirmation, and the fact that confirmation by an authenticated recipient wasn't possible. That limitation is shown clearly.

### 37. Private ledger integration

Group records don't automatically change every participant's private financial ledger. Each registered participant decides what gets adopted into their own workspace, and a group bill can exist without anyone adopting it privately. That keeps things private and stops one participant from changing someone else's private finances.

### 38. Integrated Add Expense experience

If the current user is recording a real purchase they paid for, the ordinary Add Expense flow can expand into a shared expense. Roughly:

```text
Add Expense

Amount
PHP 2,400

Category
Dining

Paid with
GCash

Split this expense?
[ ] Just me
[x] Split with people

Group
Weekend Friends

Participants
[x] You
[x] John
[x] Mark
[x] Sarah
```

Nobody should have to enter the PHP 2,400 purchase once in Expenses and then again in Shared Expenses.

### 39. Private accounting for payer's own share

Say you pay PHP 1,200 from GCash for dinner with two brothers, split equally. What that does privately for you:

```text
GCash cash movement        -PHP 1,200
Your spending                PHP   400
Group receivable             PHP   800
```

The other participants' private accounts aren't touched.

### 40. Private accounting with multiple payers

Suppose:

```text
Bill total            PHP 4,000

You paid              PHP 1,500
Brother 1 paid        PHP 2,500

Your share            PHP 1,000
Brother 1 share       PHP 1,000
Brother 2 share       PHP 1,000
Brother 3 share       PHP 1,000
```

What you adopt privately can show:

```text
Your actual funding movement      PHP 1,500
Your own spending                 PHP 1,000
Your group receivable             PHP   500
```

Brother 1 decides on their own private adoption, and nobody sees which private account anyone else picked.

### 41. Existing private purchase linking

If a purchase was already entered privately, turning it into or linking it to a shared expense never takes another cash or card deduction. It goes through the existing correction, reclassification and private-link model, with a preview of the result before it's applied.

### 42. Credit-card integration

A registered payer can fund their contribution privately with a credit card. For example:

```text
Restaurant bill
PHP 4,000

Your contribution
PHP 4,000

Funding source
BPI Visa

Your own share
PHP 1,000

Group receivable
PHP 3,000
```

Privately, that means: card liability goes up by PHP 4,000; personal spending shows the user's PHP 1,000 share; the group receivable shows the PHP 3,000 put up for others; and no duplicate purchase is created. Other participants can't see the user's card details.

### 43. Funding privacy with multiple payers

At the group level, people only need to see what each contribution means:

```text
Rendel paid           PHP 1,500
Brother 1 paid        PHP 2,500
```

They don't need to see:

```text
Rendel used BPI Visa
Brother 1 used BDO account
```

Private funding sources stay private, unless later on the owner chooses to share metadata that's allowed.

### 44. Refunds

A refund on a shared purchase keeps the original bill and its settlements. Refunds adjust the payer contribution and share effects that apply. If people have already settled, a refund can create a new amount owed in the other direction. Historical settlements are never deleted just because the merchant refunded the purchase later.

### 45. Corrections

Shared expenses use corrections that are versioned and never change in place. Changing the total, the payers, the payer contribution amounts, the participants, the participant shares, the date, or anything else with financial meaning creates a new revision that gets reviewed. Private ledger links that were accepted earlier can become:

> Needs private correction

instead of being quietly rewritten.

### 46. Group summary/reporting

Group reporting shows at least: total group spending; the current bills in effect; each participant's amount paid, shares consumed, confirmed settlements sent and confirmed settlements received; the current net position; pending outgoing and incoming settlements; the projected position if pending payments are confirmed; refunds; disputed amounts; and recent activity.

### 47. Per-person detail

Picking a participant opens a breakdown that explains itself. For example:

```text
Brother 1

Paid across bills           PHP 9,000
Own shares                  PHP 4,200
Confirmed settlements       PHP 2,000
Pending settlements         PHP   500
Refund effects              PHP   300

Current confirmed position
Gets back                   PHP 2,500
```

It links back to the source bills and settlements.

### 48. Per-expense detail

Every bill shows: who paid and how much each payer put in; who took part and each participant's share; the split method; the current revision and earlier ones where they exist; settlements allocated to the bill; pending allocations; the source amounts still unsettled, where that means something; and its refund and correction history.

### 49. Equal-split rounding

Amounts are exact to the centavo. For example:

```text
PHP 100 / 3

PHP 33.34
PHP 33.33
PHP 33.33
```

Who gets the extra centavo is saved and explained. Rounding never quietly loses or creates money.

### 50. Security rules

Shared-expense security checks: active group membership; the participant's role; that foreign references are scoped to the group; invitation authority; settlement authority; correction authority; what former members can still see historically; and that nothing leaks from private workspaces. Group tables need group-scoped RLS, and private adoption tables stay private workspace records.

### 51. Leaving a group

Leaving a group, or being removed, doesn't erase history or forgive balances. It blocks new activity that isn't authorized, keeps the historical visibility that was approved, and keeps the settlement evidence. An active group shouldn't end up without an owner by accident.

### 52. Archive behavior

Groups that are finished or inactive are normally archived, not deleted along with their financial and shared history. Archiving doesn't zero balances or remove settlement evidence.

### 53. Required acceptance scenarios

Before Shared Expenses counts as working, check at least:

1. Create a group with registered participants.
2. Add a manual/nonregistered participant.
3. Record a single-payer equal-split expense.
4. Record a multiple-payer expense.
5. Verify payer contributions exactly equal the bill.
6. Verify participant shares exactly equal the bill.
7. Record an expense involving only a subset of group members.
8. Record exact/custom participant shares.
9. Verify reciprocal obligations across expenses net correctly.
10. Verify current participant net positions sum to zero.
11. Verify source expenses remain intact after netting.
12. Display pairwise relationship explanations where applicable.
13. Produce whole-group suggested settlements.
14. Verify suggestions do not change balances.
15. Record a full settlement.
16. Record a custom partial settlement.
17. Settle only selected expenses.
18. Partially settle one selected expense.
19. Allocate one settlement across multiple expenses.
20. Record an overpayment and preview the resulting advance/reverse position.
21. Verify a reported settlement remains pending before recipient confirmation.
22. Show `Waiting for others`.
23. Show `Needs my confirmation`.
24. Confirm a settlement and verify current balances update.
25. Dispute a settlement without changing confirmed balances.
26. Record manual-participant confirmation with limitation evidence.
27. Correct a bill while retaining previous history.
28. Process a refund after settlement.
29. Link a group expense to an existing private cash purchase without deducting cash twice.
30. Create a group expense through the integrated Add Expense flow.
31. Link a card-funded shared expense without duplicating card liability or spending.
32. Verify another group member cannot see the payer's private account/card.
33. Verify group owners cannot access participant private workspaces.
34. Verify a former member retains only allowed historical access.
35. Verify pending settlement attention on group/global surfaces.
36. Verify rounding is exact.
37. Verify replay/idempotency behavior for group writes.
38. Verify concurrent group writes preserve balances/invariants.
39. Verify responsive/mobile behavior.
40. Verify keyboard/accessibility behavior.

### 54. Suggested implementation milestones

These milestone names can change once the repository's been looked at.

#### V2-I1 — Group Identity and Authorization Foundation

Groups, participants, invitations, membership, manual participants, roles, group RLS, command receipts, and the groundwork for historical access.

#### V2-I2 — Shared Bills and Multiple Payers

Expense revisions, contributions from one payer or several, equal and exact participant shares, exact rounding, working out the current group balance, and per-person and per-expense reads.

#### V2-I3 — Private Ledger Adoption

Private group bindings, linking existing purchases, new private postings, receivable and payable treatment, the privacy boundary, and Add Expense integration.

#### V2-I4 — Settlements and Pending Confirmation

Full settlement, custom partial settlement, allocations to selected expenses, partly settling a bill, pending confirmation, recipient confirmation, disputes, overpayment, and pending reports.

#### V2-I5 — Netting and Settlement Suggestions

Reciprocal netting, relationship views, whole-group net positions, settlement suggestions that are deterministic and explain themselves, and agreement on redirected settlement where that's supported.

#### V2-I6 — Refunds, Corrections and Reporting

Shared refunds, bill corrections, corrections to settled bills, reviewing private links, group reports, and Dashboard attention.

#### V2-I7 — Cross-Domain Integration and Acceptance

Shared purchases funded by card, reminders and notifications where they apply, imports and files where they apply, browser acceptance, a security review, accessibility, and full regressions.

### 55. Explicit V2 boundaries

None of these have to be built just because Shared Expenses exists: general personal lending; peer loans with interest; several currencies inside one group; making payments through banks or wallets; a mathematically guaranteed minimum number of settlement transfers; matching identities automatically by name; redirecting settlements quietly without consent; showing private financial accounts to group members; deleting settled history at will. Percentage, weighted and detailed item-level splits can come later, unless they're separately moved into V2 scope.

### 56. Final product rule

What the Shared Expenses experience is for, in one sentence:

> A user can record real shared purchases exactly once, regardless of who paid or how many people paid, see everyone's explainable current position across all group activity, settle all or part of what is owed, understand pending confirmations, and preserve complete history without exposing anyone's private finances.

## V2-B — Recurring Obligations

### Authority and boundary

This pulls together Blueprint §6.9, System Architecture §12.4 and Database Architecture §12. The ledger is still the only financial authority. V2-B is planning only; Budgets, forecasts, external delivery, other domains and production deployment were left out of this piece of work.

### Internal milestones

1. B1: private definitions, immutable recurrence versions, exact deterministic date generation, bounded preview and persisted occurrences.
2. B2: one-occurrence overrides/skips/cancellation, future supersession/archive, explicit partial financial links and immutable link reversals, correction conflicts and existing transaction creation workflows.
3. B3: accessible responsive management/review, Agenda and in-app reminders, consolidated domain/regression/database/browser acceptance.

I built these in order. Focused checks guarded the contracts in between, and one combined acceptance phase with one accepted commit/push for the domain replaced the earlier habit of a full suite and a push per milestone. That became the default for the domains after it, unless I decided otherwise.

### Rules and dates

- Income, bill and subscription definitions have a name, PHP expected amount, optional owned category/account suggestions and named IANA timezone. Suggestions never override actual transaction choices.
- Supported grammar: daily intervals 1–365; weekly intervals 1–52 and selected ISO weekdays 1–7 (Monday first); monthly intervals 1–120 and day 1–31, with explicitly selected `last_valid_day` or `skip`. Weeks anchor to Monday of the effective start week; days before the effective start are excluded. Monthly intervals anchor to the effective start month. No weekend/holiday adjustments.
- An inclusive end date and/or emitted-occurrence count (1–10,000) may bound each immutable rule version. A count includes valid dates from that version's effective start, including historical dates outside a requested horizon; skipped short months do not consume the count. A replacement starts its own explicitly reviewed count.
- Calendar dates remain date-only. Calendar arithmetic uses date-fns in an explicit UTC calendar context; the definition's timezone determines local today and reminder instants. DST cannot move a logical all-day date. Existing timezone conversion handles reminder times.
- Supported dates span 1900–2199. Creation previews and records the next 90 days from the later of local today or the rule boundary; explicit generation can extend/review any supported window. Agenda retains the civil date, discloses the definition timezone and calculates its timing state in that timezone.
- Every generation command covers an explicit inclusive window of at most 366 days and at most 500 emitted dates. No read inserts occurrences, infinite schedules or nightly jobs. Generation is explicit and replayable; deterministic identities use obligation/logical date/generation, with one noncancelled generation per logical date. Repeated windows preserve existing overrides and terminal history.

### Occurrences and actual evidence

- `planned` has no links; `linked` has partial supported links; `completed` has linked amounts exactly equal to expected amount. `skipped` and `cancelled` have no effective links. Remaining = expected − effective links, using integer minor units.
- One-occurrence changes require an expected record version and reason; due date/expected amount overrides preserve original logical date and rule association, with exact before/after audit history. Completion cannot be asserted without actual evidence. Unlink uses one exact append-only reversal; a reversal cannot be reversed.
- Eligible actual actions are finalized current income for income plans, or cash expenses/card purchases for bills/subscriptions. Transfers, debt/card payments, fees, refunds and opening balances are not ordinary recurring receipts/purchases. Category/account suggestions are not eligibility restrictions. No inferred payment/date/provider allocation.
- A link captures the exact current action revision and explicit positive amount. Across all occurrences, unreversed links cannot exceed that action's recorded eligible amount; links cannot exceed expected amount. Duplicate/excess/foreign/stale links fail atomically under workspace serialization.
- Financial correction/reversal with effective occurrence links fails with an explicit dependency conflict. Reverse those planning links, perform the existing correction, then explicitly relink eligible corrected evidence. Link reversal history remains immutable. No silent reassignment or duplicate posting.
- Financial action detail lists effective occurrence confirmations with scoped links for resolving correction dependencies. Actual entry returns the committed action as a preferred eligible candidate; the separate link still requires review/confirmation. Candidate priority and pagination share a stable ordering.
- Actual creation uses the existing reviewed income/expense workflows, then explicit linking of their committed action. It is deliberately two confirmed steps: an interrupted link does not recreate a transaction; select the existing action. Command replay protects both workflows independently.
- Future changes create immutable rule versions at a future boundary in the definition's local calendar. Preserve completed, skipped, linked and historical occurrences. Cancel/regenerate only unlinked outstanding occurrences at/after that boundary; partial linked exceptions remain visible under their original rule. Archive stops generation and cancels only unlinked future plans; history and partially linked commitments remain reviewable.
- Both original logical date and current due date must be at/after a change/archive boundary before an unlinked plan is cancelled. Earlier due overrides remain historical commitments. Individual skipped/cancelled states are terminal history; generation never silently restores them. Historical unlinked expectations are labelled separately from active remaining obligations.

### Security and acceptance

Four documented `planning` tables use concrete scoped FKs, forced active-owner RLS, restricted runtime grants, immutable rule/link evidence, permanent command replay, private audit evidence, workspace locks and approved lifecycle purge. Expected activity cannot create financial revisions/journals. Agenda/reminders use concrete occurrence references; resolution/date changes invalidate obsolete reminder generations without financial effects. Actual reports exclude planning tables.

Nullable SQL rule/reversal checks explicitly reject NULL when a selected grammar or correction requires evidence. Runtime SQL tests verify this independently of API validation. The source view emits its own calendar context; bounded reminder reads materialize the requested source projection once, avoiding repeated RLS joins without relaxing ownership or transaction isolation. Planning commands advance the existing workspace read revision as A5 evidence commands do; this is cache/review metadata, not a financial posting.

Acceptance covered grammar/count/horizon/month-end/leap/DST, exact amounts, repeat/overlap generation, version boundaries/history, overrides/state/link reversal, partial/excess/duplicate/corrected/foreign actual evidence, same-command and competing capacity/version races, SQL/audit/receipt rejection, RLS/roles/lifecycle, financial nonduplication, reminder lifecycle/preferences, browser keyboard/Axe/320px/themes and unchanged V1/V2-A regressions. B1–B3 were accepted locally on October 13, 2026 (Asia/Manila). The actual commands and results, the bounded limits, the unrelated checks I left out on purpose and the V2-C prerequisites are in handoff §22. Nothing after this domain had been started at that point.

## V2-C — Budgets

### Authority and scope

This pulls together Database Architecture §12, System Architecture §15.2 and the Blueprint's planning and reporting requirements. It uses `planning.budget`. Budgets are spending limits you can change, with an audit trail; they're never financial actions or reservations. There's no rollover, replenishment, transfers, savings goals or forecasts here.

### Internal milestones

1. C1: category/period/amount validation, protected database model, audited replayable management and transactional overlap prevention.
2. C2: repeatable snapshot comparisons from the existing immutable posting facts and net/gross definitions; historical corrections and refund dates remain authoritative.
3. C3: accessible responsive Money management, Reports comparisons, Dashboard preview and consolidated acceptance.

I built these in order with focused checks, then did one combined verification and one accepted commit/push for the domain, the same streamlined workflow as V2-B.

### Domain decisions

- Explicit expense category and PHP limit. Nonnegative integer minor units through PostgreSQL bigint maximum `9223372036854775807`; zero is a valid no-spending limit. No floating-point monetary arithmetic.
- Stored periods are `[start_date,end_date_exclusive)`. UI presents inclusive end dates and converts exactly once. Support 1900–2199, with `2200-01-01` permitted only as an exclusive boundary; periods contain 1–366 days, matching existing Reports limits. Adjacent periods are valid.
- Reject every overlap for the same owned category, including exact duplicates and archived definitions. Archive hides a budget from active summaries but preserves its period/history; update or restore that existing budget to reuse its period. This retains the approved unconditional overlap rule. Different categories may overlap.
- Save supports explicit category/period/limit/basis/notes changes. Updates, archive and restore require expected version and reason; permanent before/after audit history preserves earlier definitions. No ordinary deletion. New category assignments require active owned expense categories; retained archived categories remain readable/manageable without silently changing classification.
- Net is default; gross is selectable per budget. Use the existing Reports posting grain and signed classification: gross purchase/recognized-charge expense activity net of correction reversals; spending offsets on their actual refund/rebate/waiver date; net = gross − offsets. Include card/cash/financed purchases and recognized fees/interest without counting principal payments again. Uncategorised activity has no category budget; no guessed classification or category hierarchy aggregation.
- Remaining allowance = limit − selected recognized spending, including negative net spending. Overspending = max(spending − limit,0). Progress uses exact integer basis points; zero limits show explicit zero-limit status and no percentage denominator. Expected recurring activity never enters these calculations.
- Comparisons always query current immutable financial evidence. Backdating, corrections/reversals/refunds and posting category changes update the applicable period/category; category renames affect labels only. Budget audit history is definition evidence, not frozen financial totals.
- Management serializes on the existing active workspace financial lock. The database write guard advances read-revision metadata before checking overlap, ensuring competing writes serialize even under repeatable-read snapshots; this creates no ledger movement. Database-assigned `write_revision` binds the exact completed command result to that mutation. Commands retain normalized permanent receipts and exact attributed audit evidence. Category kind/name/archive changes take the same lock and advance metadata; referenced categories cannot change to income. Forced RLS, concrete scoped category/receipt FKs and restricted roles apply.
- Money lists/details expose whole-budget-period comparisons and paged history/contributions. Reports/Dashboard previews include budgets intersecting their selected period, explicitly label each budget's full period, and never compare a whole limit with a clipped spending window. Preview bounds disclose additional results; full management remains paginated. No cross-category grand total across mixed bases/periods.

### Acceptance

Acceptance checks exact/zero/large limits, leap/day/end boundaries, adjacency/overlaps, lifecycle and immutable audit history, source/category ownership, RLS/runtime grants, SQL bypass/forged receipts, concurrent saves/period moves/version races, permanent replay, ledger nonduplication, net/gross actual-period refunds and corrections, recurring exclusion, snapshot consistency, Money/Reports/Dashboard integration, browser keyboard/review/retry/Axe/320px/themes, migration upgrades, lifecycle/restore and unchanged V1/V2-A/B regressions. After acceptance, the results that actually ran and the V2-D prerequisites went into the handoff.

### Accepted implementation

C1–C3 were built and accepted locally and in hosted CI. Seven forward migrations add one protected, audited table, which took the chain to 111 migrations / 75 tables with every earlier definition kept. No dependencies or financial recipes changed.

The combined verification covered 901 passing unit/component/API tests, all 549 integration scenarios across the full run and affected reruns, all 44 browser scenarios across the full run and affected rerun, ten fresh/upgrade migration proofs, schema/runtime checks, production builds, dependency audit, isolated encrypted restore and restricted runtime artifacts. Guarded capacity with 100 budgets / 1,000 actual classified postings passed existing timing thresholds and financial nonduplication assertions. The exact commands, the first failures and how I fixed them, the measured results and the V2-D prerequisites are in [handoff section 23](archive/web/V2_DEVELOPMENT_HANDOFF.md#23-v2-c--budgets).

V2-D was its own separate piece of work. A budget's remaining allowance is a comparison against a spending limit; it can't turn into eligible savings cash or a reservation.

## V2-D — Savings Goals

### Authority and internal milestones

This pulls together Database Architecture §12 and System Architecture §15.2. D1 is private goal management, protected reservations, audit/replay and atomic availability checks. D2 works out current funding health from finalized cash evidence. D3 brings in accessible Money management, Dashboard/Reports previews and combined acceptance. I built them in order, with one combined verification, the docs and one approved commit/push, and stopped there before V2-E.

### Decisions

- `planning.savings_goal` and `planning.goal_reservation` are mutable audited management records. Names (1–200 characters), positive exact targets through PostgreSQL bigint maximum, optional dates (1900–2199), notes and active/completed/archived status. No new assets, money movements, financial journals or automatic completion.
- Reservations identify a concrete owned PHP cash/e-wallet/checking/savings account and an owned goal. Eligible capacity is its nonnegative finalized signed cash balance through workspace-local today; future-dated postings, future opening cutoffs and expected activity are excluded. Both account and cash ledger must be active. Card credit/limits, debt/loan balances, budgets and forecasts never enter this pool. Recorded cash remains fungible; no invented cash-provenance restrictions or net-position substitution.
- Availability is validated per account across **all goals**, including completed goals. Workspace totals sum these explicitly labelled positive eligible account pools; negative balances are disclosed separately, never described as net liquid funds. Reserves are not subtracted from ledger balances or asset totals.
- Reviewed absolute reservation changes support increases, decreases and full release. Explicit reallocation can change goal, account or both atomically; it never transfers money. New/increased reservations require an active goal and an eligible destination whose final aggregate reservations fit current capacity. Releases/decreases remain possible when underfunded or archived. Reallocating unsupported reservations cannot create available cash; the increased destination must be supported after the complete command.
- Completion is explicit management evidence and retains reservations. Reopen supports completed/archived goals. Archive requires reservations to be explicitly released first; no lifecycle action silently frees funds. Completed goals remain in current reservation totals. Targets may be revised below reservations; disclose excess instead of rewriting allocations.
- Financial and metadata changes never rewrite reservations. If several goals share an underfunded account, the app doesn't invent which goal gets the remaining cash. For reservation R, account total T and eligible capacity C, supported funding lies in `[max(0,min(R,C-(T-R))),min(R,C)]`. Sum these exact bounds per goal; disclose shared shortfalls, exact reserved target progress and supported funding range. Fully funded requires the lower supported bound to meet target; unfunded means the upper bound is zero; otherwise distinguish partial funding and uncertain shared support.
- Commands use active workspace locking, permanent normalized receipts, expected goal versions and current financial revision for reservation/reallocation review. Database guards, final aggregate validation and exact attributed audit/receipt result binding independently enforce integrity. Account/ledger eligibility metadata changes invalidate read revision metadata without posting money. Preserve approved lifecycle purge and all forced-RLS/restricted-role protections.
- Reservation writes require the platform's normal read-committed write transaction. This independently protects against stale repeatable-read financial evidence even when a raw Finance SQL command omits the service-owned revision advance. Read-only comparisons retain repeatable snapshots; authorized lifecycle deletion is unchanged.
- Database command graphs match the API: one goal for management, one goal/account for a reservation change, and two distinct reservation records for reallocation. Reallocation conserves the exact total with one decrease and one increase. One audit per changed record is required; orphan, extra and late goal history under completed or unrelated receipts is rejected.
- All comparisons use a repeatable read snapshot with generation time, local as-of date, revision and definition version. Reports/Dashboard show **current** reservations separately from period-end financial metrics, without pretending to reconstruct historical reservation states. Bounded previews, management/history/reservation/account/target pages disclose additional records. No savings projections, recurring replenishment, automatic transfers/freezing, reminders or investment interest.

### Acceptance

Acceptance checks exact/large/zero reservation amounts, target/date validation, owned eligible accounts, future/archived/noncash exclusion, same funds across goals, atomic reallocation, partial/full release, completion/archive/reopen history, excess targets, shared shortfalls and supported bounds. It tests real spending, transfers, backdating, corrections/reversals and refunds without vetoing financial commands or altering reservations. It separately proves SQL finalization/audit/result binding, rollback, concurrency/replay/stale snapshots, RLS/restricted roles and complete scoped lifecycle deletion. It runs focused domain/API/component tests, consolidated V1/V2-A–C regressions, fresh/upgrades/schema/runtime, checks/build, production browser/keyboard/retry/Axe/320px/themes, isolated restore/runtime artifacts and guarded new-query capacity. The actual outcomes and V2-E prerequisites go in the handoff.

D1–D3 were built and accepted locally. The actual combined results, the important boundary fixes, verification-harness decisions and V2-E prerequisites are in [the development handoff](archive/web/V2_DEVELOPMENT_HANDOFF.md#24-v2-d--savings-goals). Savings Goals add no financial recipe; the targeted 100-goal/100-reservation/1,000-posting workload replaces an unnecessary repeat of the unchanged A6 financial benchmark. Hosted acceptance and the exact verified remote commit went with the completion report. I stopped there before V2-E.

## V2-E — Forecasts

This pulls together System Architecture §15.2 and Database Architecture §12. E1 sets up read-only source coverage and the calculations; E2 brings in explicit scenarios and private APIs; E3 delivers accessible Money management/navigation and combined acceptance. I stopped before V2-F.

### Calculation and source decisions

- No forecast table, saved scenario, receipt, mutation, posting, allocation or reservation write. Every projection uses one active-owner read-only REPEATABLE READ snapshot, local today, generation time, financial revision, source versions and calculation version.
- Opening actual liquid funds are the shared Reports signed cash-asset posting grain through workspace-local today, including negative and archived tracked cash. Card credit/limits, liabilities, clearing, budgets, expected income and reservations do not enter opening cash. Future-dated finalized cash journals are separately labelled recorded future cash evidence and included once at their recorded effective dates, with correction/reversal signs retained.
- Default horizon is tomorrow through 30 days from today. Configurable inclusive ranges must start after today and end within 366 days of today, in 1900–2199. A later window includes a disclosed bridge from tomorrow to its start; window opening is projected, never relabelled actual. Daily closing balances and totals use exact integer minor units and preserve negatives.
- Recurring sources reuse B's calendar generator and immutable rule windows without materializing occurrences. Existing generations, due/amount overrides, effective partial links and terminal states take precedence. Cancelled evidence suppresses the same rule's occurrence; a replacement rule may supply a new projection. Archived definitions generate nothing, but retained partial commitments remain visible. Overdue sources are disclosed without inventing new dates. Default cash assumptions require an active owned cash suggestion and matching workspace/source calendar; explicitly optional assumptions can treat unassigned sources as cash or use a different source calendar's date labels without pretending to convert an unknown time.
- Card payment policy is unknown by default. Provider-verified statement balances and installment schedules are candidates, not automatically another cash outflow. A user may explicitly select **one verified statement per card**, or that card's eligible installment schedule, assuming payment on recorded due dates. The same card cannot use both bases. No minimum-payment satisfaction formula, oldest-first allocation or interest calculation is inferred. Effective A4/A5 allocation/application views supply exact remaining amounts. Missing dates/totals, suspended plans, unresolved allocations, card credit and unapplied payment/credit evidence block unsupported card projections and remain explicit.
- Recurring bills have no established card/statement relationship. When card projections are selected, recurring outflows require the user's explicit confirmation that they are independent; otherwise they remain excluded for overlap review. Likewise, unlinked recorded future cash pauses compatible recurring expectations until supported links or explicit independence resolve possible duplication. Effective links to currently eligible actions deduct the recognized amount once; names, dates and amounts never establish a guessed match. Individual expected sources can be excluded explicitly. Recorded future cash cannot be excluded to simulate cancelling a real posting. Multiple unpaid statements and provider reconciliation gaps remain coverage warnings.
- Optional dated what-if adjustments are signed by explicit inflow/outflow choice, exact positive amounts and user labels. They are visibly separate from recorded evidence and expected sources, held only in the current client/request. No scenario is saved or changes source records. Unknown/foreign/stale selection IDs fail safely.
- Savings show current reservations and supported funding separately. Projected closing minus current reservations is a labelled aggregate comparison, not an account-level availability guarantee or another cash balance. Budgets remain category allowances and never expected spending. Loan schedules, benefits/receivables, unrecorded living costs, unknown future card charges and provider rules are outside the supported automatic source set and are disclosed; users may add explicit assumptions.
- Bounded source inventories fail closed rather than silently truncate: 500 recurring definitions, 1,000 rule revisions, 10,000 relevant stored occurrences/active cash-account suggestions, 100 cards, and 5,000 forecast candidates; at most 20 adjustments, 100 exclusions and 100 card selections. A conservative 100,000-step calendar-history work guard also bounds old rule anchors. Superseded/ended rules are skipped for new generation while retained commitments remain visible. UI contribution and daily views page locally from the complete bounded snapshot. Totals always use every included source. Cross-currency expectations are excluded without inventing conversion rates.

### Acceptance

Acceptance proves exact/large/negative arithmetic, local dates/leap years/horizon/bridge, source ordering and nonduplication, unmaterialized rules and terminal overrides, partial actual links, provider revisions and effective allocations, mutually exclusive card bases, unsupported dates/amounts/credits/overlaps, explicit scenarios, current reservations/budgets without new cash, correction/reversal refresh and consistent read snapshots. It tests strict actor/origin/query/body validation, no-cache reads, foreign IDs/RLS, read-only nonmutation, response races, private browser navigation, keyboard/Axe/320px/themes and bounded performance. It runs the regressions that apply plus checks/build/runtime security. Persistence didn't change, so no new migration or upgrade path was needed. The actual acceptance and V2-F prerequisites go in the handoff.

E1–E3 were built and accepted locally on October 14, 2026 (Asia/Manila). The exact source, overlap, correction, isolation, nonmutation and scenario cases passed; full regressions and the affected final reruns covered 929 unit/component/API tests, 573 integration tests and 50 browser scenarios. Production builds, check, dependency audit, restricted containers and targeted capacity acceptance passed. See [V2-E handoff](archive/web/V2_DEVELOPMENT_HANDOFF.md#25-v2-e--forecasts) for actual run details, bounds, deliberately skipped unchanged-persistence checks and V2-F prerequisites. The exact pushed commit and the hosted workflow result are in the completion report.

## V2-F — Richer Career Analytics

This builds on the existing Career report, reporting periods, scoped repositories and CSV setup. System Architecture §11 and Database Architecture §14 are still the authority. F1 sets up the evidence and metrics; F2 brings in filters, comparisons, the Dashboard and exports; F3 delivers accessible views and combined acceptance. I stopped before V2-G.

### Evidence and metric definitions

- One application ID is one attempt. Cohorts use current corrected `applied_date` within the inclusive selected Reports period and through the effective as-of date. Saved records without a submission date are excluded; archived submitted attempts are retained. Company/role equality never merges attempts. No submission is inferred from a current stage or submission event alone.
- All reads use the established owner-scoped READ ONLY REPEATABLE READ snapshot. As-of is an inclusive workspace-local civil date, no later than local today. Current corrected history/events/source metadata are observed through that effective date; this is **not** a reconstruction of what was known then. Superseded stage observations and cancelled events remain historical evidence but do not establish milestones. Versions, current generation time and calculation version identify provenance; the financial revision is not a Career change counter.
- Response requires an explicitly dated noncancelled response event, preserving the existing definition. Interview/assessment progression requires a resolved interview/final-interview/technical-assessment observation or a completed corresponding event. A scheduled event alone is not achieved progression. Offer requires an explicit resolved offer observation or noncancelled offer event; accepted alone does not invent an offer or response. Milestones before submission are excluded and disclosed. Repeated events/visits remain separate evidence while each application counts once per milestone.
- Current accepted/rejected/withdrawn/offer-declined/offer-expired/employer-cancelled outcomes use the last resolved observation through cutoff, ordered by effective date, effective order and history ID. Earlier terminal outcomes remain reached-outcome evidence; a later reopening does not remain a current rejection. No response never means rejection. Explicit no-response events are separately reported evidence.
- Each headline conversion has the submitted cohort as its denominator. Conditional response-to-interview and interview-to-offer numerators are intersections with those denominator applications. Stages may be skipped, so the visualization is independent milestone reach, not an assumed monotonic hiring pipeline. Empty denominators return null / not applicable, never NaN or an invented zero rate.
- First-response/interview/offer timing uses the earliest eligible recorded milestone and full calendar days since submission. Timing summaries disclose samples, missing evidence and exact median (including half days); missing responses are excluded from medians. Follow-up age through cutoff discloses cohort maturity. Stage durations retain repeated visits and same-day zero durations; completed and still-open nonterminal visits are summarized separately. Saved/terminal observations are excluded from active-stage aggregates. Open duration is censored at cutoff, not a completed-stage estimate. No timestamp precision beyond recorded civil-day evidence is implied.
- Dated event activity remains a separate selected event-date period, including other cohorts. Completed, scheduled and cancelled counts are separate; past scheduled events are not treated as completed. Cohort milestone evidence may occur after the submission period but must meet cutoff. Event-date activity is visibly independent of cohort conversions and may include future scheduled reference entries.
- Source effectiveness groups exact current source labels, with null separately identified; no case/name normalization merges evidence. Source filtering applies to Career cohorts, period events and comparisons. It does not change financial scope. Weekly/monthly/quarterly/yearly cohort buckets use existing workspace week start/calendar boundaries, clipped to the selected range, and the same as-of cutoff. Optional comparison uses the immediately preceding equal-length inclusive period; differing follow-up ages and incomplete observation windows are explicit, with no maturity-adjusted predictions or causal claims.

### Interfaces, limits and privacy

- Extend `/reports/career` and its existing API. Career-only filters select cohort interval, exact recorded source (or missing source) and optional previous-period comparison. Shared period/date contracts remain intact; Financial APIs reject Career-only filters. Career list/detail and Dashboard link to the same calculations; operational active/upcoming summaries retain their distinct labelled scope.
- Derived on demand; no new table, migration, privilege, dependency, ledger operation, audit mutation or saved analytics state. Fail closed above 10,000 combined application/event/stage evidence rows across selected/comparison reads; queries request one sentinel beyond their bounds. Supporting UI lists paginate from complete bounded results and never change totals. Existing CSV 10,000-row / 10 MiB guards, scoped provenance and formula escaping remain intact.
- Analytics select only application identity/company/role/source/submission, resolved stage evidence and minimal dated event identity/title/status/version. Contact details, salary expectations, private notes, preparation/location details and private revision JSON are never loaded into analytics. Authorized Application History CSV keeps its existing explicit historical-evidence scope; aggregate exports include the same definitions/rates/timing/source/trend/comparison values without private notes or contacts.

### Acceptance

Acceptance proves compatible cohort denominators/intersections, repeated attempts/events, cancelled versus scheduled/completed activity, stage correction/supersession/reopening/same-day ordering, archived/saved/missing evidence, pre-submission exclusions, response/progression timing, open-stage censoring, empty rates, source labels/filters, bucket/date/timezone/cutoff boundaries, unequal cohort maturity, stable snapshots/nonmutation, RLS/foreign/spoof rejection and private field exclusion. It verifies shared Reports/Dashboard/detail/export consistency, strict API errors, keyboard/320px/both themes/Axe, bounded rendering and targeted query capacity. Once things were stable it ran the V1/A–E regressions that apply and the check/build/security/container gates, then only the affected reruns. Persistence didn't change, so new migration, schema or restore fixtures weren't needed; the established hosted gates stay. The actual outcomes and V2-G prerequisites go in the handoff.

F1–F3 were built on October 14, 2026 (Asia/Manila). Full regressions and the affected final checks covered 942 unit/component/API tests, 583 integration tests and 53 browser scenarios. The calculation, privacy, isolation, consistent-snapshot and nonmutation checks passed; check, production builds, audit and targeted capacity passed. Runtime-artifact acceptance is recorded separately in the [V2-F handoff](archive/web/V2_DEVELOPMENT_HANDOFF.md#26-v2-f--richer-career-analytics). CSV schema 4 adds explicit Career calculation provenance, source/trend/comparison summaries and timing/rate fields; financial definitions and recipes are unchanged. Locally I used Chrome 155 through the existing configured channel after the bundled-browser download timed out; hosted CI keeps the bundled Chromium. The handoff and completion report record the actual acceptance, what I left out and why, and the exact pushed commit.

## V2-G — Scheduled Opted-In Notifications

### Authority and sequence

This builds the notification boundaries from SYSTEM_ARCHITECTURE and
DATABASE_ARCHITECTURE on top of the existing V1 reminders and the V2 A–F sources. G1 adds
explicit consent, forced-RLS evidence and lifecycle protections. G2 adds durable
pg-boss scheduling, rechecking the current source, and authenticated provider evidence.
G3 adds the Settings and status workflows and combined acceptance. V2-H wasn't started as part of this.

### Product contract

Email is the only channel. Missing preferences mean disabled. Enabling requires a
current verified owned sign-in identity; there is no editable destination. In-app
reminder offsets, local times, overrides, dismissal, snooze and module switches
remain authoritative. Navigation hiding and Agenda visibility do not revoke
reminder consent; the module's separate reminder switch controls eligibility.
Sources are Calendar appointments, Career scheduled events,
Debt installments, verified card statements, eligible projected card installments
and materialized Recurring occurrences. Unmaterialized projections do not invent
notification sources. Statement and installment messages describe separate source
evidence, never a sum or financial instruction.

One logical delivery identifies the occurrence, source/rule generations and email
channel. Source version checks freshness but never creates another delivery for an
unrelated edit. No repeated overdue cadence is offered. Schedules predating the
current opt-in are suppressed; restoring consent does not replay already terminal
logical deliveries. Relevant due/rule changes use existing reminder generations.

Workspace timezone remains the scheduling timezone of date-only sources; timed
sources retain their recorded timezone. Optional quiet hours use a selected IANA
timezone or the current workspace timezone and defer delivery without changing
deadlines. Both endpoints must be supplied together and differ. DST transitions
follow PostgreSQL civil-time conversion. Quiet windows may cross midnight.

Default messages contain only a generic reminder and a link to authenticated
Agenda. An explicit preference may include the recorded due date. No amount,
company, title, recipient, private notes or provider payload enters queue data or
operational logs. Security/verification/recovery email is independent of consent.

### Durable processing and safety

Preferences and authoritative source rows are durable scan intent. The worker
discovers consenting scopes every minute and scans bounded current Agenda sources;
this also recovers edits committed while it was stopped. This is polling over
authoritative evidence, not a second queue or a post-commit best-effort hook.
Delivery insertion and the ID-only pg-boss job share the proven Drizzle transaction
adapter. Missing queue setup fails the transaction. Current-source validity is
checked again immediately before sending. Pending cancellation/rescheduling becomes
visible within a healthy scan interval; provider-boundary checks protect against
stale jobs between scans. Already accepted mail cannot be recalled.

Attempt evidence is committed before provider I/O. Racing workers can claim once.
An abandoned attempt becomes uncertain and is never automatically resent, including
Resend after its provider deduplication window. Definitively rejected attempts may
retry under the same logical key with a bounded count. Provider acceptance is not
delivery/read evidence. Signed, replay-deduplicated Resend events are resolved by
stored provider message ID, never by caller-supplied scope IDs. Conflicting or
unmatched events cannot fabricate acceptance or delivery.

Runtime financial tables remain read-only for notification work. Owner RLS,
workspace locking, command receipts and attributed preference audit are preserved.
Lifecycle purge removes deliveries/attempts/provider evidence before occurrences.
Restore keeps workers paused and requires external-effect reconciliation. Compact
delivery keys remain with the live workspace to prevent replay; operational
attempt/event evidence remains with the live workspace as compact audit evidence.
Queue metadata expires within seven days; operational logs have a recommended
30-day infrastructure retention gate. No raw body is kept.

### Operational gates and acceptance

Optional delivery requires NOTIFICATIONS_ENABLED=true independently of WORKER_PAUSED.
Real Resend delivery additionally requires NOTIFICATIONS_EXTERNAL_ENABLED=true,
reviewed sender/domain/quota configuration and authenticated webhook setup. These
gates stay off in this implementation's real environments. Acceptance uses mock
providers and local Mailpit. I haven't deployed it or sent any real external mail.

Acceptance covers consent/defaults/timezones/quiet hours, all source eligibility,
transaction rollback, replay/concurrency, current verified recipient, generations,
source resolution/corrections, opt-out, durable attempts/crash uncertainty, provider
events, forced RLS/roles, deletion, exact unchanged financial evidence, settings
origin/scope enforcement, accessibility, migration upgrades/schema drift, regression,
restore, container and bounded scan performance. Actual results go in the V2
handoff; infrastructure acceptance that hasn't run is never labelled passed.

## V2-H — Supporting Files, Imports and Portability

The authority here is SYSTEM_ARCHITECTURE §18 and DATABASE_ARCHITECTURE §15. H covers one owned private workspace. V2-I, shared history, V3, provider ingestion and any redesign were out of scope for it.

### H1 — Private supporting files

Eight concrete scoped relationships support financial actions, debts, settlements, reconciliations, exact statement revisions, applications, application events and exact resume versions. PDF/JPEG/PNG only; 10 MiB per object, 1 GiB reserved and at most 1,000 live objects per workspace. Forced RLS protects persisted pending, quarantined, available, rejected, deleting and deleted states. Sources are authorized before transfer. Quota reservations and command/audit evidence are serialized; retries retain their original commands.

Authenticated bounded uploads use opaque immutable keys and a four-minute operational lease to prevent expiry cleanup during bounded provider I/O. Actual size, signature, checksum and a fresh successful scan precede availability. Signatures are format hints, not guarantees of harmless content. Images retain original metadata; no document renders inline. Downloads reauthorize and validate exact readback, with attachment-only, no-store, nosniff and sandbox headers.

Production S3 uses explicit separate credentials, conditional writes, encryption/checksum evidence and private-policy probes. Enabled or suspended versioning is unsupported. Persisted namespaces bind bucket, region and endpoint; configuration changes fail closed instead of forgetting old objects. Clamd exchanges/responses are bounded, UTC-configured, and require signatures within 48 hours. Synthetic adapters verify the actual test database and are forbidden outside local testing.

Scan/cleanup intent survives crashes and provider failures. Discovery is bounded with UUID cursors; file I/O runs independently of security mail and supports cancellation. Reservations expire after 15 minutes. Unlinked files are inaccessible and retained for up to 30 days, with explicit deletion controls. Account purge acknowledges one object deletion per step before removing metadata. Storage/namespace failures retain retryable keys. Independent provider inventory, backups and real storage/scanner acceptance remain operating gates.

### H2 — Durable CSV cash history

Format `pmp-cash-activity`, version 1, requires explicit mapping of date, kind, amount minor units, classification, description and reference. PHP, an owned active cash account, date interpretation (YYYY-MM-DD, DD/MM/YYYY or MM/DD/YYYY), and opening-cutoff strategy are explicit. UTF-8 CSV is bounded to 1 MiB, 500 rows and 16 KiB per record. Positive canonical integer amounts use existing component bounds. Supported kinds are expense and income; income classes are earned, gift, reward and other. Card/debt/transfer/refund/Career/provider formats are unsupported and are not inferred.

Persistent batches retain hashes, account/source snapshots, immutable previews, decisions, stable row commands and posting provenance. Duplicate file, fingerprint and reference warnings require acknowledgement. Confirmation reads the server preview and rechecks revision/version; initial processing rejects stale snapshots. After-opening commands process at most 50 rows with existing financial services and per-row savepoints. Concurrent retries serialize without duplicate postings. Cancellation stops future chunks and preserves committed rows; corrections use existing finance correction/reversal commands.

Rebase-history requires an earlier date/amount and exact coverage equation: earlier opening plus selected historical net movement equals the original baseline. The opening transition and all selected historical rows commit atomically. Positive/zero transitions preserve reversals and immutable journals; no zero journal or guessed adjustment is invented. Ordinary opening corrections cannot move cutoffs. Imports do not infer paid installments, links, reminders or allocations.

Normalized staging and preview rows expire after 30 days. Compact hashes, row commands, receipts and recognized-action links remain as provenance. Recognized descriptions/references remain legitimate financial history.

### H3 — Private portability and recovery

Runtime format `pmp-private-workspace-graph`, manifest version 2, uses a reviewed static graph registry/fingerprint, repeatable snapshot, canonical checksum, exact values/dates, financial revision, definitions and coverage. Bounds are 10 MiB and 10,000 total graph rows, including relationships/audits; this is not a promise of 10,000 financial actions. Authentication/profile identity, lifecycle/tombstones, queue/operator records, temporary artifacts, external-effect retirement records and attachment bytes are excluded. Receiving account identity remains intact. Currency must match; timezone/week start are restored.

Exports have owned command/audit provenance and authenticated 24-hour downloads. Raw previews accept `application/vnd.pmp.private-workspace-graph+json` with a preview command in the query, rejecting duplicate keys, excessive nesting and invalid UTF-8 before parsing. JSON command envelopes remain supported. Unsupported tables/columns, incomplete coverage, duplicate identities, invalid references, ambiguous dates and wrong fingerprints/checksums block activation.

Preview reports counts, exact cash/spending/income and ledger positions, mapping, exclusions and blockers. Replacement requires the exact preview hash, current revision and typed confirmation. Lifecycle/workspace locks suspend writes. A bounded recovery snapshot precedes deletion. The narrow database bridge reconstructs the registered graph atomically; FK/check and INSERT/UPDATE constraint validators remain enabled. Failed validation preserves the prior workspace. Evidence IDs remain stable within a workspace; foreign copies remap typed UUIDs and registered internal JSON references, preserving literal provider references/notes. Previous financial receipts remain retired against replay.

Live file bytes require explicit deletion or separately supported byte recovery before replacement. Incoming file metadata is unavailable/deleted; JSON never recreates bytes. Pending imports are cancelled and notification consent is reset. In-flight external delivery blocks replacement. Provider delivery/attempt/event evidence must match trusted owned current, recovery or immutable retired evidence; fabricated/foreign provider history is blocked. Executed notification generations and actual provider evidence remain in protected operational command records, preventing replay after restoration or timezone changes. User-controlled bundles cannot inject those records.

Recovery bodies expire after 24 hours. To recover, you download your recovery bundle and reapply it through the same preview/confirmation workflow. Operational retirement survives expiry. Infrastructure recovery uses a separate trusted backup/deletion-register procedure; portability never restores authentication or erases tombstones.

### H4 — Interfaces and acceptance

Settings provides owned source selection, files/unlinked cleanup, CSV review/resumption, exports, replacement preview and recovery links. Financial action, debt, application and statement pages expose files directly; all eight sources are available centrally. Labelled native controls, progressive disclosure, bounded pages and status feedback support keyboard/mobile use. Unconfirmed requests retain exact commands; confirmed rejections allow a new reviewed operation.

Actual verification, decisions and remaining gates are in `docs/reference/V2_DEVELOPMENT_HANDOFF.md`. Production setup is tracked in `docs/reference/V2_H_MANUAL_SETUP_AND_PRODUCTION_CHECKLIST.md`. Passing locally doesn't mean production is configured, a real malware scan ran, or anything is deployed.
I finished local H1–H4 acceptance on October 15, 2026. Household capacity verification defaults to 10,000 actions because I explicitly asked for that; original latency, integrity and concurrent-load assertions remain unchanged. The 50,000-action stress profile remains optional. Production file integrations remain disabled pending the documented operating gates.
