# Payment Security Remediation Plan — PV-1 s/d PV-5

**Date:** 30 June 2026
**Scope:** Tiknol POS Mobile (Flutter client) + kontrak backend yang dibutuhkan
**Related:** `PAYMENT_SECURITY_TEST_PLAN.md`, `SECURITY_AUDIT.md`
**Status:** Ready for implementation

> Prinsip utama (sesuai dokumentasi Duitku): **Status pembayaran TIDAK BOLEH ditentukan dari URL, resultCode, atau nilai apa pun yang dikontrol client.** Satu-satunya sumber kebenaran adalah backend yang memverifikasi ke Duitku `transactionStatus` menggunakan signature `HMAC_SHA256(merchantCode + merchantOrderId, apiKey)`.

---

## Ringkasan Urutan Eksekusi

| Fase | Item | Tipe perubahan | Risiko | Est |
|------|------|----------------|--------|-----|
| 1 | PV-1 + PV-2: server-verified success (single source of truth) | Client + kontrak backend | Tinggi | 1–2 hari |
| 2 | PV-5: fail-closed status check + status enum | Client | Sedang | 0.5 hari |
| 3 | PV-3: server-side recalculation + integritas item | Backend + guard client | Tinggi (backend) | 1–2 hari |
| 4 | PV-4: enforce HTTPS + network security config | Client + platform config | Sedang | 0.5 hari |
| 5 | Regression tests: balik assertion jadi "secure" | Test | Rendah | 0.5 hari |

Disarankan dikerjakan berurutan karena PV-1/PV-2 dan PV-5 saling bergantung (keduanya menyentuh `checkPaymentStatus` dan flow sukses).

---

## PV-1 + PV-2 — Hilangkan Penentuan Sukses dari Sisi Client

### Akar masalah
- `lib/screens/payment_webview.dart:50-72` menilai sukses dari substring URL.
- `lib/screens/widgets/cart_panel.dart:218` mempercayai hasil boolean WebView tanpa verifikasi server.

### Target akhir
WebView **hanya** sebagai penampil halaman bayar. Penentuan sukses dilakukan oleh polling status server (sama seperti jalur QRIS), bukan oleh URL.

### Langkah 1.1 — Buat tipe status terpusat
Buat file baru `lib/models/payment_status.dart`:

```dart
enum PaymentStatus { pending, paid, failed, cancelled, expired, unknown }

PaymentStatus paymentStatusFromString(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'PAID':
    case 'SUCCESS':
      return PaymentStatus.paid;
    case 'FAILED':
      return PaymentStatus.failed;
    case 'CANCELLED':
    case 'CANCELED':
      return PaymentStatus.cancelled;
    case 'EXPIRED':
      return PaymentStatus.expired;
    case 'PENDING':
    case 'PROCESS':
      return PaymentStatus.pending;
    default:
      return PaymentStatus.unknown; // penting untuk PV-5 (fail-closed)
  }
}
```

### Langkah 1.2 — Ubah `OrderService.checkPaymentStatus` (lihat juga PV-5)
File: `lib/services/order_service.dart`.

Sebelum (rentan, `order_service.dart:103-119`):
```dart
Future<String> checkPaymentStatus(String orderId) async {
  if (orderId.isEmpty) return 'PENDING';
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.client.post(
      '/api/payment/check-status', data: {'orderId': orderId});
    if (response.statusCode == 200 && response.data['status'] != null) {
      return response.data['status'] as String;
    }
    return 'PENDING';
  } catch (_) {
    return 'PENDING';
  }
}
```

Sesudah:
```dart
/// Mengembalikan status terverifikasi server. Melempar [PaymentCheckException]
/// pada error transport/parse agar pemanggil bisa membedakan error vs PENDING.
Future<PaymentStatus> checkPaymentStatus(String orderId) async {
  if (orderId.isEmpty) {
    throw ArgumentError('orderId kosong');
  }
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.client.post(
      '/api/payment/check-status',
      data: {'orderId': orderId},
    );
    if (response.statusCode == 200 && response.data is Map) {
      final status = paymentStatusFromString(
        (response.data as Map)['status']?.toString(),
      );
      if (status == PaymentStatus.unknown) {
        throw PaymentCheckException('Status tidak dikenal dari server');
      }
      return status;
    }
    throw PaymentCheckException('Respons tidak valid (${response.statusCode})');
  } on DioException catch (e) {
    throw PaymentCheckException('Gangguan jaringan: ${e.type.name}');
  }
}
```

