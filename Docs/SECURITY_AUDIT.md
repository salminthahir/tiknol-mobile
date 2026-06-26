# Security Audit & Mitigation Plan
## Tiknol POS — Flutter Mobile App

**Audit Date:** 2026-06-23
**Platform:** Flutter (Android)
**Backend:** Next.js API (`tiknol-reserve-web`)
**Risk Level:** HIGH — Aplikasi ini menangani transaksi keuangan nyata

---

## 1. Ringkasan Temuan

| # | Temuan | Severity | Status | Prioritas |
|---|--------|----------|--------|-----------|
| 1 | API base URL hardcoded di source code | HIGH | Open | P0 |
| 2 | JWT token disimpan di `flutter_secure_storage` (acceptable) | LOW | OK | — |
| 3 | Tidak ada certificate pinning | MEDIUM | Open | P1 |
| 4 | Tidak ada biometric auth (device lock) | MEDIUM | Open | P1 |
| 5 | Debug mode masih aktif di production build | HIGH | Open | P0 |
| 6 | Tidak ada obfuscation/minification | MEDIUM | Open | P1 |
| 7 | Error messages expose stack trace ke user | LOW | Open | P2 |
| 8 | Tidak ada session timeout/auto-logout | MEDIUM | Open | P1 |
| 9 | Tidak ada rate limiting di client side | LOW | Open | P2 |
| 10 | `console.log` equivalent di debug build | LOW | OK | — |
| 11 | Deep link validation belum ada | MEDIUM | Open | P1 |
| 12 | Tidak ada integrity check (tamper detection) | LOW | Open | P2 |

---

## 2. Detail Temuan & Mitigasi

### CRITICAL — P0 (Harus Diperbaiki Sebelum Deploy)

#### 2.1 API Base URL Hardcoded

**File:** `lib/core/constants.dart`
**Severity:** HIGH

```dart
static const String baseUrl = 'http://192.168.100.93:3000'; // Development URL
```

**Risiko:**
- URL development ter-compile ke APK
- Attacker bisa reverse-engineer APK dan menemukan IP internal network
- Production URL juga terekspos

**Mitigasi:**
```dart
// Gunakan --dart-define saat build
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.nol.coffee',
);

// Build command:
// flutter build apk --dart-define=API_BASE_URL=https://api.nol.coffee
```

**Status:** Belum diterapkan

---

#### 2.2 Debug Mode di Production

**File:** `android/app/build.gradle.kts`
**Severity:** HIGH

**Risiko:**
- Debug mode mengaktifkan Flutter DevTools
- Attacker bisa inspect network traffic, read memory, hot-reload malicious code
- Stack trace lengkap terekspos ke user

**Mitigasi:**
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}
```

Dan di `flutter build apk --release` sudah otomatis non-debug. Tapi pastikan tidak ada `flutter run --release` yang accidentally di-deploy.

**Status:** Belum diterapkan

---

### HIGH — P1 (Harus Diperbaiki Dalam 2 Minggu)

#### 2.3 Tidak Ada Certificate Pinning

**Severity:** MEDIUM

**Risiko:**
- Man-in-the-Middle (MITM) attack
- Attacker di network yang sama bisa intercept API calls
- Terutama berbahaya karena app mengirim PIN dan menerima JWT token

**Mitigasi:**
```dart
// Tambah di pubspec.yaml:
// http_certificate_pinning: ^3.0.1

// Implementasi:
final httpClient = HttpClient();
httpClient.badCertificateCallback = (cert, host, port) => false;
```

Atau gunakan `dio` dengan custom `HttpClientAdapter` yang verify certificate.

**Status:** Belum diterapkan

---

#### 2.4 Tidak Ada Biometric Auth

**Severity:** MEDIUM

**Risiko:**
- Jika device hilang/dicuri, siapapun bisa buka app dan akses POS
- Tidak ada lapisan keamanan tambahan setelah login

**Mitigasi:**
```dart
// Tambah di pubspec.yaml:
// local_auth: ^2.2.0

// Implementasi di login_screen.dart:
final localAuth = LocalAuthentication();
final didAuthenticate = await localAuth.authenticate(
  localizedReason: 'Autentikasi untuk mengakses POS',
  options: const AuthenticationOptions(biometricOnly: true),
);
```

**Status:** Belum diterapkan

---

#### 2.5 Tidak Ada Session Timeout

**Severity:** MEDIUM

**Risiko:**
- JWT token valid selama 24 jam
- Jika device ditinggal, orang lain bisa akses POS tanpa login ulang
- Tidak ada auto-logout setelah idle

**Mitigasi:**
```dart
// Tambah di auth_provider.dart:
Timer? _sessionTimer;

void startSessionTimer() {
  _sessionTimer?.cancel();
  _sessionTimer = Timer(const Duration(minutes: 30), () {
    logout();
    // Navigate to login
  });
}

