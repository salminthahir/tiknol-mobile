# KDS (Kitchen Display System) - Supabase Implementation Plan

> **Dibuat:** 26 Juni 2026, 14:30 WIB
> **Status:** Planning
> **Backend:** Supabase Realtime (PostgreSQL Changes)
> **Scope:** Flutter Mobile App - tiknol-mobile-flutter

---

## 1. Ringkasan Eksekutif

Pengembangan Kitchen Display System (KDS) menggunakan **Supabase Realtime** untuk fitur real-time order push. Fitur ini memanfaatkan mekanisme `postgres_changes` pada Supabase yang sudah terintegrasi dengan database PostgreSQL backend `tiknol-reserve-web`.

### Tujuan
- Kitchen staff mendapat notifikasi order baru **secara real-time** tanpa refresh manual
- Elapsed timer menunjukkan durasi pesanan dengan indikator warna
- Sound & vibration alert saat order baru masuk
- BUMP bar (swipe) untuk mempercepat update status
- Pengaturan status flow yang bisa dikustomisasi

---

## 2. Kondisi Backend Saat Ini (API yang Sudah Siap)

### Endpoint yang Sudah Ada dan Siap Digunakan

| Endpoint | Method | Fungsi | Response yang Tersedia |
|---|---|---|---|
| `/api/admin/orders` | GET | Ambil semua order aktif | `id`, `branchId`, `customerName`, `items` (JSON), `status`, `totalAmount`, `orderType`, `createdAt`, `paymentType` |
| `/api/admin/update-status` | POST | Update status order | Accept: `{id, status}` — Tidak ada validasi enum |
| `/api/cash-order` | POST | Buat order cash | Simpan ke DB → trigger Supabase Realtime |
| `/api/tokenizer` | POST | Buat order QRIS | Simpan ke DB → trigger Supabase Realtime |

### Field yang Sudah Ada di Database (Prisma Order Model)

```prisma
model Order {
  id             String   @id
  branchId       String
  customerName   String
  whatsapp       String
  subtotal       Int?
  discountAmount Int      @default(0)
  totalAmount    Int
  items          Json      // [{id, name, qty, price}]
  orderType      String   @default("DINE_IN")
  status         String   @default("PENDING")
  snapToken      String?
  orderSource    String   @default("WEB_CUSTOMER")
  paymentType    String
  voucherId      String?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
}
```

### Field yang Digunakan oleh KDS

| Field | Tipe | Kegunaan KDS |
|---|---|---|
| `id` | String | Order ID, ditampilkan sebagai `#xxxxxx` |
| `customerName` | String | Nama pelanggan di card |
| `items` | JSON | Daftar item: `[{id, name, qty, price}]` |
| `status` | String | Status workflow: `PAID` → `PREPARING` → `READY` → `COMPLETED` |
| `totalAmount` | Int | Total harga (opsional di KDS) |
| `createdAt` | DateTime | **Untuk elapsed timer** — hitung durasi dari sini |
| `orderType` | String | `DINE_IN` / `TAKE_AWAY` — badge di card |

### Supabase Realtime Channel yang Sudah Ada

Backend `tiknol-reserve-web` sudah menggunakan channel ini di halaman kitchen online:

```typescript
// Dari /admin/kitchen-online/page.tsx
const channel = supabase
  .channel(`realtime-admin-orders-${targetBranchId || 'all'}`)
  .on('postgres_changes', {
    event: '*',           // INSERT, UPDATE, DELETE
    schema: 'public',
    table: 'Order',
    filter: targetBranchId ? `branchId=eq.${targetBranchId}` : undefined,
  }, (payload) => {
    fetchOrders();        // Refresh data saat ada perubahan
  })
  .subscribe();
```

**Flutter akan subscribe ke channel yang sama dengan pattern identik.**

---

## 3. Kondisi Backend yang BELUM Siap