Tambahkan exception:
```dart
class PaymentCheckException implements Exception {
  final String message;
  PaymentCheckException(this.message);
  @override
  String toString() => 'PaymentCheckException: $message';
}
```

> Catatan: ini mengubah signature `String -> PaymentStatus` dan kini melempar. Semua pemanggil harus diperbarui (Langkah 1.3 & 1.4).

### Langkah 1.3 — Tulis ulang `PaymentWebView`
File: `lib/screens/payment_webview.dart`. Hapus seluruh logika `_checkUrl` berbasis substring sukses. WebView hanya:
- memuat `paymentUrl`,
- mendeteksi sinyal **selesai/tutup** (mis. redirect ke `returnUrl`) sebagai isyarat untuk **berhenti menampilkan dan memulai verifikasi server**, bukan sebagai bukti sukses,
- mengembalikan kontrol ke pemanggil yang akan polling status.

Pola pengganti `_checkUrl`:
```dart
void _onUrlChanged(String url) {
  // returnUrl menandakan user keluar dari halaman bayar Duitku.
  // Ini BUKAN bukti pembayaran — hanya sinyal untuk mulai verifikasi server.
  if (!_returnDetected && url.startsWith(widget.returnUrl)) {
    _returnDetected = true;
    Navigator.pop(context); // tutup webview tanpa nilai sukses
  }
}
```

`PaymentWebView` tidak lagi mengembalikan `bool`. Verifikasi dilakukan oleh pemanggil.

(Opsional pengerasan) batasi navigasi ke host Duitku + host backend pada `onNavigationRequest`:
```dart
onNavigationRequest: (request) {
  final host = Uri.tryParse(request.url)?.host ?? '';
  const allowed = ['duitku.com', 'sandbox.duitku.com', 'passport.duitku.com'];
  final isAllowed = allowed.any((d) => host == d || host.endsWith('.$d')) ||
      request.url.startsWith(widget.returnUrl);
  return isAllowed ? NavigationDecision.navigate : NavigationDecision.prevent;
},
```

### Langkah 1.4 — Verifikasi server di `cart_panel`
File: `lib/screens/widgets/cart_panel.dart`, `_processOnlinePayment` (sekitar `cart_panel.dart:185-252`).

Logika baru untuk **kedua** jalur (QRIS & WebView): setelah layar bayar ditutup, **selalu** panggil verifikasi status server sebelum menandai sukses.

```dart
// Setelah Navigator.push layar pembayaran (QRIS atau WebView) selesai:
final verified = await _verifyPaymentWithServer(orderId);

if (verified == PaymentStatus.paid && mounted) {
  // sukses asli → clear cart, cetak struk, dialog sukses
} else {
  if (orderId.isNotEmpty) await orderService.cancelOrder(orderId);
  // tampilkan "Pembayaran belum selesai / dibatalkan"
}
```

Helper verifikasi (polling singkat, fail-closed):
```dart
Future<PaymentStatus> _verifyPaymentWithServer(String orderId) async {
  final orderService = ref.read(orderServiceProvider);
  for (var i = 0; i < 3; i++) {
    try {
      final status = await orderService.checkPaymentStatus(orderId);
      if (status != PaymentStatus.pending) return status;
    } on PaymentCheckException {
      // diam, retry
    }
    await Future.delayed(const Duration(seconds: 2));
  }
  return PaymentStatus.pending; // belum terbukti PAID → JANGAN anggap sukses
}
```

### Langkah 1.5 — Sesuaikan `QrisPaymentScreen`
File: `lib/screens/qris_payment_screen.dart:84-101`. Sesuaikan ke enum:
```dart
final status = await orderService.checkPaymentStatus(widget.orderId);
if (status == PaymentStatus.paid) { ... }
else if (status == PaymentStatus.cancelled || status == PaymentStatus.failed) { ... }
```
Bungkus dalam `try/on PaymentCheckException` agar error jaringan tetap retry (perilaku polling tetap), tapi `unknown` tidak lagi dianggap pending diam-diam.

