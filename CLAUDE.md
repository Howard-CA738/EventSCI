# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EventSCI** — Flutter mobile app for managing academic events at UPeU (Universidad Peruana Unión). It supports QR-based attendance, jury evaluations, certificate generation, Excel/PDF reports, and role-based dashboards. Targets Android and iOS (also has a web build). Package ID: `com.eventsci.eventos`.

## Commands

```bash
# Run on connected device
flutter run

# Build Android APK (release)
flutter build apk --release

# Build iOS (release)
flutter build ios --release

# Build web
flutter build web

# Analyze / lint
flutter analyze

# Run tests
flutter test

# Regenerate launcher icons
flutter pub run flutter_launcher_icons

# Regenerate native splash
flutter pub run flutter_native_splash:create

# Get dependencies
flutter pub get
```

## Architecture

### Role-based routing (`lib/main.dart`)

On startup `AuthWrapper` reads `PrefsHelper.getUserType()` and routes to one of four dashboards:

| Role constant | Dashboard widget | Description |
|---|---|---|
| `superAdmin` | `AdminScreen` | Full platform admin; uses Firebase Auth email + OTP |
| `admin` | `AdminScreen` | Per-filial admin; authenticated anonymously |
| `admin_carrera` | `AdminCarreraScreen` | Per-carrera admin with granular `permisos` list |
| `jurado` | `JuradosScreen` | Jury member for evaluating projects |
| `student` | `EstudianteScreen` | Student: scan QR, view attendance, certificates |

### Session management (`lib/prefs_helper.dart`)

`PrefsHelper` is the single source of truth for local session state. It wraps `shared_preferences` and Firebase Auth:

- Non-superAdmin users authenticate via **anonymous Firebase Auth** (`reautenticarAnonimo()`). Passwords are compared against AES-CBC-encrypted values stored in Firestore.
- `ensureAuthActiva()` is called before any Firestore read that requires auth; it restores the anonymous session if the OS killed it.
- Session validity is invalidated server-side when an admin changes a user's password (`isSessionValid()` checks a token in Firestore).
- Students are subject to additional checks: payment status, device lock, session lock, account disable.

### Encryption (`lib/encryption_helper.dart`)

AES-CBC (256-bit key, 128-bit IV) used to encrypt DNI and passwords before storing them in Firestore. Key and IV are hardcoded constants in `EncryptionHelper`. Passwords are verified by encrypting the input and comparing.

### Firestore data model (inferred)

Collections accessed by the app:

- `superadmins/{uid}` — SuperAdmin profile
- `filiales/{filialId}/admins/`, `/estudiantes/`, `/jurados/` — per-filial data
- `filiales/{filialId}/carreras/{carreraId}/…` — carrera-scoped students, events, evaluations
- `admin_carrera/` — AdminCarrera accounts
- Events, grupos, proyectos, rubricas, criterios, asistencias, certificados — nested under filial/carrera

### Key services

- `lib/Admin_Carrera/admin_carrera_service.dart` — login and CRUD for AdminCarrera role
- `lib/Admin_Carrera/codigo_asistencia_service.dart` — QR attendance codes
- `lib/Admin_Carrera/nota_docente_service.dart` — teacher grade import
- `lib/resolver_nombres_service.dart` — resolves filial/faculty/carrera names from IDs
- `lib/jurado_security_service.dart` / `lib/student_security_service.dart` — device-binding and session-lock logic
- `lib/super_admin_login.dart` — Firebase Auth login + EmailJS OTP for SuperAdmin

### Directory layout

```
lib/
  main.dart              # App entry, deep-link handling, AuthWrapper
  login.dart             # Login screen (all roles)
  prefs_helper.dart      # Session state, role detection, login helpers
  encryption_helper.dart # AES password/DNI encryption
  firebase_options.dart  # FlutterFire generated config (do not edit)
  Admin/
    Logica/              # Business logic + screens for SuperAdmin/Admin
    Interfaz/            # Pure UI screens for admin
  Admin_Carrera/
    interfaz/            # AdminCarreraScreen dashboard
    *.dart               # Feature screens for carrera-level admin
  Usuarios/
    Logica/              # Student business logic and screens
    Interfaz/            # Student UI screens
  Jurados/               # Jury dashboard and certificate tab
assets/
  icons/                 # PNG menu icons
  images/                # Backgrounds, logos, splash
  fonts/                 # Montserrat, Cinzel, GreatVibes
  plantilla_informe.docx # Word template for reports
  plantilla_certificado.png
```

## Important notes

- **Deep links**: scheme `myapp://asistencia?data=…` for QR-based attendance. The `data` param is URL-encoded JSON. Handled in `_MyAppState._handleDeepLink()`.
- **Firebase App Check**: enabled in release builds (Play Integrity on Android, DeviceCheck on iOS). Debug providers are used in `kDebugMode`.
- **AdminCarrera permissions** (`permisos` list): controls which menu items appear in `AdminCarreraScreen`. Feature screens check this list before rendering.
- **Locale**: fixed to `es_ES`. Date formatting uses `intl`.
- **File operations**: Excel export uses `excel` package; PDF via `pdf`+`printing`; Word reports via `xml` + `archive` (docx manipulation); files are shared via `share_plus` or opened with `open_filex`.
