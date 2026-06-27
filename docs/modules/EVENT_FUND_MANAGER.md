# Event Fund Manager — Module Documentation
**Module:** Event Fund Manager  
**Status:** ✅ Live (Sessions 1–5 — 2026-06-14 to 2026-06-27)  
**Screens:** 6 screens + 1 dashboard with 5 admin tabs / 2 resident tabs

---

## 1. WHAT IT DOES

Helps apartment communities collect and track money for community events like Ganesh Chaturthi, Diwali celebrations, etc.

Admin creates an event with a target amount → collects contributions flat-by-flat → tracks expenses by category → closes the event with a final summary.

---

## 2. SCREENS

| Screen | File | Description |
|--------|------|-------------|
| Event List | `lib/screens/events/event_list_screen.dart` | All events with color palette, progress bar, status badge |
| Create / Edit Event | `lib/screens/events/create_event_screen.dart` | Name, description, target amount, start/end dates |
| Event Dashboard | `lib/screens/events/event_dashboard_screen.dart` | 3-tab dashboard: Overview, Contributions, Expenses |
| Add Contribution | `lib/screens/events/add_contribution_screen.dart` | Per-flat contribution form with type, payment mode, received toggle |
| Add Expense | `lib/screens/events/add_expense_screen.dart` | Expense form with two-level category selection |
| Send Notification | `lib/screens/events/send_notification_screen.dart` | Send pooja/prasad alert to all residents |

---

## 3. DASHBOARD TABS

### Overview Tab
- Target amount vs total collected progress bar
- Total received, total pending, total expenses
- Event status badge (Active / Closed)
- Admin popup menu: Edit Event, Close Event, Send Notification
- Collection status by block (live via `_BlockStatsWidget`)

### Contributions Tab (admin)
- Grouped by **Wing → Block → Flat** (nested `ExpansionTile`)
- Wing level: entry count, total received for that wing
- Block level: flat count, pending count badge
- Flat level: contribution amount, type badge, PENDING badge if not received, edit icon
- **Flat chip grid** — each block shows floor-grouped flat grid with configurable rows per floor (1/2/3 from community settings)
- Grand total banner at bottom (received only, pending excluded)
- Flats sorted by flat number; wings/blocks sorted alphabetically

### Follow-up Tab (admin only)
- Same Wing → Block → Flat chip grid layout
- Flat chips color-coded: green (paid), amber (pending), grey (no record)
- Rows per floor applied same as Contributions tab

### Expenses Tab
- List of all expenses with category, sub-category, vendor, note, amount
- Subtitle format: `Category • Sub-category • Vendor • Note`
- FAB to add new expense

### Activity Tab (admin)
- Chronological log of all contribution adds, edits, deletions
- Soft-delete with restore option

---

## 4. FIRESTORE DATA MODEL

