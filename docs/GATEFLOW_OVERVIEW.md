# GateFlow — Product & Architecture Overview
### "Your community, connected."
**Version:** 1.0 | **Date:** June 2026 | **Stage:** Active Development (Week 4 of 12)

---

## 1. WHAT IS GATEFLOW?

GateFlow is a **mobile-first community management platform** for gated societies, apartments, and residential communities in India.

It replaces WhatsApp groups, paper registers, and phone calls with one unified app — making society living safer, smarter, and more connected.

---

## 2. THE PROBLEM WE SOLVE

| Today's Pain | How Bad It Is |
|---|---|
| Security guard uses paper register for visitors | No accountability, easily faked |
| Resident gets random calls from guard for approvals | Disruptive, no record kept |
| Complaints sent on WhatsApp, never tracked | Lost in chat, no resolution timeline |
| Society announcements missed by residents | No single source of truth |
| No visibility into who entered/exited | Zero security audit trail |

**Bottom line:** India has 50,000+ gated communities. Most still run on WhatsApp and paper.

---

## 3. WHO IT'S FOR

| User | Role | Core Need |
|---|---|---|
| **Resident** | Flat owner/tenant | Approve visitors, track complaints, read notices |
| **Security Guard** | Gate staff | Log visitors, deliveries, staff quickly |
| **Society Admin** | Secretary/Treasurer | Manage residents, complaints, announcements |

---

## 4. CORE FEATURES (MVP — 12 Weeks)

### Resident App
- 📲 Phone OTP Login
- ✅ Approve/Deny visitors in real-time
- 🔑 Pre-approve guests (generate OTP)
- 📦 Delivery notifications
- 📋 Notice board
- 🔧 Raise & track complaints

### Security Guard App
- 🚪 Log visitor entry (name, photo, flat)
- 📦 Log deliveries
- 👷 Staff attendance
- 🚗 Vehicle entry
- 📵 Works offline (syncs when internet returns)

### Admin App
- 👥 Manage residents
- 📢 Post announcements
- 📊 Complaint dashboard
- 📈 Visitor analytics

---

## 5. BUSINESS MODEL

**Society SaaS Subscription** — charged per society, not per resident.

| Plan | Price | Society Size |
|---|---|---|
| Starter | ₹1,999/month | Up to 100 units |
| Growth | ₹3,999/month | Up to 300 units |
| Pro | ₹7,999/month | Up to 1,000 units |

**Why this works:**
- One decision maker (Secretary) = short sales cycle
- High retention (daily habit app)
- Low CAC via direct outreach to RWA groups

**Revenue Target:** ₹1,00,000 MRR by Month 6 (30 paying societies)

---

## 6. COMPETITIVE POSITIONING

| | GateFlow | MyGate | NoBroker Hood |
|---|---|---|---|
| Target | Tier 1 + Tier 2 cities | Tier 1 metros only | Tier 1 metros only |
| Pricing | ₹1,999–₹7,999/mo | ₹8,000+/mo | Freemium |
| Onboarding | 1 day (self-serve) | 1 week (field agent) | 3–5 days |
| Guard UX | Ultra simple | Complex | Poor |
| Offline mode | ✅ Yes | ❌ No | ❌ No |
| QA-first reliability | ✅ Yes | ❌ Buggy | ❌ Crashes |

**Our edge:** Simpler UX + lower price + Tier-2 city focus + offline-first

---

## 7. TECHNOLOGY ARCHITECTURE

```
┌─────────────────────────────────────────────────────┐
│                   GATEFLOW SYSTEM                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│   │  RESIDENT    │  │    GUARD     │  │  ADMIN   │ │
│   │     APP      │  │     APP      │  │   APP    │ │
│   └──────┬───────┘  └──────┬───────┘  └────┬─────┘ │
│          │                 │               │        │
│          └─────────────────┴───────────────┘        │
│                            │                        │
│                     Flutter (Dart)                  │
│                   Single Codebase                   │
│                  Android → iOS later                │
│                            │                        │
├────────────────────────────┼────────────────────────┤
│         FIREBASE BACKEND   │                        │
│                            ▼                        │
│   ┌─────────────────────────────────────────────┐  │
│   │           Firebase Auth (Phone OTP)          │  │
│   │      Verify identity via SMS OTP             │  │
│   └─────────────────────────────────────────────┘  │
│                                                      │
│   ┌─────────────────────────────────────────────┐  │
│   │         Firestore Database (NoSQL)           │  │
│   │   Real-time sync across all devices         │  │
│   │   Offline support built-in                  │  │
│   │   Region: asia-south1 (Mumbai)              │  │
│   └─────────────────────────────────────────────┘  │
│                                                      │
│   ┌─────────────────────────────────────────────┐  │
│   │      Firebase Cloud Messaging (FCM)          │  │
│   │   Push notifications (visitor approvals,    │  │
│   │   delivery alerts, notice broadcasts)       │  │
│   └─────────────────────────────────────────────┘  │
│                                                      │
│   ┌─────────────────────────────────────────────┐  │
│   │         Firebase Storage                     │  │
│   │   Visitor photos, complaint images          │  │
│   └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 8. TECHNOLOGY STACK

| Layer | Technology | Why |
|---|---|---|
| **Mobile App** | Flutter (Dart) | One codebase for Android + iOS |
| **Backend** | Firebase (BaaS) | No server needed; real-time; free tier |
| **Database** | Firestore | Real-time sync; offline-first |
| **Authentication** | Firebase Auth | Phone OTP; works in India |
| **Push Notifications** | Firebase Cloud Messaging | Free; reliable |
| **File Storage** | Firebase Storage | Visitor photos, documents |
| **Source Control** | GitHub | Industry standard |
| **CI/CD** | GitHub Actions | Auto-build + deploy |
| **IDE** | Cursor (AI-powered) | AI writes 90% of code |
| **Analytics** | Firebase Analytics | User behaviour tracking |
| **Crash Monitoring** | Firebase Crashlytics | Real-time crash reports |

---

## 9. DATA ARCHITECTURE (KEY COLLECTIONS)

```
Firebase Firestore Structure:

