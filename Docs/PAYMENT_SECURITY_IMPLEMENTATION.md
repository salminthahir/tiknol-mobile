# Payment Security Implementation & Testing Report

**Project:** `tiknol-mobile-flutter` + `tiknol-reserve-web`
**Tanggal:** 1 Juli 2026
**Scope:** Payment Flow Security — Duitku QRIS + WebView Integration
**Status:** PV-1 sampai PV-5 diimplementasikan dan diverifikasi

---

## 1. Latar Belakang

Sistem POS Tiknol menggunakan Duitku sebagai payment gateway dengan dua jalur pembayaran:

1. **QRIS** — QR string diterima dari backend, ditampilkan di `QrisPaymentScreen`, status di-poll setiap 5 detik.
2. **WebView fallback** — `PaymentWebView` memuat `paymentUrl` Duitku bila QRIS tidak tersedia.

Audit kode awal menemukan 5 celah keamanan aktif (PV-1 s/d PV-5) yang memungkinkan transaksi palsu, manipulasi harga, dan kebocoran data. Seluruh celah telah diperbaiki.

---

## 2. Celah yang Ditemukan dan Status Perbaikan

| ID | Severity | Deskripsi | Status |
|----|----------|-----------|--------|
| PV-1 | CRITICAL | Payment success dipalsukan via URL substring | ✅ Fixed |
| PV-2 | CRITICAL | WebView path tidak verifikasi server sebelum sukses | ✅ Fixed |
| PV-3 | HIGH | Harga/diskon dari client, bisa dimanipulasi | ✅ Fixed |
| PV-4 | HIGH | HTTP cleartext sebagai default | ✅ Fixed |
| PV-5 | MEDIUM | Error status check ditelan jadi PENDING diam-diam | ✅ Fixed |
| PV-6 | MEDIUM | Tidak ada certificate pinning | Documented (follow-up) |
| PV-7 | LOW | Screenshot tidak dicegah di layar pembayaran | Documented (follow-up) |

---

## 3. Detail Implementasi Per Celah

### PV-1 — Client-Side Payment Success Spoofing

**Celah:** `PaymentWebView` menentukan sukses dari substring URL:
```dart
// SEBELUM (rentan) — payment_webview.dart
if (url.contains('status=success') || url.contains('result=00')) {
  Navigator.pop(context, true); // sukses dipalsukan!
}
```
Penyerang cukup membuka URL `https://evil.com?status=success` di WebView → cart clear + struk cetak tanpa bayar. Duitku sendiri memperingatkan: *"the URL can be changed manually by the customer."*

**Fix:**
```dart
// SESUDAH — payment_webview.dart
// Deteksi close pakai path-based (host-agnostic, multi-environment safe)
bool _isReturnUrl(String url) => url.contains('/ticket/${widget.orderId}');

void _handleUrl(String url) {
  if (_isReturnUrl(url)) {
    _returnDetected = true;
    Navigator.pop(context); // tutup saja, tanpa nilai sukses
  }
}
```
WebView sekarang hanya viewer. URL apapun hanya bisa menutup WebView — bukan menentukan sukses.

**Allow-list navigasi** tambahan:
```dart
// Hanya host Duitku atau path returnUrl yang diizinkan
static const List<String> _allowedDuitkuHosts = [
  'duitku.com', 'sandbox.duitku.com', 'passport.duitku.com',
];
bool _isAllowedNavigation(String url) {
  if (_isReturnUrl(url)) return true;
  final host = Uri.tryParse(url)?.host ?? '';
  return _allowedDuitkuHosts.any((d) => host == d || host.endsWith('.$d'));
}
```
`duitku.com.evil.com` → diblok (boundary-safe suffix match).

**File:** `lib/screens/payment_webview.dart`

---

### PV-2 — Missing Server Verification on WebView Path

**Celah:** Setelah `PaymentWebView` return `true`, cart langsung di-clear dan struk dicetak tanpa konfirmasi server.

**Fix:** Kedua jalur (QRIS dan WebView) wajib melewati `_verifyPaymentWithServer` sebelum sukses:

