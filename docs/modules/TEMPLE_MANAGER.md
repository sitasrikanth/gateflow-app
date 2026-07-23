# Temple Manager — Module Documentation
**Module:** Temple Manager
**Status:** ✅ Live (Session 11 — 2026-07-24)
**Screens:** 8 screens under a single tabbed home screen (5 sub-tabs)

---

## 1. WHAT IT DOES

Manages a temple attached to the gated community — a standing amenity, not a time-boxed event like the ones in Event Fund Manager. Covers fund donations with configurable tiers and receipts, a daily ritual routine, priest and festival scheduling, physical asset inventory, recurring anniversary pooja reminders, and a transparency report combining everything into one audit trail.

Built as a **new top-level module**, separate from Events: a new "Temple" tab in the admin nav (5th tab, alongside Residents/Guards/Visitors/Events) and a new "Temple" Quick Access card on the resident home screen.

---

## 2. SCREENS

| Screen | File | Description |
|--------|------|-------------|
| Temple Home | `lib/screens/temple/temple_home_screen.dart` | Scaffold + 5 sub-tabs (Donations, Routine, Assets, Anniversaries, Reports); settings gear icon for admin |
| Donations Tab | `lib/screens/temple/temple_donations_tab.dart` | Stats, tier cards, pending-verification queue (admin), searchable/filterable donation history |
| Add Donation | `lib/screens/temple/add_temple_donation_screen.dart` | Record/self-report a donation — tier picker, donor details, payment mode (incl. In-Kind), category |
| Temple Settings | `lib/screens/temple/temple_settings_screen.dart` | Admin-only: manage contribution tiers, donation categories, expense categories |
| Routine Tab | `lib/screens/temple/temple_routine_tab.dart` | Daily pooja schedule, priest assignments, festival calendar, daily-reset ritual checklist |
| Assets Tab | `lib/screens/temple/temple_assets_tab.dart` | Asset inventory (category, condition, value) + per-asset maintenance log |
| Anniversaries Tab | `lib/screens/temple/temple_anniversaries_tab.dart` | Recurring pooja reminders, WhatsApp send, resident Confirm/Sponsor |
| Add Expense | `lib/screens/temple/add_temple_expense_screen.dart` | Admin-only temple expense entry (category, vendor, amount, date, note) |
| Reports Tab | `lib/screens/temple/temple_reports_tab.dart` | Collected/Spent/Balance stats, category breakdowns, combined audit-trail feed |
| Receipt PDF | `lib/utils/temple_pdf_report.dart` | `exportTempleDonationReceipt` — self-contained, doesn't share code with `event_pdf_report.dart` |

---

## 3. SUB-TABS

