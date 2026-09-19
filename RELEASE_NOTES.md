## 📱 Nol Coffee Reserve POS App (Automated Build)

**Version:** v1.0.0+2
**Build Date:** 2026-09-19 WIB
**Branch:** master

---

### ✨ Fitur Tersedia & Update Terbaru

**🚀 What's New (Update Upload Gambar)**
- **Upload Gambar Super Cepat**: Gambar produk akan otomatis di-compress (60%) dan di-resize (maks 1080px) sebelum dikirim, menghemat kuota dan mempercepat upload.
- **Limit Gambar 2 MB**: Ukuran maksimal file sekarang dikunci di 2 MB agar sesuai dengan batasan dari server backend.
- **Fix "Gagal Menyimpan"**: Memperbaiki masalah kritis di mana proses upload gambar selalu gagal (Error 404/Bad Response) akibat konflik header global `Content-Type`.
- **Integrasi Cloudflare R2**: Seluruh sistem penyimpanan gambar kini di-host menggunakan infrastruktur Cloudflare R2 yang jauh lebih cepat dan andal.
- **Perbaikan UI Picker**: Memperbaiki bug UX di mana tombol "Simpan" terkadang tetap mati setelah memilih gambar.
- **Stabilitas Jaringan**: Menambahkan batas *send timeout* 60 detik agar aplikasi tidak *hang* saat koneksi sedang lambat.

---

**🧾 Point of Sale**
- Grid produk dengan search, filter kategori & sort harga
- Kustomisasi produk: pilih suhu (ICE/HOT) dan ukuran (M/L)
- Keranjang belanja dengan nama pelanggan, tipe order (Dine In/Takeaway), dan kode voucher
- Pembayaran Cash, QRIS (Duitku), dan Grab/Online
- Cetak struk otomatis setelah transaksi

**📱 QRIS Payment**
- QR code dengan countdown timer 10 menit
- Auto-polling status pembayaran setiap 5 detik
- Opsi tunda — QR tersimpan, cart tidak hilang

**🍳 Kitchen Display System**
- Kanban board 4 status: Baru → Dimasak → Siap → Selesai
- Update status order langsung dari layar dapur

**📋 Riwayat Transaksi**
- Filter tanggal, status, dan search by Order ID / nama pelanggan
- Detail order lengkap + cetak ulang struk

**⏱ Manajemen Shift**
- Buka shift dengan input modal awal per denominasi
- Tutup shift dengan blind count fisik vs sistem
- Laporan selisih kas otomatis

**🖨 Printer Thermal Bluetooth**
- Koneksi BLE dan Classic Bluetooth
- Editor template struk dengan live preview
- Auto-reconnect ke printer terakhir

**📦 Manajemen Produk & Inventory**
- CRUD produk: nama, harga, kategori, foto, kustomisasi
- Edit stok dan toggle ketersediaan produk real-time

---

### 📦 How to Install
1. Download the APK file below
2. Enable "Install from Unknown Sources" in Android settings
3. Open the APK file to install
4. Launch app and login with your credentials