```dart
// cart_panel.dart — berlaku untuk QRIS dan WebView
await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => layarBayar));

// PV-2: Selalu verifikasi ke server — tidak pernah percaya sinyal client
final verified = await _verifyPaymentWithServer(orderId);
if (verified == PaymentStatus.paid) {
  // baru clear cart + cetak struk
}
```

```dart
// Helper dengan retry + fail-closed
Future<PaymentStatus> _verifyPaymentWithServer(String orderId) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final status = await orderService.checkPaymentStatus(orderId);
      if (status != PaymentStatus.pending) return status;
    } on PaymentCheckException { /* retry */ }
    if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
  }
  return PaymentStatus.pending; // tidak bisa prove PAID → JANGAN sukses
}
```

**File:** `lib/screens/widgets/cart_panel.dart`

---

### PV-3 — Price/Discount Tampering via Client Payload

**Celah:** Backend menerima `price`, `subtotal`, `discountAmount`, `totalAmount` dari client dan memakai nilai tersebut untuk menentukan `paymentAmount` ke Duitku:

```typescript
// SEBELUM (rentan) — tokenizer/route.ts
const calculatedTotal = items.reduce((acc, item) => acc + (item.price * item.qty), 0);
const finalTotal = (subtotal || calculatedTotal) - (discountAmount || 0);
// finalTotal ini yang dikirim ke Duitku → bisa dipalsukan
```

Penyerang bisa mengirim `price: 1`, `discountAmount: 999999` dan membayar Rp 1 untuk produk Rp 50.000.

**Fix:** Library baru `lib/orderPricing.ts` sebagai single source of truth:

```typescript
// lib/orderPricing.ts
export async function calculateOrderPricing({ items, branchId, voucherId }) {
  // 1. Ambil harga DARI DATABASE — abaikan item.price dari client
  const { items: pricedItems, subtotal } = await priceItemsFromDb(items, branchId);

  // 2. Validasi voucher server-side — abaikan discountAmount dari client
  const { discountAmount, voucherId: validatedVoucherId } =
    await computeVoucherDiscount(voucherId, pricedItems, subtotal, branchId);

  // 3. Total otoritatif yang dikirim ke Duitku
  const totalAmount = Math.max(0, subtotal - discountAmount);
  return { items: pricedItems, subtotal, discountAmount, totalAmount, voucherId: validatedVoucherId };
}
```

Prioritas harga per cabang:
```typescript
// branchPrice (override per cabang) diutamakan atas base price
const unitPrice = branchRecord?.branchPrice ?? product.price;
```

Voucher divalidasi ulang server-side (expired, usage limit, minPurchase vs subtotal DB, branch restriction, happy hour).

Items yang disimpan ke DB juga menggunakan harga server:
```typescript
// Harga server disimpan, bukan harga client
const persistedItems = pricing.items.map(it => ({
  id: it.id, name: it.name, price: it.unitPrice, qty: it.qty
}));
```

**File diubah:**
- `lib/orderPricing.ts` (baru)
- `app/api/tokenizer/route.ts`
- `app/api/cash-order/route.ts`
- `app/api/vouchers/validate/route.ts` (harden `effectiveCartTotal` dari DB)

---

### PV-4 — Cleartext HTTP by Default

**Celah:** `constants.dart` defaultValue `http://192.168.100.95:3000` — data sensitif (session cookie, payment status) melewati jaringan plaintext.

**Fix (3 lapisan):**

**Lapisan 1 — Compile-time default per environment (`constants.dart`):**
```dart
static const String _prodDefaultBaseUrl = 'https://www.nol.coffee';
static const String _devDefaultBaseUrl = 'http://192.168.18.52:3000';

static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: env == 'production' ? _prodDefaultBaseUrl : _devDefaultBaseUrl,
);

static bool isSecureUrl(String url) => url.toLowerCase().startsWith('https://');
```

