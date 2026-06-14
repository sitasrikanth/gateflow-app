# GateFlow — Feature Ideas & Product Backlog

> Every feature idea lives here. During planning sessions we pick from here and move to TRACKER.md.
> Tell Claude: *"Add idea: [your idea]"* → added instantly.

**Priority:** 🔥 MVP | ⭐ Growth | 💡 Future  
**Effort:** S (1 day) | M (2-3 days) | L (1 week) | XL (2+ weeks)  
**Status:** 🔲 Not Started | 🔄 In Progress | ✅ Done

---

## 1. 🔐 Security, Visitor & Gate Management

> Core feature — the #1 reason societies adopt GateFlow

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| 1.1 | Visitor entry logging by guard | 🔥 | S | ✅ Done | Name, flat, purpose, phone |
| 1.2 | Resident approve/deny visitor in real-time | 🔥 | M | ✅ Done | Firestore StreamBuilder |
| 1.3 | Guard shift management (Start/End/Break) | 🔥 | M | ✅ Done | Shift timer, break timer |
| 1.4 | Guard quick code login (6-digit) | 🔥 | S | ✅ Done | No OTP needed for guards |
| 1.5 | Resident pending approval by admin | 🔥 | S | ✅ Done | status=pending until approved |
| 1.6 | Pre-approved Guest OTP | 🔥 | M | 🔲 | Resident generates OTP for expected guest |
| 1.7 | FCM push notification to resident on visitor arrival | 🔥 | L | 🔲 | Alert even when app is closed |
| 1.8 | Visitor photo capture by guard | 🔥 | M | 🔲 | image_picker + Firebase Storage |
| 1.9 | Emergency SOS button (resident → guard) | 🔥 | S | 🔲 | Real-time panic alert with flat + name |
| 1.10 | Visitor blacklist | ⭐ | M | 🔲 | Admin adds, guard alerted on entry attempt |
| 1.11 | QR code entry for frequent visitors | ⭐ | M | 🔲 | Resident generates QR, guard scans |
| 1.12 | Vehicle entry log | ⭐ | S | 🔲 | Plate number, vehicle type, flat |
| 1.13 | Overstay alert | ⭐ | S | 🔲 | Auto-alert if visitor stays > X hours |
| 1.14 | Guard patrol tracking (QR checkpoints) | ⭐ | L | 🔲 | Guard scans QR at each point during night rounds |
| 1.15 | Multi-gate support | ⭐ | L | 🔲 | Guard assigned to specific gate |
| 1.16 | Boom barrier integration | 💡 | XL | 🔲 | Hardware integration — auto open on approval |
| 1.17 | Face recognition entry | 💡 | XL | 🔲 | ML Kit or Google Vision API |
| 1.18 | Intercom simulation (guard calls resident) | 💡 | L | 🔲 | WebRTC or Agora SDK |
| 1.19 | Move-in / Move-out controls | ⭐ | M | 🔲 | Admin approval for large moves |
| 1.20 | Visitor analytics (peak hours, purposes) | ⭐ | M | 🔲 | Charts with fl_chart |

---

## 2. 👷 Staff & Facility Management

> Track domestic helpers, delivery, maintenance staff daily

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| 2.1 | Domestic help / maid entry-exit log | 🔥 | M | 🔲 | Name, flat, time in/out |
| 2.2 | Staff attendance tracking | 🔥 | M | 🔲 | Daily attendance per flat |
| 2.3 | Delivery notification to resident | 🔥 | S | 🔲 | "Package from Amazon at gate" |
| 2.4 | Delivery entry form (guard) | 🔥 | S | 🔲 | Courier, package type, flat |
| 2.5 | Resident tracks maid attendance | ⭐ | M | 🔲 | Monthly calendar view |
| 2.6 | Driver / vehicle management | ⭐ | M | 🔲 | Assigned vehicles per flat |
| 2.7 | Vendor / plumber / electrician entry | ⭐ | S | 🔲 | Maintenance staff entry log |
| 2.8 | Trusted vendor marketplace | 💡 | XL | 🔲 | Rated plumbers, electricians for society |
| 2.9 | Parking management (visitor) | ⭐ | M | 🔲 | Slot assignment, vacancy tracker |
| 2.10 | Resident parking slot management | ⭐ | M | 🔲 | Assigned slots per flat |
| 2.11 | Guard performance report (admin) | ⭐ | S | 🔲 | Shift hours, visitors logged |

---

## 3. 📢 Communication & Online Notices

