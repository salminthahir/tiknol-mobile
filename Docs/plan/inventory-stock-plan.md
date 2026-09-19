# Inventory & Stock — Rencana Implementasi

**Status**: Draft, belum dieksekusi  
**Dibuat**: 2026-09-18  
**Scope**: Halaman inventory baru + indikator out of stock di POS screen  
**File kode relevan yang akan disentuh**:
- `lib/models/product.dart`
- `lib/providers/product_provider.dart`
- `lib/services/stock_service.dart` _(baru)_
- `lib/providers/stock_provider.dart` _(baru)_
- `lib/screens/inventory_screen.dart` _(baru)_
- `lib/screens/pos_screen.dart`
- `lib/core/router.dart`
- `lib/screens/shell_screen.dart`

---

## 1. Latar Belakang & Keputusan Desain

### 1.1 Kondisi Backend Saat Ini

API `https://api.nol.coffee` **tidak memiliki field stok numerik**. Dari `Docs/kds-supabase-plan.md`:

```
Stock/Inventory ❌ Tidak ada
→ Tambah kolom stock Int? di Prisma Product, update API /api/admin/products return stock
```

Artinya, model `Product` hanya punya `isAvailable` (boolean), tidak ada `stock: int`.

### 1.2 Keputusan

| Keputusan | Pilihan | Alasan |
|---|---|---|
| Penyimpanan stok | `SharedPreferences` (lokal per device) | Backend belum siap, tidak perlu schema change |
| Format key | `stock_{productId}` | Unique per produk, mudah di-migrate nanti |
| Nilai default stok produk baru | `99` | Agar produk yang belum pernah di-set tidak langsung out of stock |
| Trigger "out of stock" di POS | `stock == 0` **atau** `isAvailable == false` | Dua sinyal berbeda: stok fisik habis vs admin matikan manual |
| Tampilan produk out of stock di POS | Tetap muncul dengan overlay, tidak bisa di-add ke cart | Kasir tahu produk ada tapi tidak bisa dijual |
| Sinkronisasi stok antar device | Tidak ada (lokal) | Di luar scope, bisa ditangani saat backend siap |
| Pengurangan stok otomatis saat order | Tidak ada di scope ini | Butuh diskusi bisnis terpisah (kapan berkurang: saat order masuk? saat selesai?) |

### 1.3 Relasi `isAvailable` vs `stock`

```
isAvailable = false  →  Out of stock overlay (admin matikan manual)
stock == 0           →  Out of stock overlay (stok fisik habis)
isAvailable = true AND stock > 0  →  Produk normal, bisa ditambah ke cart
```

Keduanya independen. Kasir bisa set stok = 0 tanpa mematikan `isAvailable`, atau sebaliknya.

---

## 2. Arsitektur

```
┌─────────────────────────────────────────────────────┐
│  UI Layer                                           │
│  InventoryScreen     PosScreen (_ProductCard)       │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
┌──────────▼──────────────────────▼───────────────────┐
│  Provider Layer                                     │
│  stockProvider (Map<String,int>)                    │
│  stockByIdProvider (family)                         │
│  inventoryToggleProvider (toggle isAvailable)       │
│  productsProvider (semua produk, termasuk unavaila) │
└──────────┬──────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────┐
│  Service Layer                                      │
│  StockService (SharedPreferences R/W)               │
│  ProductService (updateProduct — sudah ada)         │
└─────────────────────────────────────────────────────┘
```

---

## 3. Perubahan Per File

### 3.1 `lib/providers/product_provider.dart` — MODIFIKASI

**Perubahan tunggal**: hapus filter `.where((p) => p.isAvailable)` dari `productsProvider`.

**Sebelum:**
```dart
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(authProvider);
  final productService = ref.read(productServiceProvider);
  final products = await productService.getProducts(all: false);
  return products.where((p) => p.isAvailable).toList(); // ← HAPUS baris ini
});
```

**Sesudah:**
```dart
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(authProvider);
  final productService = ref.read(productServiceProvider);
  return await productService.getProducts(all: false); // semua produk masuk
});
```

**Dampak**: Produk dengan `isAvailable: false` sekarang muncul di POS grid. Proteksi "tidak bisa ditambah ke cart" ditangani di level `_ProductCard` (lihat §3.5).

**Tidak ada perubahan lain** di file ini. `filteredProductsProvider`, `categoriesProvider`, dan filter lainnya tidak perlu diubah.

---

### 3.2 `lib/services/stock_service.dart` — BARU

