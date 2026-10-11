# Nari Suraksha — Women Safety & Emergency Response System

**Nari Suraksha** is a Flutter-based Android application designed to support women's safety through emergency SOS alerts, priority-based escalation, emergency contact management, voice-triggered SOS, GPS location sharing, and offline emergency support.

The application combines **Flutter, Firebase, local SQLite storage, and native Android services** to help users initiate emergency alerts even when an internet connection is unavailable.

> **Platform:** Android  
> **Frontend:** Flutter / Dart  
> **Cloud Backend:** Firebase Authentication and Cloud Firestore  
> **Local Database:** Drift with SQLite  
> **Native Integration:** Kotlin and Android `SmsManager`

---

## Table of Contents

- [Key Features](#key-features)
- [Emergency SOS Workflow](#emergency-sos-workflow)
- [Priority-Based SOS Escalation](#priority-based-sos-escalation)
- [Offline Emergency Support](#offline-emergency-support)
- [System Architecture](#system-architecture)
- [Technology Stack](#technology-stack)
- [Database Design](#database-design)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation and Setup](#installation-and-setup)
- [Permissions](#permissions)
- [Testing](#testing)
- [Limitations](#limitations)
- [Future Enhancements](#future-enhancements)
- [Disclaimer](#disclaimer)

---

## Key Features

| Feature | Description |
|---|---|
| **Emergency SOS** | Initiates an emergency session and starts the configured alert workflow. |
| **Voice SOS** | Detects configured emergency phrases, such as "Help me," "Bachao," and "Emergency," when speech recognition is available. |
| **Priority-Based Escalation** | Sends alerts to emergency contacts according to predefined priority levels and time intervals. |
| **Emergency SMS** | Uses native Android `SmsManager` to send SMS messages through the cellular network. |
| **Emergency Contact Management** | Stores emergency contacts and organizes them into High, Medium, and Low priority groups. |
| **GPS Location Sharing** | Retrieves the device's current location and supports sharing it through a Google Maps link. |
| **SOS History** | Maintains records of previous emergency sessions, with locally cached records available offline. |
| **Persistent Login** | Uses Firebase Authentication to maintain the user's authentication session across app restarts. |
| **Offline Emergency Support** | Uses local SQLite storage, cached contacts, GPS, and native SMS capabilities for supported emergency operations without internet access. |
| **Cloud Synchronization** | Synchronizes eligible pending local records with Cloud Firestore when connectivity returns. |
| **User Profile and Medical Information** | Supports the storage of user profile and medical information. |
| **Recent Alerts** | Provides access to recent application alerts when the required data is available. |

---

## Emergency SOS Workflow

The application follows a predefined workflow when an emergency is triggered.

1. **SOS activation:** The user activates the SOS feature through a supported trigger.
2. **Session validation:** The application checks whether an unresolved SOS session already exists to avoid creating duplicate sessions.
3. **Location retrieval:** The application requests the device's current GPS location, subject to permissions and GPS availability.
4. **Contact retrieval:** Emergency contacts are obtained from the available local cache or cloud data.
5. **Initial alert:** The application sends the configured emergency SMS to the appropriate high-priority contacts.
6. **Local and cloud records:** The SOS session is stored locally for offline availability and persisted to Firestore when connectivity permits.
7. **Escalation:** The application follows its configured timeline to notify the next priority groups if the emergency remains unresolved.
8. **Resolution:** The user can indicate that they are safe or choose an available emergency action.

### SOS Escalation Timeline

| Time | Stage | Action |
|---|---|---|
| T = 0 | High Priority | Sends the initial emergency alert to high-priority contacts. |
| T = 4 minutes | Medium Priority | Prompts the user to confirm their safety; continues escalation if required. |
| T = 8 minutes | Low Priority | Repeats the safety confirmation flow and escalates if the emergency remains unresolved. |
| T = 12 minutes | Emergency Escalation | Presents the configured emergency action, including an option to call 112. |

The escalation workflow is implemented using application-side logic and timers. It is **rule-based, not an AI or machine-learning system**.

**Important:** The application does not automatically call 112. The user must explicitly choose the call action.

---

## Offline Emergency Support

Nari Suraksha is designed to support essential emergency operations when the device has no internet connection, provided that the required permissions, cached data, device hardware, and cellular services are available.

### What works offline?

| Capability | Offline Support | Details |
|---|---|---|
| SOS activation | Yes | Can create or resume a supported local SOS session. |
| GPS location acquisition | Yes, when available | GPS can obtain coordinates without mobile internet, although a location fix may take longer or fail indoors. |
| Emergency SMS | Yes, when cellular service is available | Native Android SMS functionality uses the cellular network rather than mobile data. |
| Emergency contact lookup | Yes, for cached contacts | Previously saved contacts can be retrieved from local storage. |
| SOS escalation | Supported | Application-side timers can operate without Firebase connectivity while the app process remains active. |
| SOS session recovery | Supported | The application checks locally persisted session information during recovery. |
| SOS history | Yes, for cached records | Locally stored records can be displayed offline. |
| Voice SOS | Device-dependent | Depends on the speech-recognition implementation and whether an offline recognition service is available. |

### What requires internet?

| Capability | Internet Requirement |
|---|---|
| Initial Firebase authentication | Requires connectivity. |
| Firestore cloud synchronization | Requires connectivity. |
| Refreshing emergency contacts from Firestore | Requires connectivity; cached contacts can be used offline. |
| Uploading pending SOS records | Requires connectivity. |
| Cloud-backed recent alerts | Requires connectivity when the relevant data is not cached. |
| Opening online map content | Generally requires connectivity on the receiving device. |

An existing Firebase Authentication session may remain available locally after a successful login. However, access to cloud data and operations still depends on connectivity.

### Synchronization workflow

When connectivity is restored:

1. `SyncService` detects or responds to the offline-to-online transition.
2. Eligible pending SOS records are uploaded to Cloud Firestore.
3. Stable record identifiers, such as UUIDs, can be used to prevent duplicate records during synchronization.
4. Emergency contacts are refreshed from Firestore and the local cache is updated.

The exact synchronization behavior depends on the application's repository and sync implementation.

### Offline Architecture

```text
                  SOS Trigger
                       |
                       v
              Check Local Session
                       |
                       v
              Retrieve Local Data
                       |
             +---------+---------+
             |                   |
             v                   v
        GPS Location       Cached Contacts
             |                   |
             +---------+---------+
                       |
                       v
                Prepare SOS Alert
                       |
                       v
              Native Android SMS
                       |
                       v
               Save Local Record
                       |
                       v
              Internet Available?
                       |
                       v
                  SyncService
                       |
                       v
                Cloud Firestore
```

**Note:** Offline support does not guarantee message delivery. SMS delivery depends on SIM availability, cellular coverage, device permissions, and carrier service. Timers and voice recognition may also be affected by Android background-execution restrictions and device configuration.

---

## System Architecture

The application uses a layered architecture that separates the user interface, application logic, data access, cloud services, and native Android capabilities.

```text
                 User
                  |
                  v
          Flutter User Interface
                  |
                  v
          Providers / State
             Management
                  |
                  v
        Application / SOS Logic
                  |
                  v
       Repositories and Services
             /           \
            /             \
           v               v
   Firebase Services    Local Database
   Authentication       Drift / SQLite
   Cloud Firestore           |
           |                 |
           +--------+--------+
                    |
                    v
           Native Android APIs
             /      |      \
            v       v       v
          GPS      SMS    Speech
                   API   Recognition
```

### Architecture Components

- **Flutter UI:** Displays screens for authentication, SOS activation, emergency contacts, user profiles, and SOS history.
- **Provider / ChangeNotifier:** Manages application state and notifies the interface when relevant data changes.
- **Application Logic:** Handles SOS sessions, priority-based escalation, safety confirmations, and emergency actions.
- **Repositories:** Separate data access for cloud-backed and locally stored information.
- **Firebase Authentication:** Manages user authentication.
- **Cloud Firestore:** Stores cloud-backed user information, emergency contacts, medical information, and SOS records.
- **Drift / SQLite:** Stores supported data locally for offline access and recovery.
- **Native Android Integration:** Uses Kotlin and Android APIs for SMS and other supported device-level operations.
- **SyncService:** Coordinates synchronization of eligible local records when connectivity becomes available.

---

## Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform UI framework used to build the application interface. |
| Dart | Main programming language for the Flutter application and its business logic. |
| Provider / ChangeNotifier | Application state management. |
| Firebase Authentication | User registration and login. |
| Cloud Firestore | Cloud-based document database. |
| Drift | Dart persistence library and type-safe database layer. |
| SQLite | Local relational database for offline data. |
| Kotlin | Native Android integration. |
| Android `SmsManager` | Sends SMS through the device's cellular service. |
| GPS / Location Services | Retrieves the device's current geographical coordinates. |
| Speech Recognition | Converts recognized speech into text for emergency keyword detection. |
| Google Maps URLs | Provides a link to view shared coordinates on a map. |
| UUID | Provides stable identifiers for records and synchronization. |

---

## Database Design

Nari Suraksha uses Cloud Firestore for cloud-backed information and Drift with SQLite for supported local data.

### Cloud Firestore

The main collections include:

| Collection | Purpose |
|---|---|
| `users` | Stores user profiles and associated information. |
| `sos_history` | Stores SOS event records. |
| `activity_logs` | Stores supported application activity records. |

Emergency contacts are stored under a user's document:

```text
users/
  {userUID}/
    contacts/
      {contactId}
```

The user document may contain profile and medical information, such as name, email, blood group, allergies, medical conditions, and medications.

### Local Database

Drift provides the Dart interface for the local SQLite database.

Supported local data can include:

- Cached emergency contacts.
- Active SOS session information.
- Local SOS records and history.
- Pending records awaiting synchronization.

Only data explicitly written to the local database is available offline. Cloud Firestore data is not automatically copied into every local table; the application must implement the required caching and persistence logic.

---

## Project Structure

The following is a high-level view of the project structure. Actual file and folder names may differ depending on the current repository.

```text
nari-suraksha/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── kotlin/
│                   └── com/
│                       └── narisuraksha/
│                           ├── MainActivity.kt
│                           └── SmsSenderHelper.kt
├── lib/
│   ├── core/
│   │   ├── services/
│   │   ├── theme/
│   │   └── widgets/
│   ├── features/
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── sos/
│   │   ├── emergency_contacts/
│   │   ├── profile/
│   │   └── splash/
│   ├── local_db/
│   ├── models/
│   ├── providers/
│   ├── repositories/
│   ├── services/
│   ├── app.dart
│   └── main.dart
├── test/
├── pubspec.yaml
└── README.md
```

---

## Prerequisites

Before running the application, install and configure:

- Flutter SDK compatible with the project's dependencies.
- Dart SDK included with Flutter.
- Android Studio or another supported Flutter development environment.
- Android SDK and a compatible Android device or emulator.
- A Firebase project with Authentication and Cloud Firestore configured.
- A physical Android device with a SIM card for testing SMS functionality.

**Recommendation:** Test actual SMS dispatch on a physical Android device. An emulator may not provide the same telephony capabilities as a real device.

---

## Installation and Setup

### 1. Clone the repository

```bash
git clone <YOUR_REPOSITORY_URL>
cd <YOUR_PROJECT_DIRECTORY>
```

Replace the placeholders with your actual repository URL and directory name.

### 2. Configure Firebase

1. Create or select a project in the Firebase Console.
2. Register the Android application using its actual application ID.
3. Download the Firebase Android configuration file.
4. Place `google-services.json` at the appropriate Android application configuration path.
5. Enable Firebase Authentication providers required by the application.
6. Create a Cloud Firestore database and configure appropriate security rules.

If the project uses FlutterFire CLI, configure Firebase using:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Follow the CLI prompts and confirm that the generated configuration matches the Android application.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Generate Drift database code

If the project uses Drift code generation, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This step is necessary when generated database files are not already included or when they need to be regenerated.

### 5. Check the project

```bash
flutter doctor
flutter analyze
```

Resolve any environment or dependency issues reported by the commands.

### 6. Run the application

Connect an Android device or start an emulator, then execute:

```bash
flutter run
```

---

## Permissions

The application may require the following permissions depending on the enabled features and their implementation:

| Permission / Access | Purpose |
|---|---|
| Location access | Retrieves the device's current location. |
| SMS permission | Allows supported direct SMS dispatch through Android APIs. |
| Microphone access | Supports voice input where required. |
| Speech recognition service | Converts spoken words into text. |
| Internet access | Communicates with Firebase and other online services. |
| Network state access | Helps detect connectivity changes. |
| Notification permission | Required if the application displays notifications under Android versions that require runtime permission. |

Permissions must be declared and requested according to Android's rules and the application's actual implementation. Granting permission does not guarantee that GPS, speech recognition, or SMS will always work.

---

## Testing

Run the automated tests and static analysis:

```bash
flutter test
flutter analyze
```

### Recommended Manual Test Cases

| Test Case | Expected Result |
|---|---|
| Register a new account | Account creation follows the configured authentication flow. |
| Log in successfully | The user reaches the authenticated application interface. |
| Restart the application | The existing authentication session is restored when valid. |
| Trigger SOS online | The application starts the SOS workflow and stores eligible cloud records. |
| Trigger SOS offline | Supported local SOS functionality remains available with required permissions and cached data. |
| Test SMS dispatch | The device attempts to send the configured SMS through its cellular service. |
| Test location retrieval | The application retrieves coordinates when a location fix is available. |
| Test escalation | The configured priority stages run according to the implemented timeline. |
| Restore connectivity | Eligible pending records are synchronized with Firestore. |
| View SOS history offline | Locally stored history remains accessible. |
| Log out | The application ends the authenticated session and returns to the login flow. |

Automated tests do not replace testing on real devices, especially for SMS, GPS, background execution, speech recognition, and connectivity changes.

---

## Limitations

- The application is not completely independent of external services. Firebase cloud features require internet connectivity.
- Direct SMS depends on the device's telephony capabilities, permissions, SIM status, carrier service, and cellular coverage.
- GPS accuracy and availability depend on the device, environment, and satellite reception.
- Voice SOS depends on microphone permission and speech-recognition availability. Offline recognition support varies by device and installed recognition service.
- Background timers and tasks can be affected by Android process termination, battery optimization, and operating-system restrictions.
- Recipients generally need internet access to load online map content from a shared location link.
- Emergency contact information is only available offline if it has been saved to the local cache.
- Cloud synchronization occurs only when connectivity and the required Firebase operations are available.
- The application does not automatically place a police call to 112.

---

## Future Enhancements

Potential future improvements include:

- More reliable background SOS recovery and escalation.
- Improved on-device voice recognition for offline operation.
- Stronger synchronization retry and conflict-handling mechanisms.
- Enhanced delivery-status reporting for emergency messages.
- Additional accessibility and usability improvements.
- Expanded automated and real-device testing.
- Optional, permission-based continuous location sharing.

These are possible future enhancements and should not be interpreted as currently implemented features.

---

## Disclaimer

Nari Suraksha is a safety-support application intended to assist users in emergency situations. It cannot guarantee SMS delivery, GPS availability, network access, or a response from emergency contacts.

Users should not rely on the application as their only source of emergency assistance. When immediate danger occurs, contact the appropriate local emergency services whenever possible.

---

**Nari Suraksha — Technology for Safety, Preparedness, and Emergency Support.**