### Kontrak backend yang dibutuhkan (PV-1/PV-2)
- `POST /api/payment/check-status` **wajib** memanggil Duitku `POST /webapi/api/merchant/transactionStatus` dengan signature `HMAC_SHA256(merchantCode + merchantOrderId, apiKey)` dan memetakan `statusCode` Duitku → `{ "status": "PAID|PENDING|FAILED|EXPIRED" }`. Jangan mengembalikan PAID hanya berdasar state lokal yang bisa di-set dari redirect.
- Endpoint callback Duitku harus memvalidasi signature callback `HMAC_SHA256(merchantCode + amount + merchantOrderId, apiKey)` dan melakukan IP allow-list (`182.23.85.8-14`, `103.177.101.184-190` untuk produksi).

---

## PV-5 — Fail-Closed pada Pengecekan Status

Sudah sebagian besar tercakup di Langkah 1.2 (melempar `PaymentCheckException`, mengembalikan `PaymentStatus.unknown` → exception). Tambahan:

- **Jangan** pernah memetakan error/timeout/respons aneh menjadi PAID atau diam-diam PENDING di tempat keputusan akhir. PENDING hanya boleh bila server eksplisit mengatakan pending.
- Di UI verifikasi (Langkah 1.4), bila setelah retry tetap `pending`/error → tampilkan opsi "Cek ulang status" daripada otomatis sukses/gagal permanen, agar kasir tidak menutup transaksi yang sebenarnya sudah dibayar.
- Tambah logging aman (tanpa data sensitif) saat `PaymentCheckException` untuk observability.

---

## PV-3 — Server-Side Recalculation (Anti Price/Discount Tampering)

### Akar masalah
`lib/services/order_service.dart:22-39, 60-78` mengirim `price`, `subtotal`, `discountAmount`, `totalAmount`, `voucherId` dari client. Bila backend memakai nilai ini untuk `paymentAmount` Duitku, penyerang bisa membayar nominal arbitrer.

### Perubahan backend (utama — wajib)
1. Backend **mengabaikan** `price`, `subtotal`, `totalAmount` dari client. Hitung ulang:
   - Ambil harga tiap item dari DB berdasarkan `productId` (+ `branchId` untuk `branchPrice`).
   - Hitung `subtotal = Σ(price_db × qty)`.
   - Validasi `voucherId` server-side → tentukan `discountAmount` dari aturan voucher di DB.
   - `paymentAmount = subtotal − discountAmount` (clamp ≥ 0; tolak bila diskon > subtotal).
2. Signature Duitku dibangun dari `paymentAmount` hasil hitung server, bukan dari client.
3. Tolak request bila item tidak ada/non-aktif/stok habis.

### Perubahan client (pengerasan defensif)
- Hentikan pengiriman `totalAmount`/`subtotal` sebagai sumber kebenaran; tetap boleh dikirim sebagai **hint untuk display**, tapi tambahkan komentar bahwa server mengabaikannya.
- Setelah `createOnlinePayment`, **bandingkan** `amount` yang dikembalikan server dengan ekspektasi client. Jika beda jauh, tampilkan peringatan ke kasir alih-alih lanjut diam-diam:
```dart
final serverAmount = int.tryParse(result['amount'] ?? '0') ?? 0;
if (serverAmount <= 0 || (expectedTotal > 0 && serverAmount != expectedTotal)) {
  // tampilkan konfirmasi: "Nominal dari server (Rp X) berbeda dari keranjang (Rp Y)"
}
```
- Kirim hanya `productId` + `qty` (+ pilihan kustomisasi) sebagai data otoritatif; biarkan harga ditentukan server.

### Catatan
Karena backend di luar repo ini, item ini butuh koordinasi tim backend. Bagian client di atas tetap bisa diimplementasikan sekarang sebagai defense-in-depth.

---

## PV-4 — Enforce HTTPS + Network Security Config

### Langkah 4.1 — Default HTTPS di produksi
File: `lib/core/constants.dart`. Pisahkan default per environment:
```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: bool.fromEnvironment('dart.vm.product')
      ? 'https://api.nol.coffee'   // produksi: WAJIB https
      : 'http://192.168.100.95:3000', // dev only
);
```
Tambahkan guard runtime di `ApiClient`/`ServerConfigService` agar di release build menolak skema `http://` (kecuali host LAN privat bila memang diizinkan untuk dev).

