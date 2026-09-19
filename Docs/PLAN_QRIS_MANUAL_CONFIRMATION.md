# QRIS Manual Confirmation - Implementation Plan (Lean Version)

**Version:** 2.0 (Lean & Pragmatic)  
**Date:** 2026-09-12  
**Status:** Approved for Implementation  

---

## 1. Ringkasan Solusi (Executive Summary)

Sistem pembayaran QRIS saat ini mengandalkan polling otomatis setiap 5 detik ke backend dan webhook Duitku. Ketika integrasi pihak ketiga lambat atau tidak merespons, kasir tertahan di layar pembayaran meskipun pelanggan telah menunjukkan bukti transfer.

### Solusi Ramping (Lean Fallback):
- **Otomatis tetap berjalan:** Polling 5 detik dan webhook Duitku tetap aktif seperti biasa.
- **Fallback setelah 10 detik:** Setelah 10 detik polling tanpa status `PAID`, tombol *"Pelanggan sudah membayar?"* muncul di layar QRIS kasir.
- **Status tetap `PAID`:** Di database, status order langsung diubah menjadi `PAID` ditambah 3 field audit (`manualConfirmedAt`, `manualConfirmedBy`, `manualConfirmNote`). Tidak perlu membuat enum status baru.
- **Alur langsung selesai:** Begitu konfirmasi manual sukses, layar QRIS kembali (`pop`) dengan hasil `'paid'`. `cart_panel.dart` otomatis memverifikasi, membersihkan keranjang, menampilkan dialog sukses, dan mencetak struk kasir.
- **Idempotency QRIS:** Menambahkan pengecekan `clientTransactionId` pada pembuatan order QRIS untuk mencegah duplikasi tagihan akibat *double-tap*.

---

## 2. File yang Dikerjakan (Scope Perubahan)

Hanya **5 file** yang dimodifikasi / dibuat (3 backend, 2 frontend):

```
Backend (tiknol-reserve-web):
├── prisma/schema.prisma                  [Ubah: tambah 3 field audit]
├── app/api/payment/manual-confirm/route.ts [Baru: endpoint konfirmasi manual]
└── app/api/notification/route.ts         [Ubah: guard webhook agar tidak menimpa status]
└── app/api/tokenizer/route.ts            [Ubah: support idempotency clientTransactionId]

Frontend (tiknol-mobile-flutter):
├── lib/services/order_service.dart       [Ubah: method manuallyConfirmPayment]
└── lib/screens/qris_payment_screen.dart   [Ubah: timer 10s, tombol fallback, dialog konfirmasi]
└── lib/screens/widgets/cart_panel.dart    [Ubah: kirim clientTransactionId saat create payment]
```

> **Yang Dieliminasi dari Rencana Sebelumnya (Anti-Overengineering):**
> - ❌ Menghapus 8 hierarki class custom exception di Flutter (cukup pakai `Exception` standar).
> - ❌ Menghapus penambahan enum `PaymentStatus.manuallyConfirmed` (karena status riil di DB adalah `PAID`).
> - ❌ Menghapus modifikasi `PendingPaymentService` (karena order yang sudah dikonfirmasi manual langsung selesai, bukan pending).
> - ❌ Menghapus kebutuhan load-testing k6 dan setup Grafana/Metabase (cukup verifikasi langsung flow POS).

---

## 3. Spesifikasi Teknis Backend (`tiknol-reserve-web`)

### A. Prisma Schema Migration (`prisma/schema.prisma`)
Tambahkan 3 field audit (opsional / nullable) pada model `Order`:

```prisma
model Order {
  // ... field yang sudah ada ...

  // Audit Manual Confirmation
  manualConfirmedAt   DateTime?
  manualConfirmedBy   String?   // userId kasir dari staff_session
  manualConfirmNote   String?   // Catatan kasir (opsional)

  // ... field yang sudah ada ...
}
```

Jalankan migrasi:
```bash
npx prisma migrate dev --name add_manual_confirmation_fields
```

### B. Endpoint Baru: `POST /api/payment/manual-confirm`
**File:** `app/api/payment/manual-confirm/route.ts`