**Lapisan 2 — Guard runtime di release build (`api_client.dart`):**
```dart
Future<void> refreshBaseUrl() async {
  final savedUrl = await ServerConfigService.getBaseUrl();
  // PV-4: release build menolak URL cleartext tersimpan
  if (kReleaseMode && !Constants.isSecureUrl(savedUrl)) {
    _dio.options.baseUrl = Constants.isSecureUrl(Constants.baseUrl)
        ? Constants.baseUrl
        : 'https://www.nol.coffee';
    return;
  }
  _dio.options.baseUrl = savedUrl;
}
```

**Lapisan 3 — Platform-level enforcement:**

Android `android/app/src/main/res/xml/network_security_config.xml`:
```xml
<network-security-config>
  <base-config cleartextTrafficPermitted="false">
    <trust-anchors><certificates src="system" /></trust-anchors>
  </base-config>
  <!-- Dev-only exception -->
  <domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="false">192.168.18.52</domain>
    <domain includeSubdomains="false">localhost</domain>
  </domain-config>
</network-security-config>
```

`AndroidManifest.xml`:
```xml
android:networkSecurityConfig="@xml/network_security_config"
android:usesCleartextTraffic="false"
```

iOS `Info.plist` — ATS tetap aktif, exception hanya LAN dev:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
  <key>NSExceptionDomains</key>
  <dict>
    <key>192.168.18.52</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
    </dict>
  </dict>
</dict>
```

**Backend (terverifikasi):** `.env` sudah `NEXT_PUBLIC_APP_BASE_URL="https://www.nol.coffee"` → `callbackUrl`/`returnUrl` ke Duitku sudah HTTPS.

**File diubah:**
- `lib/core/constants.dart`
- `lib/core/api_client.dart`
- `android/app/src/main/res/xml/network_security_config.xml` (baru)
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

---

### PV-5 — Silent Failure in Payment Status Check

**Celah:**
```dart
// SEBELUM — order_service.dart
Future<String> checkPaymentStatus(String orderId) async {
  try { ... }
  catch (_) { return 'PENDING'; } // error jaringan = anggap PENDING!
}
```
Network timeout, respons invalid, status tak dikenal → semuanya jadi `'PENDING'`. Client tidak bisa membedakan "belum bayar" dari "tidak bisa verifikasi".

**Fix:** Model `PaymentStatus` enum + `PaymentCheckException` fail-closed:

```dart
// lib/models/payment_status.dart (baru)
enum PaymentStatus { pending, paid, failed, cancelled, expired, unknown }

