# Nari Suraksha — Women Safety & Emergency Response System

A production-grade Flutter Android application for women's safety, featuring intelligent SOS escalation, emergency contacts management, Voice SOS, and a fully offline emergency support system.

---

## Features

| Feature | Description |
|---|---|
| **SOS Button** | One-tap emergency trigger with GPS location |
| **Voice SOS** | "Help me", "bachao", "emergency" keyword detection |
| **Auto-Escalation** | T=0 (High), T=4m (Medium), T=8m (Low), T=12m (Police) |
| **Emergency SMS** | Native Android SmsManager — no internet needed |
| **Contact Management** | Up to 5 tiered emergency contacts (High/Medium/Low) |
| **SOS History** | Record of all past SOS events |
| **Persistent Login** | Firebase Auth — stays logged in after phone restart |
| **Offline Emergency** | Full SOS trigger works without internet (see below) |

---

## 🔴 OFFLINE EMERGENCY SUPPORT

> **What works offline (no internet required)**

| Capability | Works Offline? | Notes |
|---|---|---|
| SOS trigger (button) | ✅ YES | Saved to local SQLite DB |
| GPS location acquisition | ✅ YES | Geolocator uses hardware GPS |
| Emergency SMS dispatch | ✅ YES | Native Android SmsManager via cellular |
| Contact lookup for SMS | ✅ YES | Contacts cached in local SQLite DB |
| SOS escalation timers | ✅ YES | Pure Dart timers, no Firebase |
| SOS session resume after restart | ✅ YES | Local DB checked first |
| SOS history (viewing past events) | ✅ YES (cached) | Shows local DB records |
| Voice SOS trigger | ✅ YES* | *On-device STT (Android 10+), Google cloud STT otherwise |

> **What requires internet**

| Capability | Requires Internet? | Notes |
|---|---|---|
| Firestore SOS history upload | ✅ YES | Auto-synced when connectivity returns |
| Real-time contact sync | ✅ YES | Local cache used when offline |
| Firebase Auth initial login | ✅ YES | Session persists locally after first login |
| Activity feed / Recent Alerts | ✅ YES | Falls back to empty when offline |

> **Sync behavior**

When the device goes back online:
1. `SyncService` automatically runs on `OFFLINE→ONLINE` transition
2. All pending SOS records are uploaded to Firestore (deduplication guaranteed via stable UUID)
3. Emergency contacts are refreshed from Firestore → local cache

> **Limitations**

- This app is **NOT fully offline**. Firebase Auth, Firestore, and cloud features require internet.
- Voice SOS may use Google Cloud STT on devices running Android < 10 — requires internet for speech recognition on those devices.
- Shared location links in SMS messages point to Google Maps — recipients need internet to view the map.
- NEVER automatically calls 112 — police call requires explicit user authorization.

---

## Architecture

```
lib/
├── core/
│   ├── services/          # ConnectivityService, LocationService, SmsService
│   ├── theme/             # AppColors, AppTextStyles
│   └── widgets/           # OfflineBanner, shared widgets
├── features/
│   ├── auth/              # Login, Registration
│   ├── dashboard/         # Home screen, Recent Alerts
│   ├── sos/               # SOS trigger UI
│   ├── emergency_contacts # Contact management
│   ├── profile/           # User profile
│   └── splash/            # Splash + persistent login
├── local_db/              # Drift/SQLite tables + AppDatabase
├── models/                # Firestore model classes
├── providers/             # ConnectivityProvider, SosEscalationProvider, etc.
├── repositories/          # Firestore + Local SQLite repositories
└── services/              # SyncService
```

```
android/
└── app/src/main/kotlin/com/narisuraksha/
    ├── MainActivity.kt      # Platform channel host
    └── SmsSenderHelper.kt   # Native SmsManager integration
```

---

## Setup

1. Clone the repository
2. Place `android/app/google-services.json` (from Firebase Console)
3. Run `flutterfire configure`
4. Run `flutter pub get`
5. Run `dart run build_runner build` (generates Drift code)
6. Run `flutter run`

---

## Running Tests

```bash
flutter test
flutter analyze
```

---

## SMS Permissions

The app requires `SEND_SMS` permission. This is requested at SOS trigger time.
SMS is sent via native Android `SmsManager` — it uses cellular network, not internet.
