# Tiknol Mobile Flutter — Session Recap
## Ringkasan Kerja untuk Sesi Berikutnya

**Project:** `tiknol-mobile-flutter` (POS Android App)
**Backend:** `tiknol-reserve-web` (Next.js API)
**Last Updated:** 2026-06-24

---

## 1. Status Implementasi

### Selesai (Done)

| Fitur | Status | File |
|-------|:------:|------|
| Staff Login (Employee ID + PIN + JWT) | ✅ | `lib/screens/login_screen.dart`, `lib/services/auth_service.dart` |
| Tablet-optimized Login (split layout) | ✅ | `lib/screens/login_screen.dart` |
| Product Grid (responsive: 3-6 kolom) | ✅ | `lib/screens/pos_screen.dart` |
| Product Images (handle relative + Supabase URLs) | ✅ | `lib/models/product.dart` |
| Cart System (add/remove/qty/customization) | ✅ | `lib/providers/cart_provider.dart` |
| Customization Sheet (temp/size, keyboard-aware) | ✅ | `lib/screens/pos_screen.dart` |
| Cart Panel (always visible di tablet) | ✅ | `lib/screens/widgets/cart_panel.dart` |
| Cash Payment | ✅ | `lib/services/order_service.dart` |
| QRIS Payment (in-app WebView) | ✅ | `lib/screens/payment_webview.dart` |
| Voucher Validation | ✅ | `lib/services/voucher_service.dart` |
| Receipt Generator (RawBT) | ✅ | `lib/services/receipt_service.dart` |
| Kitchen Display (realtime orders) | ✅ | `lib/screens/kitchen_screen.dart` |
| Order History | ✅ | `lib/screens/history_screen.dart` |
| Navigation Rail (POS/Kitchen/History) | ✅ | `lib/screens/pos_screen.dart` |
| App Theme (consistent colors) | ✅ | `lib/core/theme.dart` |
| Rate Limiting (server-side) | ✅ | `lib/rateLimit.ts` (backend) |
| JWT Session (server-side) | ✅ | `lib/session.ts` (backend) |
| PIN Hashing (bcrypt) | ✅ | `scripts/hash-existing-pins.ts` (backend) |
| `--dart-define` API URL | ✅ | `lib/core/constants.dart` |
| Session Persistence (restore token on app restart) | ✅ | `lib/providers/auth_provider.dart`, `lib/core/router.dart` |
| Auto-logout on 401 (session expired) | ✅ | `lib/core/api_client.dart`, `lib/providers/auth_provider.dart` |

### Belum Selesai (TODO)

| Fitur | Prioritas | Catatan |
|-------|:---------:|---------|
| Deep Link Validation | P1 | Validate Duitku callback URLs |
| APK Obfuscation (ProGuard/R8) | P1 | Production build security |
| Certificate Pinning | P2 | Tunda — perlu automated cert rotation strategy |
| Biometric Auth | P2 | Tunda — kurang relevan tanpa idle lock |
| Attendance (face recognition) | P2 | Complex — needs face-api.js equivalent |
| Multi-branch switching | P2 | Tidak jadi — akses branch via EmployeeAccess di DB |

---

## 2. Arsitektur Flutter App

```
lib/
├── main.dart                          # App entry + theme
├── core/
│   ├── constants.dart                 # Base URL, storage keys
│   ├── api_client.dart                # Dio + JWT cookie interceptor
│   ├── router.dart                    # GoRouter: login/pos/kitchen/history
│   └── theme.dart                     # AppColors + AppTheme
├── models/
│   ├── product.dart                   # Product + CustomizationOptions
│   └── cart_item.dart                 # CartItem with key/displayName
├── providers/
│   ├── auth_provider.dart             # AuthState + login/logout
│   ├── product_provider.dart          # Products, filters, sort, categories
│   └── cart_provider.dart             # Cart add/remove/clear + totals
├── services/
│   ├── auth_service.dart              # Staff login (ID + PIN + JWT)
│   ├── product_service.dart           # Fetch products by branch
│   ├── order_service.dart             # Cash order + Duitku online payment
│   ├── voucher_service.dart           # Validate voucher code
│   └── receipt_service.dart           # RawBT receipt generator
└── screens/
    ├── login_screen.dart              # Tablet split layout (branding + form)
    ├── pos_screen.dart                # Responsive grid + NavRail + CartPanel
    ├── kitchen_screen.dart            # Realtime order queue
    ├── history_screen.dart            # POS transaction history
    ├── payment_webview.dart           # In-app Duitku payment WebView
    └── widgets/
        └── cart_panel.dart            # Cart + voucher + payment + receipt
```

