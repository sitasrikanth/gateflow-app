# Community App — Complete Startup Execution Plan
### Role: Startup Founder · PM · CTO · QA Lead · UX Designer · Growth Advisor
### Audience: Non-technical Founder, AI-assisted development, Budget ≤ $5,000

---

## TABLE OF CONTENTS

1. Executive Summary
2. Market Analysis
3. MVP Definition
4. Technology Stack
5. AI Development Workflow
6. 12-Week Detailed Roadmap
7. 6-Month Monthly Roadmap
8. Feature Rollout Strategy
9. QA Strategy
10. UI/UX Strategy
11. Database Design
12. Security Architecture
13. DevOps Setup
14. Launch Strategy
15. Revenue Model
16. Scaling Plan
17. Founder Dashboard
18. Risk Register

---

## 1. EXECUTIVE SUMMARY

**Product Name (Working Title):** GateFlow *(rename before launch)*
**Tagline:** "Your community, connected."
**Problem:** Gated communities rely on WhatsApp groups, paper registers, and phone calls for visitor approvals, complaints, and announcements — creating chaos, security gaps, and zero accountability.
**Solution:** A mobile-first community management platform for residents, security guards, and society admins — replacing fragmented tools with one unified app.
**Target Market:** India's 50,000+ gated communities housing 10M+ urban families.
**Business Model:** Society SaaS subscription (₹3,000–₹15,000/month per society).
**Budget:** $5,000 / ₹4,20,000
**Timeline to MVP:** 12 weeks
**Timeline to First Paying Society:** 18 weeks

### Budget Allocation

| Category | Allocation | Amount (USD) |
|---|---|---|
| Tools & Subscriptions (AI, Firebase, etc.) | 30% | $1,500 |
| UI/UX Design (Figma assets/templates) | 10% | $500 |
| Domain, Hosting, Play Store | 5% | $250 |
| Marketing & Pilot Acquisition | 25% | $1,250 |
| Legal (basic company registration) | 10% | $500 |
| Buffer / Emergency | 20% | $1,000 |
| **Total** | | **$5,000** |

---

## 2. MARKET ANALYSIS

### 2.1 MyGate — Strengths
- First-mover advantage; brand recognition in metro cities
- Strong visitor management with QR/OTP-based entry
- Hardware integration (boom barriers, intercoms)
- Large sales team on the ground
- Deep integrations with society committees
- Established trust with 25,000+ communities

### 2.2 MyGate — Weaknesses
- Expensive for mid-size and tier-2 societies
- Complex onboarding requiring field agents
- App is heavy; residents complain of bugs
- Poor customer support post-onboarding
- Weak marketplace and community features
- Security guard interface is confusing
- No meaningful offline mode
- Limited customization per society

### 2.3 NoBroker Hood — Strengths
- Backed by NoBroker's brand and distribution
- Society accounting and payment collection
- Integrated with NoBroker real estate listings
- Strong in Bengaluru and Hyderabad
- Free tier attracts smaller societies

### 2.4 NoBroker Hood — Weaknesses
- Too feature-heavy; bad UX for first-time users
- Visitor management is secondary to payments
- Security guard app is under-developed
- Frequent app crashes reported
- Weak notification reliability
- Onboarding requires significant admin effort
- Poor support for multi-tower/large societies

### 2.5 Competitive Opportunities (Where You Can Win)

| Opportunity | How to Execute |
|---|---|
| Radically simple UX | Security guard onboarding in under 2 minutes |
| Offline-first for guards | Entry logs work without internet |
| Tier-2/3 city focus | Pricing at ₹1,999/month vs MyGate's ₹8,000+ |
| WhatsApp-first notifications | Residents get approvals on WhatsApp, not just app |
| Faster onboarding | Society live in 1 day, not 1 week |
| Better support | Founder-led support in early days |
| Modern UI | Clean, Material You / iOS 17 design language |
| QA-first reliability | Your QA background = fewer bugs = better reviews |

### 2.6 Target Customer Profile

**Primary:** Mid-size gated communities (100–500 units) in Tier-1 and Tier-2 cities
**Secondary:** Villa communities (20–100 units) looking for lightweight apps
**Decision Maker:** Society Secretary / Treasurer / RWA President
**Influencer:** Tech-savvy residents, security supervisors

---

## 3. MVP DEFINITION

### 3.1 MVP Philosophy
Launch with the smallest product that solves the #1 pain: **visitor entry and approval**. Everything else is secondary.

### 3.2 MVP Feature List (MoSCoW)

#### RESIDENT APP

| Feature | Priority | Notes |
|---|---|---|
| OTP Login / Phone Auth | Must Have | Firebase Auth |
| Profile Setup | Must Have | Name, flat, tower |
| Visitor Pre-approval | Must Have | Generate QR/OTP for guest |
| Visitor Approval (real-time push) | Must Have | Approve/deny incoming visitor |
| Notice Board (read-only) | Must Have | Admins post, residents read |
| Raise Complaint | Must Have | Title, category, description, photo |
| Complaint Status Tracking | Must Have | Open / In Progress / Resolved |
| Emergency Contact List | Should Have | Fire, ambulance, admin numbers |
| Package Delivery Notification | Should Have | Guard marks delivery arrived |
| Resident Directory (opt-in) | Nice to Have | See neighbours |
| Facility Booking | Nice to Have | v1.1 |
| Society Payments | Nice to Have | v1.2 |
| Buy/Sell Marketplace | Nice to Have | v2.0 |
| Polls & Surveys | Nice to Have | v1.2 |

#### SECURITY GUARD APP

| Feature | Priority | Notes |
|---|---|---|
| Guard Login (PIN-based) | Must Have | Simple 6-digit PIN |
| Mark Visitor Entry/Exit | Must Have | Name, photo, host flat |
| OTP Verification for Pre-approved | Must Have | Scan or enter OTP |
| Delivery Entry | Must Have | Courier name, parcel type |
| Staff/Domestic Help Entry | Must Have | Daily worker log |
| Vehicle Entry Log | Should Have | Plate number, type |
| Emergency Alert Button | Should Have | Broadcast to all admins |
| Visitor Photo Capture | Should Have | Camera integration |
| Offline Entry Queue | Should Have | Sync when internet returns |

#### ADMIN PORTAL (In-App, Phase 1)

| Feature | Priority | Notes |
|---|---|---|
| Admin Login | Must Have | |
| Resident Management (add/remove) | Must Have | |
| Notice Post & Broadcast | Must Have | |
| Complaint Dashboard | Must Have | View, assign, close |
| Visitor Log View | Must Have | All entries by date/flat |
| Basic Analytics (visitors/day) | Should Have | |
| Payment Tracking (manual) | Nice to Have | v1.1 |
| Role Assignment | Should Have | Admin, guard, resident |

### 3.3 MVP Scope Summary
- **3 user types:** Resident, Security Guard, Admin
- **1 platform:** Android only
- **1 backend:** Firebase (Firestore + Auth + FCM)
- **Core loop:** Visitor arrives → Guard logs → Resident approves → Visitor enters
- **12 screens for Resident, 6 for Guard, 8 for Admin**

---

## 4. TECHNOLOGY STACK

### 4.1 Final Recommendations

| Layer | Choice | Reason |
|---|---|---|
| Mobile Framework | **Flutter** | Single codebase for Android + iOS later; excellent AI support; fast UI |
| Backend / BaaS | **Firebase** | No server management; real-time DB; free tier generous; perfect for MVP |
| Database | **Firestore** | Real-time sync; offline support; JSON-like; pairs with Flutter perfectly |
| Authentication | **Firebase Auth** | Built-in OTP/phone auth; free; works in India |
| Push Notifications | **Firebase Cloud Messaging (FCM)** | Free; reliable; deep Flutter integration |
| File Storage | **Firebase Storage** | Photos, documents; pay-as-you-go |
| Analytics | **Firebase Analytics + Mixpanel** | Firebase for funnel; Mixpanel for event depth |
| Crash Monitoring | **Firebase Crashlytics** | Free; instant crash reports |
| Error Monitoring | **Sentry** | Better stack traces than Crashlytics alone |
| CI/CD | **GitHub Actions** | Free for public; automated APK builds |
| Source Control | **GitHub** | Industry standard; AI tools integrate natively |
| Design | **Figma** | Free tier; community templates for Material Design |
| AI Coding | **Cursor + Claude** | Primary dev environment |
| Testing (Mobile) | **Maestro** | Simple YAML-based mobile UI testing; no coding needed |
| Testing (E2E) | **Firebase Test Lab** | Run tests on real devices free tier |
| Project Management | **Notion** | Free; great for solo founder |

### 4.2 Flutter vs React Native

| Criteria | Flutter | React Native |
|---|---|---|
| AI Code Quality | Excellent (Claude/GPT know Dart well) | Good |
| Performance | Near-native | Near-native |
| iOS+Android from one code | Yes | Yes |
| Offline support | Excellent | Good |
| Firebase integration | Official SDK, excellent | Good |
| Guard app (simple UI) | Very fast to build | Slightly slower |
| Learning curve for AI prompts | Medium | Medium |
| **Verdict** | **Winner for this use case** | — |