/communities/{communityId}
    ├── name, address, city, plan
    │
    ├── /visitors/{visitorId}
    │       ├── visitorName, photo, hostFlat
    │       ├── status: pending → approved/denied → entered
    │       └── entryTime, exitTime, guardId
    │
    ├── /complaints/{complaintId}
    │       ├── title, category, description, photo
    │       ├── status: open → in_progress → resolved
    │       └── submittedBy, assignedTo, statusHistory[]
    │
    ├── /notices/{noticeId}
    │       ├── title, body, category (urgent/general/event)
    │       └── postedBy, expiresAt, readBy[]
    │
    └── /staff/{staffId}
            ├── name, role, approvedForFlats[]
            └── /attendance/{date}

/users/{uid}
    ├── name, phone, role (resident/guard/admin)
    ├── communityId, flatNumber, tower
    └── fcmToken (for push notifications)
```

---

## 10. SECURITY MODEL

```
Authentication:  Firebase Phone OTP → JWT token
Authorization:   Role-based (Resident / Guard / Admin)
Data Rules:      Firestore Security Rules
                 - Residents: only own flat data
                 - Guards: entry logs only
                 - Admins: full community data
Encryption:      TLS in transit, AES-256 at rest (Firebase default)
Audit:           Every admin action logged to auditLogs collection
```

---

## 11. DEVELOPMENT APPROACH

**Who builds it:** Solo non-technical founder + AI tools (95% AI-written code)

**AI Tools Used:**
| Tool | Role |
|---|---|
| Claude (Anthropic) | Architecture, planning, code review |
| Cursor IDE | AI-powered code editor (writes Flutter code) |
| ChatGPT | Quick snippets, alternate ideas |
| Firebase Studio | Schema and rules generation |

**Why this works:**
- Flutter is well-supported by all AI models
- Firebase requires zero backend coding
- QA founder background = better testing than competitors
- Lean build = launch in 12 weeks, not 12 months

---

## 12. DEVELOPMENT TIMELINE

```
Week 1–2   ✅ Foundation (Flutter + Firebase + GitHub)
Week 3–4   🔜 Authentication + Visitor Approval (core loop)
Week 5–6   🔜 Complaints + Notice Board + Admin Panel
Week 7–8   🔜 Delivery, Staff Entry, Offline Mode, Polish
Week 9     🔜 Alpha — 1 real society
Week 10    🔜 Beta — 3 societies
Week 11    🔜 Play Store listing, landing page
Week 12    🔜 PUBLIC LAUNCH 🚀
```

---

## 13. CURRENT STATUS (Week 4 of 12)

| Milestone | Status |
|---|---|
| Flutter SDK installed | ✅ Done |
| GitHub repo created | ✅ github.com/sitasrikanth/gateflow-app |
| Firebase project created | ✅ gateflow-ss (asia-south1) |
| Firebase connected to app | ✅ Done |
| QuickCode login (Admin/Resident/Guard) | ✅ Done |
| Admin home with tabs | ✅ Done |
| Resident home screen | ✅ Done |
| Guard home screen | ✅ Done |
| Event Fund Manager module | ✅ Done |
| — Create / Edit events | ✅ Done |
| — Event type catalog (29 types, 8 categories) | ✅ Done |
| — HD images per event type (Pexels CDN) | ✅ Done |
| — Custom image upload per event type | ✅ (needs Blaze plan) |
| — Per-event banner image | ✅ (needs Blaze plan) |
| — Event list 2-column grid with HD images | ✅ Done |
| — Horizontal swipe between events (PageView) | ✅ Done |
| — Contributions (Wing→Block→Flat grouping) | ✅ Done |
| — Self-report flow (resident submits, admin confirms) | ✅ Done |
| — Expenses with hierarchical categories | ✅ Done |
| — Recalculate totals (fixed to match summary) | ✅ Done |
| — Activity log with soft-delete & restore | ✅ Done |
| — Collection status by block (live updates) | ✅ Done |
| — PDF report generation | ✅ Done |
| Expense categories screen (admin) | ✅ Done |
| Firestore rules (open for quickCode auth) | ✅ Done |
| Firebase Storage (Blaze plan upgrade) | 🔜 In progress |
| **Next:** Follow-up tab — unpaid flats + reminders | 🔜 Next session |
| **Next:** Push notifications | 🔜 Planned |

---

## 14. TEAM

| Role | Person |
|---|---|
| Founder / Product / QA | Srikanth Sita |
| Development | AI-assisted (Claude + Cursor) |
| Advisory | — (seeking) |

**Founder's edge:** QA background means we test before we ship. GateFlow will be more reliable than MyGate on Day 1.

---

## 15. WHAT WE'RE LOOKING FOR

- 🏘️ **Pilot societies** — Free 3-month trial, give us feedback
- 💡 **Co-founder** — Technical or Sales background
- 💰 **Pre-seed funding** — ₹20–50L to hire 1 developer + 1 sales person
- 🤝 **Property management partnerships** — Access to multiple societies

---

*Built with Flutter + Firebase | Developed by Srikanth Sita | June 2026*
*Contact: sitasrikanth@gmail.com*
