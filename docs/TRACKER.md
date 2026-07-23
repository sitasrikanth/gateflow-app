# GateFlow — 12-Week Progress Tracker
> Last updated: 2026-07-24 (Session 11) | Tell Claude what you completed and this file gets updated automatically.

---

## HOW TO USE
1. At the end of each day or week, tell Claude: *"Week 2 done. Completed auth, skipped camera for now."*
2. Claude updates this file with status, notes, and blockers.
3. Check this file at the start of each session: *"Show me my tracker."*

---

## OVERALL PROGRESS

```
Phase 1 — Foundation & Auth      ████████████  Week 1–2   [ 2 / 2 weeks done ] ✅
Phase 2 — Core Features          ████████████  Week 3–6   [ 4 / 4 weeks done ] ✅
Phase 3 — Complete MVP           ████████░░░░  Week 7–8   [ 2 / 2 weeks done ] ✅
Phase 4 — Testing & Launch       ░░░░░░░░░░░░  Week 9–12  [ 0 / 4 weeks done ]
```

**Weeks completed:** 8 / 12  
**Current week:** Week 9  
**On track:** ✅ Yes (ahead of schedule!)  
**Launch date target:** ~2026-08-22  

---

## WEEK-BY-WEEK TRACKER

---

### 🔄 WEEK 1 — Foundation & Research
**Status:** 🔄 In Progress  
**Dates:** 2026-06-06 → 2026-06-12  
**Theme:** Set up all tools, validate idea, scaffold project

| Task | Status | Notes |
|------|--------|-------|
| Install Flutter SDK | ✅ | Installed at D:\srikanth-sita-app\flutter |
| Install Cursor IDE | ✅ | Installed v3.7, gateflow project opened |
| Create GitHub repo: `gateflow` | ✅ | github.com/sitasrikanth/gateflow-app |
| Create Firebase project | ✅ | gateflow-ss, Auth+Firestore enabled |
| Connect Firebase to Flutter (FlutterFire CLI) | ✅ | firebase_options.dart generated |
| Scaffold Flutter project with folder structure | ✅ | Created at D:\srikanth-sita-app\gateflow |
| Create Figma account + Material 3 kit | 🔲 | figma.com → Community → Material 3 |
| Set up Notion workspace | 🔲 | Projects > GateFlow board |
| Complete 5 society admin interviews | 🔲 | Target: RWA secretaries, apartment managers |
| Document interview pain points | 🔲 | |

**Success Criteria:**
- [ ] App runs on Android emulator
- [ ] Firebase read/write works from app
- [ ] 3+ interviewees confirm visitor management is top pain

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 2 — Authentication & Onboarding
**Status:** ✅ Complete  
**Dates:** 2026-06-13 (Day 3)
**Theme:** Phone OTP login, profile setup, role routing

| Task | Status | Notes |
|------|--------|-------|
| Build Login screen (phone number input) | ✅ | +91 prefix, 10-digit validation |
| Build OTP verification screen | ✅ | 6-digit input, auto-submit on last digit |
| Build Profile setup screen | ✅ | Name, flat, tower, role selection |
| Implement role-based home routing | ✅ | AuthWrapper with StreamBuilder |
| Save user to Firestore on signup | ✅ | /users/{uid} document saved |
| Test full auth flow on real Android device | ✅ | Tested on Honor ELN W09 |
| Handle error states (invalid OTP, network) | ✅ | Error messages shown on screen |

**Success Criteria:**
- [x] Full auth flow working on real device
- [x] Role routing sends user to correct home screen
- [x] Profile data correct in Firestore

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 3 — Guard App: Visitor Entry
**Status:** ✅ Complete  
**Dates:** 2026-06-13 (Day 4) → 2026-06-14 (Day 8-9)
**Theme:** Core feature — guard logs a visitor