### Donations Tab
- Stat cards: Total Raised, This Month, Donor count (all computed live from the `templeDonations` collection — see §8 on why no incremented total field is used)
- "Record Donation" (admin) / "Contribute" (resident) button → `AddTempleDonationScreen`
- Contribution Tiers list (from `appSettings/templeDonationConfig.tiers`) shown to everyone
- **Pending Verification** (admin only) — resident self-reported donations (`selfReported: true, amountReceived: false`) with Confirm/Reject actions, same trust pattern as Events' self-report flow
- Donation History: search by donor name + category filter chips (client-side, matching the app's existing search/filter convention); tap a row for a detail sheet with PDF receipt, and admin Edit/Delete

### Routine Tab
Four sections in one scrollable tab, each admin-editable via an inline "+" icon on its header:
- **Daily Pooja Schedule** — time-sorted list of `{time, title, description}`, always shown as "today's routine" (not date-specific — it repeats daily)
- **Today's Ritual Checklist** — a configured task template (`appSettings/templeRoutine.ritualChecklist`) with completion state stored per-day in `templeRitualLog/{yyyy-MM-dd}`, so it resets automatically every day
- **Priest Assignments** — name + phone + assigned weekdays (Mon–Sun chips)
- **Upcoming Festivals** — dated calendar entries (`templeFestivals` collection), past ones hidden automatically

### Assets Tab
- Category filter chips (Idol, Ornament, Utensil, Furniture, Sound System, Other)
- Each asset card shows name, category, condition badge (Good/Needs Repair/Damaged, color-coded), estimated value
- Tap an asset → detail sheet with its maintenance history (`templeAssets/{id}/maintenanceLog` subcollection) and an admin "Add" button to log new maintenance/inventory entries

### Anniversaries Tab
- List sorted by days-until-next-occurrence (soonest first), highlighted if ≤7 days away
- Admin: add/edit/delete, "Send Reminder" (WhatsApp deep link, same `wa.me` pattern as the Follow-up tab)
- Resident: sees only their own flat's entries (matched via `session_flat`), can tap **Confirm** or **Sponsor** (opens the donation form)

### Reports Tab
- Collected / Spent / Balance stat cards
- Donations-by-category and Expenses-by-category progress bars
- Combined audit-trail feed: donations, expenses, and asset additions merged and sorted newest-first — nothing that moves money or property is invisible to the community
- Admin gets a "Record Expense" button → `AddTempleExpenseScreen`

---

## 4. FIRESTORE DATA MODEL

### `/appSettings/templeDonationConfig`
```
{
  tiers: [ {name, amount, benefits, recognition} ],   // amount is required (unlike sponsor packages)
  categories: [string],                                // donation purpose tags; default if unset:
                                                         // Annadanam, Festival, General Fund, Renovation, General
  expenseCategories: [string]                           // default if unset: Pooja Materials, Priest
                                                         // Honorarium, Maintenance, Utilities, Festival, Other
}
```

### `/templeDonations/{donationId}`
```
{
  donorName: string,
  wing: string, block: string, flatNumber: string,   // '' if isExternalDonor
  isExternalDonor: boolean,
  isAnonymous: boolean,
  amount: number,                      // 0 allowed for in-kind items with no stated value
  tierName: string,                    // '' if no tier selected
  category: string,
  paymentMode: string,                 // from community_settings.paymentModes, or 'In-Kind'
  inKindDescription: string,           // populated when paymentMode = 'In-Kind'
  referenceId: string,
  note: string,
  donatedAt: string (ISO), donatedDate: string (DD/MM/YYYY),
  amountReceived: boolean,             // true = confirmed; admin entries start true, resident entries start false
  selfReported: boolean,               // true when submitted by a resident, awaiting admin confirmation
  status: 'rejected' | 'deleted'?,     // absent = active/normal
  createdAt: string (ISO)
}
```

### `/templeExpenses/{expenseId}`
```
{ category: string, vendor: string, amount: number, note: string, date: string (ISO), createdAt: string (ISO) }
```

### `/templeAssets/{assetId}`
```
{
  name: string,
  category: 'Idol' | 'Ornament' | 'Utensil' | 'Furniture' | 'Sound System' | 'Other',
  condition: 'Good' | 'Needs Repair' | 'Damaged',
  value: number,                       // 0 if not estimated
  description: string,
  createdAt: string (ISO)
}
```

### `/templeAssets/{assetId}/maintenanceLog/{entryId}`
```
{ date: string (ISO), description: string, cost: number, performedBy: string, createdAt: string (ISO) }
```

### `/templeAnniversaries/{id}`
```
{
  residentName: string, wing: string, block: string, flatNumber: string, phone: string,
  occasionType: 'Wedding Anniversary' | 'Birthday Pooja' | 'House Warming' | 'Naming Ceremony' | 'Other',
  month: number, day: number,          // recurring yearly — no year stored
  note: string,
  confirmed: boolean, confirmedAt: string (ISO)?,
  createdAt: string (ISO)
}
```

### `/appSettings/templeRoutine`
```
{
  dailySchedule: [ {time: 'HH:mm', title, description} ],   // sorted by time
  priests: [ {name, phone, days: [string]} ],                 // days ⊆ Mon..Sun
  ritualChecklist: [string]                                    // task-name template
}
```

### `/templeRitualLog/{yyyy-MM-dd}`
```
{ completed: [string] }   // subset of appSettings/templeRoutine.ritualChecklist for that date
```

### `/templeFestivals/{id}`
```
{ name: string, date: string (ISO), description: string, createdAt: string (ISO) }
```

---

## 5. KEY TECHNICAL DECISIONS

| Decision | Reason |
|----------|--------|
| New top-level module, own admin tab + resident quick-access card, not nested under Events | A temple is a standing amenity, not a time-boxed event — Events' per-event contributions/expenses shape doesn't fit |
| Donation/expense totals computed live from their collections on every read, never an incremented ledger field | Avoids the entire class of `totalCollected` drift bugs (stale increments surviving delete/restore) fixed on the Events side this same session — a new module starts clean instead of inheriting that risk |
| Receipt PDF and its save/share helpers duplicated in `temple_pdf_report.dart` rather than reused from `event_pdf_report.dart` | Keeps the module decoupled per the "new top-level module" architecture choice; the duplicated code is small (one receipt layout, one bottom sheet) |
| Ritual checklist template (`appSettings/templeRoutine.ritualChecklist`) stored separately from daily completion state (`templeRitualLog/{date}`) | A checklist redone every day needs to reset automatically; a new date naturally produces a fresh, empty log doc with no extra reset logic needed |
| Anniversaries store month + day only, no year; "next occurrence" computed at read time with year-wraparound handling | These are yearly recurring occasions — storing a year would need annual manual updates to every record |
| Anniversary WhatsApp reminder uses the same simple `wa.me/91<phone>` pattern as the existing Follow-up tab, not the configurable-country-code infrastructure | Consistency with the majority of existing WhatsApp call sites in the app; full country-code plumbing can be added later if a non-Indian community needs it |
| Sponsor packages allow a ₹0/optional amount (Events module); Temple donation tiers require a positive amount | Different real-world use: Temple tiers are marketing-style giving levels (always priced), whereas Event sponsor items can be in-kind (an idol, flowers) with no fixed price |

---

## 6. PLANNED ENHANCEMENTS

- [ ] **True push notifications** for anniversary reminders — currently a manually-triggered WhatsApp link, no automatic day-of alert
- [ ] **PDF export of the full transparency report** (currently in-app view only, no downloadable summary)
- [ ] **Photo attachments** for assets and maintenance log entries (Events' Task Management already has an `image_picker` + Firebase Storage pattern to reuse)
- [ ] **Configurable country code** for the anniversary WhatsApp reminder, matching the Community Settings country-code feature already built for Events' Follow-up tab
