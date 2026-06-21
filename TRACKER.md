# GateFlow — Progress Tracker
> Last updated: 2026-06-21 | Updated by Claude each session check-in.

---

## OVERALL PROGRESS

```
Phase 1 — Foundation & Auth          ████████████  Weeks 1–2   [ COMPLETE ✅ ]
Phase 2 — Core Features (Guard/Res)  ████████████  Weeks 3–6   [ COMPLETE ✅ ]
Phase 3 — Event Fund Manager         ████████████  Bonus       [ COMPLETE ✅ ]
Phase 4 — Testing & Launch           ░░░░░░░░░░░░  Weeks 7–12  [ Not Started ]
```

**Weeks completed:** 6 / 12  
**Current week:** Week 7 (paused — data import & testing phase)
**On track:** ✅ Yes — ahead of original plan  
**Launch date target:** ~2026-08-22

---

## WHAT'S BEEN BUILT (Summary)

| Module | Status | Notes |
|--------|--------|-------|
| Auth — Phone OTP login | ✅ | Firebase Auth, +91 prefix, 6-digit OTP |
| Auth — Profile setup | ✅ | Name, flat, role, Firestore save |
| Auth — Role-based routing | ✅ | Admin / Resident / Guard home screens |
| Guard — Visitor entry | ✅ | Name, flat, purpose chips, real-time log |
| Guard — Shift management | ✅ | Start/End shift, Break timer |
| Guard — Visitor log (today) | ✅ | Real-time StreamBuilder |
| Resident — Home screen | ✅ | Pending visitor badge, tabs |
| Resident — Approve/Deny visitor | ✅ | Real-time FCM notification + Firestore |
| Resident — Visitor history | ✅ | Last 30 days |
| Admin — Home dashboard | ✅ | Residents, Guards, Visitors, Events tabs |
| Admin — Resident management | ✅ | List, approve, deactivate |
| Admin — Guard management | ✅ | Add/remove guards |
| Admin — Visitor log | ✅ | All entries, searchable |
| Admin — Community Settings | ✅ | Wings → Blocks → Flats hierarchy, bulk add |
| Admin — Expense Categories | ✅ | Hierarchical categories with emoji icons, defaults |
| Event Fund Manager — Create event | ✅ | Name, target amount, dates |
| Event Fund Manager — Contributions | ✅ | Add, edit, carry forward, Ganesh Laddu types |
| Event Fund Manager — Expenses | ✅ | Record by category/sub-category, vendor |
| Event Fund Manager — Overview tab | ✅ | Budget progress, category breakdown |
| Event Fund Manager — Contributions tab | ✅ | Searchable list, pending/paid status |
| Event Fund Manager — Expenses tab | ✅ | List with delete, running total |
| Event Fund Manager — Follow-up tab | ✅ | Wing→Block→Flat hierarchy, pending chips |
| Event Fund Manager — PDF Export | ✅ | Wing/Block/Flat layout with amounts, Save to Downloads + Share |
| Event Fund Manager — Import CSV/Excel | ✅ | File picker, preview with validation, batch Firestore write |
| Resident — Events screen | ✅ | View active/closed events, contribution status |

---

## 🎉 EVENT FUND MANAGER — DETAILED STATUS

> Focus area for active development. Tracks every sub-feature across admin and resident views.

### ✅ Implemented

