# Event Fund Manager — Module Documentation
**Module:** Event Fund Manager (+ Task Management)  
**Status:** ✅ Live (Sessions 1–8 — 2026-06-14 to 2026-07-04)  
**Screens:** 11 screens + 1 dashboard with 8 admin tabs / 4 resident tabs

---

## 1. WHAT IT DOES

Helps apartment communities collect and track money for community events like Ganesh Chaturthi, Diwali celebrations, etc., and coordinate the volunteer work behind them.

Admin creates an event with a target amount → collects contributions flat-by-flat (or from external donors, or sponsors) → tracks expenses by category → assigns and tracks volunteer tasks → closes the event with a final summary. Residents can self-report payments, register as volunteers, work assigned tasks, and download their own contribution history/receipts.

---

## 2. SCREENS

| Screen | File | Description |
|--------|------|-------------|
| Event List | `lib/screens/events/event_list_screen.dart` | All events with color palette, progress bar, status badge |
| Create / Edit Event | `lib/screens/events/create_event_screen.dart` | Name, description, target amount, expected amount per flat, start/end dates |
| Event Dashboard | `lib/screens/events/event_dashboard_screen.dart` | 8-tab admin dashboard / 4-tab resident dashboard |
| Add Contribution | `lib/screens/events/add_contribution_screen.dart` | Per-flat, sponsor, or external-donor contribution form with type, payment mode, anonymous toggle, received toggle |
| Add Expense | `lib/screens/events/add_expense_screen.dart` | Expense form with two-level category selection (per-event-type) + receipt photo |
| Send Notification | `lib/screens/events/send_notification_screen.dart` | Send pooja/prasad alert to all residents |
| Event Settings | `lib/screens/events/event_type_settings_screen.dart` | Per-event-type config: Pooja Schedule, Special Contribution, Expense Categories, Volunteer Roles, Collection Status by Block, Overview Stats, Leaderboard, Sponsor Packages |
| Sponsor Packages | `lib/screens/events/sponsor_packages_screen.dart` | Admin defines per-event sponsorship tiers (name, amount, perks) |
| Task Form | `lib/screens/events/task_form_screen.dart` | Create/edit a task — title, description, due date, assignees, checklist, dependencies |
| Task Detail Sheet | `lib/screens/events/task_detail_sheet.dart` | Shared bottom sheet (admin + assigned volunteer) — status, checklist, dependencies, comments, photos |
| Contribution History | `lib/screens/resident/contribution_history_screen.dart` | Resident's cross-event contribution list + PDF receipt download |

---

## 3. DASHBOARD TABS

**Admin (8 tabs):** Overview · Event · Contributions · Expenses · Follow-up · Volunteers · Tasks · Activity
**Resident (4 tabs):** Event (default) · Overview · Expenses · Volunteers

### Overview Tab
- Target amount vs total collected progress bar
- Total received, total pending, total expenses
- Event status badge (Active / Closed), with Reopen Event available once closed
- Admin popup menu: Edit Event, Close/Reopen Event, Send Notification, Manage Sponsor Packages, Delete Event (cascades all subcollections)
- **Configurable stat chips** — Cash, Online, Collected/Total, Spent, Expected, Balance, Anonymous, External, chosen per event type in Event Settings → Overview Stats (defaults to all shown)
- Collection status by block (live via `_BlockStatsWidget`); tapping a block jumps to Contributions tab filtered to it
- **Leaderboard** — "Top Contributors" ranked by flat total; anonymous and external-donor amounts are excluded from ranking (footnoted/shown separately). Configurable per event type for residents, but **always shown to admin** for oversight regardless of the setting
- **Special vs Regular breakdown** (admin only) — totals Regular vs Special separately, lists each special contribution by flat; External Donations excluded (own category)
- **External Donations** (admin only) — total + list of non-resident donors (broadband company, builders, store operators, etc.)
- **My Contribution** (resident only) — the logged-in resident's own running total, tap for a detail/edit/delete sheet
- **Our Sponsors** wall — public list of sponsor tiers/names, respects the Anonymous toggle
- Budget vs Actual PDF report export