| Fitur | Status | Backend Change yang Diperlukan |
|---|---|---|
| **Special Instructions per item** | ❌ Tidak ada | Ubah struktur `items` JSON dari `{id, name, qty, price}` menjadi `{id, name, qty, price, specialInstructions?}`. Update frontend POS dan API order. |
| **Stock/Inventory** | ❌ Tidak ada | Tambah kolom `stock Int?` di Prisma `Product`, update API `/api/admin/products` return `stock` |
| **Customer Database** | ❌ Tidak ada | Buat tabel `Customer`, API `/api/customers?search={query}` |
| **Status Enum Validation** | ❌ Tidak ada | Backend terima string apa saja, seharusnya validasi: `PENDING, PAID, PREPARING, READY, COMPLETED, FAILED` |

---

## 4. Fitur yang Akan Dibuat

### 4.1 Real-Time Order Push (Supabase Realtime)

**Deskripsi:** Kitchen screen subscribe ke Supabase Realtime channel. Saat kasir membuat order baru, order langsung muncul di kitchen tanpa refresh.

**Cara Kerja:**
1. `KitchenScreen` subscribe ke channel `realtime-admin-orders-{branchId}`
2. Event `INSERT` pada tabel `Order` → payload berisi data order baru
3. Parse payload → tambahkan ke state list order
4. Trigger sound + vibration alert
5. Event `UPDATE` → update status order di list
6. Event `DELETE` → hapus order dari list (jika diperlukan)

**State Management:**
- `kitchenRealtimeProvider` (StreamProvider) — ganti `kitchenOrdersProvider` (FutureProvider)
- Data source: Supabase realtime stream, bukan HTTP GET manual

**Resource Impact:**
- Network: 1 persistent WebSocket connection per device (sangat ringan)
- Battery: Lebih hemat dari polling (tidak ada request periodik)
- Memory: Minimal — hanya stream listener

---

### 4.2 Sound & Vibration Alert

**Deskripsi:** Saat order baru masuk via realtime, play notifikasi audio dan getarkan device.

**Cara Kerja:**
1. `AlertUtils.playOrderAlert(volume, enableSound, enableVibration)` dipanggil saat event INSERT
2. Sound: play `assets/sounds/new_order.mp3` via `audioplayers`
3. Vibration: pattern `[400, 200, 400]` ms via `vibration`
4. Volume & enable/disable bisa diatur di KDS Settings

**Resource Impact:**
- Storage: file audio ~30KB di assets
- Battery: Hanya saat order baru masuk (jarang)
- CPU: Negligible

---

### 4.3 Elapsed Timer per Order

**Deskripsi:** Setiap order card menampilkan durasi sejak order dibuat, dengan indikator warna berdasarkan threshold.

**Cara Kerja:**
1. Hitung `DateTime.now().difference(order.createdAt)` setiap detik
2. Warna timer:
   - Hijau: < 5 menit (default, bisa diubah di settings)
   - Kuning: 5-10 menit
   - Merah: > 10 menit (warning)
3. Timer berhenti saat status `COMPLETED`
4. Gunakan `Timer.periodic(Duration(seconds: 1))` per card

**Resource Impact:**
- CPU: 1 timer per order card. 20 order aktif = 20 ticks/detik. Negligible karena hanya DateTime arithmetic
- Battery: Minimal
- Optimasi: Bungkus timer widget dengan `RepaintBoundary` agar hanya timer yang redraw

---

### 4.4 BUMP Bar (Swipe to Complete)

**Deskripsi:** Kitchen staff bisa swipe order card ke kanan untuk advance ke status berikutnya, lebih cepat dari menekan tombol.

**Cara Kerja:**
1. Bungkus `_OrderCard` dengan `Dismissible` widget
2. Swipe direction: startToEnd (kanan)
3. On dismissed: panggil `POST /api/admin/update-status` dengan `_nextStatus`
4. Confirmation: snackbar "Status updated to PREPARING" dengan undo action (5 detik)
5. Bisa di-enable/disable di KDS Settings

**Resource Impact:**
- CPU: Negligible (gesture handling built-in Flutter)
- Memory: Tidak ada perubahan

---

### 4.5 Status Flow Configuration (Settings)

**Deskripsi:** Screen pengaturan untuk mengkonfigurasi workflow status, timer thresholds, dan preferensi alert.