| Feature | Details |
|---------|---------|
| Create / Edit event | Name, target amount, start/end dates, edit after creation |
| Event list screen | Color palette cards, progress bar, active/closed filter |
| Close event | Locks contributions + expenses; admin only |
| Event Dashboard — Overview tab | Budget ring, collected vs target, category breakdown |
| Event Dashboard — Contributions tab (admin) | Wing → Block → Flat chip grid; chip shows flat + amount; tapping chip opens contribution history |
| Event Dashboard — Contributions tab (resident) | Resident sees only their own flat's status card + contribution entries — other flats hidden |
| Event Dashboard — Expenses tab | List with delete, running total, category + sub-category + vendor |
| Event Dashboard — Follow-up tab | Wing → Block → Flat chip grid; green=paid, orange=pending, grey=not recorded; wings/blocks with 0 unpaid hidden; bell icon to send WhatsApp reminder |
| Add contribution | Flat picker (Wing → Block → Flat), amount, type (Regular / Carry Forward / Ganesh Laddu), payment mode, date, optional reference ID |
| Edit contribution | Pre-filled form; adjusts `totalCollected` by diff |
| Delete contribution | Removes doc; `totalCollected` adjusts via `FieldValue.increment(-amount)` |
| Contribution types | Regular, Carry Forward, Ganesh Laddu — with Received / Pending toggle |
| Recalculate Totals | Admin ⋮ menu — recomputes `totalCollected` from actual contributions (fixes drift after console deletions) |
| Unassigned contributions section | Shows contributions whose flat number doesn't match current community structure; view / delete per entry |
| Add expense | Item name, hierarchical category/sub-category, vendor, amount |
| Expense categories | Hierarchical: 9 main categories with sub-categories; emoji icons; admin-configurable in Settings; auto-seeds defaults |
| Send FCM notification | Notify all residents from admin event dashboard |
| PDF Export | Wing → Block → Flat layout; amount per flat; Save to Downloads + Share |
| Import contributions (CSV/Excel) | Template download, file picker, preview with validation, batch Firestore write |
| Resident Events screen | View active/closed events; own contribution status card |
| Flats per floor (grouping) | Admin configures 12 or 15 flats/floor per block; contributions + follow-up + residents tab all show "Floor 1", "Floor 2" … labels |
| WhatsApp reminder after approve/reject | Admin gets WhatsApp deep-link dialog after approving/rejecting a resident registration; AndroidManifest patched for Android 11+ |

---

### 🔲 Pending — Events

| Feature | Priority | Notes |
|---------|----------|-------|
| **Resident Self-Report ("I've Paid")** | 🔴 High | Resident taps "I've Paid" → fills amount/mode/ref → saved as `selfReported: true, amountReceived: false` |
| Admin confirmation of self-reported payments | 🔴 High | Orange badge in Contributions tab; admin taps Confirm ✅ or Reject ❌ |
| FCM notification to resident on confirm/reject | 🔴 High | Resident notified when admin confirms or rejects their self-report |
| WhatsApp reminder from Follow-up tab | 🟠 Medium | Bell icon is shown; reminder dialog & message already built — verify end-to-end |
| Test Dushehra 2025 CSV import with real data | 🟠 Medium | Feature built; real data not yet imported |
| Validate PDF export with real data | 🟠 Medium | Feature built; needs real-data check |
| Bank Statement Import (Option 2) | 🟡 Low | Download CSV from HDFC/SBI → auto-match to flats by name/UPI |
| In-App Payment Gateway (Option 3) | 🟡 Low | Razorpay/Cashfree; requires merchant KYC — post MVP |
| Expense editing | 🟡 Low | Currently can only delete expenses; no edit form |
| Contribution receipt / PDF per flat | 🟡 Low | Single-flat receipt to share via WhatsApp |

---

## WEEK-BY-WEEK TRACKER

---

### ✅ WEEK 1 — Foundation & Setup
**Status:** ✅ Complete  
**Dates:** 2026-06-06 (Day 1)

| Task | Status | Notes |
|------|--------|-------|
| Install Flutter SDK | ✅ | D:\srikanth-sita-app\flutter |
| Create GitHub repo | ✅ | github.com/sitasrikanth/gateflow-app |
| Create Firebase project | ✅ | gateflow-ss, Auth + Firestore enabled |
| Connect Firebase to Flutter | ✅ | firebase_options.dart generated |
| Scaffold Flutter project | ✅ | D:\srikanth-sita-app\gateflow |

---

### ✅ WEEK 2 — Authentication & Onboarding
**Status:** ✅ Complete  
**Dates:** 2026-06-13 (Day 3)

| Task | Status | Notes |
|------|--------|-------|
| Phone OTP login screen | ✅ | +91 prefix, 10-digit validation |
| OTP verification screen | ✅ | 6-digit, auto-submit on last digit |
| Profile setup screen | ✅ | Name, flat, role |
| Role-based home routing | ✅ | Admin / Resident / Guard |
| Save user to Firestore | ✅ | /users/{uid} |
| 2-tab login (Resident/Admin + Guard PIN) | ✅ | Day 7 — guard quick code, pending approval |

