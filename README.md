# Mobile VMS

Mobile Visitor Management System untuk Android berbasis Flutter dan terintegrasi dengan backend Frappe/ERPNext `visitor_management`.

## Fitur Utama

### Security
- Dashboard security
- Scan check-in visitor
- Scan check-out visitor
- Manual input Visitor ID
- Visitor aktif di area
- Pending approval
- Riwayat visitor

### Karyawan
- QR / barcode karyawan
- Pending visitor approval
- Approve visitor
- Reject visitor
- Complete visitor
- Notifikasi visitor masuk

### Admin / Manager
- Dashboard summary
- Monitoring gate
- Laporan visitor
- Statistik status visitor

## Struktur

```text
lib/
  main.dart
  app.dart
  config/
  models/
  services/
  screens/
  widgets/
```

## Setup

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --release
```

Output APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Konfigurasi API

Edit file:

```text
lib/config/app_config.dart
```

Isi `baseUrl` dengan alamat server Frappe Anda.

Contoh:

```dart
static const String baseUrl = 'https://your-frappe-site.com';
```

## Catatan

Project ini adalah mobile client. Backend tetap berada di repo `visitor_management`.

## Architecture Proposal

See detailed production architecture: `docs/flutter_vms_architecture.md`.