### 4.3 Firebase vs Supabase

| Criteria | Firebase | Supabase |
|---|---|---|
| Real-time sync | Native, excellent | Good (via Realtime) |
| Offline-first | Excellent | Basic |
| Phone/OTP Auth in India | Native, reliable | Needs Twilio setup |
| Free tier | Generous (Spark plan) | Good |
| No-code/AI friendly | Excellent | Good but SQL knowledge helps |
| Scaling cost | Can spike unexpectedly | More predictable |
| **Verdict** | **Winner for MVP** | Use at v2.0 if needed |

### 4.4 Cost Estimate (Monthly, Post-MVP)

| Service | Free Tier | Paid Estimate (10 societies) |
|---|---|---|
| Firebase Spark | 1GB storage, 50k reads/day | Blaze plan ~$30/month |
| GitHub | Free | Free |
| Sentry | 5K errors/month free | Free initially |
| Mixpanel | 20M events/month free | Free initially |
| Play Store | $25 one-time | Done |
| Domain | — | $12/year |
| **Total** | **$0** | **~$50/month** |

---

## 5. AI DEVELOPMENT WORKFLOW

### 5.1 Tool Roles

| Tool | Primary Use |
|---|---|
| **Claude (this tool)** | Architecture, planning, complex logic, documentation, code review |
| **ChatGPT (GPT-4o)** | Brainstorming, quick snippets, alternate approaches |
| **Cursor** | Primary IDE; write, edit, refactor Flutter code with AI inline |
| **Windsurf** | Alternative to Cursor; use when Cursor struggles with a file |
| **Lovable / Bolt.new** | Rapid UI prototyping for admin web portal (Phase 3) |
| **Firebase Studio** | Firebase schema and rules generation |
| **GitHub Copilot** | In-IDE autocomplete while in Cursor |

### 5.2 Daily AI Workflow

```
Morning (30 min):
  1. Open Notion → Check today's tasks
  2. Open Cursor → Load Flutter project
  3. Give Claude the context prompt (below)
  4. Start building

During Development:
  - Use Cursor (Ctrl+K) for inline code generation
  - Use Claude for architecture questions
  - Use ChatGPT for quick UI ideas or alternate solutions
  - Commit to GitHub every 2 hours

Evening (15 min):
  - Run Maestro test suite
  - Review Crashlytics for any issues
  - Update Notion task status
```

### 5.3 Master Context Prompt (Use at Start of Every Session)

```
You are a senior Flutter developer helping me build a community management app 
called GateFlow. The app has 3 user types: Resident, Security Guard, and Admin.

Tech stack:
- Flutter (latest stable)
- Firebase (Firestore, Auth, FCM, Storage, Crashlytics)
- State management: Riverpod
- Navigation: GoRouter
- Architecture: Clean Architecture (feature-first folder structure)

Current task: [DESCRIBE WHAT YOU WANT TO BUILD]

Rules:
- Write production-quality code
- Add error handling
- Use Riverpod providers
- Follow Flutter best practices
- Add comments for non-obvious logic
- Keep widgets small and reusable
```

### 5.4 AI Prompts by Stage

#### Stage 1: Project Setup
```
Create a new Flutter project called gateflow with:
- Firebase integration (Auth, Firestore, FCM, Storage)
- Riverpod for state management
- GoRouter for navigation
- Feature-first folder structure:
  /lib
    /features
      /auth
      /visitor
      /complaints
      /notices
      /guard
      /admin
    /core
      /theme
      /widgets
      /utils
      /services
- Material 3 theme with primary color #1A73E8
- Dark mode support
Show the complete pubspec.yaml and main.dart.
```

#### Stage 2: Authentication Screen
```
Build a Flutter phone authentication screen for GateFlow:
- OTP-based login using Firebase Phone Auth
- Fields: phone number input with +91 prefix
- Send OTP button → navigate to OTP verification screen
- OTP verification: 6-digit OTP input, auto-submit on complete
- After login: check Firestore if user profile exists
  - If yes: navigate to home based on role (resident/guard/admin)
  - If no: navigate to profile setup
- Handle errors: invalid OTP, network error, timeout
- Use Riverpod for state
- Show loading states
```

#### Stage 3: Visitor Approval Flow
```
Build the visitor approval flow for GateFlow:

1. Guard screen: "New Visitor" form
   - Visitor name (text field)
   - Host flat number (text field, e.g., A-101)
   - Visitor photo (camera capture, optional)
   - Purpose of visit (dropdown: Guest, Delivery, Service, Other)
   - On submit: create Firestore document in /communities/{id}/visitors/{id}
     with status: "pending", timestamp, guardId
   - Send FCM push notification to resident of that flat

2. Resident screen: Incoming approval notification
   - Shows visitor name, photo, purpose
   - Approve / Deny buttons
   - On approve: update visitor status to "approved", 
     send FCM back to guard
   - On deny: update status to "denied", 
     send FCM back to guard with optional reason

3. Guard screen: real-time listener on visitor doc
   - Shows "Approved ✓" in green or "Denied ✗" in red
   - Auto-updates without refresh

Use Firestore real-time listeners. Handle offline case.
```

#### Stage 4: Complaint System
```
Build the complaint management feature for GateFlow:

Resident side:
- "Raise Complaint" screen
  - Title (text, max 100 chars)
  - Category (dropdown: Plumbing, Electrical, Housekeeping, 
    Security, Parking, Noise, Other)
  - Description (multiline, max 500 chars)
  - Photo upload (optional, Firebase Storage)
  - Submit → Firestore /communities/{id}/complaints/{id}
    fields: title, category, description, photoUrl, status: "open",
    flatNumber, residentId, createdAt

- Complaint list screen
  - My complaints with status chips (Open=orange, In Progress=blue, 
    Resolved=green)
  - Tap to see details and status history

Admin side:
- Complaint dashboard
  - List all complaints, filter by status/category
  - Tap → view details → Update status dropdown
  - Add admin note
  - Push notification to resident on status change
```

#### Stage 5: Notice Board
```
Build the notice board feature:

Admin:
- Post Notice screen: title, body (rich text), category 
  (General, Urgent, Event, Maintenance), expiry date
- On post: save to Firestore, send FCM to all residents 
  of the community (topic-based FCM)

Resident:
- Notice list: sorted by date, category filter tabs
- Unread indicator (dot badge)
- Notice detail: full text, timestamp, posted by
- Mark as read (update Firestore)

Use Firestore /communities/{id}/notices collection.
```

#### Stage 6: Testing Prompts (for Maestro)
```
Write a Maestro YAML test for the GateFlow visitor approval flow:
1. Launch app
2. Login with test phone number
3. Navigate to Guard role
4. Tap "New Visitor"
5. Enter visitor name "Test Guest"
6. Enter flat number "A-101"
7. Select purpose "Guest"
8. Tap Submit
9. Assert success message appears
10. Assert visitor appears in Today's log

Use Maestro syntax. Add assertions after each step.
```

### 5.5 Code Review Prompt
```
Review this Flutter code for:
1. Performance issues (unnecessary rebuilds, missing const)
2. Security issues (data exposure, missing auth checks)
3. Error handling gaps
4. Firestore query efficiency
5. Memory leaks (missing dispose, uncancelled subscriptions)
6. Accessibility (missing semantics labels)

[PASTE CODE]

Provide specific fixes with code examples.
```

---

## 6. 12-WEEK DETAILED ROADMAP

### WEEK 1–2 — Foundation & Research ✅ COMPLETE

**Goals:**
- Set up all tools and accounts
- Complete project scaffolding

**Deliverables:**
- [x] GitHub repo created
- [x] Firebase project set up (Firestore, Storage)
- [x] Flutter project running on Android device
- [x] QuickCode login for Admin / Resident / Guard
- [x] Role-based home screens (Admin, Resident, Guard)

---

### WEEK 3–4 — Event Fund Manager ✅ COMPLETE

**What was built (ahead of plan — Event module instead of visitor loop):**
- [x] Event Fund Manager module (create, edit, close events)
- [x] 29 event types catalog across 8 categories with HD images
- [x] Custom image upload per event type (Firebase Storage — Blaze needed)
- [x] Per-event banner image
- [x] Event list 2-column grid with horizontal PageView swipe navigation
- [x] Contributions (Wing→Block→Flat grouping, self-report flow, admin confirm)
- [x] Expenses with hierarchical categories
- [x] Activity log with soft-delete and restore
- [x] Collection status by block (live StreamBuilder)
- [x] PDF report generation
- [x] Recalculate totals bug fixed (now matches Summary tab)
- [x] Firestore rules updated for quickCode auth
- [x] Expense categories admin screen

---

### WEEK 5 — Follow-up Tab + Push Notifications 🔜 NEXT

**Goals:**
- Admin can see unpaid flats and send reminders
- Push notifications for payment reminders

**Deliverables:**
- [ ] Follow-up tab: list unpaid flats, filter by wing/block
- [ ] Send payment reminder notification from admin
- [ ] Firebase Storage working (Blaze plan upgrade)

