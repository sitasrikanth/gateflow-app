# GateFlow — 12-Week Progress Tracker
> Last updated: 2026-06-14 | Tell Claude what you completed and this file gets updated automatically.

---

## HOW TO USE
1. At the end of each day or week, tell Claude: *"Week 2 done. Completed auth, skipped camera for now."*
2. Claude updates this file with status, notes, and blockers.
3. Check this file at the start of each session: *"Show me my tracker."*

---

## OVERALL PROGRESS

```
Phase 1 — Foundation & Auth      ████████████  Week 1–2   [ 2 / 2 weeks done ] ✅
Phase 2 — Core Features          ████████░░░░  Week 3–6   [ 2 / 4 weeks done ]
Phase 3 — Complete MVP           ░░░░░░░░░░░░  Week 7–8   [ 0 / 2 weeks done ]
Phase 4 — Testing & Launch       ░░░░░░░░░░░░  Week 9–12  [ 0 / 4 weeks done ]
```

**Weeks completed:** 4 / 12  
**Current week:** Week 5  
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

### ✅ WEEK 5 — Notice Board + Complaints (Resident)
**Status:** 🔲 Not Started  
**Dates:** 2026-06-27 → 2026-07-03  
**Theme:** Communication and complaints

| Task | Status | Notes |
|------|--------|-------|
| Build Notice list screen | 🔲 | Category tabs, unread dot |
| Build Notice detail screen | 🔲 | Full text, timestamp |
| Mark notice as read (Firestore update) | 🔲 | |
| Build Raise Complaint form | 🔲 | Title, category, description, photo |
| Upload complaint photo to Firebase Storage | 🔲 | |
| Build My Complaints list screen | 🔲 | Status chips: Open/In Progress/Resolved |
| Build Complaint detail screen | 🔲 | Status history timeline |

**Success Criteria:**
- [ ] Notice broadcasts to all residents within 10 seconds
- [ ] Complaint with photo submits in under 5 seconds on 4G
- [ ] Status updates reflect in real-time

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 6 — Admin Panel (In-App)
**Status:** 🔲 Not Started  
**Dates:** 2026-07-04 → 2026-07-10  
**Theme:** Admin can manage everything from the app

| Task | Status | Notes |
|------|--------|-------|
| Build Admin home dashboard (stats cards) | 🔲 | Total residents, open complaints, today visitors |
| Build Resident Management screen | 🔲 | List, add, deactivate |
| Build Add Resident form | 🔲 | Name, flat, phone |
| Build Post Notice screen | 🔲 | Title, body, category, expiry |
| Build Complaint Dashboard | 🔲 | List all, filter by status |
| Build Complaint detail + status update | 🔲 | Admin updates, notifies resident |
| Build Visitor Log screen (admin view) | 🔲 | All entries, date filter |
| Add audit logging for all admin actions | 🔲 | /communities/{id}/auditLogs |

**Success Criteria:**
- [ ] Admin posts notice → all residents notified
- [ ] Complaint status update notifies resident
- [ ] Resident deactivation blocks login

**Blockers:** None yet  
**Notes:** —

---

### ✅ WEEK 7 — Delivery + Staff Entry + Offline Queue
**Status:** 🔲 Not Started  
**Dates:** 2026-07-11 → 2026-07-17  
**Theme:** Complete guard app + offline-first

| Task | Status | Notes |
|------|--------|-------|
| Build Delivery Entry form | 🔲 | Courier, package type, flat number |
| Send delivery notification to resident | 🔲 | "Package from Amazon at gate" |
| Build Staff/Domestic Help entry form | 🔲 | Name, role, flat, attendance mark |
| Build Vehicle Entry log | 🔲 | Plate number, vehicle type |
| Implement offline entry queue (drift/SQLite) | 🔲 | Store locally, sync on reconnect |
| Show sync status indicator in guard app | 🔲 | "Syncing..." / "All synced ✓" |

**Success Criteria:**
- [ ] Delivery notification in under 5 seconds
- [ ] Offline entries sync correctly on reconnect
- [ ] Guard logs delivery in under 20 seconds

**Blockers:** None yet  
**Notes:** —

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
| — | — | — | — | — | — |

**Severity:** 🔴 P0 (blocker) | 🟠 P1 (critical) | 🟡 P2 (major) | 🟢 P3 (minor)

---

## KEY DECISIONS LOG

| Date | Decision | Reason |
|---|---|---|
| 2026-05-30 | Flutter + Firebase chosen | Best AI support, offline-first, free tier |
| 2026-05-30 | Android Phase 1 only | Faster launch, validate before iOS investment |
| 2026-05-30 | Society subscription pricing | Predictable MRR, single decision-maker |

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