Service ini hanya bertugas membaca dan menulis stok ke `SharedPreferences`. Tidak ada logika bisnis di sini.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final stockServiceProvider = Provider<StockService>((ref) => StockService());

class StockService {
  static const String _prefix = 'stock_';
  static const int _defaultStock = 99;

  /// Load semua stok yang pernah disimpan.
  /// Return: Map<productId, qty>
  Future<Map<String, int>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final result = <String, int>{};
    for (final key in keys) {
      final productId = key.substring(_prefix.length);
      result[productId] = prefs.getInt(key) ?? _defaultStock;
    }
    return result;
  }

  /// Simpan stok untuk satu produk.
  Future<void> setStock(String productId, int qty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$productId', qty);
  }

  /// Baca stok satu produk. Jika belum pernah diset, return defaultStock (99).
  Future<int> getStock(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$productId') ?? _defaultStock;
  }
}
```

**Catatan**: `SharedPreferences` sudah ada di `pubspec.yaml` (`^2.5.0`), tidak perlu tambah dependency.

---

### 3.3 `lib/providers/stock_provider.dart` — BARU

Dua provider:
1. `stockProvider` — state utama berupa `Map<String, int>` (semua stok), di-load saat pertama kali diakses.
2. `stockByIdProvider` — derived provider `.family` untuk baca stok satu produk secara reaktif.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stock_service.dart';

// ─── State Notifier ──────────────────────────────────────────────────────────

class StockNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final service = ref.read(stockServiceProvider);
    return service.loadAll();
  }

  /// Set stok produk. Optimistic update: ubah state dulu, simpan ke disk.
  Future<void> setStock(String productId, int qty) async {
    final service = ref.read(stockServiceProvider);

    // Optimistic update
    final current = state.valueOrNull ?? {};
    state = AsyncData({...current, productId: qty});

    // Persist
    await service.setStock(productId, qty);
  }

  /// Baca stok satu produk dari state saat ini.
  /// Jika belum ada di state (map belum load), return 99 (default).
  int getStockSync(String productId) {
    return state.valueOrNull?[productId] ?? 99;
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final stockProvider = AsyncNotifierProvider<StockNotifier, Map<String, int>>(
  StockNotifier.new,
);

/// Derived provider per-produk. Reaktif: rebuild saat stok produk ini berubah.
final stockByIdProvider = Provider.family<int, String>((ref, productId) {
  final stockMap = ref.watch(stockProvider).valueOrNull ?? {};
  return stockMap[productId] ?? 99; // default 99 jika belum pernah diset
});
```

---

### 3.4 `lib/screens/inventory_screen.dart` — BARU

#### Layout

Halaman berstruktur vertikal, dioptimalkan untuk tablet landscape (orientasi paksa yang sudah ada di project).

```
┌──────────────────────────────────────────────────────────────────────┐
│ AppBar: "Inventory"                                                  │
├──────────────────────────────────────────────────────────────────────┤
│ Filter chips: [ ALL ] [ COFFEE ] [ NON-COFFEE ] [ SNACK ] [ MEALS ] │
├──────┬───────────────────────┬────────────┬──────────┬──────┬───────┤
│      │ Nama Produk           │ Kategori   │ Harga    │ Stok │ On/Off│
├──────┼───────────────────────┼────────────┼──────────┼──────┼───────┤
│  🖼  │ Americano             │ COFFEE     │ Rp 25.000│  [45]│  ●   │
│  🖼  │ Matcha Latte          │ NON-COFFEE │ Rp 30.000│  [ 0]│  ○   │  ← row merah tipis
│  🖼  │ Croissant             │ SNACK      │ Rp 18.000│  [12]│  ●   │
└──────┴───────────────────────┴────────────┴──────────┴──────┴───────┘
```

#### Kolom Stok (interaksi)

- Tap angka stok → dialog kecil muncul dengan `TextField` angka
- Dialog: title "Ubah Stok", input number, tombol Batal + Simpan
- Validasi: angka >= 0, tidak boleh kosong

#### Kolom Status (isAvailable)

- `Switch` widget yang memanggil `ProductService.updateProduct`
- Optimistic update: switch berubah langsung, rollback + `SnackBar` error jika API gagal
- State toggle ini butuh `inventoryProvider` lokal di screen (Notifier sederhana)

#### State screen

```dart
class _InventoryScreenState {
  List<Product> products;      // dari productsProvider (all: true via service langsung)
  String categoryFilter;       // 'ALL' | 'COFFEE' | ...
  bool isLoading;
  String? errorMessage;
  Map<String, bool> togglingIds; // untuk disable switch saat sedang API call
}
```