---

## 3. Backend API yang Digunakan

| Endpoint | Method | Auth | Digunakan Untuk |
|----------|--------|------|-----------------|
| `/api/auth/staff/login` | POST | No | Staff login (employeeId + pin) |
| `/api/auth/staff/logout` | POST | Cookie | Logout |
| `/api/auth/me` | GET | Cookie | Get current session info |
| `/api/admin/products` | GET | Cookie | Fetch products by branch |
| `/api/admin/orders` | GET | Cookie | Kitchen display orders |
| `/api/admin/pos-history` | GET | Cookie | Order history |
| `/api/admin/update-status` | POST | Cookie | Update order status |
| `/api/cash-order` | POST | Cookie | Create cash order |
| `/api/vouchers/validate` | POST | No | Validate voucher code |
| `/api/payment/methods` | POST | No | Get Duitku payment methods |
| `/api/tokenizer` | POST | No | Create Duitku payment |

---

## 4. Perubahan Backend (Security Fixes) yang Berpengaruh

| Perubahan | File Backend | Impact ke Flutter |
|-----------|-------------|-------------------|
| Staff login wajib PIN | `api/auth/staff/login/route.ts` | Login screen harus kirim `{employeeId, pin}` |
| Cookie JWT (bukan plain JSON) | `middleware.ts`, `lib/session.ts` | Dio interceptor capture JWT dari Set-Cookie |
| `/api/auth/session` dihapus | `api/auth/session/route.ts` | Tidak ada — Flutter tidak pakai endpoint ini |
| Default PIN `000000` dihapus | `api/auth/super-admin/login/route.ts` | Tidak ada impact ke Flutter POS |
| Rate limiting ditambah | `lib/rateLimit.ts` | Tidak ada impact — server-side |
| PIN hashed (bcrypt) | `scripts/hash-existing-pins.ts` | PIN yang dikirim tetap plaintext, server yang hash |
| `console.log` debug dihapus | `lib/duitku.ts`, dll | Tidak ada impact ke Flutter |
| `/api/super-admin/dashboard` di-protect | `middleware.ts` | Tidak ada impact ke Flutter POS |

---

## 5. Bug Fixes yang Sudah Dilakukan

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Cash payment blank screen | `Navigator.pop(context)` di tablet pop route (bukan drawer) | Conditional pop: hanya di phone |
| QRIS payment tidak muncul | `showModalBottomSheet` gagal tanpa Scaffold ancestor di tablet | Ganti dengan `showDialog` |
| QRIS `isNegative` error | Duitku `totalFee` adalah String, bukan number | Parse dengan `_parseNum()` helper |
| QRIS branchId missing | `/api/tokenizer` butuh `branchId` di request body | Tambah `branchId` ke `createOnlinePayment` |
| Login overflow 2.3px | Padding terlalu besar di tablet landscape | Kurangi padding + wrap di `SingleChildScrollView` |
| Product images tidak muncul | Relative path `/uploads/...` bukan full URL | Prepend `Constants.baseUrl` untuk relative paths |
| ADD TO CART terpotong | System dock/navigation bar menutupi bottom sheet | Tambah `MediaQuery.padding.bottom` |
| Payment WebView domain mismatch | Return URL pakai production domain | Check path only (`/ticket/{orderId}`), ignore domain |

---

## 6. Environment Variables

### Flutter (`--dart-define`)
```
API_BASE_URL=http://192.168.100.93:3000  (development)
API_BASE_URL=https://api.nol.coffee      (production)
```