**UI Layout:**
```
┌─────────────────────────────────────┐
│ ⚙️ Kitchen Settings                  │
├─────────────────────────────────────┤
│ Status Flow                         │
│   PAID ──→ PREPARING ──→ READY ──→  │
│            COMPLETED                │
│   [Drag to reorder]                 │
├─────────────────────────────────────┤
│ Timer Thresholds                    │
│   Warning:  [====5====] minutes     │
│   Critical: [===10===] minutes      │
├─────────────────────────────────────┤
│ Alerts                              │
│   Sound:     [ON]                   │
│   Volume:    [====80%====]          │
│   Vibration: [ON]                   │
├─────────────────────────────────────┤
│ BUMP Bar                            │
│   Swipe to advance: [ON]            │
└─────────────────────────────────────┘
```

**Data Storage:** `SharedPreferences` — tidak perlu backend

**Fields yang Disimpan:**
```json
{
  "kds_status_flow": ["PAID", "PREPARING", "READY", "COMPLETED"],
  "kds_timer_warning": 5,
  "kds_timer_critical": 10,
  "kds_alert_sound": true,
  "kds_alert_volume": 0.8,
  "kds_alert_vibration": true,
  "kds_bump_bar": true
}
```

---

### 4.6 Screen Always-On (Wakelock)

**Deskripsi:** Layar kitchen tidak akan mati/lock otomatis saat KDS aktif.

**Cara Kerja:**
1. `initState`: `WakelockPlus.enable()`
2. `dispose`: `WakelockPlus.disable()`
3. Toggle di settings (opsional)

**Resource Impact:**
- Battery: Layar terus nyala. KDS biasanya dicolok charger.
- OLED: Pertimbangkan screensaver mode setelah 30 menit idle (opsional, fase 2)

---

## 5. File yang Akan Dibuat & Dimodifikasi

### File Baru

| File | Purpose | Lines (est.) |
|---|---|---|
| `lib/services/supabase_service.dart` | Init Supabase client, subscribe/unsubscribe realtime channel | ~80 |
| `lib/providers/kitchen_realtime_provider.dart` | StreamProvider untuk orders via Supabase realtime | ~60 |
| `lib/providers/kds_settings_provider.dart` | SharedPreferences-based settings state | ~80 |
| `lib/screens/widgets/order_timer.dart` | Timer widget dengan color coding | ~50 |
| `lib/screens/widgets/special_instructions_badge.dart` | Badge catatan khusus (skeleton, menunggu backend) | ~30 |
| `lib/screens/kds_settings_screen.dart` | Settings UI lengkap | ~200 |
| `lib/utils/alert_utils.dart` | Sound & vibration helper | ~60 |

**Total estimasi: ~560 lines baru**

### File yang Dimodifikasi

| File | Perubahan |
|---|---|
| `lib/screens/kitchen_screen.dart` | Major refactor: realtime stream, timer, alerts, BUMP bar, settings integration |
| `pubspec.yaml` | Tambah 6 dependencies baru |

---

## 6. Dependencies Baru

```yaml
# KDS Real-time & Alerts
supabase_flutter: ^2.3.4
audioplayers: ^5.2.1
vibration: ^1.8.4
wakelock_plus: ^1.1.4

# Shared
shared_preferences: ^2.2.2
```

**Resource Impact:**
- APK size: +3-4MB
- Memory: On-demand loading, tidak signifikan

---

## 7. Data Flow Diagram

```
┌──────────────┐         ┌──────────────────┐         ┌──────────────┐
│   POS App    │──POST──►│  Backend API     │──INSERT─►│  PostgreSQL  │
│  (Cashier)   │         │  /api/cash-order │         │  Order Table │
└──────────────┘         └──────────────────┘         └──────┬───────┘
                                                             │
                                                    postgres_changes
                                                    (Supabase Realtime)
                                                             │
                                                             ▼
┌──────────────┐         ┌──────────────────┐
│  KDS App     │◄─stream─│  Supabase        │
│  (Kitchen)   │         │  Realtime        │
│              │         │  Channel         │
│  • Timer     │         └──────────────────┘
│  • Alert     │
│  • BUMP Bar  │
└──────────────┘
         │
         │  POST /api/admin/update-status
         ▼
┌──────────────────┐         ┌──────────────┐
│  Backend API     │──UPDATE─►│  PostgreSQL  │
│  /update-status  │         │  Order Table │
└──────────────────┘         └──────────────┘
```

