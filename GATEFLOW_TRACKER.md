# GateFlow — Project Tracker

> Community Management App (MyGate/NoBroker Hood alternative for Indian gated communities)
> Developer: Srikanth Sita | GitHub: github.com/sitasrikanth/gateflow-app

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Auth | Firebase Phone OTP + SharedPreferences (guard sessions) |
| Database | Cloud Firestore (real-time) |
| Notifications | Firestore StreamBuilder (in-app) → FCM planned |
| Storage | SharedPreferences (PIN, guard session) |
| Hosting | Firebase |

---

## ⚙️ Dev Setup

```powershell
# MUST run before every flutter run session (cross-drive fix)
$env:PUB_CACHE = "D:\pub-cache"
cd D:\srikanth-sita-app\gateflow
flutter run --no-pub
```

- **Test phone:** `9999999999` | **OTP:** `123456`
- **Guard quick code:** `123456` (Ravi Kumar in Firestore)
- **SHA-1:** `51:3C:8E:BC:43:CA:CA:10:23:11:32:4A:80:AD:E2:A4:95:F7:3A:61`
- **Firebase project:** `gateflow-ss`

---

## 👥 User Roles

| Role | Login Method | Status on Register |
|---|---|---|
| Resident | Phone OTP → 4-digit PIN | `pending` (needs admin approval) |
| Admin | Phone OTP → 4-digit PIN | `active` (auto-approved) |
| Guard | 6-digit Quick Code | Session in SharedPreferences |

---

## 📁 Key Files

```
lib/
├── main.dart                          # AuthWrapper + role-based routing
├── firebase_options.dart              # Firebase config
└── screens/
    ├── auth/
    │   ├── login_screen.dart          # 2-tab login (Resident/Admin | Guard)
    │   ├── otp_screen.dart            # OTP verification
    │   ├── profile_setup_screen.dart  # Name, flat, role selection
    │   ├── pin_setup_screen.dart      # 4-digit PIN setup
    │   ├── pin_entry_screen.dart      # PIN entry for returning users
    │   └── pending_approval_screen.dart # Waiting for admin approval
    ├── guard/
    │   ├── guard_home_screen.dart     # Shift mgmt + visitor log
    │   └── new_visitor_screen.dart    # Log new visitor form
    ├── resident/
    │   └── resident_home_screen.dart  # Visitor alerts + history
    └── admin/
        └── admin_home_screen.dart     # Approve residents, manage guards
```

---

## 🗄 Firestore Collections

### `users/{uid}`
```
name, phone, flatNumber, role (resident/admin), status (pending/active/inactive),
permissions[], createdAt
```

### `guards/{guardId}`
```
name, phone, quickCode, status (active/inactive), createdAt
```

### `guards/{guardId}/shifts/{shiftId}`
```
startTime, endTime, breaks: [{startTime, endTime}], guardName
```

### `visitors/{visitorId}`
```
visitorName, flatNumber, visitorPhone, purpose, entryTime,
status (pending/approved/denied/entered), loggedBy (guardId)
```

---

## ✅ Completed Features

| Day | Feature |
|---|---|
| Day 1-2 | Project setup, Firebase integration |
| Day 3 | Phone OTP login, profile setup, Firestore save |
| Day 4 | Guard Dashboard + visitor entry form |
| Day 6 | Resident Home Screen + role-based routing |
| Day 7 | 2-tab login, PIN system, guard quick code, pending approval |
| Day 8 | Guard Home with shift management (Start/End Shift, Break, timer) |
| Day 8 | Admin Panel (approve residents, add guards, generate codes, visitor log) |
| Day 9 | Real-time visitor notification — resident approve/deny at gate |

---

## 🔜 Pending Features

| Priority | Feature | Notes |
|---|---|---|
| 🔥 High | FCM Push Notifications | Alerts when app is closed/background |
| 🔥 High | Pre-approved Guest OTP | Resident generates code for expected visitor |
| ⭐ Medium | Emergency SOS | Panic button → instant guard alert |
| ⭐ Medium | Parking Management | Visitor parking entry + vacancy |
| 📋 Low | Guard Patrol Tracking | QR code checkpoints |
| 📋 Low | Staff Tracking | Maid/cook entry logs |
| 📋 Low | Move-in/Move-out Controls | Admin approval for moves |
| 📋 Low | Overstay Alerts | Auto-alert if visitor stays too long |

---

## 🐛 Known Fixes & Gotchas

| Issue | Fix |
|---|---|
| Cross-drive Kotlin build error | `$env:PUB_CACHE = "D:\pub-cache"` + `kotlin.incremental=false` |
| Gradle daemon crash | `cd android; .\gradlew.bat --stop` then re-run |
| Firestore composite index missing | Click auto-generated URL in console logs |
| mitmproxy blocking Firestore | `adb shell settings put global http_proxy :0` |
| PIN session persisting after close | Reset `pin_verified_session=false` in main() |
| Guard routed to resident screen | Fixed AuthWrapper to check guard session before Firebase Auth |

---

## 🟩 GitHub Commit Log

| Commit | Description |
|---|---|
| Day 7 | 2-tab login, PIN system, guard quick code, pending approval |
| Day 8 | Guard Home with shift management |
| Day 8 | Admin Panel with resident approval, guard management |
| Day 9 | Real-time visitor notification — resident approve/deny |

---

*Updated: 2026-06-14*