---

### WEEK 6 — Visitor Management (Original Week 3–4)
- [ ] Notion workspace set up with project tracker

**AI Prompts to Use:**
- Project setup prompt (Section 5.4, Stage 1)
- "Generate 20 discovery questions to ask a society secretary about their current pain points with visitor management, complaints, and communication."

**Testing Tasks:**
- Verify Firebase project connects to Flutter app
- Verify Auth emulator works locally

**Success Criteria:**
- App runs on Android emulator
- Firebase read/write works from app
- At least 3 interviewees confirm visitor management is a top pain point

**Risks:**
- Firebase setup complexity → Use FlutterFire CLI (one command setup)
- Interview access → Contact 5 local housing societies directly

---

### WEEK 2 — Authentication & Onboarding

**Goals:**
- Build phone OTP authentication
- Build profile setup flow
- Implement role-based routing

**Deliverables:**
- [ ] Login screen (phone number input)
- [ ] OTP verification screen
- [ ] Profile setup screen (name, flat, tower, type: resident/guard/admin)
- [ ] Role-based home screen routing
- [ ] Firestore user document creation on signup

**AI Prompts to Use:**
- Authentication screen prompt (Section 5.4, Stage 2)
- "Build a profile setup screen in Flutter with fields: full name, flat number (e.g., A-101), tower name, phone (pre-filled, read-only), role. Save to Firestore users/{uid}. Validate all fields before save."

**Testing Tasks:**
- Manual test: OTP flow on real Android device
- Test invalid OTP error handling
- Test network disconnection during OTP send

**Success Criteria:**
- Full auth flow working end-to-end on real device
- Role routing sends user to correct home screen
- Profile data appears correctly in Firestore

**Risks:**
- Firebase Phone Auth requires real device for OTP → Have test device ready
- Indian phone numbers need correct region code (+91)

---

### WEEK 3 — Guard App: Visitor Entry

**Goals:**
- Build the security guard's visitor entry flow
- This is the #1 core feature

