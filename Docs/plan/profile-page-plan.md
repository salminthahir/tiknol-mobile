# Profile Page — Rencana Implementasi

**Status**: Draft, siap dieksekusi  
**Dibuat**: 2026-09-18  
**Scope**: Halaman profil kasir + perubahan sidebar navbar (icon user + nama jadi tombol)  
**File kode relevan**:
- `lib/screens/profile_screen.dart` _(baru)_
- `lib/core/router.dart` _(modifikasi: tambah `/profile`)_
- `lib/screens/shell_screen.dart` _(modifikasi: user block di bawah navbar)_

---

## 1. Data yang Tersedia (dari `AuthState`)

| Field | Tipe | Contoh |
|---|---|---|
| `userName` | `String?` | "Budi Santoso" |
| `role` | `String?` | "CASHIER" / "ADMIN" |
| `branchId` | `String?` | "branch_01" |
| `branchName` | `String?` | "Titik Nol - Sudirman" |
| `branchCode` | `String?` | "SDR" |

Tidak ada foto profil, email, atau nomor telepon di backend saat ini. Semua yang ditampilkan di halaman Profile adalah data real dari sesi login.

---

## 2. Konten Halaman Profile

### Header: Avatar Inisial
- Lingkaran besar berisi inisial 1-2 huruf dari `userName`
- Contoh: "Budi Santoso" → **"BS"** (dua huruf pertama dari setiap kata)
- Warna background: `AppColors.primary` (#552CB7) agar ada identitas visual yang spesifik
- Nama lengkap dan role di bawah avatar

### Grup Informasi 1: Data Staff
| Label | Value |
|---|---|
| Nama | `auth.userName` |
| Role | `auth.role` (diformat: "CASHIER" → "Kasir", "ADMIN" → "Admin") |

### Grup Informasi 2: Outlet
| Label | Value |
|---|---|
| Nama Outlet | `auth.branchName` |
| Kode Outlet | `auth.branchCode` |

### Grup Informasi 3: Sistem
| Label | Value |
|---|---|
| API Server | URL dari `ServerConfigService` (SharedPreferences) |

Tiap grup ditampilkan sebagai **info list** bergaya `ListTile` sederhana dengan label di atas value, bukan card bertumpuk.

---

## 3. Layout

```
┌─────────────────────────────────────────────────────┐
│  AppBar: "Profil"                                   │
├─────────────────────────────────────────────────────┤
│                                                     │
│              ┌────────────────┐                     │
│              │   Avatar: BS   │  ← lingkaran ungu   │
│              └────────────────┘                     │
│               Budi Santoso                          │
│               Kasir                                 │
│                                                     │
├──── Informasi Staff ────────────────────────────────┤
│  Nama               Budi Santoso                    │
│  ─────────────────────────────────────              │
│  Role               Kasir                          │
├──── Outlet ─────────────────────────────────────────┤
│  Nama Outlet        Titik Nol - Sudirman            │
│  ─────────────────────────────────────              │
│  Kode Outlet        SDR                             │
├──── Sistem ─────────────────────────────────────────┤
│  API Server         https://api.nol.coffee          │
└─────────────────────────────────────────────────────┘
```

- Background: `Color(0xFFF8F9FA)` selaras dengan halaman Produk & Inventory
- Setiap grup diberi header teks kecil uppercase sebagai pemisah (bukan card terpisah) agar tidak membengkak jadi banyak card bertumpuk
- Tap pada baris API Server: tidak ada aksi (read-only, bukan link)

---

## 4. Perubahan Sidebar (`shell_screen.dart`)

### Sebelum (saat ini)
```
[Nama kecil, text saja, tidak bisa di-tap]
[Tombol Logout]
```

### Sesudah
```
┌──────────────────────┐
│  Icon User (lingkaran│  ← GestureDetector → /profile
│  inisial)            │
│  Nama (terpotong)    │
└──────────────────────┘
[Tombol Logout]
```

- Ganti blok nama text dengan sebuah `GestureDetector` yang berisi:
  - Avatar kecil (lingkaran 32px, inisial, background `AppColors.primary`)
  - Nama di bawahnya (font 8px, tetap seperti sekarang)
- Tap seluruh blok → `_handleNavigation(context, '/profile')`
- Jika sedang aktif di `/profile` → blok avatar diberi highlight background seperti `_navItem` aktif

---

## 5. File yang Dibuat / Dimodifikasi

| File | Aksi | Isi |
|---|---|---|
| `lib/screens/profile_screen.dart` | Baru | Seluruh halaman profil |
| `lib/core/router.dart` | Modifikasi | Tambah route `/profile` di ShellRoute |
| `lib/screens/shell_screen.dart` | Modifikasi | Ganti blok user di bawah navbar jadi tombol navigasi |

---

## 6. Yang Tidak Diimplementasi

| Fitur | Alasan |
|---|---|
| Ganti PIN/Password | Tidak ada endpoint API untuk ini |
| Upload foto profil | Tidak ada endpoint, tidak ada field di `AuthState` |
| Edit nama/role | Data bersumber dari server saat login, bukan user-editable di sini |
| Riwayat shift kasir ini | Out of scope untuk iterasi ini |