### Contributions Tab (admin)
- Grouped by **Wing → Block → Flat** (nested `ExpansionTile`)
- Wing level: entry count, total received for that wing
- Block level: flat count, pending count badge
- Flat level: contribution amount, type badge, PENDING badge if not received, ANONYMOUS badge (admin still sees real name/flat — anonymity only hides identity from other residents), edit icon, PDF receipt download
- **Flat chip grid** — each block shows floor-grouped flat grid with configurable rows per floor (1/2/3 from community settings)
- Grand total banner at bottom (received only, pending excluded)
- Flats sorted by flat number; wings/blocks sorted alphabetically

### Follow-up Tab (admin only)
- Same Wing → Block → Flat chip grid layout
- Flat chips color-coded: green (paid), amber (pending), grey (no record)
- Rows per floor applied same as Contributions tab

### Expenses Tab
- List of all expenses with category, sub-category, vendor, note, amount, receipt photo
- Subtitle format: `Category • Sub-category • Vendor • Note`
- Categories loaded from `/eventTypeConfig/{eventTypeId}` (per-event-type); falls back to global categories
- FAB to add new expense

### Volunteers Tab (admin + resident)
- Admin: manually add volunteers with name, flat, role, phone; auto-approved
- Resident: self-register for available roles; sees a **"My Tasks"** section (only rendered if they have tasks assigned) with the same task cards/detail sheet used in the admin Tasks tab, minus edit/delete
- Roles are per-event-type, loaded from `/eventTypeConfig/{eventTypeId}.volunteerRoles`
- Default roles: Coordinator, Decoration, Food & Catering, Security, Music & Sound, Collection, Photography, Transport, Other

### Tasks Tab (admin only) — new in Session 8
Birds-eye view of task management for volunteer coordination. See §6 for full detail.
- Stat chips: Total / Pending / In Progress / Done, plus an overdue-count banner
- Status filter chips (All / Pending / In Progress / Done)
- Task cards: title, assignees, due date (red if overdue), checklist progress, dependency count, status
- FAB → Create Task (`TaskFormScreen`)
- Tap a card → shared detail sheet (`task_detail_sheet.dart`) with edit/delete, status, checklist, dependencies, comments, photos

### Activity Tab (admin)
- Chronological log of all contribution/volunteer adds, edits, approvals, rejections, deletions
- Status filter (pending/approved/rejected/deleted) alongside wing/block/date filters
- Soft-delete with restore option; rejected entries can now be permanently deleted
- Resident sees a prominent in-app banner when their own contribution is rejected

---

## 4. FIRESTORE DATA MODEL

### `/events/{eventId}`
```
{
  name: string,
  description: string,
  targetAmount: number,
  expectedAmountPerFlat: number?,  // optional; drives "Pay Remaining Balance" banner
  sponsorPackages: [ {name, amount, perks} ],  // admin-defined tiers
  startDate: Timestamp,
  endDate: Timestamp,
  status: 'active' | 'closed',
  totalCollected: number,       // atomic increment — received only
  totalExpenses: number,        // atomic increment on each expense add
  createdBy: string (uid),
  createdAt: Timestamp
}
```

### `/events/{eventId}/contributions/{contribId}`
```
{
  wing: string,                 // '' for External Donation
  block: string,                // '' for External Donation
  flatNumber: string,           // '' for External Donation
  fullAddress: string,
  residentName: string,         // donor/organization name for External Donation
  amount: number,
  contributionType: 'Regular Contribution' | 'Special Contribution' | 'Sponsorship' | 'External Donation'
                     | 'Carry Forward' | 'Ganesh Laddu' (legacy),
  specialDescription: string,   // populated when type = Special Contribution, else ''
  sponsorPackageName: string?,  // populated when type = Sponsorship
  isAnonymous: boolean,         // hides identity from other residents/public wall; admin always sees real name/flat
  paymentMode: string,          // from community_settings.paymentModes list
  amountReceived: boolean,      // false = pending
  referenceId: string?,         // optional; shown when mode requires reference (UPI, Bank, etc.)
  date: Timestamp,
  notes: string?,
  selfReported: boolean?,       // true when resident self-reported; absent or false for admin entry
  status: 'pending' | 'rejected' | 'deleted'?,  // absent = approved/normal
  createdAt: Timestamp
}
```

