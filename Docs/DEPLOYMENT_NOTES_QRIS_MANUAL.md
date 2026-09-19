# Deployment Notes: QRIS Manual Confirmation Fallback

Dokumen ini berisi rangkuman perubahan pada sisi Backend (`tiknol-reserve-web`) untuk persiapan deployment ke server produksi. Perubahan ini mengimplementasikan fitur konfirmasi manual (fallback) ketika sistem Duitku mengalami keterlambatan (delay) atau gangguan.

## 1. Perubahan Database (Prisma Schema)
Terdapat penambahan 4 kolom baru pada tabel `Order` di file `prisma/schema.prisma`.

**Sebelumnya:**
```prisma
model Order {
  // ... field lain ...
  // Cash ledger entries (only for CASH transactions)
}
```

**Setelah Diubah:**
```prisma
model Order {
  // ... field lain ...

  // Idempotency key (untuk sync offline dari Flutter / mencegah double-tap)
  clientTransactionId String? @unique

  // Audit Manual Confirmation (Fallback QRIS)
  manualConfirmedAt   DateTime?
  manualConfirmedBy   String?   // userId kasir dari staff_session
  manualConfirmNote   String?   // Catatan kasir (opsional)

  // Cash ledger entries (only for CASH transactions)
}
```

### Tindakan Deployment:
Saat deployment ke server production, wajib menjalankan migrasi database:
```bash
npx prisma migrate deploy
# ATAU jika menggunakan push:
npx prisma db push
```

---

## 2. Endpoint Baru: Konfirmasi Manual QRIS
Terdapat pembuatan 1 rute API (endpoint) baru.

- **Path:** `POST /api/payment/manual-confirm`
- **File:** `app/api/payment/manual-confirm/route.ts`
- **Fungsi:** Menerima permintaan dari POS kasir untuk mengesahkan pembayaran secara manual ketika polling gagal. Endpoint ini akan mengubah status `Order` dari `PENDING` menjadi `PAID` dan merekam data audit (`manualConfirmedAt`, `manualConfirmedBy`, dan `note`).

---

## 3. Modifikasi Endpoint yang Sudah Ada

### A. Webhook Duitku (`/api/notification`)
- **File:** `app/api/notification/route.ts`
- **Perubahan:** Menambahkan "guard" (pelindung) agar webhook yang datang terlambat dari Duitku **tidak menimpa** data pesanan yang sudah dikonfirmasi secara manual oleh kasir.
- **Logika Tambahan:**
  ```typescript
  if (existingOrder.manualConfirmedAt) {
    console.log(`[Webhook] Order ${merchantOrderId} sudah dikonfirmasi manual. Melewati update webhook.`);
    return NextResponse.json({ success: true, message: "Already manually confirmed" });
  }
  ```

### B. Tokenizer Pembayaran (`/api/tokenizer`)
- **File:** `app/api/tokenizer/route.ts`
- **Perubahan:** Menambahkan dukungan Idempotency. Kini menerima `clientTransactionId` dari Flutter.
- **Fungsi:** Mencegah terjadinya *double-tap* atau tagihan ganda jika koneksi POS tidak stabil saat menekan tombol checkout QRIS. Jika `clientTransactionId` yang sama dikirimkan dua kali, server hanya akan mengembalikan data QRIS yang sudah dibuat sebelumnya tanpa membuat transaksi Duitku yang baru.

---

## Ringkasan Langkah Deployment (Server)
1. Lakukan `git pull` (atau prosedur deployment CI/CD Anda) untuk menarik versi kode terbaru.
2. Jalankan `npm install` (opsional, untuk memastikan dependensi lengkap).
3. **Penting:** Jalankan `npx prisma db push` (atau `migrate deploy`) untuk menambahkan 4 kolom baru di tabel `Order`. Tanpa ini, endpoint akan mengalami *Error 500* karena kolom tidak ditemukan.
4. Lakukan _build_ ulang aplikasi Next.js (`npm run build`).
5. _Restart_ _service_ Next.js (misalnya via PM2: `pm2 restart tiknol-reserve-web`).