### `/events/{eventId}`
```
{
  name: string,
  description: string,
  targetAmount: number,
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
  wing: string,
  block: string,
  flatNumber: string,
  residentName: string,
  amount: number,
  contributionType: 'Regular' | 'Carry Forward' | 'Special Contribution' | 'Ganesh Laddu',
  specialDescription: string,   // populated when type = Special Contribution, else ''
  paymentMode: string,          // from community_settings.paymentModes list
  amountReceived: boolean,      // false = pending
  referenceId: string?,         // optional; shown when mode requires reference (UPI, Bank, etc.)
  date: Timestamp,
  notes: string?,
  selfReported: boolean?,       // true when resident self-reported; absent or false for admin entry
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
  date: Timestamp,
  createdAt: Timestamp
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

### Default Categories (auto-seeded when empty)

| Icon | Main Category | Example Sub-categories |
|------|--------------|----------------------|
| 🍚 | Annadam | Rice, Dal, Vegetables, Oil, Plates, Cups, Spoons |
| 🎨 | Decoration | Flowers, Balloons, Banners, Rangoli, Lights |
| 🪔 | Ganesh Idol | Idol Cost, Transportation, Visarjan Arrangements |
| 🙏 | Priest / Pandit | Dakshina, Pooja Items, Flowers, Fruits |
| 🎵 | Music & Sound | DJ / Band, Sound System, Microphone Rental |
| 💡 | Lighting | Stage Lighting, Decoration Lights, Generator |
| 🚗 | Transport | Vehicle Rental, Fuel, Parking |
| 🍬 | Prasad | Modak, Coconut, Fruits, Sweets |
| 📦 | Miscellaneous | Printing, Stationery, Cleaning, Contingency |

Admin can rename, delete, add new main categories and sub-categories from Settings.

---

## 6. CONTRIBUTION TYPES

| Type | Description | Extra Field |
|------|-------------|-------------|
| Regular | Standard flat contribution | — |
| Carry Forward | Contribution carried from a previous event | — |
| Special Contribution | One-off special amount (e.g. from donor, surplus) | `specialDescription` text box |
| Ganesh Laddu | In-kind contribution (laddus for prasad) | — |

**Special Contribution:** when this type is selected, a multi-line text field ("Special Contribution Description") is shown and required. Saved as `specialDescription` in Firestore. Loaded back when editing.

Each contribution has a **Received / Pending** toggle:
- `amountReceived: true` → increments `totalCollected` on the event
- `amountReceived: false` → listed as pending, excluded from totals
- Edit mode: calculates diff (`newAmount - oldAmount`) and applies as `FieldValue.increment()` to avoid double-counting

---

## 7. KEY TECHNICAL DECISIONS

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
| Admin tab bar: `_CustomTabBar`; Resident: classic `TabBar` | Admin has 5 tabs needing grocery-style horizontal layout; resident has 2 tabs and simple use case |

---

## 8. ADMIN FLOWS

### Create Event
1. Admin → Events tab → `+` FAB
2. Fill name, description, target amount, start/end dates
3. Event created with `status: 'active'`

### Add Contribution
1. Event Dashboard → Contributions tab → `+` FAB
2. Select wing/block, enter flat number and resident name
3. Set amount, type, payment mode
4. Toggle Received/Pending
5. Save → `totalCollected` updated atomically (if received)

### Add Expense
1. Event Dashboard → Expenses tab → `+` FAB
2. Select main category → sub-category chips appear
3. Enter vendor, amount, note, date
4. Save → `totalExpenses` updated atomically

### Edit Event
1. Event Dashboard → `⋮` menu → Edit Event
2. Pre-filled form loads (fetches fresh from Firestore if stream data not ready)
3. Save → event document updated

### Close Event
1. Event Dashboard → `⋮` menu → Close Event (only when status = active)
2. Status set to `'closed'`

---

## 9. SETTINGS (Admin)

Accessed from Admin panel → Settings icon.

**Wings & Blocks section:**
- Add / rename / delete wings
- Add / delete blocks per wing
- Set flats per floor per block (shows flat grid preview)
- Set rows per floor (1/2/3) per block — shown inline next to "Set Floor Size"
- Changes reflected immediately in contribution form flat grid

**Payment Modes section:**
- Drag to reorder, add custom mode, remove mode
- Stored as ordered list in `community_settings/address.paymentModes`
- Propagated live to all contribution screens

**Expense Categories section:**
- Add / rename / delete main categories (with emoji icon)
- Add / delete sub-categories per main
- Changes reflected immediately in Add Expense screen

All sections are collapsible (`ExpansionTile` in `Card`). Add actions via `+` button in section header (opens dialog).

---

## 10. PLANNED ENHANCEMENTS

- [ ] **Push notifications** — admin sends payment reminders to specific flats/wings from Follow-up tab
- [ ] **Firebase Storage (Blaze plan)** — custom banner images and event type photos
- [ ] **PDF report** — contribution + expense summary exportable as PDF
- [ ] **Budget vs actual chart** — target vs collected vs spent on Overview tab
- [ ] **Event templates** — reuse last year's category setup for recurring events