### `/events/{eventId}/expenses/{expenseId}`
```
{
  category: string,             // main category name
  subCategory: string?,         // sub-category name (optional)
  vendor: string?,
  amount: number,
  note: string?,
  receiptUrl: string?,          // Firebase Storage download URL
  date: Timestamp,
  createdAt: Timestamp
}
```

### `/events/{eventId}/tasks/{taskId}` — new in Session 8
```
{
  title: string,
  description: string,
  status: 'pending' | 'in_progress' | 'done',
  dueDate: Timestamp?,
  assignees: [ {volunteerId, name, flat, role} ],   // denormalized from the volunteers subcollection
  assigneeFlats: [string],       // parallel flat-only array, for the resident "My Tasks" array-contains query
  checklist: [ {text, done} ],
  dependsOn: [taskId],           // other task IDs in the same event that must be Done first
  photos: [string],              // Firebase Storage download URLs
  createdBy: 'admin',
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### `/events/{eventId}/tasks/{taskId}/comments/{commentId}`
```
{
  text: string,
  authorName: string,
  authorFlat: string,
  isAdmin: boolean,
  createdAt: Timestamp
}
```

### `/appSettings/poojaSchedule`
```
{
  enabledTypeIds: [string],     // event type IDs that show Pooja Schedule tab
  morningCapacity: number,      // default morning slot capacity (e.g. 2 families)
  eveningCapacity: number       // default evening slot capacity
}
```

### `/appSettings/specialContribution`, `/appSettings/leaderboard`, `/appSettings/sponsorPackages`, `/appSettings/payments`, `/appSettings/collectionStatusByBlock`, `/appSettings/deleteEvents`
```
{
  enabledTypeIds: [string]      // event type IDs where the feature is opt-in
}
```

### `/eventTypeConfig/{typeId}`
```
{
  expenseCategories: [          // per-event-type expense categories; auto-seeded from event_types.dart
    { name: string, icon: string, subCategories: [string] }
  ],
  volunteerRoles: [string],     // per-event-type volunteer roles list
  specialDescriptions: [string],// preset Special Contribution description chips
  specialDefaultNote: string,   // default note pre-filled in Add Contribution (Special type)
  overviewChips: [string]?      // which Overview stat chips show for this type; unset = all shown.
                                 // Values: cash, online, collected, spent, expected, balance, anonymous, external
}
```

### `/community_settings/address` (shared with other modules)
```
{
  wings: [string],                          // ['Diamond', 'Ruby', ...]
  wingBlocks: { wingName: [string] },       // { Diamond: ['A','B','C'], Ruby: ['A','B'] }
  flatsPerFloor: { wingName_block: number },// { Diamond_A: 12, Diamond_B: 8 }
  flatGridRows: { wingName_block: number }, // { Diamond_A: 2, Diamond_B: 1 } — rows per floor in UI
  paymentModes: [string],                   // ordered list; e.g. ['Cash','UPI','PhonePe',...]
  defaultNote: string,                      // pre-filled note in Add Contribution form
  residentLandingScreen: 'home' | 'events', // post-login landing screen for residents; defaults to 'home'
  expenseCategories: [
    {
      name: string,
      icon: string,                         // emoji
      subCategories: [string]
    }
  ]
}
```

---

## 5. EXPENSE CATEGORIES

### Category inheritance (two-level)
1. **Per-event-type** — `/eventTypeConfig/{typeId}.expenseCategories` (auto-seeded from `event_types.dart` on first expand in settings)
2. **Global fallback** — `kDefaultCategories` in `expense_categories_screen.dart` (used when no event type specified)

### Generic Default Categories (`kDefaultCategories` — global fallback)

| Icon | Main Category | Example Sub-categories |
|------|--------------|----------------------|
| 🍽️ | Food & Catering | Catering Service, Raw Materials, Snacks & Beverages, Plates & Cups |
| 🎨 | Decoration | Flowers & Garlands, Balloons, Banners & Flex, Stage Setup, Lighting |
| 🏠 | Venue & Setup | Hall Rental, Chairs & Tables, Tent / Shamiana, Cleaning |
| 🎤 | Entertainment | Performers, Anchor, Kids Activities, Games & Prizes |
| 🎵 | Music & Sound | Sound System, DJ / Band, Microphone Rental |
| 📸 | Photography | Photographer, Videographer, Drone, Printing |
| 🚗 | Transport | Vehicle Rental, Fuel, Parking Charges |
| 🎁 | Gifts & Prizes | Trophies, Gift Hampers, Certificates, Mementos |
| 📦 | Misc | — |

Event-type-specific defaults (e.g. Ganesh Chaturthi gets Ganesh Idol, Prasad, Priest) come from `event_types.dart` and are auto-seeded into `/eventTypeConfig/{typeId}` on first expand.

Admin can rename, delete, add main categories and sub-categories from **Event Settings → Expense Categories**.

---

## 6. TASK MANAGEMENT (new in Session 8)

Per-event task board for coordinating volunteer work — admin creates and assigns, volunteers work and report progress.

**Scope decisions:**
- **Per-event, not community-wide** — tasks live inside one event and can only be assigned to that event's approved volunteers, since volunteers register per-event (no community-wide pool)
- **Tasks tab is admin-only**; volunteers (who only have a resident login, no separate account) get a lightweight **"My Tasks"** view embedded in their existing resident Volunteers tab instead of a second tab

**Feature set (all built 2026-07-04):**

| Feature | How it works |
|---|---|
| Create Tasks | `TaskFormScreen` — title, description, due date |
| Assign Owners | Multi-select restricted to `status: approved` volunteers for that event |
| Due Dates | Date picker; overdue (past due, not Done) flagged red |
| Progress Tracking | Admin birds-eye stat chips (Total/Pending/In Progress/Done) + overdue banner + status filter |
| Checklist | Add/remove items in the form; toggled live by admin or assignee in the detail sheet (whole-array rewrite on toggle) |
| Dependencies | A task can depend on other tasks in the same event; detail view shows each dependency's live title + status. No cycle-detection — self-reference is simply excluded from the picker |
| Comments | `tasks/{taskId}/comments` subcollection, live stream, admin + assignee can post |
| Attach Photos | Camera or gallery via `image_picker`; uploaded to Firebase Storage at `tasks/{eventId}/{taskId}/{timestamp}.jpg`; shown as a thumbnail strip with delete |
| Status (Pending/In Progress/Done) | Editable by admin or the assigned volunteer from the shared detail sheet |

**Shared UI:** `task_detail_sheet.dart` is used both from the admin Tasks tab and the resident My Tasks section — an `isAdmin` flag gates the edit/delete buttons, everything else (checklist, status, comments, photos) is editable by both admin and the assigned volunteer.

---

## 7. CONTRIBUTION TYPES

| Type | Description | Extra Field |
|------|-------------|-------------|
| Regular Contribution | Standard flat contribution | — |
| Special Contribution | One-off special amount (e.g. from donor, surplus) | `specialDescription` text box |
| Sponsorship | Business/individual sponsor at a defined package tier | `sponsorPackageName` tier picker |
| External Donation | Donation from a non-resident source (broadband company, builder, store operator, etc.) | Donor/Organization Name instead of wing/block/flat; no flat selection shown |
| Carry Forward *(legacy)* | Contribution carried from a previous event | — |
| Ganesh Laddu *(legacy)* | In-kind contribution (laddus for prasad) | — |

**Special Contribution:** when this type is selected, a multi-line text field ("Special Contribution Description") is shown and required. Saved as `specialDescription` in Firestore. Loaded back when editing.

**Sponsorship:** tier picker populated from `events/{eventId}.sponsorPackages` (configured via Manage Sponsor Packages); shown publicly in the "Our Sponsors" wall unless anonymous.

**External Donation:** admin-only (reuses the existing admin-only Record Contribution screen — no extra permission code needed). Wing/block/flat UI is skipped entirely; a required "Donor / Organization Name" field is shown instead. Counted into Collected/Cash-Online totals like any other contribution, shown in a dedicated "External" Overview chip and an admin-only donor list, and excluded from the Special vs Regular breakdown and the Leaderboard ranking (which already skips empty-flat entries).

**Anonymous toggle:** available on Regular, Special, and Sponsorship types. Hides identity from other residents and the public Sponsors wall; **admin always sees the real name/flat** with an "ANONYMOUS" badge as a reminder. Anonymous totals are shown as a separate Overview stat chip and excluded from the ranked Leaderboard (footnoted instead).

Each contribution has a **Received / Pending** toggle:
- `amountReceived: true` → increments `totalCollected` on the event
- `amountReceived: false` → listed as pending, excluded from totals
- Edit mode: calculates diff (`newAmount - oldAmount`) and applies as `FieldValue.increment()` to avoid double-counting

---

## 8. KEY TECHNICAL DECISIONS

| Decision | Reason |
|----------|---------|
| `totalCollected` uses `FieldValue.increment()` | Atomic — safe for concurrent updates from multiple admins |
| Edit mode diffs old vs new amount | Prevents double-counting when editing received contributions |
| Contributions grouped Wing → Block in UI | Easy to spot missing flats per block; pending count visible without opening each flat |
| `TextEditingController.dispose()` via `addPostFrameCallback` | Synchronous dispose during dialog dismiss animation causes `editable_text.dart:6268` assertion crash |
| Categories stored as `List<Map<String,dynamic>>` | Supports sub-categories; flat `List<String>` was insufficient |
| `PageStorageKey` on each `ExpansionTile` | Preserves expand/collapse state across widget rebuilds |
| `flatGridRows` saved with read-merge-write (not `set merge:true`) | `set` with `merge:true` does shallow merge — replaces entire sub-map, wiping other blocks' rows settings |
| `flatGridRows` stored as `{wing_block: n}` map (not global int) | Different blocks have different floor sizes; a global rows setting would be wrong for mixed-size blocks |
| Payment modes loaded via `StreamSubscription` (not `FutureBuilder`) | Modes can change while the form is open; stream ensures the picker stays in sync |
| Admin tab bar: `_CustomTabBar`; Resident: classic `TabBar` | Admin has many tabs needing grocery-style horizontal layout; resident has fewer tabs and a simpler use case |
| Admin always sees real name/flat on anonymous contributions | Admin needs accurate accounting; anonymity is a public/other-resident-facing feature only |
| Admin always sees the Leaderboard regardless of the per-event-type setting | Oversight need is independent of whether the public leaderboard is enabled for that event type |
| External Donations stored in the existing `contributions` subcollection with empty wing/block/flat | Downstream aggregations (Leaderboard, Block Stats) already skip empty-flat entries gracefully; avoids a parallel data model |
| Task checklist/dependencies embedded as arrays; comments as a subcollection | Checklist/dependencies are small and bounded (cheap whole-array rewrite); comments grow unbounded and need their own live stream, consistent with how contributions/expenses/volunteers are modeled |
| Task assignment restricted to that event's approved volunteers | Volunteers register per-event; a global assignee pool would let tasks go to people not actually signed up for that event |
| Overview Stats chips configurable per event type, default = all shown | Different event types care about different numbers; unset config must not silently hide chips on existing events |

---

## 9. ADMIN FLOWS

### Create Event
1. Admin → Events tab → `+` FAB
2. Fill name, description, target amount, expected amount per flat (optional), start/end dates
3. Event created with `status: 'active'`

### Add Contribution
1. Event Dashboard → Contributions tab → `+` FAB
2. Choose contribution type (Regular / Special / Sponsorship / External Donation)
3. For Regular/Special/Sponsorship: select wing/block, enter flat number and resident name. For External Donation: enter donor/organization name instead (no flat)
4. Set amount, payment mode, anonymous toggle
5. Toggle Received/Pending
6. Save → `totalCollected` updated atomically (if received)

### Add Expense
1. Event Dashboard → Expenses tab → `+` FAB
2. Select main category → sub-category chips appear
3. Enter vendor, amount, note, date, optional receipt photo
4. Save → `totalExpenses` updated atomically

### Create Task (Session 8)
1. Event Dashboard → Tasks tab → "Create Task" FAB
2. Fill title, description, due date
3. Assign owners from that event's approved volunteers
4. Add checklist items and/or dependencies on other tasks
5. Save → task appears on the admin board and in each assignee's "My Tasks" section

### Edit Event
1. Event Dashboard → `⋮` menu → Edit Event
2. Pre-filled form loads (fetches fresh from Firestore if stream data not ready)
3. Save → event document updated

### Close / Reopen Event
1. Event Dashboard → `⋮` menu → "Close Event" (when active) or "Reopen Event" (when closed)
2. Status toggled between `'active'` and `'closed'`

### Delete Event
1. Event Dashboard → `⋮` menu → Delete Event (only shown when enabled for that event type)
2. Cascades delete across `contributions`, `expenses`, `poojaRegistrations`, `volunteers`, `schedule`, and the event doc itself

---

## 10. SETTINGS (Admin)

### Community Settings — `settings_screen.dart`
Accessed from Admin panel → Settings icon.

**Wings & Blocks:** Add/rename/delete wings and blocks, set flats per floor, set rows per floor (1/2/3).  
**Payment Modes:** Drag to reorder, add custom, remove. Stored in `community_settings/address.paymentModes`.  
**Expense Categories (global):** Global fallback categories (add/rename/delete). Per-event-type categories managed in Event Settings.
**Resident Landing Screen:** Home Screen vs My Events — where residents land right after login. Defaults to Home Screen.

### Event Settings — `event_type_settings_screen.dart`
Accessed from Admin panel → Events tab → tune icon (⚙️).

**Pooja Schedule:**
- Collapsable hierarchy: top section → EventCategory groups → individual event types
- Default morning/evening slot capacity (stepper)
- Controls whether Pooja Schedule section appears in the event dashboard

**Special Contribution:**
- Same hierarchy: category → event type → checkbox to enable
- Per-type: preset description chips (pre-fill in Add Contribution) + default note text
- Stored in `/eventTypeConfig/{typeId}` as `specialDescriptions` and `specialDefaultNote`

**Expense Categories:**
- Category → event type hierarchy; per-type category/sub-category editor
- Auto-seeds from `event_types.dart` on first expand
- Badge always shows count (defaults before seeding, live count after)
- Add / delete categories and sub-categories; Reset Defaults button

**Volunteer Roles:**
- Category → event type hierarchy
- Roles as chips: tap to rename, long-press to delete; Add Role button; Reset Defaults
- Stored in `/eventTypeConfig/{typeId}.volunteerRoles`
- Loaded by Volunteers tab on next dashboard open

**Collection Status by Block:** opt-in per event type — controls whether the live Block Stats widget shows on the Overview tab.

**Overview Stats (Session 8):**
- Per event type, choose which of the 8 Overview stat chips (Cash, Online, Collected/Total, Spent, Expected, Balance, Anonymous, External) are shown
- Stored as `/eventTypeConfig/{typeId}.overviewChips`; unset means all shown (safe default for existing events)

**Leaderboard:**
- Opt-in per event type — controls whether **residents** see the "Top Contributors" widget
- Admin always sees it regardless of this setting (Session 8 change)

**Sponsor Packages:**
- Opt-in per event type; admin then defines the actual tiers per-event via Event Tools → Manage Sponsor Packages

---

## 11. PLANNED ENHANCEMENTS

- [ ] **True push notifications** — rejection/reminder banners are currently in-app only (no FCM push yet)
- [ ] **Task dependency cycle detection** — currently only self-reference is excluded when picking dependencies
- [ ] **Event templates** — reuse last year's category/task setup for recurring events
- [ ] **Budget vs actual chart** — visual chart (currently numeric only) on Overview tab