**Catatan**: `InventoryScreen` memanggil `productService.getProducts(all: true)` secara langsung (bukan reuse `productsProvider` yang `all: false`), karena inventory perlu lihat **semua** produk termasuk yang `isAvailable: false`.

#### Kode Struktur (skeleton)

```dart
class InventoryScreen extends ConsumerStatefulWidget { ... }

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _categoryFilter = 'ALL';
  final Map<String, bool> _togglingIds = {};

  // Load produk langsung dari service (all: true)
  Future<void> _loadProducts() { ... }

  // Toggle isAvailable via ProductService.updateProduct
  Future<void> _toggleAvailability(Product product) async {
    if (_togglingIds[product.id] == true) return;
    setState(() => _togglingIds[product.id] = true);

    final updated = product.copyWith(isAvailable: !product.isAvailable);
    try {
      await ref.read(productServiceProvider).updateProduct(updated);
      // refresh list lokal
    } catch (e) {
      // rollback + SnackBar
    } finally {
      setState(() => _togglingIds.remove(product.id));
    }
  }

  // Edit stok: buka dialog, simpan via stockProvider
  Future<void> _editStock(Product product, int currentStock) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _StockEditDialog(initialValue: currentStock),
    );
    if (result != null) {
      await ref.read(stockProvider.notifier).setStock(product.id, result);
    }
  }

  Widget _buildRow(Product product) { ... }

  Widget _buildStockEditDialog(int initialValue) { ... }

  @override
  Widget build(BuildContext context) { ... }
}
```

#### Warna row

- Stok 0: background row `Colors.red.withOpacity(0.06)` + teks stok merah
- `isAvailable: false`: background row `Colors.grey.withOpacity(0.04)`
- Normal: background transparan

---

### 3.5 `lib/screens/pos_screen.dart` — MODIFIKASI

**Dua perubahan** di `_ProductCard`:

#### Perubahan 1: Tambah `stockByIdProvider` watch

```dart
// Di dalam _ProductCardState.build():
final qtyInCart = ref.watch(cartProductQtyProvider(widget.product.id));
final stock = ref.watch(stockByIdProvider(widget.product.id)); // ← TAMBAH
final isOutOfStock = stock == 0 || !widget.product.isAvailable; // ← TAMBAH
```

#### Perubahan 2: Disable tap jika out of stock

```dart
// GestureDetector.onTapUp:
onTapUp: (_) {
  setState(() => _isPressed = false);
  if (!isOutOfStock) _onTap(); // ← tambah guard
},
```

#### Perubahan 3: Overlay "OUT OF STOCK" di image area

Di dalam `Stack` yang sudah ada di area gambar (setelah `CachedNetworkImage`):

```dart
// Tambah setelah AnimatedContainer press highlight:
if (isOutOfStock)
  Container(
    color: Colors.black.withOpacity(0.55), // dim gambar
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'OUT OF\nSTOCK',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.reserve, // warna kuning yang sudah ada
            height: 1.3,
          ),
        ),
      ),
    ),
  ),
```

#### Perubahan 4: Sembunyikan cart qty badge jika out of stock

```dart
child: qtyInCart > 0 && !isOutOfStock  // ← tambah kondisi
    ? Container(key: ValueKey(qtyInCart), ...)
    : const SizedBox.shrink(key: ValueKey(0)),
```

**Tidak ada perubahan lain** di `pos_screen.dart`.

---

### 3.6 `lib/core/router.dart` — MODIFIKASI

Tambah route `/inventory` di dalam `ShellRoute`:

```dart
// Di dalam routes ShellRoute:
GoRoute(
  path: '/inventory',
  pageBuilder: (context, state) => const NoTransitionPage(
    child: InventoryScreen(),
  ),
),
```

Import `InventoryScreen` di atas file.

---

### 3.7 `lib/screens/shell_screen.dart` — MODIFIKASI

Tambah nav rail destination untuk Inventory. Posisi: antara `/products` dan `/printer` (urutan sesuai alur kerja).

```dart
NavigationRailDestination(
  icon: const Icon(LucideIcons.packageCheck),
  label: const Text('Inventory'),
),
```

Tambah juga di logika `_selectedIndex` dan `_onDestinationSelected` (pattern yang sama dengan destination lain yang sudah ada).

---

## 4. Urutan Eksekusi

Urutan ini penting karena ada dependency antar file.