PaymentStatus paymentStatusFromString(String? raw) {
  switch (raw?.toUpperCase().trim()) {
    case 'PAID': case 'SUCCESS': return PaymentStatus.paid;
    case 'FAILED': case 'FAIL': return PaymentStatus.failed;
    case 'CANCELLED': case 'CANCELED': return PaymentStatus.cancelled;
    case 'EXPIRED': return PaymentStatus.expired;
    case 'PENDING': case 'PROCESS': return PaymentStatus.pending;
    default: return PaymentStatus.unknown; // FAIL CLOSED
  }
}
```

```dart
// order_service.dart
Future<PaymentStatus> checkPaymentStatus(String orderId) async {
  if (orderId.isEmpty) throw ArgumentError('orderId kosong');
  try {
    final response = await api.client.post('/api/payment/check-status', ...);
    if (response.statusCode == 200 && response.data is Map) {
      final status = paymentStatusFromString(response.data['status']?.toString());
      if (status == PaymentStatus.unknown) {
        throw PaymentCheckException('Status tidak dikenal dari server');
      }
      return status;
    }
    throw PaymentCheckException('Respons tidak valid (HTTP ${response.statusCode})');
  } on DioException catch (e) {
    throw PaymentCheckException('Gangguan jaringan: ${e.type.name}');
  }
}
```

`QrisPaymentScreen` diadaptasi: `PaymentCheckException` di-catch per tick polling — retry terus, tidak pernah assume sukses dari error.

**File diubah:**
- `lib/models/payment_status.dart` (baru)
- `lib/services/order_service.dart`
- `lib/screens/qris_payment_screen.dart`

---

## 4. Hasil Testing

### 4.1 Flutter Security Tests (37 tests, `test/security/`)

#### `payment_webview_spoof_test.dart` — PV-1 & PV-2 (12 tests)

| Test | Hasil |
|------|-------|
| `status=success` URL tidak memicu sinyal close | ✅ |
| `result=00` URL tidak memicu sinyal close | ✅ |
| Close WebView ≠ bukti pembayaran | ✅ |
| Production host return URL menutup WebView | ✅ |
| Dev LAN host return URL menutup WebView (multi-env) | ✅ |
| Order ID berbeda tidak trigger close | ✅ |
| Host sandbox Duitku diizinkan navigasi | ✅ |
| Subdomain Duitku diizinkan | ✅ |
| Backend return-url path diizinkan semua host | ✅ |
| Host attacker tanpa return path diblok | ✅ |
| Lookalike `duitku.com.evil.com` diblok | ✅ |
| Attacker host + return path = close saja, bukan sukses | ✅ |

#### `payment_flow_integration_test.dart` — PV-2 (7 tests)

| Test | Hasil |
|------|-------|
| Server PAID = selesaikan transaksi | ✅ |
| WebView close palsu tanpa bayar = tidak selesai | ✅ |
| Error verifikasi (fail-closed) = tidak selesai | ✅ |
| Retry pending → paid berhasil setelah flip | ✅ |
| Status FAILED = tidak selesai | ✅ |
| Verifikasi selalu query backend minimal 1x | ✅ |
| `cancelOrder` best-effort boleh throw | ✅ |

#### `order_service_tampering_test.dart` — PV-3 surface & PV-5 (9 tests)

| Test | Hasil |
|------|-------|
| `createCashOrder` kirim harga dari client (surface) | ✅ |
| `createOnlinePayment` kirim subtotal/discount client (surface) | ✅ |
| Diskon palsu besar dikirim tanpa validasi client-side | ✅ |
| Network timeout lempar `PaymentCheckException` (bukan PENDING) | ✅ |
| Respons non-Map lempar exception | ✅ |
| Status tidak dikenal lempar (fail-closed) | ✅ |
| PAID eksplisit → `PaymentStatus.paid` | ✅ |
| PENDING eksplisit → `PaymentStatus.pending` | ✅ |
| orderId kosong → `ArgumentError` | ✅ |

#### `transport_security_test.dart` — PV-4 (9 tests)

| Test | Hasil |
|------|-------|
| Production default base URL adalah HTTPS | ✅ |
| Helper `isSecureUrl` tersedia | ✅ |
| Cleartext dev gated oleh `env == 'production'` | ✅ |
| Release build menolak URL cleartext tersimpan (`kReleaseMode`) | ✅ |
| Network config file ada + blok cleartext global | ✅ |
| AndroidManifest daftarkan config + disable cleartext | ✅ |
| iOS ATS aktif (`NSAllowsArbitraryLoads=false`) | ✅ |
| WebView punya allow-list (`NavigationDecision.prevent`) | ✅ |
| WebView tidak pernah `pop(context, true)` dari URL | ✅ |

---

### 4.2 Backend Jest Tests (34 tests)

#### `__tests__/unit/order-pricing.test.ts` — PV-3 (14 tests)

| Test | Hasil |
|------|-------|
| Harga DB dipakai, bukan harga client | ✅ |
| `branchPrice` override diutamakan | ✅ |
| Produk tidak ditemukan → error 400 | ✅ |
| Item unavailable di branch → tolak | ✅ |
| Qty ≤ 0 → tolak | ✅ |
| Items kosong / branch kosong → tolak | ✅ |
| Tidak ada voucher → diskon 0 | ✅ |
| PERCENTAGE dengan maxDiscount cap | ✅ |
| Di bawah minPurchase → tolak | ✅ |
| FIXED_AMOUNT tidak melebihi subtotal | ✅ |
| Voucher branch salah → tolak | ✅ |
| Voucher kadaluarsa → tolak | ✅ |
| End-to-end: harga client diabaikan | ✅ |
| `totalAmount` tidak pernah negatif | ✅ |

#### `__tests__/integration/pv3-pricing-tampering.test.ts` — PV-3 Route Level (3 tests)

| Test | Hasil |
|------|-------|
| `/api/tokenizer` tanda tangan Duitku pakai amount DB (50000), bukan client (1) | ✅ |
| `/api/tokenizer` tolak produk tidak dikenal | ✅ |
| `/api/cash-order` simpan total DB (50000), bukan client (1) | ✅ |

#### `__tests__/integration/voucher-validate.test.ts` — Existing (17 tests)

Semua test validasi voucher yang sudah ada tetap hijau setelah hardening `effectiveCartTotal`.

---

### 4.3 Ringkasan Total

```
Flutter security tests:  37 / 37  PASS
Backend unit tests:      14 / 14  PASS
Backend integration:     20 / 20  PASS (17 voucher + 3 PV-3)
                        ─────────────