> Keep all residents informed in one place

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| 3.1 | Notice board (admin posts) | 🔥 | M | 🔲 | Categories: General, Emergency, Events |
| 3.2 | Notice detail screen | 🔥 | S | 🔲 | Full text, timestamp, attachments |
| 3.3 | FCM broadcast to all residents | 🔥 | M | 🔲 | Admin posts notice → all notified |
| 3.4 | Mark notice as read | ⭐ | S | 🔲 | Unread dot on notice list |
| 3.5 | Notice expiry (auto-hide old notices) | ⭐ | S | 🔲 | Admin sets expiry date |
| 3.6 | Emergency broadcast (fire/flood/power) | 🔥 | M | 🔲 | High priority alert to all |
| 3.7 | Poll / voting for residents | ⭐ | L | 🔲 | Society decisions via app |
| 3.8 | Resident social feed (buy/sell/lost-found) | 💡 | XL | 🔲 | Community marketplace |
| 3.9 | WhatsApp Business integration | 💡 | L | 🔲 | Notifications via WhatsApp |
| 3.10 | Event announcements with RSVP | ⭐ | M | 🔲 | Society events, festival celebrations |

---

## 4. 🛠 Community Helpdesk

> Resident raises issue → admin/maintenance resolves it

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| 4.1 | Raise complaint form (resident) | 🔥 | M | 🔲 | Title, category, description, photo |
| 4.2 | Complaint status tracking | 🔥 | M | 🔲 | Open → In Progress → Resolved |
| 4.3 | Admin complaint dashboard | 🔥 | M | 🔲 | All complaints, filter by status/category |
| 4.4 | Admin updates complaint + notifies resident | 🔥 | S | 🔲 | Status change → FCM to resident |
| 4.5 | Complaint photo upload | ⭐ | M | 🔲 | Firebase Storage |
| 4.6 | Complaint history timeline | ⭐ | S | 🔲 | All status changes with timestamps |
| 4.7 | Assign complaint to maintenance staff | ⭐ | M | 🔲 | Staff gets notified |
| 4.8 | Resident rates resolution | 💡 | S | 🔲 | 1-5 star rating after resolved |
| 4.9 | SLA tracking (response time targets) | 💡 | M | 🔲 | Admin sees overdue complaints |
| 4.10 | Common area issue reporting | ⭐ | S | 🔲 | Lift, parking, lobby issues |

---

## 5. 🏊 Clubhouse & Amenities Reservations

> Book gym, pool, clubhouse, party hall from the app

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| 5.1 | List of amenities in society | ⭐ | S | 🔲 | Gym, Pool, Clubhouse, Party Hall, etc. |
| 5.2 | Amenity booking (calendar-based) | ⭐ | L | 🔲 | Pick date/time slot, confirm |
| 5.3 | Booking approval by admin | ⭐ | M | 🔲 | Admin approves/rejects bookings |
| 5.4 | My bookings screen | ⭐ | S | 🔲 | Upcoming + past bookings |
| 5.5 | Booking cancellation | ⭐ | S | 🔲 | With/without refund policy |
| 5.6 | Amenity rules / guidelines | ⭐ | S | 🔲 | Shown before booking |
| 5.7 | Guest charges for amenity use | 💡 | M | 🔲 | Extra fee for non-residents |
| 5.8 | Amenity availability calendar (admin) | ⭐ | M | 🔲 | Admin sees all bookings |
| 5.9 | Amenity booking notifications | ⭐ | S | 🔲 | Reminder 1 hour before slot |
| 5.10 | Waiting list for popular slots | 💡 | M | 🔲 | Auto-notify if slot opens up |

---

## 6. 💰 Billing & Payment Collections

> Collect maintenance fees, track payments, send reminders

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| 6.1 | Monthly maintenance bill generation | 🔥 | L | 🔲 | Auto-generate per flat |
| 6.2 | Online payment (Razorpay/UPI) | 🔥 | XL | 🔲 | Pay maintenance fee in app |
| 6.3 | Payment receipt / history | 🔥 | M | 🔲 | Download PDF receipt |
| 6.4 | Payment reminder notifications | 🔥 | M | 🔲 | FCM reminder before due date |
| 6.5 | Overdue payment alerts | ⭐ | S | 🔲 | Admin sees who hasn't paid |
| 6.6 | Partial payment support | ⭐ | M | 🔲 | Pay in installments |
| 6.7 | Payment dashboard (admin) | 🔥 | M | 🔲 | Collected vs pending per flat |
| 6.8 | Late fee calculation | ⭐ | M | 🔲 | Auto-add penalty after due date |
| 6.9 | Custom bill items | ⭐ | M | 🔲 | Water, electricity, parking charges |
| 6.10 | Bulk payment reminder (admin) | ⭐ | S | 🔲 | Send reminder to all pending flats |

---

## 7. 📊 Apartment Accounting