### Langkah 4.2 — Android Network Security Config
Buat `android/app/src/main/res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="false">
    <trust-anchors>
      <certificates src="system" />
    </trust-anchors>
  </base-config>
  <!-- Izinkan cleartext HANYA untuk host dev di build debug, opsional -->
  <domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="false">192.168.100.95</domain>
  </domain-config>
</network-security-config>
```
Daftarkan di `AndroidManifest.xml` (`<application>`):
```xml
android:networkSecurityConfig="@xml/network_security_config"
android:usesCleartextTraffic="false"
```

### Langkah 4.3 — iOS ATS
File `ios/Runner/Info.plist`: pastikan tidak ada `NSAllowsArbitraryLoads=true` untuk produksi. Bila perlu exception dev, batasi per-domain via `NSExceptionDomains`.

### Langkah 4.4 — (PV-6 terkait) Certificate Pinning — opsional fase ini
Tambahkan `badCertificateCallback`/`IOHttpClientAdapter` dengan pin SPKI SHA-256 untuk domain produksi. Tandai sebagai follow-up bila sertifikat belum final.

---

## Perubahan Test (balik assertion ke "secure")

Setelah implementasi, perbarui `test/security/`:

1. `payment_webview_spoof_test.dart` (PV-1):
   - Hapus/penjadian-negatif: URL `status=success`/`/ticket/{id}` **tidak lagi** memicu sukses. Karena logika sukses pindah ke server, test ini berubah menjadi: "WebView hanya pop tanpa nilai sukses saat redirect returnUrl".
2. `order_service_tampering_test.dart`:
   - PV-5: ganti ekspektasi `'PENDING'` → `expect(() => service.checkPaymentStatus(...), throwsA(isA<PaymentCheckException>()))` untuk timeout & malformed.
   - Tambah test: status `'PAID'` valid → `PaymentStatus.paid`.
   - PV-3 (client guard): test bahwa mismatch `amount` server vs client memicu peringatan.
3. `payment_flow_integration_test.dart` (PV-2):
   - Test baru: setelah layar bayar ditutup, `_verifyPaymentWithServer` dipanggil dan **hanya** `PaymentStatus.paid` yang membersihkan cart.
4. `transport_security_test.dart` (PV-4):
   - Produksi: `defaultValue` produksi `startsWith('https://')`.
   - AndroidManifest mengandung `networkSecurityConfig` dan `usesCleartextTraffic="false"`.

Tambahkan juga unit test untuk `paymentStatusFromString` (semua cabang + `unknown`).

---

## Daftar File yang Disentuh

| File | PV | Aksi |
|------|----|------|
| `lib/models/payment_status.dart` (baru) | 1,5 | enum + parser |
| `lib/services/order_service.dart` | 1,5 | refactor `checkPaymentStatus`, exception |
| `lib/screens/payment_webview.dart` | 1,2 | hapus logika sukses berbasis URL, allow-list navigasi |
| `lib/screens/widgets/cart_panel.dart` | 1,2,3 | verifikasi server sebelum sukses, cek mismatch amount |
| `lib/screens/qris_payment_screen.dart` | 1,5 | adaptasi ke enum + handle exception |
| `lib/core/constants.dart` | 4 | default HTTPS per-env |
| `lib/core/api_client.dart` | 4,6 | guard skema http, (opsional) pinning |
| `android/app/src/main/res/xml/network_security_config.xml` (baru) | 4 | blokir cleartext |
| `android/app/src/main/AndroidManifest.xml` | 4 | daftarkan config |
| `ios/Runner/Info.plist` | 4 | ATS |
| `test/security/*` | 1–5 | balik ke assertion aman |
| **Backend (luar repo)** | 1,2,3,5 | verifikasi Duitku + recalculation |

---

## Verifikasi Akhir

1. `flutter analyze` bersih.
2. `flutter test test/security/` hijau dengan assertion baru (secure).
3. Manual sandbox Duitku:
   - Spoof URL `?status=success` di WebView → app **tidak** menandai sukses (PV-1/PV-2 closed).
   - Intercept `/api/tokenizer` ubah `subtotal` → `amount` server tidak ikut berubah (PV-3 closed, butuh backend).
   - Matikan jaringan saat polling → muncul opsi "cek ulang", bukan sukses/pending diam (PV-5 closed).
   - Release build menolak `http://` (PV-4 closed).
4. `graphify update .` setelah perubahan kode.

---

*Document Version:* 1.0
*Last Updated:* 30 June 2026