Total:                   71 / 71  PASS

flutter analyze: 1 info (withOpacity deprecated, pre-existing di pos_screen.dart)
tsc --noEmit:    0 errors di file yang diubah (error pre-existing di file lain)
```

---

## 5. Arsitektur Keamanan Payment (Setelah Fix)

```
Flutter Client                    Backend (Next.js)              Duitku
─────────────────                 ─────────────────              ──────
                                                                 
CartPanel                         POST /api/tokenizer
 ├─ createOnlinePayment()    →     ├─ calculateOrderPricing()
 │   items: [{ id, qty }]         │   ├─ priceItemsFromDb()       [DB lookup]
 │   (price diabaikan)            │   │   branchPrice ?? base
 │                                │   └─ computeVoucherDiscount()  [DB validate]
 │                                ├─ duitku.requestPayment(amount=server)
 │                                └─ Response { qrString, orderId, amount }
 │
 ├─ QrisPaymentScreen (QRIS)
 │   └─ poll checkPaymentStatus() →  POST /api/payment/check-status
 │       PaymentCheckException         └─ duitku.checkTransaction()
 │       pada semua error              signature: HMAC(merchantCode+orderId)
 │                                     → { status: PAID|PENDING|FAILED }
 │
 ├─ PaymentWebView (fallback)
 │   ├─ viewer only, no URL trust
 │   ├─ allow-list: Duitku hosts + /ticket/{id} path
 │   └─ close → tidak ada nilai sukses
 │
 └─ _verifyPaymentWithServer()   →  POST /api/payment/check-status
     retry 3x, 2s interval           (sama seperti QRIS polling)
     hanya PaymentStatus.paid         → server verifikasi ke Duitku
     yang selesaikan transaksi
```

---

## 6. Kontrak Backend yang Harus Dipertahankan

Implementasi client-side aman bergantung pada kontrak backend berikut. **Jangan ubah tanpa koordinasi:**

| Endpoint | Kontrak |
|----------|---------|
| `POST /api/payment/check-status` | Wajib verifikasi ke Duitku `transactionStatus`. Jangan return PAID dari state lokal saja. |
| `POST /api/notification` (callback) | Validasi signature `HMAC_SHA256(merchantCode + amount + merchantOrderId, apiKey)`. Sudah diimplementasikan. |
| `POST /api/tokenizer` | Amount ke Duitku = `calculateOrderPricing().totalAmount` (server DB), bukan dari client. |
| `POST /api/cash-order` | Total = `calculateOrderPricing().totalAmount`. Items disimpan dengan `unitPrice` server. |

---

## 7. Hal yang Masih Perlu Dikerjakan (Follow-up)

| Item | Prioritas | Keterangan |
|------|-----------|-----------|
| **Ganti MD5 → HMAC-SHA256 di `duitku.ts`** | HIGH | Duitku docs: MD5 obsolete. Perlu koordinasi karena mengubah signature format. Test sandbox sebelum produksi. |
| **Certificate Pinning (PV-6)** | MEDIUM | Implementasikan `IOHttpClientAdapter` + `badCertificateCallback` di `api_client.dart` setelah domain `api.nol.coffee` live dan sertifikat final. |
| **Routing `api.nol.coffee`** | MEDIUM | Saat DNS subdomain sudah aktif, update `_prodDefaultBaseUrl` di `constants.dart` dari `https://www.nol.coffee` ke `https://api.nol.coffee`. |
| **Screenshot prevention (PV-7)** | LOW | Tambahkan `FLAG_SECURE` di `QrisPaymentScreen` dan `PaymentWebView` untuk mencegah tangkapan layar QR code. |
| **Rewrite integration test tokenizer/cash-order lama** | LOW | Test lama stale (era Midtrans). Rewrite menggunakan mock session + Duitku seperti `pv3-pricing-tampering.test.ts`. |

