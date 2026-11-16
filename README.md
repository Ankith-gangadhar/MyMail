# MyMail — Secure Offline-First Email Vault

[![Flutter](https://img.shields.io/badge/Flutter-3.44.8-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.2-blue.svg)](https://dart.dev)
[![Security](https://img.shields.io/badge/Security-AES--256--GCM-green.svg)](https://en.wikipedia.org/wiki/Galois/Counter_Mode)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**MyMail** is a privacy-first, offline-first Android vault for storing email accounts and passwords organized by categories. Inspired by the clean, ergonomic interface of **Zoho OneAuth**, MyMail is modernized with Material 3, rounded cards, soft shadows, fluid animations, and automatic dark/light theme switching.

---

## 📸 Key Features

- **Zoho OneAuth Inspired Layout**:
  - High-readability card design with primary email line and secondary category/tag.
  - Passwords masked as dots (`••••••••••••`) by default.
  - Quick-reveal eye icon with **10-second automatic re-masking**.
  - One-tap clipboard copy with **30-second automated clipboard clearing** to prevent leaks.
  - Floating `+` action button with built-in **Strong Password Generator**.
  - Real-time search filter by email or label within each category.

- **Category Organization**:
  - Default categories: **Work** (default entry screen) and **Personal**.
  - **Personal** is placed securely at the end of the category bar with a dedicated lock indicator.
  - Create, rename, reorder (drag & drop), and delete custom categories.
  - Independent per-category lock toggle.
  - Deleting any category requires confirmation **plus device authentication**.

- **Military-Grade Security**:
  - **AES-256-GCM** authenticated encryption for all stored credentials.
  - Master encryption key stored in **Android Keystore** via `flutter_secure_storage`.
  - **FLAG_SECURE** enabled at the native Android activity level: completely blocks screenshots, screen recording, and blacks out recent-apps previews.
  - **Local Authentication** (`local_auth`): Fingerprint, Face unlock, or device PIN/pattern/password fallback.
  - Enforces device lock setup: If no PIN/passcode is set on the device, the vault refuses to open.
  - Configurable auto-lock inactivity timeout: **Immediate**, **1 Minute (Default)**, or **5 Minutes**.
  - **100% Offline Vault**: Zero `INTERNET` permission in `AndroidManifest.xml`.
  - Android cloud backup disabled (`android:allowBackup="false"`).

- **Encrypted Backup & Restore**:
  - Full vault export encrypted using **PBKDF2** (100,000 iterations, HMAC-SHA256, 16-byte random salt) + **AES-256-GCM**.
  - Restore with passphrase verification and user choice between **Merge** or **Replace Everything**.
  - Personal accounts are safely included in encrypted JSON backups.

- **Excel Category Sharing**:
  - Export category accounts to `.xlsx` spreadsheet for team/colleague handover.
  - **Strictly disabled for Personal accounts**.
  - Requires fresh device authentication and displays a clear plaintext warning dialog before exporting.
  - Shared via Android share sheet and automatically purges temporary export files.

---

## 🏗️ Architecture & Folder Structure

Built using Clean Architecture principles with state management powered by **Riverpod 3.x**:

```
lib/
├── core/
│   ├── crypto/
│   │   ├── aes_gcm_service.dart          # AES-256-GCM encryption & key management
│   │   └── backup_crypto_service.dart   # PBKDF2 (100k) + AES-GCM backup envelope
│   ├── security/
│   │   ├── biometric_service.dart       # local_auth wrapper with PIN fallback
│   │   ├── clipboard_service.dart       # Clipboard copy with 30s auto-purge
│   │   └── key_storage_service.dart     # Android Keystore secure storage
│   └── theme/
│       └── app_theme.dart               # Material 3 light & dark themes
├── data/
│   ├── datasources/
│   │   ├── export_import_service.dart   # Excel generation & backup handler
│   │   └── local_database.dart          # SQLite database with encrypted rows
│   └── repositories/
│       └── vault_repository_impl.dart   # Repository implementation
├── domain/
│   ├── entities/
│   │   ├── category_entity.dart         # Category domain model (UUID, soft-delete)
│   │   └── credential_entity.dart       # Credential model (UUID, timestamps)
│   └── repositories/
│       └── vault_repository.dart        # Abstract repository contract
├── presentation/
│   ├── providers/
│   │   └── vault_providers.dart         # Riverpod notifiers & state management
│   ├── screens/
│   │   ├── auth_guard_screen.dart       # Device security & lock screen
│   │   ├── category_management_dialog.dart # Category reorder/add/delete
│   │   ├── credential_form_sheet.dart   # Add/Edit account sheet
│   │   ├── home_screen.dart             # Main screen with account cards
│   │   └── settings_screen.dart         # Timeout, backup & restore
│   └── widgets/
│       ├── category_chip_bar.dart       # Chips with Work first & Personal locked
│       ├── credential_card.dart         # Zoho OneAuth card with auto-masking
│       └── search_bar_widget.dart       # Search bar filter
└── main.dart                            # Application entry point
```

---

## 🔒 Security Design Deep-Dive

1. **At-Rest Encryption**:
   - Every email, password, and optional label is encrypted with an isolated 96-bit cryptographic nonce and AES-256-GCM.
   - Decryption occurs only in transient memory when rendering the active card.
   - SQLite tables store only ciphertexts, nonces, and authentication tags.

2. **Android Keystore Isolation**:
   - The master 256-bit AES key is generated on the device's hardware security module (HSM) on first startup and saved in `FlutterSecureStorage` using `AndroidOptions(resetOnError: true)`.

3. **Screen Capture & Recents Protection**:
   - `MainActivity.kt` executes:
     ```kotlin
     window.setFlags(
         WindowManager.LayoutParams.FLAG_SECURE,
         WindowManager.LayoutParams.FLAG_SECURE
     )
     ```
   - Prevents screenshot utilities, screen mirroring/recording, and blanks out the thumbnail in the Android Recent Apps switcher.

4. **Biometric & Credential Gate**:
   - Built on `FlutterFragmentActivity` and `local_auth`.
   - Supports fingerprint sensors, face unlock, and device PIN/pattern fallback.
   - Prevents access if the user has disabled lock screen security on their phone.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.24+ (Dart 3.5+)
- Android SDK 24+ (Android 7.0 Nougat or higher)
- Android Studio or VS Code with Flutter extension

### Run locally
```bash
# Clone the repository
git clone https://github.com/Ankith-gangadhar/MyMail.git
cd MyMail

# Get dependencies
flutter pub get

# Run unit tests
flutter test

# Launch on connected Android device
flutter run
```

---

## 📦 Building a Release APK / AAB

### Build Instant Release APK (Debug Signed)
```bash
flutter build apk --release
```
The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### Custom Release Signing (Play Store / Distribution)

1. **Generate an upload keystore**:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Create `android/key.properties`**:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

3. **Build Android App Bundle (AAB)**:
   ```bash
   flutter build appbundle --release
   ```

---

## 🧪 Unit Tests

Run the full test suite covering encryption round-trips, PBKDF2 backup envelopes, wrong passphrase rejections, and repository contracts:

```bash
flutter test
```

Test files:
- `test/crypto_unit_test.dart`
- `test/backup_restore_unit_test.dart`
- `test/repository_unit_test.dart`
- `test/widget_test.dart`