---

### ✅ WEEK 3 — Guard App
**Status:** ✅ Complete  
**Dates:** 2026-06-13 (Days 4 & 8)

| Task | Status | Notes |
|------|--------|-------|
| Guard home screen (today's log) | ✅ | Real-time StreamBuilder, empty state |
| New Visitor entry form | ✅ | Name, flat, phone, purpose chips |
| Save visitor to Firestore | ✅ | /visitors collection |
| Shift management (Start/End/Break) | ✅ | Timer, shift state in Firestore |
| Real-time visitor log | ✅ | Today's entries, live sync |

---

### ✅ WEEK 4 — Resident App & Real-time Notifications
**Status:** ✅ Complete  
**Dates:** 2026-06-13 (Day 9)

| Task | Status | Notes |
|------|--------|-------|
| Resident home screen | ✅ | Tabs, pending visitor badge |
| Real-time visitor notification | ✅ | FCM push → in-app approve/deny screen |
| Approve visitor → guard notified | ✅ | Firestore update + FCM back to guard |
| Deny visitor → guard notified | ✅ | With optional reason |
| Visitor history screen | ✅ | Last 30 days |

---

### ✅ WEEK 5 — Admin Panel
**Status:** ✅ Complete  
**Dates:** 2026-06-13 (Day 8)

| Task | Status | Notes |
|------|--------|-------|
| Admin home dashboard | ✅ | 4 tabs: Residents, Guards, Visitors, Events |
| Resident management | ✅ | List, approve pending, deactivate |
| Guard management | ✅ | Add / remove guards |
| Visitor log (all entries) | ✅ | Real-time, searchable |
| Community Settings screen | ✅ | Wings → Blocks → Flats, bulk add, rename, delete |
| Expense categories management | ✅ | Hierarchical, emoji icons, seed defaults |

---

### ✅ WEEK 6 — Event Fund Manager (Bonus Module)
**Status:** ✅ Complete  
**Dates:** 2026-06-14 → 2026-06-20

This entire module was not in the original plan — built as a high-value addition for festival contribution tracking.

| Task | Status | Notes |
|------|--------|-------|
| Create Event screen | ✅ | Name, target, start/end date, status |
| Add Contribution screen | ✅ | Flat picker, amount, type, payment mode, date |
| Add Expense screen | ✅ | Item, category/sub-category, vendor, amount |
| Event Dashboard — Overview tab | ✅ | Budget ring, category pie, totals |
| Event Dashboard — Contributions tab | ✅ | Searchable, edit/delete, pending/paid filter |
| Event Dashboard — Expenses tab | ✅ | List, delete, running total |
| Event Dashboard — Follow-up tab (admin) | ✅ | Wing→Block→Flat grid, pending/not-recorded chips, send reminder |
| Resident Events screen | ✅ | View events, own contribution status |
| Send FCM notification to residents | ✅ | From admin event dashboard |
| Close event (admin) | ✅ | Locks contributions + expenses |
| Edit event details (admin) | ✅ | |
| PDF Export | ✅ | Wing/Block layout, amounts per flat, Save to Downloads / Share |
| Import Contributions (CSV/Excel) | ✅ | Template download, file picker, preview + validation, batch import |

---

### 🔄 WEEK 7 — Data Import Testing & Bug Fixing
**Status:** 🔄 In Progress  
**Dates:** 2026-06-20

| Task | Status | Notes |
|------|--------|-------|
| Import Dushehra 2025 real data via CSV | 🔄 | Feature built, ready to test |
| Validate PDF export with real data | 🔄 | |
| Fix bool/double crash in Community Settings | ✅ | `SingleChildScrollView` inside `ExpansionTile` — replaced with `Wrap` |
| Fix bool/double crash in Follow-up tab | ✅ | Same root cause, same fix |
| Fix ListTile background color warnings | ⚠️ | Cosmetic only, harmless, not yet fixed |
| Performance audit | 🔲 | |
| Test on 3 Android devices | 🔲 | |

---

### 🔲 WEEK 8 — Polish + Internal Testing
**Status:** 🔲 Not Started

| Task | Status |
|------|--------|
| Fix all P1/P2 bugs | 🔲 |
| Add loading states on all async operations | 🔲 |
| Add empty states on all list screens | 🔲 |
| App icon + splash screen | 🔲 |
| Firebase security rules audit | 🔲 |
| Cold start performance (<3 seconds) | 🔲 |

---

### 🔲 WEEKS 9–12 — Alpha / Beta / Launch
*(unchanged from original plan)*

---

## BUGS & ISSUES LOG

| # | Description | Severity | Status | Found | Fixed |
|---|---|---|---|---|---|
| 1 | `type 'bool' is not a subtype of type 'double?'` crash in Community Settings when expanding blocks | 🔴 P0 | ✅ Fixed | Week 6 | Week 7 |
| 2 | Same bool/double crash in Event Dashboard → Follow-up tab | 🔴 P0 | ✅ Fixed | Week 7 | Week 7 |
| 3 | `LinearProgressIndicator` crash — dynamic value from Firestore passed without explicit cast | 🟠 P1 | ✅ Fixed | Week 6 | Week 6 |
| 4 | ListTile background color warning (cosmetic) in block ExpansionTiles | 🟢 P3 | 🔲 Open | Week 6 | — |
| 5 | Block rename missing — no `_renameBlock` method existed in Settings screen | 🔴 P0 | ✅ Fixed | Week 7 | Week 7 |
| 6 | `totalCollected` showing stale value after contributions deleted from Firestore console | 🟠 P1 | ✅ Fixed | Week 7 | Week 7 |
| 7 | 9 old contributions invisible in flat-chip UI — flat numbers didn't match community structure | 🟠 P1 | ✅ Fixed | Week 7 | Week 7 |
| 8 | WhatsApp not opening after approval/rejection on Android 11+ | 🔴 P0 | ✅ Fixed | Week 7 | Week 7 |
| 9 | Resident could see all flats' contributions in Contributions tab | 🟠 P1 | ✅ Fixed | Week 7 | Week 7 |

**Severity:** 🔴 P0 (blocker) | 🟠 P1 (critical) | 🟡 P2 (major) | 🟢 P3 (minor)

---

## PACKAGES ADDED

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.10.0 | Firebase init |
| `firebase_auth` | ^6.5.2 | Phone OTP auth |
| `cloud_firestore` | ^6.5.0 | Database |
| `firebase_messaging` | ^16.3.0 | Push notifications (FCM) |
| `shared_preferences` | ^2.5.5 | Session persistence |
| `pdf` | ^3.11.0 | PDF generation |
| `printing` | ^5.13.0 | PDF share / save |
| `path_provider` | ^2.1.0 | Save files to Downloads |
| `file_picker` | ^8.0.0 | Pick CSV/Excel for import |
| `csv` | ^6.0.0 | Parse CSV files |
| `excel` | ^4.0.2 | Parse XLSX/XLS files |

---

## KEY DECISIONS LOG

| Date | Decision | Reason |
|------|----------|--------|
| 2026-05-30 | Flutter + Firebase | Best AI support, offline-first, free tier |
| 2026-05-30 | Android Phase 1 only | Faster launch, validate before iOS |
| 2026-05-30 | Society subscription pricing | Predictable MRR |
| 2026-06-14 | Event Fund Manager added as bonus module | High demand for Dushehra/festival contribution tracking; replaces manual Excel sheets |
| 2026-06-14 | Wings → Blocks → Flats hierarchy for community structure | Matches real Indian apartment layouts (DIAMOND Wing → Block A → DA101) |
| 2026-06-20 | PDF export shows Wing/Block layout (not flat table) | Matches how committee reviews data in meetings |
| 2026-06-20 | Import from CSV/Excel with preview + validation | Real data (Dushehra 2025) needs migration; preview prevents bad imports |
| 2026-06-20 | `SingleChildScrollView` inside `ExpansionTile` causes bool/double cast crash | Flutter 3.44 PageStorage key collision — fixed by replacing horizontal scroll with `Wrap` |

---

## PAYMENT COLLECTION ROADMAP

How residents pay (PhonePe / GPay / Bank Transfer / Cash) and how it gets into the app.

---

### ✅ Option 1 — Resident Self-Report *(Next up)*
**Status:** 🔄 In Progress  
Resident reports their own payment inside the app. Admin confirms with one tap.

**Flow:**
1. Resident opens event → taps "I've Paid"
2. Fills: Amount · Payment Mode · Transaction Ref / UTR · Date
3. Contribution saved as **Pending Verification** (`selfReported: true, amountReceived: false`)
4. Admin sees pending items in Contributions tab with orange badge
5. Admin taps Confirm ✅ or Reject ❌ — resident notified either way

**Tasks:**
| Task | Status |
|------|--------|
| "I've Paid" button on resident event card | 🔲 |
| Self-report form (amount, mode, ref, date) | 🔲 |
| Save as `selfReported: true, amountReceived: false` | 🔲 |
| Admin contributions tab — pending verification section | 🔲 |
| Admin one-tap confirm / reject | 🔲 |
| FCM notification to resident on confirm/reject | 🔲 |

---

### 🔲 Option 2 — Bank Statement Import
**Status:** 🔲 Not Started  
Download CSV from bank (HDFC/SBI/ICICI) → upload to app → auto-match transactions to flats by resident name or UPI ID.

**Flow:**
1. Admin downloads bank statement CSV from net banking
2. Opens Import screen → picks bank statement CSV
3. App detects bank format (HDFC / SBI / ICICI / generic)
4. Auto-matches transactions to flats using resident name / registered UPI ID
5. Unmatched rows shown for manual assignment
6. Confirm → bulk-import all matched contributions

**Tasks:**
| Task | Status |
|------|--------|
| Store resident UPI ID / bank name in profile | 🔲 |
| Detect bank CSV format (HDFC, SBI, ICICI headers) | 🔲 |
| Auto-match transactions → flats | 🔲 |
| Manual assignment UI for unmatched rows | 🔲 |
| Preview + confirm import | 🔲 |

---

### 🔲 Option 3 — In-App Payment Gateway (Razorpay / Cashfree)
**Status:** 🔲 Future — post MVP  
Resident pays directly inside the app. Contribution recorded automatically on payment success.

**Prerequisites:**
- Society needs a registered business / trust account
- Razorpay / Cashfree merchant account + KYC (~1–2 weeks)
- ~2% transaction fee per payment

**Tasks:**
| Task | Status |
|------|--------|
| Razorpay Flutter SDK integration | 🔲 |
| Payment order creation on backend / Cloud Function | 🔲 |
| Payment success webhook → auto-record contribution | 🔲 |
| Refund flow | 🔲 |
| Settlement report screen (admin) | 🔲 |

---

## NEXT UP

1. **Resident Self-Report ("I've Paid")** — resident-side form + admin confirmation flow
2. Verify WhatsApp deep-link works end-to-end after cold restart (AndroidManifest fix applied)
3. Test Dushehra 2025 CSV import with real data
4. Validate PDF export with real data
5. **Bank Statement Import (Option 2)**
6. Fix P3 ListTile background color warnings

---

## KEY DECISIONS LOG

| Date | Decision | Reason |
|------|----------|--------|
| 2026-05-30 | Flutter + Firebase | Best AI support, offline-first, free tier |
| 2026-05-30 | Android Phase 1 only | Faster launch, validate before iOS |
| 2026-05-30 | Society subscription pricing | Predictable MRR |
| 2026-06-14 | Event Fund Manager added as bonus module | High demand for Dushehra/festival contribution tracking; replaces manual Excel sheets |
| 2026-06-14 | Wings → Blocks → Flats hierarchy for community structure | Matches real Indian apartment layouts (DIAMOND Wing → Block A → DA101) |
| 2026-06-20 | PDF export shows Wing/Block layout (not flat table) | Matches how committee reviews data in meetings |
| 2026-06-20 | Import from CSV/Excel with preview + validation | Real data (Dushehra 2025) needs migration; preview prevents bad imports |
| 2026-06-20 | `SingleChildScrollView` inside `ExpansionTile` causes bool/double cast crash | Flutter 3.44 PageStorage key collision — fixed by replacing horizontal scroll with `Wrap` |
| 2026-06-20 | Payment collection: Option 1 (self-report) before Option 2 (bank import) | Self-report reduces admin entry immediately with no infrastructure; bank import adds automation later |

---

*Tracker Version: 2.1 | Started: 2026-05-30 | Updated: 2026-06-20*
