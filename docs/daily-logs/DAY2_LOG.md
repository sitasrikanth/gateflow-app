# GateFlow — Day 2 Log
**Date:** 8th June 2026
**Session Duration:** ~2 hours
**Status:** ✅ Completed Successfully

---

## 🎯 Goals for Day 2
- Install Cursor IDE
- Create Firebase project
- Connect Firebase to Flutter
- Run GateFlow app with Firebase initialized

---

## ✅ What We Accomplished

### 1. Installed Cursor IDE
- Downloaded **Cursor v3.7** (Windows x64 User installer)
- Opened gateflow project via **File → Open Folder**
- Accessed files via **View → Files (Ctrl+G)**
- Note: This version of Cursor is agent-first (no Extensions panel like VS Code)

### 2. Created Firebase Project
- Project name: **gateflow**
- Project ID: **gateflow-ss**
- Region: **asia-south1** (Mumbai)
- Disabled Google Analytics (not needed for MVP)

**Services enabled:**
| Service | Status |
|---|---|
| Authentication (Phone) | ✅ Enabled |
| Firestore Database | ✅ Created (test mode, asia-south1) |
| Storage | ⏭️ Skipped (requires paid plan — will add in Week 3) |
| Cloud Messaging | ✅ Default enabled |

### 3. Installed Firebase CLI
**Why needed:** FlutterFire CLI requires Firebase CLI to be installed first

```powershell
npm install -g firebase-tools
```
- Installed successfully with Node.js (already on machine)
- Logged in: **sitasrikanth@gmail.com**

### 4. Installed FlutterFire CLI
```powershell
D:\srikanth-sita-app\flutter\bin\dart.bat pub global activate flutterfire_cli
```
- Installed: **flutterfire_cli 1.4.0**
- Added `C:\Users\Home\AppData\Local\Pub\Cache\bin` to System PATH

### 5. Connected Firebase to Flutter
```powershell
flutterfire configure
```
- Selected project: **gateflow-ss**
- Platform: Android (+ ios, macos, web, windows auto-registered)
- Generated: **lib/firebase_options.dart** ✅

**Firebase App IDs registered:**
| Platform | App ID |
|---|---|
| Android | 1:862953136740:android:8483d020de370fc7ab7571 |
| iOS | 1:862953136740:ios:4921ff4a802608d2ab7571 |
| Web | 1:862953136740:web:8fddd4c5a0a65cefab7571 |

### 6. Installed Firebase Flutter Packages
```powershell
flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging
```

**Packages installed:**
| Package | Version |
|---|---|
| firebase_core | 4.10.0 |
| firebase_auth | 6.5.2 |
| cloud_firestore | 6.5.0 |
| firebase_messaging | 16.3.0 |

### 7. Updated main.dart with Firebase Initialization
Replaced default Flutter demo code with:
- Firebase initialization (`await Firebase.initializeApp()`)
- GateFlow branded splash screen
- Blue background (#1A73E8)
- App icon, title, tagline
- "Firebase Connected ✓" confirmation

### 8. Ran App Successfully on Phone
- Device: **Honor ELN W09**
- GateFlow blue splash screen showing ✅
- Firebase initialized successfully ✅
- Hot reload working (`r` key) ✅
- Checkmark icon showing "Firebase Connected ✓" ✅

---

## 🛠️ Tools Used Today
| Tool | Purpose | Status |
|---|---|---|
| Cursor IDE v3.7 | Code editor | ✅ Installed |
| Firebase Console | Backend setup | ✅ Project created |
| Firebase CLI | CLI tool for Firebase | ✅ Installed |
| FlutterFire CLI | Connect Firebase to Flutter | ✅ Configured |
| Node.js / npm | Required for Firebase CLI | ✅ Already installed |
| PowerShell | Running commands | ✅ |
| Honor ELN W09 | Test device | ✅ App running |

---

## ⚠️ Issues Faced & How We Fixed Them

| Issue | Cause | Fix |
|---|---|---|
| Cursor has no Extensions panel | New agent-first Cursor v3.7 | Not needed — Cursor AI understands Flutter natively |
| FlutterFire CLI not found after install | PATH not updated | Added `C:\Users\Home\AppData\Local\Pub\Cache\bin` to PATH |
| `flutterfire configure` failed first time | Firebase CLI not installed | Installed Firebase CLI via `npm install -g firebase-tools` |
| Firebase Storage requires paid plan | Recent Firebase policy change | Skipped Storage — will add in Week 3 when needed |
| Loading spinner never stopped | No navigation logic yet | Replaced with checkmark icon as placeholder |

---

## 📁 New Files Created Today
```
D:\srikanth-sita-app\gateflow\
├── lib\
│   ├── firebase_options.dart    ← NEW — Firebase config (auto-generated)
│   └── main.dart                ← UPDATED — Firebase initialized
└── pubspec.yaml                 ← UPDATED — 4 Firebase packages added
```

---

## 🔑 Key Info to Remember
| Item | Value |
|---|---|
| Firebase Project ID | gateflow-ss |
| Firebase Console | console.firebase.google.com/project/gateflow-ss |
| Firebase Account | sitasrikanth@gmail.com |
| Firestore Region | asia-south1 (Mumbai) |
| Android App ID | 1:862953136740:android:8483d020de370fc7ab7571 |

---

## 📋 Day 3 — What's Next
- [ ] Build Phone Login screen (OTP authentication)
- [ ] Build OTP Verification screen
- [ ] Build Profile Setup screen (name, flat, tower, role)
- [ ] Test full auth flow on real device
- [ ] Save user profile to Firestore

---

## 💡 Lessons Learned
1. **Always install Firebase CLI before FlutterFire CLI**
2. **Firebase Storage now requires Blaze (paid) plan — skip for MVP**
3. **Cursor v3.7 is agent-first — use Ctrl+G for file explorer**
4. **Hot reload (`r`) is instant — use it constantly while building**
5. **`flutterfire configure` does everything automatically — don't manually edit Firebase config**

---

*Log written by Claude | Day 2 of 12-Week GateFlow Build Journey*