```typescript
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { verifySession } from "@/lib/session";
import { cookies } from "next/headers";

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    // 1. Validasi sesi staff
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get('staff_session');
    if (!sessionCookie) {
      return NextResponse.json({ error: "Sesi tidak valid / belum login" }, { status: 401 });
    }

    const session = await verifySession(sessionCookie.value);

    // 2. Parse request body
    const { orderId, note } = await request.json();
    if (!orderId) {
      return NextResponse.json({ error: "orderId wajib diisi" }, { status: 400 });
    }

    // 3. Validasi status order saat ini
    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (!order) {
      return NextResponse.json({ error: "Order tidak ditemukan" }, { status: 404 });
    }

    if (order.status === 'PAID') {
      return NextResponse.json({ error: "Order sudah berstatus PAID" }, { status: 400 });
    }

    if (order.status !== 'PENDING') {
      return NextResponse.json(
        { error: `Order tidak dapat dikonfirmasi karena status: ${order.status}` },
        { status: 400 }
      );
    }

    // 4. Update status ke PAID + simpan metadata audit
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: 'PAID',
        manualConfirmedAt: new Date(),
        manualConfirmedBy: session.userId,
        manualConfirmNote: note?.trim() || null,
        updatedAt: new Date(),
      },
    });

    return NextResponse.json({
      success: true,
      orderId: updatedOrder.id,
      status: updatedOrder.status,
      manualConfirmedAt: updatedOrder.manualConfirmedAt,
    });
  } catch (error: any) {
    console.error("Manual Confirm Error:", error);
    return NextResponse.json(
      { error: error.message || "Gagal konfirmasi manual" },
      { status: 500 }
    );
  }
}
```

### C. Guard di Webhook Duitku (`app/api/notification/route.ts`)
Tambahkan pengecekan agar webhook Duitku yang terlambat tidak menimpa order yang sudah diselesaikan manual:

```typescript
// Tambahkan sebelum update status di line 77:
if (existingOrder.manualConfirmedAt) {
  console.log(`[Webhook] Order ${merchantOrderId} sudah dikonfirmasi manual. Melewati update webhook.`);
  return NextResponse.json({ success: true, message: "Already manually confirmed" });
}
```

### D. Idempotency QRIS (`app/api/tokenizer/route.ts`)
Tangani `clientTransactionId` jika dikirimkan oleh Flutter:

```typescript
const clientTransactionId = body.clientTransactionId;
if (clientTransactionId) {
  const existingOrder = await prisma.order.findUnique({
    where: { clientTransactionId },
  });
  if (existingOrder) {
    return NextResponse.json({
      paymentUrl: existingOrder.snapToken || null,
      orderId: existingOrder.id,
      qrString: null,
      amount: existingOrder.totalAmount,
      expiryPeriod: 10,
    });
  }
}
```
Dan pastikan field `clientTransactionId` disimpan saat `prisma.order.create`.

---

## 4. Spesifikasi Teknis Frontend (`tiknol-mobile-flutter`)

### A. Tambah Method di `OrderService` (`lib/services/order_service.dart`)
Tambahkan method langsung tanpa class exception berbelit-belit:

```dart
Future<void> manuallyConfirmPayment({
  required String orderId,
  String? note,
}) async {
  if (orderId.isEmpty) throw ArgumentError('orderId kosong');
  final api = ref.read(apiClientProvider);

  try {
    final response = await api.client.post(
      '/api/payment/manual-confirm',
      data: {
        'orderId': orderId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Gagal melakukan konfirmasi manual');
    }
  } on DioException catch (e) {
    final serverMsg = e.response?.data is Map ? e.response?.data['error'] : null;
    throw Exception(serverMsg ?? 'Gangguan jaringan: ${e.type.name}');
  }
}
```

### B. UI & Timer di `QrisPaymentScreen` (`lib/screens/qris_payment_screen.dart`)

1. **State & Timer (10 Detik):**
   ```dart
   Timer? _manualButtonTimer;
   bool _showManualButton = false;
   bool _isSubmittingManual = false;

   @override
   void initState() {
     super.initState();
     _remainingSeconds = widget.expiryMinutes * 60;
     _startCountdown();
     _startPolling();

     // Munculkan tombol setelah 10 detik polling tanpa status PAID
     _manualButtonTimer = Timer(const Duration(seconds: 10), () {
       if (mounted && _paymentStatus == 'PENDING') {
         setState(() => _showManualButton = true);
       }
     });
   }

   @override
   void dispose() {
     _manualButtonTimer?.cancel();
     _pollTimer?.cancel();
     _countdownTimer?.cancel();
     super.dispose();
   }
   ```

2. **Tombol Fallback di Bawah Tombol Check Status:**
   ```dart
   if (_showManualButton && _paymentStatus == 'PENDING') ...[
     const SizedBox(height: 12),
     OutlinedButton.icon(
       onPressed: _isSubmittingManual ? null : _showManualConfirmDialog,
       icon: const Icon(Icons.help_outline, size: 18),
       label: const Text('Pelanggan sudah membayar?'),
       style: OutlinedButton.styleFrom(
         foregroundColor: AppColors.textSecondary,
         side: BorderSide(color: Colors.grey.shade400),
         padding: const EdgeInsets.symmetric(vertical: 14),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       ),
     ),
   ],
   ```