---

## 8. Sprint Plan

### Sprint 1: Foundation (Minggu 1)

| Task | Estimasi | Priority |
|---|---|---|
| Tambah dependencies ke `pubspec.yaml` | 15 min | Critical |
| Buat `supabase_service.dart` | 2 jam | Critical |
| Buat `kitchen_realtime_provider.dart` | 2 jam | Critical |
| Refactor `kitchen_screen.dart` pakai realtime stream | 4 jam | Critical |
| Testing realtime connection | 1 jam | Critical |

**Sprint 1 Deliverable:** Kitchen screen menerima order baru secara realtime tanpa refresh.

### Sprint 2: Alerts & Timer (Minggu 1-2)

| Task | Estimasi | Priority |
|---|---|---|
| Buat `alert_utils.dart` (sound + vibration) | 2 jam | High |
| Buat `order_timer.dart` widget | 2 jam | High |
| Integrasikan alert ke realtime provider | 1 jam | High |
| Integrasikan timer ke `_OrderCard` | 1 jam | High |
| Testing alert di device | 1 jam | High |

**Sprint 2 Deliverable:** Sound/vibration alert saat order baru, timer di setiap card.

### Sprint 3: Settings & BUMP Bar (Minggu 2)

| Task | Estimasi | Priority |
|---|---|---|
| Buat `kds_settings_provider.dart` | 2 jam | Medium |
| Buat `kds_settings_screen.dart` | 4 jam | Medium |
| Implementasi BUMP bar (Dismissible) | 2 jam | Medium |
| Integrasi settings ke kitchen screen | 2 jam | Medium |
| Tambah route settings ke router | 30 min | Medium |

**Sprint 3 Deliverable:** Full KDS dengan settings, BUMP bar, configurable alerts.

---

## 9. Risiko & Mitigasi

| Risiko | Impact | Mitigasi |
|---|---|---|
| Supabase Realtime connection timeout | KDS tidak menerima order baru | Implementasi fallback polling setiap 30 detik |
| VPS pindah dari Supabase sebelum selesai | Fitur realtime tidak berguna | Buat abstraction layer yang bisa swap ke polling/SSE |
| Battery drain di device kitchen | Device cepat habis baterai | Wakelock + charger wajib, optimasi timer |
| Audio playback gagal di beberapa device | Tidak ada alert sound | Fallback ke vibration only + visual flash |

---

## 10. Catatan Teknis

### Supabase Setup di Flutter

```dart
// lib/services/supabase_service.dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);

// Subscribe ke channel
final channel = Supabase.instance.client
    .channel('realtime-admin-orders-$branchId')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Order',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'branchId',
        value: branchId,
      ),
      callback: (payload) {
        // Handle new/updated order
      },
    )
    .subscribe();
```

### Timer Implementation

```dart
// lib/screens/widgets/order_timer.dart
class OrderTimer extends StatefulWidget {
  final DateTime createdAt;
  final int warningMinutes;
  final int criticalMinutes;

  @override
  State<OrderTimer> createState() => _OrderTimerState();
}

class _OrderTimerState extends State<OrderTimer> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.createdAt);
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.createdAt);
      });
    });
  }

  Color get _timerColor {
    final minutes = _elapsed.inMinutes;
    if (minutes >= widget.criticalMinutes) return AppColors.danger;
    if (minutes >= widget.warningMinutes) return AppColors.accent;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
      style: TextStyle(color: _timerColor, fontWeight: FontWeight.w800),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
```

---

## 11. Referensi Backend

- Backend project: `tiknol-reserve-web` (Next.js 15 + Prisma + PostgreSQL)
- Supabase Realtime docs: https://supabase.com/docs/guides/realtime
- Prisma Order model: `/prisma/schema.prisma`
- Kitchen online page (reference): `/app/(staff)/admin/kitchen-online/page.tsx`