| Task | Status | Notes |
|------|--------|-------|
| Build Guard home screen (today's log) | ✅ | Shift mgmt + real-time visitor log |
| Build New Visitor entry form | ✅ | Name, flat, phone, purpose chips |
| Guard shift management | ✅ | Start/End Shift, Start/End Break, timer |
| Guard quick code login | ✅ | 6-digit code, no Firebase Auth needed |
| Integrate camera for visitor photo | 🔲 | Future enhancement |
| Save visitor document to Firestore | ✅ | /visitors collection, real-time sync |
| Show visitor in Today's Log (real-time) | ✅ | Filtered by guard ID + today's date |

**Success Criteria:**
- [x] Guard logs visitor in under 30 seconds
- [x] Visitor status updates in real time
- [ ] Works offline (entry queued, syncs later)

**Blockers:** None  
**Notes:** Shift management added. Guard session via SharedPreferences (no Firebase Auth).

---

### ✅ WEEK 4 — Resident App: Visitor Approval
**Status:** ✅ Complete  
**Dates:** 2026-06-14 (Day 9)
**Theme:** Resident approves/denies visitors in real-time

| Task | Status | Notes |
|------|--------|-------|
| Build Resident home screen (pending badge) | ✅ | Welcome card, stats, visitor list |
| Build incoming visitor notification banner | ✅ | Orange banner with visitor name + purpose |
| Implement real-time Firestore listener | ✅ | StreamBuilder on pending visitors for flat |
| Approve visitor → update Firestore + notify guard | ✅ | status → 'approved', guard sees instantly |
| Deny visitor → update Firestore + notify guard | ✅ | status → 'denied', guard sees instantly |
| Build visitor history screen | ✅ | Full list with status badges per flat |
| Build pre-approve visitor screen (OTP) | 🔲 | Next session |
| Admin Panel (approve residents, manage guards) | ✅ | 3-tab admin panel added (bonus!) |

**Success Criteria:**
- [x] Resident sees notification within 3 seconds (Firestore real-time)
- [x] Guard screen updates in under 2 seconds after approval
- [ ] Pre-approval OTP works end-to-end

**Blockers:** None  
**Notes:** Works across devices over internet via Firestore StreamBuilder. FCM (background notifications) planned next session.

---

### ✅ WEEK 5 — Event Fund Manager: Core Module
**Status:** ✅ Complete  
**Dates:** 2026-06-14 (Session 1)  
**Theme:** Community event/fund collection management

| Task | Status | Notes |
|------|--------|-------|
| Event list screen with color palette + progress bars | ✅ | `event_list_screen.dart` |
| Create Event form (name, description, target, dates) | ✅ | `create_event_screen.dart` |
| Event dashboard — 3-tab (Overview, Contributions, Expenses) | ✅ | `event_dashboard_screen.dart` |
| Add Contribution form (wing/block/flat, amount, type, mode) | ✅ | `add_contribution_screen.dart` |
| Add Expense form (category, vendor, amount, note) | ✅ | `add_expense_screen.dart` |
| Send Notification screen (pooja/prasad alerts) | ✅ | `send_notification_screen.dart` |
| Three contribution types (Regular, Carry Forward, Ganesh Laddu) | ✅ | With Received/Pending toggle |
| Edit existing contributions (pre-fill + adjust totalCollected diff) | ✅ | Atomic Firestore increment |
| Wings & Blocks configurable from admin Settings | ✅ | Reads from community_settings |
| Expense categories configurable from Settings (emoji picker) | ✅ | Load Defaults button |
| Wire Events tab into AdminHomeScreen + ResidentHomeScreen | ✅ | Fixed nested Scaffold issue |

**Success Criteria:**
- [x] Admin can create event and track contributions per flat
- [x] Dashboard shows live totals (received vs pending)
- [x] Wings and blocks are configurable, not hardcoded

**Blockers:** None  
**Notes:** Wings/blocks read from `community_settings/address`. Flat number digits-only enforced. Reference ID optional.

---

### ✅ WEEK 6 — Event Fund Manager: Enhancements + Settings Polish
**Status:** ✅ Complete  
**Dates:** 2026-06-14 (Session 2)  
**Theme:** Hierarchical categories, collapsible UI, event editing, bug fixes

| Task | Status | Notes |
|------|--------|-------|
| Contributions tab — Wing → Block nested grouping | ✅ | `_ContributionsTab` rewritten with nested `ExpansionTile` |
| Wing level: blue avatar, entry count, received total | ✅ | Sorted alphabetically |
| Block level: flat count, pending badge | ✅ | Flats sorted by flat number |
| Grand total banner (received only, excludes pending) | ✅ | |
| Edit Event — rename, change dates | ✅ | `existingEventId`/`existingData` params added to `CreateEventScreen` |
| Edit Event — deferred Firestore fetch if data not loaded yet | ✅ | Fixed race condition via `_fetchAndPrefill()` |
| Dashboard popup "Edit Event" menu item | ✅ | Popup now shows for all admins (not just active events) |
| Hierarchical expense categories (main + sub) | ✅ | Firestore: `{name, icon, subCategories:[...]}` |
| 9 default main categories with sub-categories | ✅ | Annadam, Decoration, Idol, Priest, Music, Lighting, Transport, Prasad, Misc |
| Settings: add/rename/delete main categories | ✅ | Emoji picker in dialog |
| Settings: add/delete sub-category chips per main | ✅ | "Add Sub-category" inside each `ExpansionTile` |
| Auto-seed default categories on first load | ✅ | `didUpdateWidget` silently seeds when empty |
| Add Expense: two-level category selection (main → sub chips) | ✅ | Sub resets when main changes |
| Expense list subtitle: Category • Sub-category • Vendor • Note | ✅ | |
| Settings — Wings & Blocks section collapsible | ✅ | `ExpansionTile` wrapped in `Card` |
| Settings — Expense Categories section collapsible | ✅ | Same pattern |
| Compact + buttons beside section headers (no inline forms) | ✅ | `+` opens dialog |
| Full settings_screen.dart rewrite with proper widget extraction | ✅ | `_SectionCard`, `_WingTile`, `_CategoryTile`, `_TileTrailing`, `_IconBtn` |

**Success Criteria:**
- [x] Contributions grouped by Wing → Block, totals visible at each level
- [x] Admin can rename event and change dates after creation
- [x] Categories have main + sub hierarchy, configurable from settings
- [x] Settings screen clean, collapsible, no crashes

**Blockers:** None  
**Notes:** `flutter analyze` returned "No issues found!" after full rewrite. `PageStorageKey` used on each `ExpansionTile` for persistent expand/collapse state.

---

### ✅ WEEK 7 — Event Fund: UX Polish & Settings Configurability
**Status:** ✅ Complete  
**Dates:** 2026-06-27 (Session 5)  
**Theme:** Flat grid layout, configurable payment modes, admin tab bar redesign, special contributions

| Task | Status | Notes |
|------|--------|-------|
| Fix overflow in Pending Verification card | ✅ | Wrapped "Already paid — Additional payment" in `Flexible` |
| Compact flat selection grid (60+ flats) | ✅ | Replaced Wrap with floor-grouped grid in `add_contribution_screen.dart` |
| Rows per Floor setting in community settings | ✅ | 1/2/3 toggle next to "Set Floor Size" per block in `settings_screen.dart` |
| Apply rows-per-floor to Contributions tab | ✅ | `event_dashboard_screen.dart` `_buildFlatChips` uses sub-row logic |
| Apply rows-per-floor to Follow-up tab | ✅ | Same sub-row logic in follow-up `_buildFlatChips` |
| Live settings propagation via StreamBuilder | ✅ | All three views update instantly; no restart needed |
| Configurable payment modes in community settings | ✅ | `_PaymentModesCard` with drag-to-reorder, add, remove |
| Payment modes synced to Admin add contribution | ✅ | `add_contribution_screen.dart` loads via stream subscription |
| Payment modes synced to Resident payment screen | ✅ | `resident_events_screen.dart` loads via StreamBuilder |
| Admin tab bar — grocery-style design | ✅ | `_CustomTabBar` with icon in rounded square + text + animated underline |
| Resident tab bar — keep classic design | ✅ | Classic `TabBar` on purple header for residents (2 tabs) |
| Special Contribution Description text field | ✅ | Admin and resident screens; saved as `specialDescription` in Firestore |

**Success Criteria:**
- [x] 60+ flats readable and selectable without excessive scrolling
- [x] Rows-per-floor setting applies live across all contribution screens
- [x] Payment modes configurable from admin settings; propagated everywhere
- [x] Special contribution has description field

**Blockers:** None  
**Notes:** `flatGridRows` stored as `flatGridRows.${wing}_${block}` map in Firestore. Read-merge-write pattern handles int→map migration from old data. Grocery-style tab bar only for admin (5 tabs); resident keeps classic purple bar.

---

### ✅ WEEK 8 — Event Settings: Per-Type Config & Volunteer Roles
**Status:** ✅ Complete  
**Dates:** 2026-06-28 (Session 6)  
**Theme:** Hierarchical admin settings for event types — Pooja Schedule, Special Contribution, Expense Categories, Volunteer Roles

| Task | Status | Notes |
|------|--------|-------|
| Event Settings screen (`event_type_settings_screen.dart`) | ✅ | Tune icon in admin Events tab opens settings |
| Pooja Schedule — enable per event type + slot capacity | ✅ | Category → event type collapse; morning/evening stepper |
| Special Contribution — enable per event type + preset chips + default note | ✅ | `_SpecialContributionSection`, per-type config |
| Expense Categories — per-event-type editor (hierarchical) | ✅ | Auto-seeds from `event_types.dart` defaults on first expand |
| Fix: category count badge always visible (not just after seeding) | ✅ | Shows default count before Firestore is written |
| Replace generic default categories (remove Annadam/Ganesh Idol etc.) | ✅ | Now: Food & Catering, Venue & Setup, Entertainment, Photography, Gifts & Prizes |
| Volunteer Roles — per-event-type roles editor | ✅ | `_VolunteerRolesSection`; add/rename/delete chips |
| Dashboard Volunteer tab loads roles from Firestore | ✅ | `_VolunteersTabState._loadRoles()` reads `/eventTypeConfig/{typeId}` |
| Wire `eventTypeId` to `_ContributionsTab` and `_VolunteersTab` | ✅ | Passed from main `build` → `data['eventTypeId']` |
| `AddContributionScreen` loads default note + preset descriptions | ✅ | Three nested StreamBuilders (specialContribution, eventTypeConfig, community_settings) |
| Firestore: `/appSettings/poojaSchedule`, `/appSettings/specialContribution`, `/eventTypeConfig/{typeId}` | ✅ | Paths live, rules open |

**Success Criteria:**
- [x] Admin can enable Pooja Schedule for specific event types only
- [x] Special Contribution chips and default note configurable per event type
- [x] Expense categories differ per event type (Ganesh vs Sports vs Kids)
- [x] Volunteer roles differ per event type and can be customised

**Blockers:** None  
**Notes:** Volunteer Roles stored under `volunteerRoles: [String]` in `/eventTypeConfig/{typeId}`. Dashboard loads roles once in `initState` (not real-time stream) — acceptable since roles rarely change mid-event.

---

### 🔜 WEEK 6 — Emergency SOS + Parking Management
**Status:** 🔲 Not Started  
**Dates:** TBD  
**Theme:** Safety features

| Task | Status | Notes |
|------|--------|-------|
| Emergency SOS button in resident app | 🔲 | Big red panic button on home screen |
| SOS alert → guard home screen instantly | 🔲 | Firestore real-time alert with flat + name |
| SOS history log (admin view) | 🔲 | All SOS events with timestamp |
| Visitor parking entry (guard logs) | 🔲 | Vehicle number, parking slot |
| Parking vacancy tracker | 🔲 | Available slots count |
| Parking approval by resident | 🔲 | Resident approves visitor parking |

**Success Criteria:**
- [ ] SOS reaches guard in under 2 seconds
- [ ] Guard sees resident flat + name on SOS alert
- [ ] Parking entry logged in under 20 seconds

**Blockers:** None yet  
**Notes:** —

---

### 🔜 WEEK 7 — Guard Patrol + Staff Tracking + Overstay Alerts
**Status:** 🔲 Not Started  
**Dates:** TBD  
**Theme:** Advanced guard features

| Task | Status | Notes |
|------|--------|-------|
| Guard patrol tracking (QR checkpoints) | 🔲 | QR scan at each checkpoint during night rounds |
| Patrol log (admin view) | 🔲 | Time + location of each checkpoint scan |
| Staff/Domestic Help entry form | 🔲 | Name, role, flat, attendance mark |
| Staff regular schedule tracking | 🔲 | Expected arrival/departure times |
| Overstay alert | 🔲 | Auto-alert if visitor stays > X hours |
| Move-in/Move-out controls | 🔲 | Admin approval required for large moves |
| Vehicle entry log | 🔲 | Plate number, vehicle type, flat |

**Success Criteria:**
- [ ] Patrol QR scan logs in under 5 seconds
- [ ] Overstay alert fires automatically
- [ ] Staff attendance tracked daily

**Blockers:** None yet  
**Notes:** —

---

### 🔜 WEEK 8 — Notice Board + Complaints
**Status:** 🔲 Not Started  
**Dates:** TBD  
**Theme:** Community communication

| Task | Status | Notes |
|------|--------|-------|
| Build Notice list screen | 🔲 | Category tabs, unread dot |
| Build Notice detail screen | 🔲 | Full text, timestamp |
| Admin posts notice → all residents notified | 🔲 | FCM broadcast |
| Build Raise Complaint form | 🔲 | Title, category, description, photo |
| Build My Complaints list screen | 🔲 | Status chips: Open/In Progress/Resolved |
| Admin complaint dashboard + status update | 🔲 | Notifies resident on update |

**Success Criteria:**
- [ ] Notice broadcasts to all residents within 10 seconds
- [ ] Complaint with photo submits in under 5 seconds on 4G
- [ ] Status updates reflect in real-time

**Blockers:** None yet  
**Notes:** —

---

### 🔜 WEEK 9 — Delivery + Intercom + Boom Barrier
**Status:** 🔲 Not Started  
**Dates:** TBD  
**Theme:** Complete guard app

| Task | Status | Notes |
|------|--------|-------|
| Delivery Entry form (guard) | 🔲 | Courier, package type, flat number |
| Delivery notification to resident | 🔲 | "Package from Amazon at gate" |
| Intercom simulation | 🔲 | Guard calls resident via app before entry |
| Boom barrier integration (future) | 🔲 | Auto open on approval |
| Offline entry queue | 🔲 | Store locally, sync on reconnect |
| Sync status indicator | 🔲 | "Syncing..." / "All synced ✓" |

**Success Criteria:**
- [ ] Delivery notification in under 5 seconds
- [ ] Offline entries sync correctly on reconnect

**Blockers:** None yet  
**Notes:** —

---

### 🔜 WEEK 10 — Polish + Bug Fix + Internal Testing
**Status:** 🔲 Not Started  
**Dates:** TBD  
**Theme:** Make it feel like a real product

| Task | Status | Notes |
|------|--------|-------|
| Fix all P0/P1 bugs | 🔲 | |
| Add loading states on all async operations | 🔲 | |
| Add empty states on all list screens | 🔲 | |
| Design and set app icon | 🔲 | 512x512 PNG |
| Build splash screen | 🔲 | |
| Build community onboarding flow | 🔲 | First-time setup for new society |
| Performance audit (cold start < 3 seconds) | 🔲 | |
| Security audit (Firebase rules) | 🔲 | OWASP checklist |
| Test on 3 Android devices | 🔲 | Low/mid/high-end |

---

### ✅ WEEK 8 — Polish + Bug Fix + Internal Testing
**Status:** 🔲 Not Started  
**Dates:** 2026-07-18 → 2026-07-24  
**Theme:** Make it feel like a real product

| Task | Status | Notes |
|------|--------|-------|
| Fix all P0/P1 bugs from Weeks 1–7 | 🔲 | |
| Add loading states on all async operations | 🔲 | |
| Add empty states on all list screens | 🔲 | |
| Add error screens with retry | 🔲 | |
| Design and set app icon | 🔲 | 512x512 PNG |
| Build splash screen | 🔲 | |
| Build community onboarding flow | 🔲 | First-time setup for new society |
| Performance audit (cold start < 3 seconds) | 🔲 | Use Claude code review prompt |
| Security audit (Firebase rules) | 🔲 | Use OWASP prompt from STARTUP_PLAN.md §9.8 |
| Test on 3 Android devices | 🔲 | Low/mid/high-end |

**Success Criteria:**
- [ ] Zero P0 bugs
- [ ] Cold start under 3 seconds on mid-range device
- [ ] No ANR crashes

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 9 — Alpha: 1 Real Society
**Status:** 🔲 Not Started  
**Dates:** 2026-07-25 → 2026-07-31  
**Theme:** First real users in the wild

| Task | Status | Notes |
|------|--------|-------|
| Sign APK and upload to Play Store Internal Testing | 🔲 | |
| Onboard 1 society (admin + 5 residents + 1 guard) | 🔲 | Friend/family connection preferred |
| Create feedback survey (Google Forms) | 🔲 | 10 questions |
| Monitor Crashlytics daily | 🔲 | |
| Fix critical bugs same day | 🔲 | |
| Daily WhatsApp check-in with society admin | 🔲 | |

**Society 1:** _(name TBD)_  
**Units:** —  
**Residents onboarded:** 0  

**Success Criteria:**
- [ ] No app crash in first 48 hours
- [ ] Visitor flow used 20+ times
- [ ] 3/5 residents rate 4+/5

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 10 — Beta: 3 Societies
**Status:** 🔲 Not Started  
**Dates:** 2026-08-01 → 2026-08-07  
**Theme:** Small-scale validation

| Task | Status | Notes |
|------|--------|-------|
| Onboard 2 more societies | 🔲 | Target: 50-unit, 100-unit, 200-unit |
| Set up WhatsApp Business support channel | 🔲 | |
| Create informal pricing page | 🔲 | Even a PDF is fine |
| Collect 3 testimonials | 🔲 | |
| Crash-free rate check (target >99%) | 🔲 | Firebase Crashlytics |
| FCM delivery rate check (target >95%) | 🔲 | |

**Society 1:** _(name TBD)_ — Units: — | Status: —  
**Society 2:** _(name TBD)_ — Units: — | Status: —  
**Society 3:** _(name TBD)_ — Units: — | Status: —  

**Success Criteria:**
- [ ] 3 active societies with daily usage
- [ ] 1+ testimonial secured
- [ ] Crash-free rate >99%

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 11 — Pre-Launch Prep
**Status:** 🔲 Not Started  
**Dates:** 2026-08-08 → 2026-08-14  
**Theme:** Everything ready before the big day

| Task | Status | Notes |
|------|--------|-------|
| Write Play Store listing (title, description, screenshots) | 🔲 | Use AI prompt from STARTUP_PLAN.md |
| Capture 5 Play Store screenshots | 🔲 | Use Android emulator |
| Build landing page | 🔲 | Carrd.co free tier — 1 hour job |
| Create LinkedIn, Instagram, Twitter/X accounts | 🔲 | Handle: @gateflow or similar |
| Record 3-minute demo video | 🔲 | Loom screen recording |
| Create press kit (1-page PDF) | 🔲 | |
| Submit app to Play Store for public review | 🔲 | Takes 3–7 days |
| Prepare list of 100 society contacts to email | 🔲 | |

**Waitlist signups target:** 100  
**Current signups:** 0  

**Success Criteria:**
- [ ] Play Store listing approved
- [ ] Landing page live with waitlist
- [ ] 100+ waitlist signups

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 12 — PUBLIC LAUNCH 🚀
**Status:** 🔲 Not Started  
**Dates:** 2026-08-15 → 2026-08-22  
**Theme:** Ship it

| Task | Status | Notes |
|------|--------|-------|
| Promote to Play Store Production track | 🔲 | |
| Post launch announcement on LinkedIn | 🔲 | |
| Post on Reddit (r/india, r/bangalore, r/Chennai etc.) | 🔲 | |
| Email 50 society secretary contacts | 🔲 | Use cold email template from STARTUP_PLAN.md |
| Post in Facebook groups (RWA groups, apartment groups) | 🔲 | |
| Monitor Crashlytics hourly on launch day | 🔲 | |
| Respond to every Play Store review | 🔲 | |
| Run smoke test suite on production build | 🔲 | |
| Book 5+ demo calls for Month 4 sales | 🔲 | |

**Launch Day Metrics:**
| Metric | Target | Actual |
|--------|--------|--------|
| Downloads (Day 1) | 100 | — |
| Downloads (Week 1) | 500 | — |
| Demo calls booked | 5 | — |
| Play Store rating | >4.0 | — |
| Production crashes | 0 | — |

**Blockers:** None yet  
**Notes:** —

---

## SOCIETIES TRACKER

| # | Society Name | City | Units | Status | Onboarded | Paying | Monthly Fee |
|---|---|---|---|---|---|---|---|
| 1 | — | — | — | 🔲 Prospect | — | No | — |
| 2 | — | — | — | 🔲 Prospect | — | No | — |
| 3 | — | — | — | 🔲 Prospect | — | No | — |

**Status legend:** 🔲 Prospect → 📞 Demo scheduled → 🧪 Pilot → 💰 Paying

---

## BUGS & ISSUES LOG

| # | Description | Severity | Status | Week Found | Week Fixed |
|---|---|---|---|---|---|
| 1 | Cross-drive Kotlin incremental build error (C: pub cache, D: project) | 🟠 P1 | ✅ Fixed | Week 2 | Week 2 |
| 2 | mitmproxy global proxy blocking Firestore | 🔴 P0 | ✅ Fixed | Week 2 | Week 2 |
| 3 | Firestore composite index missing (status+entryTime query) | 🟠 P1 | ✅ Fixed | Week 3 | Week 3 |
| 4 | PIN session persisting after app close | 🟡 P2 | ✅ Fixed | Week 3 | Week 3 |
| 5 | Guard routed to resident screen (Firebase Auth check before guard session) | 🔴 P0 | ✅ Fixed | Week 4 | Week 4 |
| 6 | Guards not showing in admin panel (missing createdAt field) | 🟡 P2 | ✅ Fixed | Week 4 | Week 4 |
| 7 | Visitors tab "no such method" error (null safety) | 🟠 P1 | ✅ Fixed | Week 4 | Week 4 |
| 8 | Red screen crash on dialog dismiss — `editable_text.dart:6268` assertion | 🔴 P0 | ✅ Fixed | Week 6 | Week 6 |
| 9 | Settings screen not showing categories; wings/blocks not collapsible | 🔴 P0 | ✅ Fixed | Week 6 | Week 6 |
| 10 | Event edit popup not appearing for closed/ended events | 🟠 P1 | ✅ Fixed | Week 6 | Week 6 |
| 11 | Edit Event form blank due to StreamBuilder race condition | 🟠 P1 | ✅ Fixed | Week 6 | Week 6 |
| 12 | `targetAmount` runtime error — `.toStringAsFixed()` on dynamic type | 🟠 P1 | ✅ Fixed | Week 6 | Week 6 |
| 13 | Overflow "RIGHT OVERFLOWED BY 19 PIXELS" in pending verification card | 🟡 P2 | ✅ Fixed | Week 7 | Week 7 |
| 14 | `type 'int' is not a subtype of Map` crash in settings_screen — old `flatGridRows` stored as int | 🔴 P0 | ✅ Fixed | Week 7 | Week 7 |
| 15 | Flat grid rows setting not propagating to contributions tab — shallow merge replaced whole map | 🟠 P1 | ✅ Fixed | Week 7 | Week 7 |
| 16 | Tab bar truncating labels ("Overv, Contr...") on mobile | 🟡 P2 | ✅ Fixed | Week 7 | Week 7 |
| 17 | Event cascade-delete missing `schedule` subcollection — orphaned Pooja slot bookings on event deletion | 🟠 P1 | ✅ Fixed | Session 8 | Session 8 |

**Severity:** 🔴 P0 (blocker) | 🟠 P1 (critical) | 🟡 P2 (major) | 🟢 P3 (minor)

---

## CONTRIBUTION & DONATIONS ROADMAP

Feature set for events like Ganesh Chaturthi, Navratri, Independence Day. Audited existing code on 2026-07-04 against a 9-item wishlist; two were already built. Build order below is MVP-first (low effort / high value first, and items that other items depend on go before their dependents).

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Custom Contribution | ✅ Built | Admin ("Record Contribution") and resident ("Report Payment") both accept any free-form amount. |
| 2 | Multiple Payment Methods | ✅ Built | Cash, UPI, PhonePe, Google Pay, Bank Transfer, NEFT/RTGS, Cheque, Other — configurable in Admin Settings. |
| 3 | Suggested Contribution | ✅ Built (2026-07-04) | Quick-amount chips (₹500/₹1000/₹2000/₹5000) added beside the amount field in both Record Contribution and Report Payment. |
| 4 | Anonymous Donation | ✅ Built (2026-07-04) | Toggle in both flows; `isAnonymous` stored on the doc, flat/name kept for admin accounting, name hidden + "ANONYMOUS" badge shown in admin's Contributions tab and pending-verification queue. |
| 5 | Contribution History | ✅ Built (2026-07-04) | New "My Contribution History" screen (receipt icon in My Events AppBar) — cross-event list with total-paid summary card. Queries each event's contributions subcollection per-flat rather than a Firestore collectionGroup query, to avoid requiring a manually-created composite index. |
| 6 | Download Receipt | ✅ Built (2026-07-04) | Per-contribution A5 PDF receipt (`exportContributionReceipt` in `event_pdf_report.dart`), downloadable from resident's Contribution History and admin's Contributions tab. Only offered for confirmed (non-pending) contributions. |
| 7 | Pay Remaining Balance | ✅ Built (2026-07-04) | New optional `expectedAmountPerFlat` field on event create/edit. Remaining-balance banner + "Pay Remaining" quick-chip in both Report Payment and Record Contribution. No "at a glance" indicator on the event card yet (only shown when opening the contribute flow) — noted as a possible future polish item. |
| 8 | Leaderboard | ✅ Built (2026-07-04) | Configurable per event type (new Leaderboard section in Event Settings, opt-in like Collection Status by Block). Overview tab shows "Top Contributors" ranked by flat total; anonymous contributions are summed separately as an unranked footnote, never shown with a flat number. |
| 9 | Sponsor Packages | ✅ Built (2026-07-04) | Configurable per event type (new section in Event Settings). Admins define tiers per event via Event Tools → Manage Sponsor Packages (`sponsor_packages_screen.dart`, stored as `events/{id}.sponsorPackages`). New "Sponsorship" contribution type with tier picker in Record Contribution. Public "Our Sponsors" wall in Overview tab, respecting the Anonymous toggle. |

**All 9 items shipped as of 2026-07-04.** Roadmap complete.

**Status legend:** ✅ Built | 🟡 Partial (exists but needs polish) | 🔲 Planned

---

## SESSION 8 — EVENT MANAGEMENT ENHANCEMENTS (2026-07-04)

Follow-on polish pass after the Contribution & Donations roadmap shipped, plus a new Task Management module.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Delete rejected contributions from Activity tab | ✅ Built | Admin can permanently remove rejected entries instead of only restoring them. |
| 2 | Status filter in Activity tab | ✅ Built | Filter chips for pending/approved/rejected/deleted alongside existing wing/block/date filters. |
| 3 | Block tap → Contributions tab | ✅ Built | Tapping a block in Block Stats jumps to the Contributions tab pre-filtered to that block. |
| 4 | Contribute Now vs Contribute More button colors | ✅ Built | Green vs blue for clearer visual distinction (previously green vs teal, too similar). |
| 5 | Resident "My Contribution" stat + detail sheet | ✅ Built | New Overview stat chip showing the logged-in resident's own total, with a tap-through detail/edit/delete sheet. |
| 6 | Rejection notification banner | ✅ Built | Prominent in-app red banner shown to a resident when their contribution is rejected (no backend push infra yet, so in-app only). |
| 7 | Admin Special vs Regular contribution breakdown | ✅ Built | New Overview widget totals Regular vs Special separately and lists each special entry by flat. Excludes External Donations (own category). |
| 8 | Reopen a closed event | ✅ Built | Event Tools menu shows "Reopen Event" when status is closed, "Close Event" when active. |
| 9 | Cascade-delete fix — `schedule` subcollection | ✅ Fixed | Event deletion was missing the Pooja Schedule slot-booking subcollection, leaving orphaned data. Added to the cascade-delete list. |
| 10 | Configurable Overview Stats chips | ✅ Built | New "Overview Stats" section in Event Settings — admin chooses which of Cash / Online / Collected / Spent / Expected / Balance / Anonymous / External chips show per event type. Defaults to all shown. |
| 11 | Admin-always-visible Leaderboard | ✅ Built | Admin now always sees "Top Contributors" on the Overview tab regardless of the per-event-type Leaderboard setting, for oversight. Residents still gated by the setting. |
| 12 | External Donations | ✅ Built | New "External Donation" contribution type for non-resident sources (broadband company, builders, store operators). No wing/block/flat — donor/organization name instead. Admin-only entry (reuses the existing admin-only Record Contribution screen). New admin-only "External Donations" viewer card + configurable "External" Overview chip beside Anonymous. |
| 13 | My Events header reposition | ✅ Built | Resident's "My Events" header now shows the resident name/flat info line above the "My Events" title (previously below), both moved up for better spacing above the tab bar. |

**Status legend:** ✅ Built | 🟡 Partial | 🔲 Planned

---

## TASK MANAGEMENT MODULE (2026-07-04)

New admin-only "Tasks" tab per event, scoped to that event's approved volunteers (per-event, not a community-wide board — decided since volunteers are only registered per-event). Volunteers have no separate login (they're residents), so a lightweight "My Tasks" view was added inside the resident-facing Volunteers tab instead of a second tab.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Create Tasks | ✅ Built | `TaskFormScreen` (`task_form_screen.dart`) — title, description, due date. |
| 2 | Assign Owners | ✅ Built | Multi-select picker restricted to that event's `status: approved` volunteers only. |
| 3 | Due Dates | ✅ Built | Date picker; overdue tasks (past due, not Done) flagged red in cards and detail view. |
| 4 | Progress Tracking | ✅ Built | Admin birds-eye view: stat chips (Total/Pending/In Progress/Done) + overdue banner + status filter chips. |
| 5 | Checklist | ✅ Built | Add/remove text items in the form; checkboxes toggled live by admin or assigned volunteer in the detail sheet. |
| 6 | Dependencies | ✅ Built | Tasks can depend on other tasks in the same event; detail view shows each dependency's live title + status. No cycle-detection (simple community-app scope), just self-reference is excluded. |
| 7 | Comments | ✅ Built | `tasks/{taskId}/comments` subcollection; both admin and assigned volunteers can post; shows author name + admin/resident badge. |
| 8 | Attach Photos | ✅ Built | Camera or gallery via `image_picker`, uploaded to Firebase Storage at `tasks/{eventId}/{taskId}/...`, shown as a thumbnail strip with delete. |
| 9 | Status (Pending/In Progress/Done) | ✅ Built | Editable by admin or the assigned volunteer from the shared detail sheet; drives the birds-eye stat counts. |

