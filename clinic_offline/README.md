# clinic_offline

Offline-only, single-user clinic app (Flutter) for iOS/iPadOS/macOS. Data is stored locally in SQLite (Drift) and the file system. Encrypted backups enable sequential device usage via AirDrop/Files.

## Setup

### iOS / iPadOS
- Minimum iOS 13+ recommended.
- Add the following to `ios/Runner/Info.plist`:
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`
  - `NSPhotoLibraryAddUsageDescription`
  - `NSFaceIDUsageDescription`

### macOS
- Add the following to `macos/Runner/Info.plist`:
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`
  - `NSPhotoLibraryAddUsageDescription`

### Permissions Notes
- Camera is required for photo capture.
- Photo Library is required for selecting images and saving thumbnails.
- Face ID / Touch ID is used for app lock and backup gating.

## Offline-only + Sequential Device Usage
- There is **no online sync**. Use the encrypted backup flow to move data between devices.
- Export generates `clinicbackup.enc` (AES-256-GCM, PBKDF2). Import validates hashes and replaces local data atomically.
- Only use one device at a time to avoid conflicting data.

## Development
```bash
flutter pub get
dart run build_runner build
flutter analyze
```

## Backup File Format
`clinicbackup.enc` is a binary file:
- Magic: `CLINICBK` (8 bytes)
- Version: `1` (1 byte)
- Iterations: uint32 big-endian (PBKDF2)
- Salt length: 1 byte
- Nonce length: 1 byte
- MAC length: 1 byte
- Salt bytes
- Nonce bytes
- MAC bytes (GCM tag)
- Ciphertext bytes (AES-256-GCM)

The decrypted payload is a zip containing:
- `db.sqlite`
- `photos/`
- `thumbs/`
- `manifest.json`