```
Step 1  →  lib/providers/product_provider.dart  (hapus .where filter)
Step 2  →  lib/services/stock_service.dart       (buat baru)
Step 3  →  lib/providers/stock_provider.dart     (buat baru, depend on StockService)
Step 4  →  lib/screens/inventory_screen.dart     (buat baru, depend on StockProvider + ProductService)
Step 5  →  lib/screens/pos_screen.dart           (modifikasi _ProductCard, depend on StockProvider)
Step 6  →  lib/core/router.dart                  (tambah route /inventory)
Step 7  →  lib/screens/shell_screen.dart         (tambah nav item)
```

---

## 5. Edge Cases & Penanganan Error

| Skenario | Penanganan |
|---|---|
| `SharedPreferences` gagal load | `stockProvider` return `AsyncError`, `stockByIdProvider` return default `99` |
| API `updateProduct` gagal saat toggle | Rollback `isAvailable` di state lokal + tampil `SnackBar` error |
| Produk di-delete tapi stok-nya masih tersimpan di SharedPrefs | Tidak masalah — key `stock_{id}` orphan tidak berpengaruh, dibersihkan natural |
| User input stok negatif | Validasi di dialog: nilai minimum 0 |
| Produk baru yang belum pernah di-set stoknya | Default `99` dari `StockService._defaultStock` |
| Kasir sudah tambah produk ke cart, lalu stok di-set ke 0 dari inventory | Item tetap di cart (tidak di-remove otomatis). Ini by design: inventory dan cart adalah dua alur berbeda |

---

## 6. Yang Tidak Diimplementasi (Out of Scope)

| Fitur | Alasan |
|---|---|
| Stok numerik dari backend | API belum support, perlu schema change Prisma |
| Pengurangan stok otomatis saat order masuk | Butuh keputusan bisnis: berkurang saat paid? saat READY? |
| Sinkronisasi stok antar device/kasir | Membutuhkan backend. Bisa ditambah saat API siap dengan migrasi data dari SharedPrefs |
| Notifikasi stok menipis | Out of scope, bisa ditambah sebagai fitur terpisah |
| Search di inventory | Bisa ditambah later, filter kategori cukup untuk jumlah menu coffee shop |
| CRUD produk dari inventory | Sudah ada di `/products`, tidak duplikat |

---

## 7. Catatan Migrasi ke Backend (Future)

Saat backend siap menambah kolom `stock Int?` ke Prisma:

1. `StockService` ditambah method `syncToBackend(Map<String, int> localData)` untuk one-time migration.
2. `productService.getProducts()` akan return `stock` di JSON → tambah field `stock` ke `Product.fromJson`.
3. `stockProvider` diubah menjadi derived dari `productsProvider` (tidak lagi dari SharedPrefs).
4. `StockService` dan `SharedPreferences` key `stock_*` bisa dihapus.

Arsitektur lokal yang dibuat di plan ini sengaja didesain agar migration seminimal mungkin — hanya `stockProvider` yang perlu diubah, `stockByIdProvider` dan seluruh UI tidak berubah.

---

## 8. Checklist Verifikasi

Setelah implementasi selesai, verifikasi item berikut sebelum dianggap done:

### Inventory Screen
- [ ] Semua produk muncul (termasuk yang `isAvailable: false`)
- [ ] Filter kategori bekerja: ALL, COFFEE, NON-COFFEE, SNACK, MEALS
- [ ] Stok default `99` muncul untuk produk yang belum pernah di-set
- [ ] Tap angka stok → dialog terbuka, angka bisa diubah, Simpan menyimpan, Batal menutup
- [ ] Stok 0 di row inventory: background merah tipis, angka stok berwarna merah
- [ ] Toggle `isAvailable` berhasil: switch berubah langsung (optimistic), API dipanggil
- [ ] Toggle `isAvailable` gagal: switch kembali ke posisi asal, `SnackBar` error muncul
- [ ] Nav rail `/inventory` aktif saat halaman ini terbuka

### POS Screen
- [ ] Produk `isAvailable: false` muncul di grid (tidak hilang)
- [ ] Produk dengan stok 0 muncul di grid dengan overlay "OUT OF STOCK"
- [ ] Tap produk out of stock: tidak ada respons (tidak bisa di-add ke cart)
- [ ] Cart qty badge tidak muncul di produk out of stock
- [ ] Produk normal (stok > 0 dan available): perilaku tidak berubah sama sekali
- [ ] Stok yang di-ubah di inventory langsung terrefleksi di POS tanpa restart app

### Data Persistence
- [ ] Set stok di inventory, close app, buka lagi: stok tidak reset
- [ ] Stok tersimpan per produk, bukan global