### Backend (.env)
```
JWT_SECRET=VEK90XFVUk3/GvPVoN3vefxEVMazOQ9FMwQsRxJ12MA=
INTERNAL_API_SECRET=IJNQOmsVIdrphH4r2hytjA==
SUPER_ADMIN_PIN=918273
```

---

## 7. Dependencies Flutter

```yaml
dependencies:
  flutter_riverpod: ^3.2.1      # State management
  go_router: ^17.1.0            # Navigation
  dio: ^5.9.1                   # HTTP client
  flutter_secure_storage: ^10.0.0  # Encrypted storage (JWT)
  google_fonts: ^8.0.1          # Typography (Inter + SpaceMono)
  lucide_icons: ^0.257.0        # Icons
  cached_network_image: ^3.3.1  # Image caching
  intl: ^0.20.2                 # Number/date formatting
  url_launcher: ^6.2.5          # RawBT print intent
  webview_flutter: ^4.10.0      # In-app Duitku payment
```

### Typography (Brand Consistency dengan nol.coffee)

| Role | Font | Usage |
|------|------|-------|
| Body / UI | **Inter** via `GoogleFonts.inter()` | Semua teks, label, filter, product name, price |
| Branding / Mono | **SpaceMono** via `GoogleFonts.spaceMono()` | "NOL POS", "O" logo, label kode, est. |

Warna website `#FBC02D` (kuning) → di app `AppColors.accent` (sama).
Warna website `#1A1A1A` (dark) → di app `AppColors.darkBg` (sama).

---

## 8. Build & Deploy

### Development
```bash
cd /Users/macbooksale/Work/Projects/tiknol-mobile-flutter
flutter run -d <device_id>
```

### Production Build
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.nol.coffee \
  --obfuscate \
  --split-debug-info=build/debug-info
```

### Install ke Tablet (via ADB)
```bash
adb -s <device_id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

### ADB Wireless Connection
```bash
adb connect <tablet_ip>:<port>
adb devices -l
```

---

## 9. Login Credentials (Development)

| Portal | URL | Credentials |
|--------|-----|-------------|
| Staff POS (Flutter) | App on tablet | Employee ID + PIN |
| Staff POS (Web) | `http://localhost:3000/login` | Employee ID + PIN |
| Super Admin (Web) | `http://localhost:3000/super-admin/login` | PIN: `918273` |

### Staff Accounts
| ID | Name | Role | PIN |
|----|------|------|-----|
| DEV0ALE | ALE | STAFF | `123456` (temporary) |
| EMP-001 | Alan | STAFF | `123456` (temporary) |
| EMP-002 | Cepro | STAFF | `123456` (temporary) |
| EMP-003 | Agus | MANAGER | (hashed — reset via Super Admin) |
| EMP-004 | Manager Bacan | MANAGER | (hashed — reset via Super Admin) |

---

## 10. Known Issues & Next Steps

### Immediate
- [ ] Test QRIS payment flow end-to-end dengan Duitku sandbox
- [ ] Test cash payment + receipt print (RawBT)
- [ ] Pastikan semua product images muncul di tablet

### Short-term
- [ ] Implement `--dart-define` untuk API URL (remove hardcoded)
- [ ] Session timeout (30 menit idle → auto logout)
- [ ] APK obfuscation (ProGuard/R8) untuk production

### Long-term
- [ ] Certificate pinning
- [ ] Biometric auth
- [ ] Attendance (face recognition) — perlu library ML
- [ ] Multi-branch switching dari POS

---

## 11. File Changes Summary