**Deliverables:**
- [ ] Guard home screen (Today's visitor log)
- [ ] New Visitor entry form
- [ ] Camera integration (visitor photo)
- [ ] Firestore visitor document creation
- [ ] FCM push notification to resident on entry

**AI Prompts to Use:**
- Visitor approval flow prompt (Section 5.4, Stage 3) — Guard side
- "Build a Flutter camera screen that captures a photo, previews it, and allows retake or confirm. On confirm, upload to Firebase Storage at visitors/{visitorId}/photo.jpg and return the download URL."

**Testing Tasks:**
- Test visitor entry with and without photo
- Test notification delivery to resident app
- Test with airplane mode (offline entry)

**Success Criteria:**
- Guard can log a visitor in under 30 seconds
- Notification reaches resident within 5 seconds
- Visitor appears in today's log immediately

**Risks:**
- Camera permissions on Android → Handle runtime permissions
- FCM delivery in India can be delayed → Test on multiple devices

---

### WEEK 4 — Resident App: Visitor Approval

**Goals:**
- Build resident-side approval experience
- Real-time listener for incoming visitors

**Deliverables:**
- [ ] Resident home screen with pending approvals badge
- [ ] Incoming visitor notification screen
- [ ] Approve / Deny with real-time Firestore update
- [ ] Visitor history screen (past entries)
- [ ] Pre-approve visitor (generate OTP for guest)

**AI Prompts to Use:**
- Visitor approval flow prompt — Resident side
- "Build a Flutter screen showing a real-time list of today's visitors for flat A-101. Use Firestore StreamBuilder. Show visitor name, photo, time, and status (pending/approved/denied) with color-coded chips."

**Testing Tasks:**
- Test approval reaches guard screen in real-time
- Test deny flow with optional reason
- Test pre-approval OTP generation and usage

**Success Criteria:**
- Resident receives push + in-app notification within 3 seconds
- Approval status updates on guard screen in under 2 seconds
- Pre-approval OTP works for guard verification

**Risks:**
- Real-time listener performance → Use Firestore compound queries carefully

---

### WEEK 5 — Notice Board + Complaints (Resident)

**Goals:**
- Build notice board (read-only for residents)
- Build complaint submission and tracking

**Deliverables:**
- [ ] Notice list screen with categories
- [ ] Notice detail screen
- [ ] Unread notice badge on home
- [ ] Raise complaint form
- [ ] My complaints list with status
- [ ] Complaint detail screen

**AI Prompts to Use:**
- Notice board prompt (Section 5.4, Stage 5)
- Complaint system prompt (Section 5.4, Stage 4) — Resident side

**Testing Tasks:**
- Test notice FCM broadcast delivery
- Test complaint photo upload (large file, slow connection)
- Test complaint category filtering

**Success Criteria:**
- Notice reaches all residents within 10 seconds of posting
- Complaint with photo submits in under 5 seconds on 4G
- Status updates reflect in real-time

**Risks:**
- Photo upload on slow connections → Add upload progress indicator

---

### WEEK 6 — Admin Panel (In-App)

**Goals:**
- Build admin screens within the Flutter app
- Admin can manage residents, complaints, and notices

**Deliverables:**
- [ ] Admin home dashboard (stats: residents, open complaints, today's visitors)
- [ ] Resident management screen (add, deactivate, view)
- [ ] Post notice screen
- [ ] Complaint dashboard (list, filter, update status)
- [ ] Visitor log view (all entries, date filter)

**AI Prompts to Use:**
- Complaint system prompt — Admin side
- "Build an admin dashboard screen in Flutter showing: total residents count, open complaints count, today's visitor count. Each stat is a tappable card navigating to the respective list. Use Firestore aggregation queries. Show a recent activity feed below the stats."

**Testing Tasks:**
- Test admin posting notice → resident receives notification
- Test complaint status update → resident receives notification
- Test resident deactivation (user can't login after deactivation)

**Success Criteria:**
- Admin can post a notice in under 1 minute
- Complaint status update notifies resident immediately
- All admin actions write audit log to Firestore

**Risks:**
- Admin role verification → Implement Firestore security rules strictly

---

### WEEK 7 — Delivery + Staff Entry (Guard)

**Goals:**
- Complete guard app with delivery and staff entry
- Add offline entry queue

**Deliverables:**
- [ ] Delivery entry form (courier name, package type, flat number)
- [ ] Delivery notification to resident
- [ ] Domestic staff entry (known worker, mark attendance)
- [ ] Vehicle entry log (plate number, type)
- [ ] Offline queue with sync indicator

**AI Prompts to Use:**
- "Build a Flutter offline-first queue for GateFlow guard app. When a visitor entry is submitted without internet: store in local SQLite (drift package), show 'Queued - will sync' badge. When internet returns, auto-sync all queued entries to Firestore in order. Show sync progress."
- "Build a delivery entry screen for guard: fields for courier company (dropdown: Amazon, Flipkart, Swiggy, Zomato, Other), package description, recipient flat number. On submit, send FCM notification to resident: 'Package from Amazon waiting at gate.'"

**Testing Tasks:**
- Test offline entry: airplane mode → enter visitor → reconnect → verify sync
- Test delivery notification delivery
- Test staff entry duplicate detection (same staff, same day)

**Success Criteria:**
- Offline entries sync correctly when reconnected
- Delivery notification reaches resident within 5 seconds
- Guard can log a delivery in under 20 seconds

**Risks:**
- SQLite + Firestore sync conflicts → Use server timestamp for ordering

---

### WEEK 8 — Polish, Bug Fixing & Internal Testing

**Goals:**
- Fix all critical bugs found in Weeks 1–7
- Polish UI across all screens
- Performance optimization

**Deliverables:**
- [ ] All P0/P1 bugs fixed
- [ ] Loading states on all async operations
- [ ] Empty states on all list screens
- [ ] Error screens with retry
- [ ] App icon and splash screen
- [ ] Onboarding flow for new communities

**AI Prompts to Use:**
- Code review prompt (Section 5.5)
- "Audit this Flutter app for performance issues. Check for: setState in StatefulWidget where Riverpod should be used, missing const constructors, large widget trees that should be split, image caching issues. List each issue with file name, line number, and fix."
- "Create a professional app icon for GateFlow: a modern gate/shield symbol in blue (#1A73E8) on white background. Describe it for a designer or generate SVG code."

**Testing Tasks:**
- Full regression test of all flows
- Test on 3 different Android devices (low-end, mid, high)
- Test on Android 10, 12, 14
- Measure cold start time (target: under 3 seconds)

**Success Criteria:**
- Zero P0 bugs
- Less than 5 P1 bugs
- Cold start under 3 seconds on mid-range device
- No ANR (App Not Responding) crashes

**Risks:**
- More bugs than expected → Triage ruthlessly; defer non-critical to v1.1

---

### WEEK 9 — Alpha Testing with 1 Real Society

**Goals:**
- Deploy to internal test track on Play Store
- Onboard 1 known society (friend/family connection)
- Collect real-world feedback

**Deliverables:**
- [ ] APK signed and uploaded to Play Store Internal Testing
- [ ] 1 society onboarded (admin + 5 residents + 1 guard)
- [ ] Feedback form created (Google Forms)
- [ ] Daily monitoring of Crashlytics
- [ ] Bug fix cycle (fix same day if critical)

**AI Prompts to Use:**
- "Write a 10-question feedback survey for a society admin who has just used GateFlow for one week. Focus on: ease of onboarding, visitor management usefulness, complaint management, notifications, and likelihood to recommend. Include 1–5 rating scales and open text fields."

**Testing Tasks:**
- Monitor Crashlytics daily
- Check Firestore for data integrity issues
- Performance test under real load (multiple concurrent entries)

**Success Criteria:**
- No app crashes in first 48 hours
- Visitor approval flow used at least 20 times
- At least 3 out of 5 residents rate experience 4+/5

**Risks:**
- Society onboarding failure → Have 2 backup contacts ready
- Critical bug in production → Have hotfix process ready (GitHub Actions deploy)

---

### WEEK 10 — Beta Testing with 3 Societies

**Goals:**
- Expand to 3 societies
- Validate pricing
- Start collecting testimonials

**Deliverables:**
- [ ] 3 societies onboarded (different sizes: 50, 100, 200 units)
- [ ] Pricing page created (even if informal)
- [ ] Support channel set up (WhatsApp Business)
- [ ] Crashlytics stable (crash-free rate > 99%)
- [ ] FCM delivery rate > 95%

**AI Prompts to Use:**
- "Write a 5-minute society admin onboarding script: what to say, what to show, and what to set up first. Assume the admin has never used a community app before. Make it conversational and confidence-building."

**Testing Tasks:**
- Load test: 200 concurrent Firestore writes
- Test with weak 2G network (guard scenario)
- UAT sign-off from at least 1 society admin

**Success Criteria:**
- 3 active societies with daily usage
- At least 1 society admin willing to give a testimonial
- Crash-free rate > 99%

**Risks:**
- Society admin engagement drops → Schedule weekly 15-min check-in calls

---

### WEEK 11 — Pre-Launch Preparation

**Goals:**
- Prepare all launch materials
- Set up marketing channels
- Submit app to Play Store public track

**Deliverables:**
- [ ] Play Store listing complete (screenshots, description, icon)
- [ ] Landing page live (use Carrd.co or Framer free tier)
- [ ] Social media accounts created (LinkedIn, Instagram, Twitter/X)
- [ ] Demo video recorded (Loom, 3 minutes max)
- [ ] Press kit (1-pager PDF with screenshots and key stats)
- [ ] App submitted for Play Store review

**AI Prompts to Use:**
- "Write a compelling Play Store description for GateFlow, a community management app. 500 words. Highlight: visitor approvals, security, complaints, and notice board. Include keywords: society app, apartment management, visitor management, gated community app India."
- "Write 5 LinkedIn posts announcing the launch of GateFlow. Each post should be under 200 words, include a hook first line, and end with a call to action. Target audience: society secretaries, RWA members, apartment residents."

**Testing Tasks:**
- Full end-to-end test on 5 different Android devices
- Play Store pre-launch report review
- Accessibility audit (TalkBack compatibility)

**Success Criteria:**
- Play Store listing approved
- Landing page live with waitlist form
- 100+ waitlist signups before launch day

**Risks:**
- Play Store review rejection → Have alternate APK distribution via landing page

---

### WEEK 12 — Public Launch

**Goals:**
- Launch on Play Store
- Acquire first 5 paying societies (or committed pilots)
- Set up support infrastructure

**Deliverables:**
- [ ] App live on Play Store (public)
- [ ] Launch post on LinkedIn, Twitter, relevant Facebook groups
- [ ] Email 50 housing society contacts directly
- [ ] Post on IndieHackers, Reddit r/india, r/bangalore (or target city)
- [ ] Set up Intercom or WhatsApp Business for support
- [ ] Week 1 post-launch metrics review

**AI Prompts to Use:**
- "Write a cold email to a housing society secretary introducing GateFlow. It should be under 150 words, mention the free pilot offer, and have a clear CTA to schedule a 15-minute demo call."
- "Write a Reddit post for r/bangalore announcing GateFlow, a free visitor management app for gated communities. Make it honest, founder-led, community-friendly, not salesy."

**Testing Tasks:**
- Monitor Crashlytics hourly on launch day
- Test all flows on launch day (smoke test)
- Monitor FCM delivery rates

**Success Criteria:**
- 500+ app downloads in Week 1
- 5+ society admin demo requests
- Zero critical production outages
- App rating > 4.0 on Play Store

**Risks:**
- Low organic discovery → Supplement with direct outreach, not just app store
- Negative reviews from bugs → Respond personally to every review in Week 1

---

## 7. 6-MONTH MONTHLY ROADMAP

### Month 1 — Research & Design
**Theme:** Validate before you build

| KPI | Target |
|---|---|
| Customer interviews | 15 |
| Figma screens completed | 30 |
| Firebase setup complete | Yes |
| Flutter project scaffolded | Yes |
| Waitlist signups | 50 |

**Feature Targets:** None (design only)
**User Targets:** 0 app users (research phase)
**Revenue Targets:** $0
**Key Activities:**
- 15 society admin/secretary interviews
- Complete all Figma wireframes for MVP screens
- Set up Firebase, GitHub, Cursor, Notion
- Validate willingness to pay (ask directly: "Would you pay ₹3,000/month?")

---

### Month 2 — Core Development
**Theme:** Build the core loop (visitor management)

| KPI | Target |
|---|---|
| Auth flow working | Yes |
| Visitor approval flow working | Yes |
| Guard app basic version | Yes |
| Internal testers | 5 |
| Crashlytics integrated | Yes |

**Feature Targets:** Auth, Visitor Entry, Visitor Approval, Basic Guard App
**User Targets:** 5 internal testers
**Revenue Targets:** $0
**Key Activities:**
- Weeks 2–5 of development roadmap
- Daily Cursor + Claude development sessions
- Weekly code review using Claude

---

### Month 3 — MVP Launch
**Theme:** Get real users using it every day

| KPI | Target |
|---|---|
| Societies onboarded | 3 |
| Daily active residents | 50 |
| Visitor entries logged/day | 20 |
| Crash-free rate | >99% |
| App Store rating | >4.0 |
| Play Store downloads | 200+ |

**Feature Targets:** Full MVP (all Must Have features)
**User Targets:** 3 societies, 50 residents, 3 guards
**Revenue Targets:** $0 (free pilots)
**Key Activities:**
- Weeks 9–12 of development roadmap
- Direct outreach to 50 societies
- Personal onboarding for each pilot society

---

### Month 4 — Pilot Communities
**Theme:** Deepen engagement, fix everything broken

| KPI | Target |
|---|---|
| Active societies | 10 |
| Daily active users | 200 |
| Visitor entries/day | 100 |
| NPS score | >40 |
| Paying societies | 2 |
| Monthly revenue | ₹6,000 |

**Feature Targets:**
- Emergency alert button (Guard)
- Facility booking v1 (basic)
- Payment reminder (manual, admin sends)
- WhatsApp notification integration

**Key Activities:**
- Onboard 7 more societies (founder-led)
- Weekly check-in calls with each society admin
- Fix all feedback from Month 3
- Start charging 2 societies (₹2,999/month pilot price)

---

### Month 5 — Growth
**Theme:** Build repeatable acquisition

| KPI | Target |
|---|---|
| Active societies | 25 |
| Monthly revenue | ₹37,500 |
| CAC (Cost per society) | <₹500 |
| Churn rate | <5% |
| Referrals from existing societies | 5 |
| Play Store downloads | 2,000 |

**Feature Targets:**
- Society payments (online collection via Razorpay)
- Polls & surveys
- Resident directory
- Improved analytics for admin

**Key Activities:**
- Launch referral program: "Refer a society, get 1 month free"
- Partner with 2 property management companies
- Post weekly content on LinkedIn
- Set up Google Ads campaign (₹5,000/month budget)

---

### Month 6 — Revenue
**Theme:** Build predictable MRR

| KPI | Target |
|---|---|
| Active societies | 50 |
| MRR | ₹1,00,000 ($1,200) |
| Paying societies | 40 |
| Churn rate | <3% |
| Support tickets/day | <10 |
| iOS app in TestFlight | Yes |

**Feature Targets:**
- iOS app (TestFlight beta)
- Society accounting (basic ledger)
- Marketplace (buy/sell listings)
- Admin web portal v1 (Lovable-built)

**Key Activities:**
- Hire first part-time support person (₹8,000/month)
- Automate onboarding (self-serve signup flow)
- Apply to Y Combinator / Antler India / 100X.VC
- Financial model: path to ₹10L MRR

---

## 8. FEATURE ROLLOUT STRATEGY

### MVP (Week 12 Launch)
**Theme:** Core security + communication
- Phone OTP auth
- Visitor entry (guard)
- Visitor approval (resident)
- Pre-approval with OTP
- Delivery entry
- Notice board
- Complaints (submit + track)
- Admin: resident management, complaint dashboard
- Emergency contacts list

**Why:** These solve the top 3 daily pains: who's at the gate, what's happening in the society, and where do I report a problem.

---

### Version 1.1 (Month 4 — 4 weeks post-launch)
**Theme:** Retention and stickiness
- Facility booking (gym, clubhouse, parking)
- WhatsApp notification integration
- Payment reminders (admin sends manual)
- Domestic staff attendance tracking
- Visitor history for residents (last 30 days)
- Guard shift handover notes
- Improved admin analytics

**Why:** These features create daily habits beyond visitor management.

---

### Version 1.2 (Month 5)
**Theme:** Community and payments
- Society maintenance payment collection (Razorpay)
- Payment history and receipts
- Polls & surveys
- Resident directory (opt-in)
- Bulk notifications (admin sends to specific towers)
- Multi-society admin (for property managers)

**Why:** Payments create direct revenue share opportunity and lock-in. Community features increase engagement.

---

### Version 2.0 (Month 7–8)
**Theme:** iOS + Web Portal
- iOS app (Flutter, same codebase)
- Web admin portal (React/Lovable)
- Advanced visitor analytics
- Vendor management (approved service list)
- Society document vault (rules, forms)
- Meeting minutes management

**Why:** iOS unlocks a premium user segment. Web portal is demanded by admins managing large societies.

---

### Version 3.0 (Month 10–12)
**Theme:** Marketplace and Scale
- Buy/sell marketplace (classifieds)
- Trusted vendor marketplace (plumbers, electricians with ratings)
- Society events calendar
- Multi-city dashboard for enterprise clients
- API for hardware integrations (boom barriers)
- White-label option for property developers

**Why:** Marketplace creates transaction revenue. Enterprise clients = high-value contracts.

---

## 9. QA STRATEGY

### 9.1 Test Strategy

**Approach:** Shift-left testing — test as features are built, not after.
**Principle:** As a QA professional, you have an edge. Use it to ship a more reliable product than MyGate.

**Test Types:**
| Type | Tool | When | Who |
|---|---|---|---|
| Unit Tests | Flutter test | During development | Claude generates |
| Widget Tests | Flutter test | During development | Claude generates |
| Integration Tests | Maestro | After each feature | You run |
| Smoke Tests | Maestro | Every build | GitHub Actions auto |
| Regression Tests | Maestro suite | Before every release | You run |
| UAT | Manual | Before each version release | Society admin testers |
| Performance Tests | Firebase Test Lab | Monthly | You run |
| Security Tests | OWASP checklist | Before public launch | Claude audit |
| Accessibility Tests | Manual (TalkBack) | Before each version | You test |

---

### 9.2 Test Plan — MVP

**Scope:** Resident App, Guard App, Admin App (Android)
**Environment:** Firebase Emulator Suite (local), Firebase Staging project
**Test Devices:** 
- Low-end: Redmi 9A (Android 10)
- Mid-range: Samsung Galaxy M32 (Android 12)
- High-end: Pixel 7 (Android 14)

**Test Data Strategy:**
- 3 test communities (Small: 50 units, Medium: 200 units, Large: 500 units)
- 10 test resident accounts, 2 guard accounts, 2 admin accounts
- All test data isolated in Firebase Staging project

---

### 9.3 Core Test Cases

#### AUTH-01: Phone OTP Login
```
Precondition: App installed, fresh install
Steps:
1. Launch app
2. Enter valid Indian phone number (+91 98765 43210)
3. Tap "Send OTP"
4. Enter correct 6-digit OTP
5. Tap "Verify"
Expected: User navigated to profile setup (new user) or home (existing)
```

#### AUTH-02: Invalid OTP
```
Steps: Enter wrong OTP 3 times
Expected: "Too many attempts" error after 3rd try, input disabled for 60s
```

#### VISITOR-01: Guard Logs New Visitor
```
Precondition: Logged in as guard
Steps:
1. Tap "New Visitor"
2. Enter name, flat A-101, purpose Guest
3. Tap Submit
Expected: 
- Visitor document created in Firestore
- Resident of A-101 receives FCM notification within 5s
- Visitor appears in Today's Log immediately
```

#### VISITOR-02: Resident Approves Visitor
```
Precondition: Visitor pending for flat A-101
Steps:
1. Open notification or pending approvals
2. View visitor details
3. Tap "Approve"
Expected:
- Visitor status → approved in Firestore
- Guard screen updates to "Approved ✓" within 3s
- No further action needed
```

#### VISITOR-03: Offline Entry
```
Precondition: Guard device in airplane mode
Steps:
1. Enter visitor details
2. Submit
Expected:
- Entry saved locally
- "Syncing..." indicator shown
3. Disable airplane mode
Expected:
- Entry syncs to Firestore within 10s
- Resident receives notification after sync
```

#### COMPLAINT-01: Raise Complaint with Photo
```
Steps:
1. Tap "Raise Complaint"
2. Enter title, select Plumbing, enter description
3. Attach photo (< 2MB)
4. Submit
Expected:
- Complaint created in Firestore with photoUrl
- Status = "Open"
- Complaint appears in My Complaints list
```

#### NOTICE-01: Admin Posts Notice
```
Precondition: Logged in as admin
Steps:
1. Tap "Post Notice"
2. Enter title and body, select "Urgent"
3. Post
Expected:
- Notice saved to Firestore
- FCM sent to all residents (topic: community/{id})
- Notice appears at top of resident notice board
```

---

### 9.4 Smoke Test Suite (Run on Every Build)

```yaml
# maestro/smoke_test.yaml
appId: com.gateflow.app
---
- launchApp
- assertVisible: "Login with Phone"
- tapOn: "Phone Number"
- inputText: "9876543210"
- tapOn: "Send OTP"
- assertVisible: "Enter OTP"
- inputText: "123456"  # Test OTP from emulator
- tapOn: "Verify"
- assertVisible: "Home"
- assertVisible: "Visitors"
- assertVisible: "Notices"
- assertVisible: "Complaints"
```

---

### 9.5 Regression Test Suite

**Run before every release. Total estimated time: 45 minutes.**

| Suite | Cases | Time |
|---|---|---|
| Auth flows | 5 | 5 min |
| Visitor management | 8 | 10 min |
| Complaints | 5 | 8 min |
| Notice board | 4 | 5 min |
| Guard flows | 6 | 8 min |
| Admin flows | 5 | 9 min |
| **Total** | **33** | **45 min** |

---

### 9.6 UAT Process

**When:** Before each public release
**Who:** 3 volunteer society admins from pilot communities
**Duration:** 3–5 days
**Process:**
1. Deploy to Play Store Internal Testing track
2. Share APK link and UAT checklist
3. Daily 15-min call to capture verbal feedback
4. Collect written feedback via Google Form
5. Triage: P0 (block release) / P1 (fix before release) / P2 (next version)
6. Fix P0 and P1, retest, then promote to production

---

### 9.7 Performance Testing

**Tools:** Firebase Test Lab, Flipboard PerfDog (free version)
**Tests:**
- Cold start time: Target < 3 seconds
- Screen transition: Target < 300ms
- Firestore query: Target < 500ms
- FCM delivery: Target < 5 seconds (P95)
- Image upload (2MB photo): Target < 8 seconds on 4G

**Load Test (Firestore):**
- Simulate 100 simultaneous visitor entries
- Monitor Firestore read/write latency
- Check for Firestore quota limits

---

### 9.8 Security Testing Checklist (OWASP Mobile Top 10)

| # | Check | How to Test |
|---|---|---|
| M1 | Improper Credential Usage | Verify no keys in APK source (use Claude to audit) |
| M2 | Inadequate Supply Chain Security | Audit pubspec.yaml dependencies |
| M3 | Insecure Authentication | Test auth bypass attempts |
| M4 | Insufficient Input/Output Validation | Test XSS in text fields |
| M5 | Insecure Communication | Verify all traffic is HTTPS/TLS |
| M6 | Inadequate Privacy Controls | Check no PII in logs |
| M7 | Insufficient Binary Protections | Enable ProGuard/R8 |
| M8 | Security Misconfiguration | Audit Firebase security rules |
| M9 | Insecure Data Storage | Check no sensitive data in SharedPreferences |
| M10 | Insufficient Cryptography | Verify Firebase Auth tokens used correctly |

**AI Prompt for Security Audit:**
```
Audit these Firebase Firestore security rules for GateFlow.
The rules should ensure:
1. Users can only read/write their own profile
2. Only admins can post notices and manage residents
3. Only guards can create visitor entries
4. Residents can only approve/deny visitors for their own flat
5. No unauthenticated access to any data
6. Admins can only access their own community data

[PASTE SECURITY RULES]

List any vulnerabilities found with severity (Critical/High/Medium/Low) 
and provide fixed rule code.
```

---

### 9.9 Automation Strategy

**Phase 1 (Weeks 1–12):** Manual testing + Maestro smoke tests
**Phase 2 (Months 4–6):** Full Maestro regression suite in GitHub Actions
**Phase 3 (Month 7+):** Firebase Test Lab integration, Appium for cross-device

```yaml
# .github/workflows/test.yml
name: Mobile Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Flutter Test
        run: flutter test
      - name: Build APK
        run: flutter build apk --debug
      - name: Run Maestro
        uses: mobile-dev-inc/action-maestro-cloud@v1
        with:
          api-key: ${{ secrets.MAESTRO_CLOUD_API_KEY }}
          app-file: build/app/outputs/flutter-apk/app-debug.apk
          workspace: .maestro
```

---

## 10. UI/UX STRATEGY

### 10.1 Design Principles
1. **Clarity over cleverness** — Guards use the app in dim light, under pressure
2. **Speed first** — Every core action reachable in 2 taps
3. **Offline feedback** — Always show connection status to guard
4. **Large tap targets** — Minimum 48x48dp for all interactive elements
5. **Color-coded status** — Green = approved, Red = denied, Orange = pending

### 10.2 Design System

**Color Palette:**
| Token | Color | Use |
|---|---|---|
| Primary | #1A73E8 | Buttons, links, active states |
| Primary Dark | #1557B0 | Pressed states |
| Success | #34A853 | Approved, resolved |
| Warning | #FBBC04 | Pending, attention |
| Error | #EA4335 | Denied, critical |
| Surface | #FFFFFF | Card backgrounds |
| Background | #F8F9FA | Screen background |
| On-Surface | #202124 | Primary text |
| Subtle | #5F6368 | Secondary text |
| Border | #DADCE0 | Dividers, borders |

**Typography:**
| Style | Font | Size | Weight |
|---|---|---|---|
| Display | Roboto | 28sp | 700 |
| Headline | Roboto | 22sp | 600 |
| Title | Roboto | 18sp | 600 |
| Body | Roboto | 16sp | 400 |
| Caption | Roboto | 13sp | 400 |
| Button | Roboto | 15sp | 600 |

**Component Rules:**
- All cards: 8dp radius, 1dp border, 4dp elevation
- All buttons: 48dp height, 12dp horizontal padding
- All text inputs: 56dp height, outlined style
- Bottom navigation: max 5 items
- Icons: Material Icons 3, 24dp size

### 10.3 Screen List

**Resident App (12 screens):**
1. Splash Screen
2. Phone Login
3. OTP Verification
4. Profile Setup
5. Home Dashboard
6. Visitor Approval (incoming)
7. Pre-Approve Visitor (form)
8. Visitor History
9. Notice Board (list)
10. Notice Detail
11. Raise Complaint (form)
12. My Complaints (list)

**Guard App (8 screens):**
1. Guard Login (PIN)
2. Guard Home (today's log)
3. New Visitor Form
4. Visitor Photo Capture
5. Delivery Entry Form
6. Staff Entry Form
7. Vehicle Entry Form
8. Today's Entry Log

**Admin App (9 screens):**
1. Admin Home (dashboard)
2. Resident Management (list)
3. Add Resident Form
4. Notice Management (list)
5. Post Notice Form
6. Complaint Dashboard
7. Complaint Detail
8. Visitor Log
9. Settings

### 10.4 Key User Flows

**Flow 1: Visitor Entry & Approval (Core Loop)**
```
Guard opens app (2s)
→ Taps "New Visitor" 
→ Enters name + flat (15s)
→ Takes photo (optional, 5s)
→ Taps Submit (1s)
→ Resident gets push notification (3s)
→ Resident taps Approve (2s)
→ Guard sees "Approved ✓" (1s)
Total: ~30 seconds end-to-end
```

**Flow 2: Resident Pre-Approves a Guest**
```
Resident opens app
→ Taps "Pre-Approve Visitor"
→ Enters guest name + expected date
→ Gets 6-digit OTP
→ Shares OTP via WhatsApp to guest
→ Guest arrives, gives OTP to guard
→ Guard enters OTP, gets instant verification
→ Guest enters without notification needed
```

### 10.5 Accessibility Standards
- Minimum contrast ratio: 4.5:1 (WCAG AA)
- All images have content descriptions
- Navigation works with TalkBack
- No color-only information (always pair with icon/text)
- Font scaling: app works at 150% font size
- Touch target: minimum 48x48dp

---

## 11. DATABASE DESIGN

### 11.1 Firestore Collection Structure

```
/communities/{communityId}
  - name: string
  - address: string
  - city: string
  - totalUnits: number
  - adminIds: string[]
  - plan: string (free/basic/pro)
  - createdAt: timestamp
  - settings: map

/users/{uid}
  - name: string
  - phone: string
  - role: string (resident/guard/admin)
  - communityId: string
  - flatNumber: string (e.g., "A-101")
  - tower: string
  - isActive: boolean
  - profilePhotoUrl: string
  - fcmToken: string
  - createdAt: timestamp
  - lastLoginAt: timestamp

/communities/{communityId}/visitors/{visitorId}
  - visitorName: string
  - visitorPhone: string (optional)
  - photoUrl: string
  - hostFlatNumber: string
  - hostResidentId: string
  - purpose: string (guest/delivery/service/other)
  - entryTime: timestamp
  - exitTime: timestamp (null if not exited)
  - status: string (pending/approved/denied/entered/exited)
  - approvedBy: string (uid)
  - guardId: string
  - denyReason: string (optional)
  - isOfflineEntry: boolean
  - syncedAt: timestamp

/communities/{communityId}/deliveries/{deliveryId}
  - courierCompany: string
  - packageDescription: string
  - recipientFlatNumber: string
  - recipientResidentId: string
  - guardId: string
  - entryTime: timestamp
  - collectedAt: timestamp (null if uncollected)
  - status: string (arrived/collected)

/communities/{communityId}/complaints/{complaintId}
  - title: string
  - category: string
  - description: string
  - photoUrl: string (optional)
  - status: string (open/in_progress/resolved/closed)
  - submittedBy: string (uid)
  - flatNumber: string
  - assignedTo: string (admin uid, optional)
  - statusHistory: array of {status, changedBy, changedAt, note}
  - createdAt: timestamp
  - updatedAt: timestamp

/communities/{communityId}/notices/{noticeId}
  - title: string
  - body: string
  - category: string (general/urgent/event/maintenance)
  - postedBy: string (admin uid)
  - expiresAt: timestamp
  - createdAt: timestamp
  - readBy: string[] (uids who read it)

/communities/{communityId}/staff/{staffId}
  - name: string
  - role: string (maid/driver/cook/security/gardener/other)
  - phone: string (optional)
  - photoUrl: string
  - approvedForFlats: string[] (flat numbers)
  - isActive: boolean
  - addedBy: string (resident uid)

/communities/{communityId}/staff/{staffId}/attendance/{date}
  - entryTime: timestamp
  - exitTime: timestamp
  - guardId: string

/communities/{communityId}/auditLogs/{logId}
  - action: string
  - performedBy: string (uid)
  - targetCollection: string
  - targetDocId: string
  - timestamp: timestamp
  - metadata: map
```

### 11.2 Indexing Strategy

```javascript
// Required composite indexes in Firestore:
visitors: [communityId, hostFlatNumber, entryTime DESC]
visitors: [communityId, status, entryTime DESC]
complaints: [communityId, status, createdAt DESC]
complaints: [communityId, submittedBy, createdAt DESC]
notices: [communityId, category, createdAt DESC]
staff/attendance: [staffId, date DESC]
```

### 11.3 Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin(communityId) {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.communityId == communityId;
    }
    
    function isGuard(communityId) {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'guard' &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.communityId == communityId;
    }
    
    function isResident(communityId) {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'resident' &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.communityId == communityId;
    }
    
    function isMember(communityId) {
      return isAdmin(communityId) || isGuard(communityId) || isResident(communityId);
    }
    
    // Users
    match /users/{uid} {
      allow read: if isAuthenticated() && request.auth.uid == uid;
      allow create: if isAuthenticated() && request.auth.uid == uid;
      allow update: if isAuthenticated() && request.auth.uid == uid;
    }
    
    // Communities
    match /communities/{communityId} {
      allow read: if isMember(communityId);
      allow write: if isAdmin(communityId);
      
      // Visitors
      match /visitors/{visitorId} {
        allow read: if isMember(communityId);
        allow create: if isGuard(communityId);
        allow update: if isGuard(communityId) || 
          (isResident(communityId) && 
           resource.data.hostFlatNumber == 
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatNumber);
      }
      
      // Complaints
      match /complaints/{complaintId} {
        allow read: if isMember(communityId);
        allow create: if isResident(communityId);
        allow update: if isAdmin(communityId) || 
          (isResident(communityId) && resource.data.submittedBy == request.auth.uid);
      }
      
      // Notices
      match /notices/{noticeId} {
        allow read: if isMember(communityId);
        allow write: if isAdmin(communityId);
      }
    }
  }
}
```

---

## 12. SECURITY ARCHITECTURE

### 12.1 Authentication Flow
```
User opens app
→ Enter phone number
→ Firebase sends OTP via SMS (Twilio/MSG91 backend)
→ User enters OTP
→ Firebase Auth issues JWT (valid 1 hour)
→ Refresh token (valid 1 year, stored securely)
→ All Firestore requests include JWT in header
→ Firestore security rules validate JWT claims
```

### 12.2 Role-Based Access Control

| Action | Resident | Guard | Admin |
|---|---|---|---|
| Read own profile | ✓ | ✓ | ✓ |
| Read other profiles | ✗ | ✗ | ✓ |
| Create visitor entry | ✗ | ✓ | ✓ |
| Approve own flat visitor | ✓ | ✗ | ✓ |
| Read all visitors | ✗ | ✓ (today) | ✓ |
| Post notice | ✗ | ✗ | ✓ |
| Submit complaint | ✓ | ✗ | ✗ |
| Update complaint status | ✗ | ✗ | ✓ |
| Add residents | ✗ | ✗ | ✓ |
| View analytics | ✗ | ✗ | ✓ |

### 12.3 Data Encryption
- **In Transit:** All Firebase SDK traffic uses TLS 1.3
- **At Rest:** Firebase encrypts all data at rest by default (AES-256)
- **Sensitive Fields:** Phone numbers stored as-is (Firebase Auth handles this)
- **Photos:** Firebase Storage enforces authentication before serving

### 12.4 Audit Logs
Every admin action writes to `/communities/{id}/auditLogs`:
```
- Resident added/removed
- Notice posted/deleted
- Complaint status changed
- Guard PIN reset
- Community settings changed
```

### 12.5 API Security
- Firebase App Check (prevents API abuse from non-app clients)
- Rate limiting via Firebase Security Rules (max 10 writes/minute per user)
- No custom backend API in MVP (Firebase handles everything)

### 12.6 Guard PIN Security
- Guard uses 6-digit PIN (not full OTP every time — usability requirement)
- PIN hashed before storage (never stored in plaintext)
- PIN reset only by admin
- 5 wrong PINs → account locked, admin must unlock

---

## 13. DEVOPS SETUP

### 13.1 Repository Structure
```
gateflow/
├── lib/                    # Flutter source
├── test/                   # Unit and widget tests
├── integration_test/       # Integration tests
├── .maestro/              # Maestro test flows
├── .github/
│   └── workflows/
│       ├── test.yml       # Run tests on PR
│       ├── build.yml      # Build APK on merge
│       └── deploy.yml     # Deploy to Play Store
├── firebase/
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── storage.rules
├── docs/                  # Architecture docs
└── scripts/               # Utility scripts
```

### 13.2 Branching Strategy
```
main          ← production (Play Store)
staging       ← internal testing
develop       ← active development
feature/*     ← new features (merge to develop)
hotfix/*      ← critical fixes (merge to main + develop)
```

### 13.3 GitHub Actions — Build Pipeline

```yaml
# .github/workflows/build.yml
name: Build & Deploy
on:
  push:
    branches: [main, staging]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run tests
        run: flutter test
        
      - name: Build APK
        run: flutter build apk --release
        
      - name: Sign APK
        uses: r0adkll/sign-android-release@v1
        with:
          releaseDirectory: build/app/outputs/flutter-apk
          signingKeyBase64: ${{ secrets.SIGNING_KEY }}
          alias: ${{ secrets.KEY_ALIAS }}
          keyStorePassword: ${{ secrets.KEY_STORE_PASSWORD }}
          
      - name: Deploy to Play Store (Internal)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.gateflow.app
          releaseFiles: build/app/outputs/flutter-apk/app-release-signed.apk
          track: internal
```

### 13.4 Environment Setup

**GitHub Secrets to Configure:**
```
FIREBASE_OPTIONS       ← google-services.json content
SIGNING_KEY            ← Keystore base64 encoded
KEY_ALIAS              ← Keystore alias
KEY_STORE_PASSWORD     ← Keystore password
KEY_PASSWORD           ← Key password
SERVICE_ACCOUNT_JSON   ← Google Play service account
MAESTRO_CLOUD_API_KEY  ← Maestro Cloud API key
```

### 13.5 Play Store Track Strategy
```
Internal Testing  ← Developers + founders (instant)
Closed Testing    ← 50 pilot society users
Open Testing      ← Public beta (after Week 10)
Production        ← Public launch (Week 12)
```

### 13.6 Monitoring Setup

**Crashlytics Alerts:** Email on new crash type, email if crash-free rate drops below 99%
**Sentry Alerts:** Slack/email on new error, on error spike (>10/hour)
**Firebase Performance:** Alert if app start time exceeds 3 seconds
**Uptime:** Firebase is 99.95% SLA; no additional monitoring needed for MVP

---

## 14. LAUNCH STRATEGY

### 14.1 Alpha Launch (Week 9)
**Target:** 1 society, 10–20 users
**Channel:** Direct personal contact (friend's society, relative's society)
**Goal:** Find critical bugs before more users see them
**Success Metric:** No app crash for 48 hours, core visitor flow works end-to-end

### 14.2 Beta Launch (Weeks 10–11)
**Target:** 3–5 societies, 50–100 users
**Channel:**
- Facebook groups for housing societies (search "RWA [City]")
- LinkedIn posts targeting society secretaries
- Local property management WhatsApp groups
**Goal:** Validate product-market fit, test at small scale
**Success Metric:** DAU > 30%, at least 1 admin says "I'd pay for this"

### 14.3 Pilot Community Launch (Week 12)
**Target:** 10 societies, 200+ users
**Channel:**
- Play Store public listing
- LinkedIn founder posts
- Reddit r/[city] posts
- Direct cold outreach to 100 society secretaries
- Partner with 1–2 property management companies
**Offer:** Free for 3 months, no credit card required
**Goal:** Acquire 10 active societies before charging

### 14.4 Public Launch (Month 4)
**Target:** 25 societies, paid
**Pricing announced:** ₹2,999/month (introductory), then ₹4,999/month
**Channel:**
- Google Ads (search: "society management app", "gated community app")
- Facebook/Instagram Ads (target: apartment owners in metros)
- YouTube demo video (3 minutes)
- Referral program: "Refer a society, get 1 month free"
**Goal:** First ₹50,000 MRR

### 14.5 User Acquisition Tactics (Zero to Low Cost)

| Tactic | Cost | Effort | Expected Yield |
|---|---|---|---|
| Direct cold email/WhatsApp to RWA secretaries | $0 | High | 10% conversion |
| Facebook groups (RWA, Apartments, Residents) | $0 | Medium | 5% conversion |
| LinkedIn founder posts | $0 | Low | Brand awareness |
| Reddit r/india, r/bangalore etc. | $0 | Low | Downloads spike |
| Google Play Store organic | $0 | None | Long-term SEO |
| Partner with property management companies | $0 | High | 5–10 societies |
| Referral from existing societies | $0 | None | Best quality leads |
| Google Ads (Month 4+) | $50/month | Medium | 2–5 leads/day |

### 14.6 Feedback Collection Process
- **In-app:** NPS survey after 7 days (Mixpanel trigger)
- **Weekly:** 30-minute call with each pilot society admin
- **Monthly:** Written feedback survey via Google Forms
- **Ongoing:** Monitor Play Store reviews (respond to all)
- **Support:** WhatsApp Business for real-time issues

---

## 15. REVENUE MODEL

### 15.1 Revenue Model Comparison

| Model | Pros | Cons | Fit |
|---|---|---|---|
| Society Subscription | Predictable MRR; one decision-maker | Sales cycle 1–3 weeks | **Best for MVP** |
| Per-Resident Subscription | Scales with community size | Residents don't see value; churn | Poor |
| Freemium | Easy adoption | Hard to convert; free users expensive | Phase 2 |
| Marketplace Commission | High potential | Needs scale first | Phase 3 |
| Advertising | Easy to implement | Poor UX; destroys trust | Never |

### 15.2 Recommended Pricing (Society Subscription)

| Plan | Price | Societies | Features |
|---|---|---|---|
| **Starter** | ₹1,999/month | Up to 100 units | Visitor management, notices, complaints |
| **Growth** | ₹3,999/month | Up to 300 units | + Payments, facility booking, analytics |
| **Pro** | ₹7,999/month | Up to 1,000 units | + API access, multi-admin, priority support |
| **Enterprise** | Custom | 1,000+ units | + White label, hardware integration |

**Annual discount:** 2 months free (≈16% off) for annual pre-payment

### 15.3 Revenue Projections

| Month | Societies | MRR | ARR |
|---|---|---|---|
| 4 | 5 paying | ₹14,995 | ₹1.8L |
| 5 | 15 paying | ₹44,985 | ₹5.4L |
| 6 | 30 paying | ₹89,970 | ₹10.8L |
| 9 | 75 paying | ₹2,24,925 | ₹27L |
| 12 | 150 paying | ₹4,49,850 | ₹54L |

**Break-even:** ~30 paying societies (covers ₹50,000/month infra + ₹40,000/month founder salary)

### 15.4 Secondary Revenue (Phase 3+)
- **Marketplace commission:** 5–10% on verified vendor bookings
- **Payment gateway revenue share:** 0.3% on society payment collections
- **Premium add-ons:** Hardware integration (boom barriers) — one-time setup fee ₹5,000–₹25,000
- **Enterprise SLA:** Priority support contract ₹25,000/year

### 15.5 Unit Economics Target

| Metric | Target |
|---|---|
| CAC (Cost to Acquire 1 Society) | < ₹1,500 |
| LTV (Society stays 24 months avg) | ₹71,976 (Starter) |
| LTV:CAC Ratio | > 40:1 |
| Gross Margin | > 85% (SaaS margin) |
| Payback Period | < 1 month |

---

## 16. SCALING PLAN

### Stage 1: 1 → 10 Societies (Months 1–4)

**Infrastructure:**
- Firebase Spark plan → Blaze plan (~$30/month)
- 1 GitHub repo, manual deployments

**Team:**
- Founder only (you)
- Claude/AI as co-developer

**Costs:**
- Tools: $150/month
- Marketing: $100/month
- Total: ~$250/month

**KPIs:**
- 10 active societies
- >70% DAU of onboarded residents
- <2 support tickets/society/week

---

### Stage 2: 10 → 100 Societies (Months 5–10)

**Infrastructure:**
- Firebase Blaze plan (~$200/month at this scale)
- Implement Firebase caching rules to reduce read costs
- Add Cloudflare for CDN (optional)

**Team:**
- Hire 1 part-time support person (₹10,000/month)
- Hire 1 sales person on commission (10% of MRR they bring)
- Continue AI-assisted development

**Costs:**
- Infrastructure: $200/month
- Team: ₹15,000/month
- Marketing: ₹20,000/month
- Total: ~₹55,000/month
- Revenue at 100 societies: ~₹3,00,000/month ✓ Profitable

**KPIs:**
- 100 societies, 10,000 residents
- <1% monthly churn
- NPS > 50
- CAC < ₹1,500

---

### Stage 3: 100 → 1,000 Societies (Months 11–24)

**Infrastructure:**
- Evaluate migration from Firebase to custom backend (Supabase/PostgreSQL)
- Multi-region Firebase deployment
- Dedicated Firebase support plan

**Team:**
- 1 full-time Flutter developer (₹50,000/month)
- 1 full-time customer success (₹25,000/month)
- 1 part-time content/marketing (₹15,000/month)
- Founder focuses on sales and fundraising

**Costs:**
- Infrastructure: $500/month
- Team: ₹1,20,000/month
- Marketing: ₹50,000/month
- Total: ~₹2,15,000/month
- Revenue at 1,000 societies: ~₹40,00,000/month ($48K) ✓ Series A ready

**KPIs:**
- 1,000 societies, 1,00,000 residents
- Present in 5+ cities
- MRR > ₹40L ($48K)
- Raise Seed round: $500K–$1M

---

### Stage 4: 1,000+ Societies (Year 3+)

**Infrastructure:**
- Custom backend (move off Firebase for cost efficiency)
- Kubernetes on GCP/AWS
- Multi-tenancy architecture with data isolation

**Team:**
- 15–25 person team
- Engineering, Product, Sales, CS, Marketing

**Expansion:**
- iOS app (already built by Stage 2)
- Web portal (already built by Stage 2)
- Hardware partnerships (boom barriers, intercoms)
- Enterprise contracts with property developers (Prestige, DLF, Godrej)
- Southeast Asia expansion (similar market: Singapore, Indonesia)

---

## 17. FOUNDER DASHBOARD

Track these metrics every Monday morning. Takes 15 minutes.

### Product Metrics (Firebase/Mixpanel)

| Metric | Week 12 Target | Month 6 Target |
|---|---|---|
| DAU | 50 | 500 |
| MAU | 100 | 1,500 |
| DAU/MAU Ratio | >40% | >40% |
| Visitor entries/day | 20 | 200 |
| Notifications sent/day | 50 | 600 |
| Crash-free rate | >99% | >99.5% |
| App cold start (P95) | <3s | <2s |
| FCM delivery rate | >95% | >97% |

### User Metrics

| Metric | Week 12 Target | Month 6 Target |
|---|---|---|
| Active societies | 5 | 50 |
| Total residents onboarded | 200 | 5,000 |
| Resident activation rate | >60% | >70% |
| Guard daily usage | >80% | >90% |
| NPS Score | >30 | >50 |
| Play Store rating | >4.0 | >4.3 |

### Revenue Metrics

| Metric | Week 12 Target | Month 6 Target |
|---|---|---|
| MRR | ₹0 (pilot) | ₹1,00,000 |
| Paying societies | 0 | 30 |
| Trial → Paid conversion | — | >60% |
| Churn rate (monthly) | — | <3% |
| ARPS (avg revenue/society) | — | ₹3,333 |

### Growth Metrics

| Metric | Week 12 Target | Month 6 Target |
|---|---|---|
| New societies this week | 2 | 5 |
| Demo calls booked | 5 | 15 |
| Demo → Trial conversion | >30% | >40% |
| Referrals from existing users | 0 | 5/month |
| Play Store downloads | 500 | 5,000 |
| App Store (iOS) downloads | — | 500 |

### Support Metrics

| Metric | Target |
|---|---|
| Avg response time (WhatsApp) | < 2 hours |
| Open support tickets | < 10 |
| Tickets resolved same day | > 80% |
| Critical bug → Fix time | < 4 hours |

---

## 18. RISK REGISTER

| # | Risk | Probability | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Firebase costs spike unexpectedly | Medium | High | Set billing alerts at $50, $100, $200. Optimize Firestore queries |
| R2 | FCM notifications unreliable in India | High | High | Add WhatsApp notification as fallback (Twilio WhatsApp API) |
| R3 | Play Store rejection | Medium | Medium | Follow Play Store policies strictly; avoid in-app payment bypass |
| R4 | Society admin doesn't onboard residents | High | High | Provide "Resident Invite Link" with one-tap join |
| R5 | Guard finds app too complex | High | High | UX test with actual guards; keep guard app max 3 taps to entry |
| R6 | MyGate copies feature and outspends you | Low | Medium | Focus on Tier-2 cities first; better support wins loyalty |
| R7 | Firebase phone auth quota limits | Low | High | Monitor SMS quota; upgrade plan before hitting limit |
| R8 | Founder burnout (solo founder) | Medium | Critical | Cap work at 50 hours/week; take 1 full day off per week |
| R9 | Low conversion from pilot to paid | Medium | High | Start pricing conversation at Week 6 (not Week 12) |
| R10 | Security breach/data leak | Low | Critical | Implement security rules strictly; run OWASP audit before launch |
| R11 | No-show on demo calls | High | Low | Send 3 reminders; use Calendly for easy rescheduling |
| R12 | AI-generated code quality issues | Medium | Medium | Code review every feature with Claude before testing |

---

## APPENDIX A: WEEK 1 QUICK-START CHECKLIST

**Day 1:**
- [ ] Create GitHub account and private repo: `gateflow`
- [ ] Install Flutter SDK (flutter.dev)
- [ ] Install Cursor IDE (cursor.sh)
- [ ] Create Firebase project (console.firebase.google.com)
- [ ] Enable Firebase Auth (Phone), Firestore, FCM, Storage

**Day 2:**
- [ ] Run Flutter project setup AI prompt
- [ ] Verify app runs on Android emulator
- [ ] Connect Firebase to Flutter (FlutterFire CLI)
- [ ] First Firestore read/write test

**Day 3:**
- [ ] Create Figma account (figma.com)
- [ ] Download Material 3 Design Kit from Figma Community
- [ ] Create color palette and typography in Figma

**Day 4:**
- [ ] Create Notion workspace: Projects > GateFlow
- [ ] Set up weekly task board (Week 1–12 columns)
- [ ] Create contact spreadsheet for society outreach (50 targets)

**Day 5:**
- [ ] Contact 5 housing society secretaries for 30-min interviews
- [ ] Use this prompt: "Generate 20 interview questions for a housing society secretary to validate the need for a visitor management and community app."
- [ ] Install Maestro CLI (maestro.mobile.dev)

**Day 6–7:**
- [ ] Complete 3 interviews
- [ ] Document key pain points
- [ ] Confirm: visitor management is a top 3 pain point (if not, pivot to whatever they said)

---

## APPENDIX B: KEY AI TOOL SHORTCUTS

| Task | Tool | Command |
|---|---|---|
| Generate Flutter screen | Cursor | Ctrl+K → describe screen |
| Debug error | Claude | Paste error + "Fix this Flutter error:" |
| Write test cases | Claude | "Write Maestro tests for [feature]" |
| Firestore security rules | Firebase Studio | "Generate rules for [schema]" |
| Play Store description | ChatGPT | "Write Play Store description for [app]" |
| Cold email | Claude | "Write cold email to society secretary" |
| Refactor code | Cursor | Select code → Ctrl+K → "Refactor this" |
| Performance audit | Claude | "Audit this Flutter code for performance" |

---

*Document Version: 1.0 | Created: 2026-05-30 | Next Review: 2026-06-30*
*Built with Claude Sonnet 4.6 | For internal use only*
