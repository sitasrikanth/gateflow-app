# GateFlow — 12-Week Progress Tracker
> Last updated: 2026-06-14 (Session 2) | Tell Claude what you completed and this file gets updated automatically.

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
Phase 3 — Complete MVP           ░░░░░░░░░░░░  Week 7–8   [ 0 / 2 weeks done ]
Phase 4 — Testing & Launch       ░░░░░░░░░░░░  Week 9–12  [ 0 / 4 weeks done ]
```

**Weeks completed:** 6 / 12  
**Current week:** Week 7  
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

**Severity:** 🔴 P0 (blocker) | 🟠 P1 (critical) | 🟡 P2 (major) | 🟢 P3 (minor)

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