### Flutter Files Created/Modified
| File | Action | Description |
|------|--------|-------------|
| `lib/core/constants.dart` | Modified | Base URL, `String.fromEnvironment` |
| `lib/core/api_client.dart` | Modified | Dio + JWT interceptor + 401 handler |
| `lib/core/router.dart` | Modified | Auth redirect guard + `_GoRouterRefreshNotifier` + FadeTransition page |
| `lib/core/theme.dart` | **Created** | AppColors + AppTheme (Inter font) |
| `lib/main.dart` | Modified | Use AppTheme + landscape lock |
| `lib/models/product.dart` | Modified | Handle relative image URLs |
| `lib/models/cart_item.dart` | **Created** | CartItem model |
| `lib/providers/auth_provider.dart` | Modified | Session restore + `sessionExpired()` + `cartProductQtyProvider` |
| `lib/providers/product_provider.dart` | **Created** | Product filters/sort |
| `lib/providers/cart_provider.dart` | Modified | `cartProductQtyProvider` (qty per product) |
| `lib/services/auth_service.dart` | **Created** | Staff login service |
| `lib/services/product_service.dart` | **Created** | Product API service |
| `lib/services/order_service.dart` | **Created** | Cash + online payment |
| `lib/services/voucher_service.dart` | **Created** | Voucher validation |
| `lib/services/receipt_service.dart` | **Created** | RawBT receipt generator |
| `lib/screens/login_screen.dart` | **Created** | Tablet split layout |
| `lib/screens/pos_screen.dart` | Modified | 5-col grid, cart badge, active nav, Inter/SpaceMono fonts, staggered grid, bounce, AnimatedSwitcher, customization UX |
| `lib/screens/widgets/cart_panel.dart` | Modified | AnimatedList (insert/remove animation) |
| `lib/main.dart` | Modified | Landscape orientation lock |
| `android/app/src/main/AndroidManifest.xml` | Modified | screenOrientation=landscape |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Modified | Native landscape lock via `requestedOrientation` |
| `ios/Runner/Info.plist` | Modified | Landscape-only orientations |
| `lib/screens/kitchen_screen.dart` | **Created** | Kitchen display |
| `lib/screens/history_screen.dart` | **Created** | Order history |
| `lib/screens/payment_webview.dart` | **Created** | In-app Duitku WebView |
| `lib/screens/widgets/cart_panel.dart` | **Created** | Cart + payment flow |
| `pubspec.yaml` | Modified | Add webview_flutter dep |
| `android/app/src/main/AndroidManifest.xml` | Modified | Add INTERNET permission |

### Backend Files Modified (Security Fixes)
| File | Action |
|------|--------|
| `lib/session.ts` | **Created** — JWT sign/verify |
| `lib/auth.ts` | **Created** — RBAC helper |
| `lib/rateLimit.ts` | **Created** — Rate limiting |
| `scripts/hash-existing-pins.ts` | **Created** — PIN migration |
| `middleware.ts` | **Modified** — JWT verify + matcher |
| `app/api/auth/staff/login/route.ts` | **Modified** — PIN requirement |
| `app/api/auth/super-admin/login/route.ts` | **Modified** — No fallback |
| `app/api/auth/session/route.ts` | **Deleted** |
| `app/api/auth/me/route.ts` | **Modified** — JWT verify |
| `app/api/upload/route.ts` | **Modified** — Auth guard |
| `app/api/notify-whatsapp/route.ts` | **Modified** — Internal secret |
| `app/api/payment/reset/route.ts` | **Modified** — Auth guard |
| `app/api/cash-order/route.ts` | **Modified** — JWT verify |
| `app/api/super-admin/dashboard/route.ts` | **Modified** — Auth guard |
| `app/api/admin/employees/route.ts` | **Modified** — RBAC + hash PIN |
| `app/api/admin/vouchers/route.ts` | **Modified** — RBAC |
| `app/api/admin/revenue/route.ts` | **Modified** — RBAC |
| `app/api/admin/branches/route.ts` | **Modified** — JWT verify |
| `app/api/admin/branches/[id]/route.ts` | **Modified** — JWT verify |
| `app/api/admin/orders/route.ts` | **Modified** — JWT verify |
| `app/api/admin/pos-history/route.ts` | **Modified** — JWT verify |
| `app/api/order/[id]/route.ts` | **Modified** — Rate limit + hide WA |
| `lib/duitku.ts` | **Modified** — Remove debug logs |
| `lib/supabaseAdmin.ts` | **Modified** — Lazy init |
| `lib/midtrans.ts` | **Modified** — Add cancelTransaction |
| `.env` | **Modified** — Add JWT_SECRET, etc. |

---

*Recap ini untuk melanjutkan kerja di sesi berikutnya.*
*Gunakan graphify untuk query arsitektur project.*