**All 9 items shipped as of 2026-07-04.**

**Status legend:** ✅ Built | 🟡 Partial | 🔲 Planned

---

## SESSION 9 — TAB VISIBILITY CONTROLS, EXPENSE DATES, IMPORT SAFETY (2026-07-17)

Live 2024 Ganesh Chaturthi data import (141 contributions, 40 expenses, cross-validated against the source spreadsheet's own check totals), several bug fixes surfaced during that import, a new app icon, and a two-tier tab/section visibility system for the event dashboard.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Live 2024 Ganesh Chaturthi data import | ✅ Done | Contributions + Expenses CSVs extracted from the source spreadsheet, cross-validated against its own summary totals, pushed to device and imported in-app. |
| 2 | Floor-aware bulk "Add Flats" range | ✅ Built | Range + "flats per floor" input generates 101–112, 201–212, etc. instead of one flat run. |
| 3 | Case-insensitive flat number matching | ✅ Fixed | CSV import wing/block tagging and Collection Status by Block both normalize flat numbers to uppercase before comparing. |
| 4 | Exact (non-abbreviated) amounts everywhere | ✅ Built | All 11 duplicated K/L-abbreviation `_fmt` helpers across the event dashboard replaced with comma-grouped exact figures. |
| 5 | Pooja Schedule 0-capacity slots | ✅ Built | Admin can set Morning/Afternoon/Evening capacity to 0; a 0-capacity shift is hidden from residents instead of shown as bookable. |
| 6 | Regular/Special contribution badge fix | ✅ Fixed | CSV import now normalizes the short "Regular" string to the canonical `kTypeRegular`; `_typeBadge()`'s catch-all no longer mislabels every non-Special contribution as "Special". |
| 7 | App icon — "GF" monogram | ✅ Built | Iterated through a gate+house design and a community-circle design before settling on a bold white "GF" monogram on the brand purple gradient, for legibility at small launcher sizes. |
| 8 | Event Settings visual restyle | ✅ Built | Bold border around every settings group (matching Allowed Event Categories); thinner matching border added to every sub-section card inside. |
| 9 | Resident Visibility — tabs | ✅ Built | New per-event-type setting: admin chooses which of the 7 resident-facing tabs residents see. Opt-in (unset = nothing shown); dashboard always keeps the Event tab as a safety-net minimum. Admins always see everything. |
| 10 | Resident Visibility — Overview sections | ✅ Built | Budget vs Actual, Stat Chips, Block Stats, Sponsors individually toggleable for residents, same opt-in policy. |
| 11 | Resident Visibility — per-tab sections (fast-follow) | ✅ Built | Extended the same section-toggle pattern to Event (Details/Schedule/Pooja), Expenses (Summary/By Category/List), Volunteers (Invitation/Appreciation/My Registrations), Competitions (list), Prasad (Today/Other Days), and Leaderboard (Main/Most Active Volunteers/Competition Winners/Apartment Participation) — one generalized settings-UI component reused across all 6 tabs instead of duplicating code per tab. |
| 12 | Applicable Tabs (two-tier visibility model) | ✅ Built | New event-type-scoped setting, separate from Resident Visibility: a tab can be marked as not applicable to a given event type at all (e.g. no Prasad tab for a Community Potluck), hiding it for **both** admin and resident. Opt-out (unset = all 11 tabs applicable), so existing event types are unaffected until narrowed down. Required making the admin tab bar/`TabController` dynamic (previously a fixed 11-tab list) and rewriting the FAB's tab detection from raw index checks to tab-identity checks. |
| 13 | Expense date picker | ✅ Built | Add Expense form previously had no date field at all (always stamped `DateTime.now()`); added a date picker mirroring Add Contribution's UX, backdatable, used for both new and edited expenses. |
| 14 | Mandatory date in Expenses CSV import | ✅ Built | Blank Date column now rejected as an error row instead of silently defaulting to today. |
| 15 | Duplicate-import protection | ✅ Built | Both Contributions and Expenses CSV import now fetch existing records once before parsing and flag rows matching an existing record's flat/item + amount + date as duplicates — auto-excluded from the import and shown in a distinct blue-grey "duplicate" style in the preview, instead of silently creating duplicate records and double-counting `totalCollected`/`totalSpent` on repeat imports. |

**Status legend:** ✅ Built | 🟡 Partial | 🔲 Planned

---

## SESSION 10 — CARRY-FORWARD SELF-HEALING, SPONSOR ITEMS, SETTINGS SEARCH (2026-07-18)

Bug-fix-heavy session triggered by real usage of the carry-forward and sponsor-package features after Session 9's data import, plus a batch of UX cleanup requested along the way.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Carry-forward delete/restore lifecycle rebuilt | ✅ Fixed | New `events/{sourceId}/carryForwardTransfers/{id}` subcollection bidirectionally linked to the destination contribution (`carryForwardTransferId` / `destContributionId`). Deleting the destination-side entry now reverses (`reversed: true`) the source transfer instead of leaving it stuck; `carriedForwardOut` on the source event is recomputed fresh from live transfers on every delete/restore/recalculate instead of trusting `FieldValue.increment`, eliminating the drift bugs that showed up under real use. |
| 2 | "Recalculate Carry-Forward Balance" admin action | ✅ Built | New Event Tools menu item that cross-checks every transfer against its destination contribution's live status and rewrites `reversed`/`carriedForwardOut` from scratch — self-heals any already-broken data from before this fix existed. |
| 3 | Restore removed for carry-forward Activity entries | ✅ Built | Deleting a carry-forward-out log entry is now log-only (no Restore button); admin re-imports the balance via Carry Forward Balance picker instead, which is self-healing by design. |
| 4 | Legacy carry-forward data fallback | ✅ Built | Transfers created before the linking system existed (no `carryForwardTransferId`) are matched by `destEventId` + `amount` as a best-effort fallback, filtering `reversed != true` client-side (Firestore `!=` excludes docs missing the field entirely). |
| 5 | Anonymous contributions given display priority | ✅ Fixed | A contribution's `isAnonymous` flag now takes precedence over its `contributionType` for *display* purposes — excluded from Residents/wing tiles, Unassigned, External Donations, and Sponsored Contributions sections (previously showed in two places at once); Overview's Anonymous vs External stat chips now use `if/else if` instead of independent `if` checks. Grand totals were never actually double-counted — only the visual listing was confusing. |
| 6 | Cash/Online breakdown on External Donations + Anonymous sections | ✅ Built | Matches the breakdown already shown on Residents and Unassigned sections in the Contributions tab. |
| 7 | Carried Forward chip merged into Anonymous/External card | ✅ Built | Moved out of its own standalone row in Overview and folded into `_AnonymousExternalCard` as a third chip, alongside Anonymous and External. |
| 8 | Residents-contributed count in Collection Status by Block | ✅ Built | "`X of Y residents contributed`" line added above the wing list, computed from the same paid/total flat counts used to render the block chips below it. |
| 9 | Sponsor Packages: amount made optional | ✅ Built | Not every sponsor item (e.g. a donated idol) has a fixed price; the Add/Edit dialog no longer requires an amount, and items with none just show the name (no "₹0"). |
| 10 | Sponsor Packages: "Tier" renamed to "Item" | ✅ Built | "Add/Edit Sponsor Tier" → "Add/Edit Sponsor Item", "Tier Name" → "Item Name", empty-state and delete-confirm text updated to match, across both the management screen and the Add Contribution sponsor picker. |
| 11 | Sponsor tier/item dialog validation fix | ✅ Fixed | Previously silently discarded the entered name/amount if invalid with zero feedback (dialog just closed and nothing appeared); now validates inline with a visible error message and doesn't close until valid. |
| 12 | Sponsorship Wing/Block/Flat fully optional | ✅ Fixed | Previously required Flat if Wing/Block were set; now all three are independently optional with no cross-field requirement, and labels simplified to a plain "(Optional)" suffix. |
| 13 | Contribution Type selector: cards → dropdown | ✅ Built | Replaced the tappable-card list with a `DropdownButtonFormField`, description shown below the selected value. |
| 14 | Event Settings search bar | ✅ Built | Search box at the top of Event Settings filters a static registry of every leaf setting section; tapping a result auto-expands its parent group and scrolls it into view — solves the "can't find Sponsor Packages, it's 3 levels of collapsed sections deep" problem. |
| 15 | Sponsor Highlights card moved from Overview to Event tab | ✅ Built | The "Thank You to Our Sponsors!" narrative card is no longer unconditionally shown on Overview; it now lives in the Event tab, gated behind a new `sponsor_highlights` toggle in Event Settings → Resident Visibility → Event Tab Sections (same opt-in pattern as Event Schedule/Pooja Schedule), positioned above Event Schedule per follow-up request. |
| 16 | Sponsorship amounts excluded from Contributions tab total | ✅ Built | The tab's own "Total: ₹X" header sum now skips `Sponsorship`-type contributions (item value is often nominal, not cash collected) — a local display-only change, doesn't touch the event's official `totalCollected` ledger or Overview/Budget-vs-Actual figures. Individual amounts are still shown in the Sponsored Contributions section. |
| 17 | Sponsor amount removed from the public highlight card | ✅ Built | The Event tab's Sponsor Highlights card no longer shows a ₹ figure per sponsor (still shown per-item in the admin Contributions tab). |
| 18 | "sponsored X tier" text bug | ✅ Fixed | Dropped the redundant literal word "tier" from the sentence (was rendering e.g. "sponsored Laddu tier" even when "Laddu" was just the item name). |

**Status legend:** ✅ Built | 🟡 Partial | 🔲 Planned

---

## SESSION 11 — NEW MODULE: TEMPLE MANAGEMENT (2026-07-24)

Community requested a new amenity module for a temple attached to the gated community, distinct from Events (which are time-boxed) since a temple is an ongoing amenity. Built as a brand-new top-level module — new "Temple" tab in admin nav (5th tab), new "Temple" Quick Access card on resident home — covering all 7 requested features across 5 sub-tabs. See `docs/modules/TEMPLE_MANAGER.md` for full detail.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Temple Fund Contributions / Donations | ✅ Built | Configurable tiers (name, amount, benefits, recognition), donor details with an external/non-resident toggle, payment mode including a dedicated In-Kind option, categories, anonymous toggle, PDF receipts, searchable/filterable history, resident self-report → admin-confirm pending queue (same trust pattern as Events). Totals computed live from the collection rather than an incremented ledger field, avoiding the whole class of drift bugs just fixed on the Events side this session. |
| 2 | Anniversary Pooja Reminders | ✅ Built | Recurring (month + day, no year) occasions sorted by days-until-next-occurrence; WhatsApp deep-link reminder (no push notification infra yet, matches the existing Follow-up tab's reminder pattern); resident Confirm / Sponsor-this-pooja actions (Sponsor opens the donation form). |
| 3 | Transparency & Tracking | ✅ Built | Reports tab: Collected/Spent/Balance stats, category breakdowns (donations and expenses separately) as progress bars, and a merged chronological audit-trail feed combining donations + expenses + asset additions. Read-only for residents; admin gets the same view plus a Record Expense entry point. |
| 4 | Daily Temple Routine | ✅ Built | Four sub-sections in one tab: configurable daily pooja schedule (time-sorted), priest assignments (name + assigned weekdays), festival/special-event calendar (dated, upcoming-sorted), and a ritual checklist whose completion state resets automatically every day (a new date is a fresh, empty log doc). |
| 5 | Temple Donations | ✅ Built | Same feature as #1 — the original wishlist's #5 and #7 (Donation History) were the same thing described twice; merged into one. |
| 6 | Temple Assets | ✅ Built | Inventory (idols, ornaments, utensils, furniture, sound systems, etc.) with category, condition (Good/Needs Repair/Damaged), estimated value, and a per-asset maintenance log subcollection (date, description, cost, performed by) — same "small bounded fields + unbounded subcollection" pattern as Task comments. |
| 7 | Donation History | ✅ Built | Merged into #1/#5 (see above). |

**Status legend:** ✅ Built | 🟡 Partial | 🔲 Planned

---

## KEY DECISIONS LOG

| Date | Decision | Reason |
|---|---|---|
| 2026-05-30 | Flutter + Firebase chosen | Best AI support, offline-first, free tier |
| 2026-05-30 | Android Phase 1 only | Faster launch, validate before iOS investment |
| 2026-05-30 | Society subscription pricing | Predictable MRR, single decision-maker |
| 2026-06-13 | Guard login via 6-digit quick code (no OTP) | Guards don't have smartphones always; simpler UX |
| 2026-06-13 | Guard session in SharedPreferences (no Firebase Auth) | Guards need fast login without phone verification |
| 2026-06-13 | Hybrid RBAC — roles for routing, permissions array for admin UI | Flexible without complex Firebase rules |
| 2026-06-13 | Resident status = 'pending' until admin approves | Security — prevents unauthorized access |
| 2026-06-14 | Visitor notification via Firestore StreamBuilder (not FCM) | Works in-app instantly; FCM added later for background |
| 2026-06-14 | Visitor status flow: pending → approved/denied | Guard logs, resident decides, guard sees result |
| 2026-06-14 | Hierarchical expense categories (`{name, icon, subCategories:[]}`) | Flat list insufficient for community events (Annadam has rice/veg/plates sub-items) |
| 2026-06-14 | Dialog-based add forms instead of inline forms in settings | Inline forms too space-heavy in collapsed card UI |
| 2026-06-14 | `TextEditingController.dispose()` deferred via `addPostFrameCallback` in all dialogs | Synchronous dispose triggers `editable_text.dart` assertion during dismiss animation |
| 2026-06-14 | Extract `StatelessWidget` subclasses when `ExpansionTile` tree gets complex | Monolithic build methods cause `PageStorageKey` state and gesture detection bugs |
| 2026-06-14 | Contributions grouped Wing → Block, not flat list | Makes it easy to spot missing flats per block; pending count visible at block level |
| 2026-06-27 | Flat grid rows stored per-block as `flatGridRows.${wing}_${block}` map in Firestore | Different blocks have different floor sizes; global setting would be wrong |
| 2026-06-27 | Read-merge-write pattern for `flatGridRows` updates (not `set` with merge) | Shallow merge in `set` replaces whole sub-map; read-merge-write preserves all blocks |
| 2026-06-27 | Grocery-style tab bar for admin only; classic bar for residents | Admin has 5 tabs needing more horizontal space; resident has only 2 tabs and simple use case |
| 2026-06-27 | Payment modes configurable in community settings (not hardcoded) | Admin wanted PhonePe/Google Pay by default but needed flexibility for future |
| 2026-06-28 | Per-event-type config stored in `/eventTypeConfig/{typeId}` (separate from `/appSettings`) | App-level settings (which types support pooja) live in `/appSettings`; per-type details (categories, roles, special note) live in `/eventTypeConfig` — keeps documents small |
| 2026-06-28 | Volunteer roles loaded once in `initState` (not StreamBuilder) | Roles don't change mid-event; one fetch is cheaper and simpler than a live stream on every tab |
| 2026-06-28 | Expense category count badge shows default count before seeding | UX fix — badge was hidden until admin expanded the event type once, which felt broken |
| 2026-06-28 | `kDefaultCategories` replaced with generic names (removed Annadam, Ganesh Idol) | Fallback defaults apply to any event type; event-type-specific defaults come from `event_types.dart` |
| 2026-07-04 | Anonymous Donation moved up to #4 in Contribution & Donations roadmap (ahead of Contribution History/Receipt) | Deciding the anonymous-entry data shape early avoids reworking Leaderboard ranking and history display later |
| 2026-07-04 | Sponsor Packages placed last in Contribution & Donations roadmap | Highest complexity (tiers, perks, admin config) and least essential for a resident-run festival fund vs. a corporate-sponsored event |
| 2026-07-04 | Admin always sees the Leaderboard; residents remain gated by the per-event-type setting | Admin needs contribution rankings for oversight even on event types where the public leaderboard is intentionally turned off |
| 2026-07-04 | External Donations reuse the existing `contributions` subcollection (empty wing/block/flat) instead of a new collection | Downstream aggregations (Leaderboard, Block Stats) already skip empty-flat entries gracefully; avoids a parallel data model for a small feature |
| 2026-07-04 | External Donations counted into Collected/Cash-Online totals, same as Anonymous | Money still gets deposited into the event fund; it's a labeling/reporting distinction, not a separate ledger |
| 2026-07-04 | Task Management scoped per-event, assignable only to that event's approved volunteers | Volunteers register per-event (no community-wide volunteer pool); a global task board would let tasks be assigned to people not actually signed up for that event |
| 2026-07-04 | Resident "My Tasks" view embedded in the existing Volunteers tab instead of a new resident-facing tab | Volunteers only have a resident login (no separate account); admin explicitly asked for the Tasks tab itself to stay admin-only |
| 2026-07-04 | Task checklist and dependencies stored as embedded arrays on the task doc; comments as a subcollection | Checklist/dependency lists are small and bounded (whole-array rewrite is cheap); comments grow unbounded over an event's lifetime and benefit from their own live stream, consistent with how contributions/expenses/volunteers are already modeled as subcollections |
| 2026-07-04 | Overview Stats chips configurable per event type via `eventTypeConfig/{typeId}.overviewChips` | Different event types care about different numbers (e.g. a small pooja may not need a Sponsor/External chip); unset = all shown, so existing events aren't affected by default |
| 2026-07-17 | Resident Visibility settings are opt-in (unset = nothing shown to residents) | Admin explicitly asked to flip from the initial opt-out default — wants full deliberate control over what's exposed per event type rather than everything on by default |
| 2026-07-17 | Applicable Tabs is a separate, opt-out setting from Resident Visibility | Two different questions: "does this tab even make sense for this event type" (affects admin too, e.g. no Prasad tab for a Potluck) vs. "should residents specifically see it" (resident-only, opt-in). Conflating them would force admins to lose their own access just to hide something from residents |
| 2026-07-17 | Admin tab bar/`TabController` made dynamic (built from `applicableTabs`) instead of a fixed 11-tab list | Required for Applicable Tabs to actually hide tabs from admins; the FAB's tab-detection logic was changed from raw index checks (`tab == 2`) to tab-identity checks since tab positions can now shift per event type |
| 2026-07-17 | One generalized `_ResidentTabSectionsSection` widget trio reused across all 6 non-Overview tabs' section toggles | Avoids ~18 near-identical classes (3 per tab × 6 tabs); parameterized by tab id, emoji, title, help text, and section defs instead |
| 2026-07-17 | Duplicate-import signature = flat/item + amount + date (not a full-row match) | Matches the realistic "accidentally re-imported the same file" case without requiring every column (payment mode, note, vendor) to also match; existing records fetched once per import, not per row |
| 2026-07-18 | Carry-forward bookkeeping recomputed fresh from source-of-truth on every delete/restore/recalculate, not `FieldValue.increment()` | Increment-based tracking silently drifted whenever a carry-forward entry was deleted or restored, since there was no way to reverse exactly what was added; recomputing from the `carryForwardTransfers` subcollection + destination contribution status every time is self-healing even against already-corrupted historical data |
| 2026-07-18 | Restore button removed for carry-forward Activity log entries (log-only, re-import instead) | Restoring a carry-forward-out log entry can't cleanly re-establish the link to a destination contribution that may have moved on; re-importing via the Carry Forward Balance picker goes through the same self-healing path as a fresh transfer |
| 2026-07-18 | Anonymous flag takes display priority over `contributionType` in Contributions tab sections | Contributions were appearing in two sections at once (e.g. Anonymous + External) even though `grandTotal` only counted them once — the fix is purely which section a doc is *rendered* under, not a change to any total |
| 2026-07-18 | Sponsor package amount made optional | Not every sponsor "item" is a fixed-price tier — some are in-kind donations (an idol, flowers) with no set price, but still worth tracking and recognizing |
| 2026-07-18 | "Tier" renamed to "Item" throughout the sponsor packages UI | Once amount became optional, "tier" (implying a fixed pricing ladder) no longer matched what admins were actually using the feature for — arbitrary named sponsor items, priced or not |
| 2026-07-18 | Sponsorship amounts excluded from the Contributions tab's own total, but not from `totalCollected` | The tab's local total answers "how much cash came in," which a nominal item value would distort; `totalCollected`/Budget-vs-Actual are a separate, unaffected ledger since changing those has much bigger financial-reporting consequences |
| 2026-07-18 | Event Settings search is a static per-file keyword registry, not live-indexed | Settings sections are a small, fixed, rarely-changing set (~20 entries); a hardcoded registry is simpler and faster than building a generic search index for content that changes maybe once a session |
| 2026-07-24 | Temple built as a new top-level module (own admin tab + resident quick-access card), not nested inside Events | A temple is a standing amenity, not a time-boxed event with a start/end date — forcing it into the Events data model (contributions/expenses per-event) would be the wrong shape |
| 2026-07-24 | Temple donation/expense totals computed live from their collections, never an incremented ledger field | Sidesteps entirely the class of `totalCollected` drift bugs this session spent significant effort fixing on the Events side (increment desyncing on delete/restore) — a new module gets to start clean |
| 2026-07-24 | Temple PDF receipt and its save/share helpers duplicated in their own file rather than reused from `event_pdf_report.dart` | Keeps the Temple module decoupled from Events internals, matching the "new top-level module" architecture decision; the duplication is small (one receipt layout + a bottom-sheet helper) |
| 2026-07-24 | Ritual checklist completion stored per-day (`templeRitualLog/{yyyy-MM-dd}`), template stored separately in `appSettings/templeRoutine` | A checklist that's redone every day needs today's state to reset automatically; storing the template and the daily instance separately means a new date is a fresh empty log with no extra code |
| 2026-07-24 | Anniversary reminders store month+day only (no year), next-occurrence computed at read time | These are yearly recurring occasions — storing a specific year would require updating every record annually; computing "next occurrence" from today's date handles the year-wraparound automatically |

---

## HOW TO UPDATE THIS FILE

Tell Claude any of these:
- *"Mark Week 1 as complete"*
- *"Week 3 done except camera — that's blocked by X"*
- *"Add Society: Green Valley Apartments, Hyderabad, 120 units, pilot stage"*
- *"Log bug: visitor photo upload fails on Android 10, P1"*
- *"I finished login and OTP but profile setup is still pending"*
- *"Show me my overall progress"*

Claude will update this file instantly.

---

*Tracker Version: 1.0 | Started: 2026-05-30 | Updated by Claude on each check-in*