---

## 8. Cara Menjalankan Test Keamanan

```bash
# Flutter — semua security tests
flutter test test/security/

# Backend — unit test pricing
npx jest __tests__/unit/order-pricing.test.ts

# Backend — integration PV-3 (route level)
npx jest __tests__/integration/pv3-pricing-tampering.test.ts

# Backend — semua test yang relevan
npx jest __tests__/unit/order-pricing.test.ts \
         __tests__/integration/pv3-pricing-tampering.test.ts \
         __tests__/integration/voucher-validate.test.ts

# Flutter analyze (pastikan bersih)
flutter analyze lib/ test/security/

# Backend type check (file yang diubah harus 0 error)
npx tsc --noEmit 2>&1 | grep -iE "orderPricing|tokenizer|cash-order|vouchers"
```

---

## 9. File yang Diubah (Daftar Lengkap)

### Flutter (`tiknol-mobile-flutter`)

| File | Perubahan | PV |
|------|-----------|-----|
| `lib/models/payment_status.dart` | BARU — enum + parser + exception | PV-5 |
| `lib/services/order_service.dart` | `checkPaymentStatus` fail-closed | PV-5 |
| `lib/screens/payment_webview.dart` | Hapus logika sukses URL; allow-list; path-based detection | PV-1 |
| `lib/screens/widgets/cart_panel.dart` | `_verifyPaymentWithServer` setelah semua jalur bayar | PV-2 |
| `lib/screens/qris_payment_screen.dart` | Adaptasi ke enum; handle exception per tick | PV-5 |
| `lib/core/constants.dart` | Per-env HTTPS default; `isSecureUrl()` | PV-4 |
| `lib/core/api_client.dart` | Guard cleartext di `kReleaseMode` | PV-4 |
| `android/.../network_security_config.xml` | BARU — blok cleartext global | PV-4 |
| `android/.../AndroidManifest.xml` | Daftarkan network config | PV-4 |
| `ios/Runner/Info.plist` | ATS config; exception LAN dev saja | PV-4 |
| `test/security/payment_webview_spoof_test.dart` | Test aman PV-1/PV-2 | — |
| `test/security/order_service_tampering_test.dart` | Test aman PV-3 surface + PV-5 | — |
| `test/security/payment_flow_integration_test.dart` | Test aman PV-2 flow | — |
| `test/security/transport_security_test.dart` | Test aman PV-4 | — |
| `pubspec.yaml` | Tambah `mocktail: ^1.0.4` | — |

### Backend (`tiknol-reserve-web`)

| File | Perubahan | PV |
|------|-----------|-----|
| `lib/orderPricing.ts` | BARU — recalculation otoritatif dari DB | PV-3 |
| `app/api/tokenizer/route.ts` | Wire `calculateOrderPricing`; simpan harga server | PV-3 |
| `app/api/cash-order/route.ts` | Wire `calculateOrderPricing`; simpan harga server | PV-3 |
| `app/api/vouchers/validate/route.ts` | `effectiveCartTotal` dari DB via `priceItemsFromDb` | PV-3 |
| `__tests__/unit/order-pricing.test.ts` | BARU — 14 unit test pricing | — |
| `__tests__/integration/pv3-pricing-tampering.test.ts` | BARU — 3 integration test route level | — |

---

*Dokumen ini dibuat otomatis berdasarkan implementasi dan hasil test aktual pada 1 Juli 2026.*
*Untuk referensi teknis rinci, lihat juga: `PAYMENT_SECURITY_TEST_PLAN.md` dan `PAYMENT_SECURITY_REMEDIATION_PLAN.md` di root project.*