3. **Dialog Konfirmasi Kasir:**
   ```dart
   Future<void> _showManualConfirmDialog() async {
     final noteController = TextEditingController();

     final confirmed = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         title: Row(
           children: [
             Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
             const SizedBox(width: 8),
             const Text('Konfirmasi Manual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
           ],
         ),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(
               'Pastikan Anda telah melihat bukti pembayaran dari e-wallet/m-banking pelanggan.',
               style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
             ),
             const SizedBox(height: 12),
             Text('Order ID: ${widget.orderId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
             Text('Total: Rp ${NumberFormat('#,###', 'id').format(widget.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
             const SizedBox(height: 12),
             TextField(
               controller: noteController,
               decoration: const InputDecoration(
                 labelText: 'Catatan (opsional)',
                 hintText: 'Contoh: Terlihat berhasil di DANA pelanggan',
                 border: OutlineInputBorder(),
               ),
               maxLines: 2,
             ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(ctx, false),
             child: const Text('Batal'),
           ),
           ElevatedButton(
             onPressed: () => Navigator.pop(ctx, true),
             style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
             child: const Text('Konfirmasi Pembayaran'),
           ),
         ],
       ),
     );

     if (confirmed == true) {
       _executeManualConfirm(noteController.text);
     }
   }
   ```

4. **Eksekusi Konfirmasi Manual:**
   ```dart
   Future<void> _executeManualConfirm(String note) async {
     setState(() => _isSubmittingManual = true);
     try {
       final orderService = ref.read(orderServiceProvider);
       await orderService.manuallyConfirmPayment(
         orderId: widget.orderId,
         note: note,
       );

       if (!mounted) return;

       _stopTimers();
       _manualButtonTimer?.cancel();
       _paymentStatus = 'PAID';

       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('✅ Pembayaran dikonfirmasi manual'),
           backgroundColor: AppColors.success,
           duration: Duration(seconds: 2),
         ),
       );

       // Pop kembali dengan status 'paid', cart_panel akan otomatis menangani cetak struk & clear cart
       Navigator.pop(context, 'paid');
     } catch (e) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Gagal konfirmasi: ${e.toString().replaceAll('Exception: ', '')}'),
           backgroundColor: AppColors.danger,
         ),
       );
     } finally {
       if (mounted) setState(() => _isSubmittingManual = false);
     }
   }
   ```

### C. Sambungan ke `cart_panel.dart`
Kirim `clientTransactionId` saat membuat pesanan QRIS:
```dart
final clientTxnId = 'qris_${DateTime.now().millisecondsSinceEpoch}';
// Kirim clientTxnId ke createOnlinePayment
```
Karena `QrisPaymentScreen` me-return `'paid'`, flow yang sudah ada di `cart_panel.dart` akan langsung berjalan mulus:
- Memverifikasi status ke backend (menghasilkan `PaymentStatus.paid`)
- Membersihkan item di cart
- Membuka popup transaksi sukses
- Mencetak struk secara otomatis via Bluetooth thermal printer

---

## 5. Checklist Pelaksanaan Cepat (1 - 2 Jam)

### Langkah Backend (`tiknol-reserve-web`)
- [ ] 1. Tambah 3 field di `prisma/schema.prisma` & jalankan migrasi database.
- [ ] 2. Buat file route `app/api/payment/manual-confirm/route.ts`.
- [ ] 3. Tambahkan 3 baris guard di `app/api/notification/route.ts`.
- [ ] 4. Tambahkan pengecekan `clientTransactionId` di `app/api/tokenizer/route.ts`.

### Langkah Frontend (`tiknol-mobile-flutter`)
- [ ] 1. Tambahkan fungsi `manuallyConfirmPayment` di `lib/services/order_service.dart`.
- [ ] 2. Pasang timer 10 detik dan tombol fallback di `lib/screens/qris_payment_screen.dart`.
- [ ] 3. Pasang dialog konfirmasi kasir di `lib/screens/qris_payment_screen.dart`.
- [ ] 4. Kirim `clientTransactionId` saat panggil `createOnlinePayment` di `lib/screens/widgets/cart_panel.dart`.

### Pengujian Praktis
- [ ] 1. Buat pesanan QRIS baru di POS Flutter.
- [ ] 2. Perhatikan layar pembayaran: selama 10 detik pertama, hanya tombol biasa yang terlihat.
- [ ] 3. Di detik ke-10, tombol *"Pelanggan sudah membayar?"* muncul.
- [ ] 4. Tekan tombol, isi catatan, dan konfirmasi.
- [ ] 5. Layar kembali ke POS, keranjang kosong, struk terbit, dan record di DB memiliki `manualConfirmedAt` dan nama kasir.