> Full financial management for society admin/treasurer

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| 7.1 | Income & expense tracking | ⭐ | L | 🔲 | Society income, maintenance expenses |
| 7.2 | Society bank account balance | ⭐ | M | 🔲 | Running balance with transactions |
| 7.3 | Expense categories | ⭐ | M | 🔲 | Lift, generator, cleaning, security |
| 7.4 | Monthly financial report | ⭐ | L | 🔲 | PDF report for committee |
| 7.5 | Vendor payments tracking | ⭐ | M | 🔲 | Security agency, housekeeping bills |
| 7.6 | Audit trail for all transactions | ⭐ | M | 🔲 | Who approved, when, how much |
| 7.7 | Budget planning (annual) | 💡 | L | 🔲 | Set budget per category |
| 7.8 | GST / tax compliance reports | 💡 | XL | 🔲 | For registered societies |
| 7.9 | Balance sheet export (Excel/PDF) | 💡 | L | 🔲 | For AGM meetings |
| 7.10 | Sinking fund management | 💡 | L | 🔲 | Long-term maintenance fund |

---

## 🧰 Technical & Platform Ideas

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| T1 | Offline support (guard entry without internet) | 🔥 | L | 🔲 | SQLite/Drift queue, sync on reconnect |
| T2 | App icon + splash screen | 🔥 | S | 🔲 | GateFlow branding |
| T3 | Firebase security rules audit | 🔥 | S | 🔲 | Lock down all collections |
| T4 | Biometric login (fingerprint) | ⭐ | M | 🔲 | Replace PIN with fingerprint |
| T5 | Multi-society support | ⭐ | XL | 🔲 | One app, multiple societies |
| T6 | iOS version | 💡 | XL | 🔲 | Phase 2 after Android validated |
| T7 | Web dashboard for admin | 💡 | XL | 🔲 | Flutter Web or React |
| T8 | Dark mode | 💡 | S | 🔲 | ThemeData dark mode |
| T9 | Hindi / regional language support | 💡 | L | 🔲 | flutter_localizations |
| T10 | Performance audit (cold start < 3s) | ⭐ | S | 🔲 | Profile mode testing |

---

## 🎉 Event Fund Manager (NEW)

> Track collections + expenses for society events like Ganesh Chaturthi, Diwali, Holi etc.
> All residents see real-time dashboard. Admin manages funds. Notifications for pooja/prasad.

| # | Feature | Priority | Effort | Status | Notes |
|---|---|---|---|---|---|
| EF1 | Create Event (admin) | 🔥 | S | 🔲 | Name, target amount, date range, description |
| EF2 | Contribution tracking per flat | 🔥 | M | 🔲 | Admin marks who paid + amount |
| EF3 | Real-time fund dashboard (all residents) | 🔥 | M | 🔲 | Total collected, total spent, balance |
| EF4 | Expense logging (admin) | 🔥 | M | 🔲 | Item, amount, category, receipt photo |
| EF5 | Resident contribution status | 🔥 | S | 🔲 | Each resident sees if they've paid |
| EF6 | Event notifications (pooja/prasad alerts) | 🔥 | M | 🔲 | "Ganesh pooja at 6PM today — all are invited!" |
| EF7 | Expense breakdown chart | ⭐ | M | 🔲 | Decorations, food, priest, misc |
| EF8 | Payment reminder to non-contributors | ⭐ | S | 🔲 | Admin sends reminder to pending flats |
| EF9 | Multiple events support | ⭐ | S | 🔲 | Ganesh Chaturthi, Diwali, Holi etc. |
| EF10 | Event photo gallery | ⭐ | M | 🔲 | Upload celebration photos |
| EF11 | Final event settlement report (PDF) | 💡 | M | 🔲 | Downloadable summary after event |
| EF12 | Online payment for contribution (UPI) | 💡 | XL | 🔲 | Razorpay integration — Phase 2 |

---

## 📝 Raw Ideas Inbox
> Quick capture — unfiltered ideas, refined later

- _Tell Claude "Add idea: [your idea]" anytime!_

---

## 📊 Summary

| Category | Total Features | Done | In Progress | Remaining |
|---|---|---|---|---|
| 1. Security & Gate Management | 20 | 5 | 0 | 15 |
| 2. Staff & Facility Management | 11 | 0 | 0 | 11 |
| 3. Communication & Notices | 10 | 0 | 0 | 10 |
| 4. Community Helpdesk | 10 | 0 | 0 | 10 |
| 5. Clubhouse & Amenities | 10 | 0 | 0 | 10 |
| 6. Billing & Payments | 10 | 0 | 0 | 10 |
| 7. Apartment Accounting | 10 | 0 | 0 | 10 |
| Technical | 10 | 0 | 0 | 10 |
| **TOTAL** | **91** | **5** | **0** | **86** |

---

*Last updated: 2026-06-14 | Tell Claude "Add idea: [your idea]" to capture instantly*