void resetSessionTimer() {
  _sessionTimer?.cancel();
  startSessionTimer();
}
```

**Status:** Belum diterapkan

---

#### 2.6 Deep Link Validation

**Severity:** MEDIUM

**Risiko:**
- App menerima deep links (Duitku payment callback)
- Attacker bisa craft malicious deep link untuk bypass atau inject data

**Mitigasi:**
- Validate semua incoming deep link parameters
- Whitelist allowed deep link domains
- Jangan trust data dari deep link tanpa verifikasi server

**Status:** Belum diterapkan

---

### MEDIUM — P2 (Best Practice)

#### 2.7 Error Messages Expose Stack Trace

**Severity:** LOW

**Contoh:**
```dart
SnackBar(content: Text('Error: $e'))  // Exposes full exception
```

**Mitigasi:**
```dart
// Gunakan user-friendly error messages
SnackBar(content: Text('Terjadi kesalahan. Coba lagi.'))
// Log error secara internal
FirebaseCrashlytics.instance.recordError(e, stackTrace);
```

**Status:** Belum diterapkan

---

#### 2.8 Client-Side Rate Limiting

**Severity:** LOW

**Risiko:**
- User bisa spam tombol CASH/PAY untuk create banyak order
- Tidak ada debounce pada API calls

**Mitigasi:**
- Sudah ada `_isProcessing` flag yang men-disable button
- Bisa ditambahkan debounce library untuk extra safety

**Status:** Sudah ada basic protection

---

#### 2.9 APK Integrity Check

**Severity:** LOW

**Risiko:**
- Attacker bisa decompile APK, modify code, repackage
- Bypass payment logic, inject malicious API endpoint

**Mitigasi:**
- Enable ProGuard/R8 obfuscation di release build
- Tambahkan SafetyNet/App Check (Google Play)
- Implement checksum verification

**Status:** Belum diterapkan

---

## 3. Keamanan yang Sudah Baik

| Aspek | Status | Detail |
|-------|--------|--------|
| JWT storage | ✅ | `flutter_secure_storage` (encrypted, hardware-backed) |
| HTTP headers | ✅ | Cookie-based auth, not hardcoded tokens |
| Input validation | ✅ | Form validators di login screen |
| PIN input | ✅ | `obscureText: true`, `maxLength: 6` |
| HTTPS ready | ✅ | Dio support HTTPS (tinggal ganti URL) |
| No secrets in code | ✅ | API keys di server-side, bukan di Flutter |

---

## 4. Rekomendasi Build & Deploy

### Production Build Command
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.nol.coffee \
  --obfuscate \
  --split-debug-info=build/debug-info
```

### Checklist Sebelum Deploy

- [ ] Ganti `baseUrl` ke production URL via `--dart-define`
- [ ] Build dengan `--release` (bukan debug)
- [ ] Enable ProGuard/R8 obfuscation
- [ ] Test di physical device (bukan emulator)
- [ ] Verify HTTPS certificate valid
- [ ] Test payment flow end-to-end di production
- [ ] Backup signing key (jangan hilang!)
- [ ] Set `minSdkVersion` ke 21+ (Android 5.0+)

### Environment Variables yang Perlu di-Set

| Variable | Lokasi | Nilai |
|----------|--------|-------|
| `API_BASE_URL` | `--dart-define` saat build | `https://api.nol.coffee` |
| `JWT_SECRET` | Server `.env` | Sudah ada |
| `INTERNAL_API_SECRET` | Server `.env` | Sudah ada |

---

## 5. Mitigation Priority Matrix

```
KRITIS (Lakukan Sekarang):
├── Ganti hardcoded URL ke --dart-define
├── Pastikan production build pakai --release
└── Enable ProGuard/R8

TINGGI (Dalam 2 Minggu):
├── Certificate pinning
├── Session timeout (30 menit idle)
└── Biometric auth

SEDANG (Dalam 1 Bulan):
├── Deep link validation
├── Error message sanitization
└── APK integrity check

RENDAH (Kapan Saja):
├── Client-side rate limiting (sudah ada basic)
└── Audit logging
```

---

## 6. Compliance Notes

### PDP Law (Indonesia)
- Foto attendance disimpan di Supabase (sudah di-migrate dari filesystem) ✅
- WhatsApp number tidak di-expose ke public API ✅
- Employee data hanya bisa diakses oleh ADMIN+ ✅

### Payment Security
- Duitku signature verification dilakukan di server-side ✅
- Tidak ada payment logic di client-side (hanya redirect) ✅
- Cash order divalidasi oleh server dengan session verification ✅

---

*Audit ini berdasarkan analisis source code tiknol-mobile-flutter per 2026-06-23.*
*Diperlukan penetration testing tambahan untuk validasi lengkap.*
