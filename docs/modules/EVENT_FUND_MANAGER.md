# Event Fund Manager — Module Documentation
**Module:** Event Fund Manager  
**Status:** ✅ Live (Sessions 1 & 2 — 2026-06-14)  
**Screens:** 6 screens + 1 dashboard with 3 tabs

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

### Contributions Tab
- Grouped by **Wing → Block → Flat** (nested `ExpansionTile`)
- Wing level: entry count, total received for that wing
- Block level: flat count, pending count badge
- Flat level: contribution amount, type badge, PENDING badge if not received, edit icon
- Grand total banner at bottom (received only, pending excluded)
- Flats sorted by flat number; wings/blocks sorted alphabetically

### Expenses Tab
- List of all expenses with category, sub-category, vendor, note, amount
- Subtitle format: `Category • Sub-category • Vendor • Note`
- FAB to add new expense

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
  contributionType: 'Regular' | 'Carry Forward' | 'Ganesh Laddu',
  paymentMode: 'Cash' | 'UPI' | 'Bank Transfer' | 'Cheque',
  amountReceived: boolean,      // false = pending
  referenceId: string?,         // optional
  date: Timestamp,
  notes: string?,
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

| Type | Description |
|------|-------------|
| Regular | Standard flat contribution |
| Carry Forward | Contribution carried from a previous event |
| Ganesh Laddu | In-kind contribution (laddus for prasad) |

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
- Changes reflected immediately in contribution form dropdowns

**Expense Categories section:**
- Add / rename / delete main categories (with emoji icon)
- Add / delete sub-categories per main
- Changes reflected immediately in Add Expense screen

Both sections are collapsible (`ExpansionTile` in `Card`). Add actions via `+` button in section header (opens dialog).

---

## 10. PLANNED ENHANCEMENTS

- [ ] **Pending follow-up list** — flats with `amountReceived: false`, with reminder notification button
- [ ] **PDF report** — contribution + expense summary exportable as PDF
- [ ] **Budget vs actual chart** — target vs collected vs spent on Overview tab
- [ ] **Resident view** — residents see their own contribution status for active events
- [ ] **Multiple events** — currently supports multiple events in list; ensure dashboard handles switching cleanly
- [ ] **Event templates** — reuse last year's category setup for recurring events
