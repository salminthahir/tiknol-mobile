# Algoritma Flutter: Shift & Cash Reconciliation

## 1. Data Models (Dart)

```dart
// ============================================
// DATA MODELS
// ============================================

enum ShiftStatus { OPEN, CLOSED }

enum CashLedgerType {
  MODAL_AWAL,       // + uang masuk (modal awal)
  SALE_CASH_IN,     // + uang masuk (penjualan tunai)
  CHANGE_OUT,       // - uang keluar (kembalian)
  CASH_IN_OTHER,    // + uang masuk (kas masuk manual)
  CASH_OUT,         // - uang keluar (kas keluar manual)
}

class Shift {
  final String id;
  final String branchId;
  final String cashierName;
  final int startCash;
  final DateTime startTime;
  final DateTime? endTime;
  final ShiftStatus status;
  final int? expectedCash;
  final int? actualCash;
  final int? difference;
  final String? closingNotes;

  Shift.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        branchId = json['branchId'],
        cashierName = json['cashierName'] ?? 'Unknown',
        startCash = json['startCash'] ?? 0,
        startTime = DateTime.parse(json['startTime']),
        endTime = json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        status = ShiftStatus.values.firstWhere((e) => e.name == json['status']),
        expectedCash = json['expectedCash'],
        actualCash = json['actualCash'],
        difference = json['difference'],
        closingNotes = json['closingNotes'];
}

class CashLedgerEntry {
  final String id;
  final String shiftId;
  final CashLedgerType type;
  final int amount;
  final String? refOrderId;
  final String? note;
  final String? clientTxnId;
  final DateTime createdAt;

  CashLedgerEntry.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        shiftId = json['shiftId'],
        type = CashLedgerType.values.firstWhere((e) => e.name == json['type']),
        amount = json['amount'],
        refOrderId = json['refOrderId'],
        note = json['note'],
        clientTxnId = json['clientTxnId'],
        createdAt = DateTime.parse(json['createdAt']);
}

class OfflineTransaction {
  final String clientTransactionId;
  final String shiftId;
  final Map<String, dynamic> orderData;
  final DateTime createdAt;
  bool isSynced;

  OfflineTransaction({
    required this.clientTransactionId,
    required this.shiftId,
    required this.orderData,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
    'clientTransactionId': clientTransactionId,
    'shiftId': shiftId,
    'orderData': orderData,
  };
}
```

---

## 2. State Management

```dart
// ============================================
// SHIFT STATE MANAGEMENT (Riverpod / Provider)
// ============================================

class ShiftNotifier extends StateNotifier<ShiftState> {
  final ApiService apiService;
  final OfflineQueueService offlineQueue;

  ShiftNotifier(this.apiService, this.offlineQueue) : super(ShiftState.initial());

  /// Panggil saat splash screen / app start
  Future<void> checkActiveShift() async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await apiService.get('/api/shift/current');

      if (response['hasActiveShift'] == false) {
        state = ShiftState(
          hasActiveShift: false,
          currentShift: null,
          expectedCash: 0,
          isLoading: false,
        );
      } else {
        final shift = Shift.fromJson(response);
        state = ShiftState(
          hasActiveShift: true,
          currentShift: shift,
          expectedCash: response['expectedCash'] ?? 0,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Buka shift baru
  Future<bool> openShift(int startCash) async {
    try {
      final response = await apiService.post('/api/shift/open', body: {
        'startCash': startCash,
      });
      final shift = Shift.fromJson(response);
      state = ShiftState(
        hasActiveShift: true,
        currentShift: shift,
        expectedCash: startCash,
        isLoading: false,
      );
      return true;
    } catch (e) {
      if (e is ApiException && e.statusCode == 409) {
        // Shift sudah ada, refresh
        await checkActiveShift();
      }
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Tutup shift (step 1: review, step 2: confirm)
  Future<ShiftCloseResult> closeShift({
    required String shiftId,
    required int physicalCount,
    required int step,
    String? closingNotes,
  }) async {
    try {
      final response = await apiService.post('/api/shift/close', body: {
        'step': step,
        'shiftId': shiftId,
        'physicalCount': physicalCount,
        if (closingNotes != null) 'closingNotes': closingNotes,
      });

      if (step == 1) {
        return ShiftCloseResult.review(
          expectedCash: response['expectedCash'],
          difference: response['difference'],
          message: response['message'],
        );
      } else {
        state = ShiftState(
          hasActiveShift: false,
          currentShift: null,
          expectedCash: 0,
          isLoading: false,
        );
        return ShiftCloseResult.closed(
          isFlagged: response['isFlagged'],
          difference: response['difference'],
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return ShiftCloseResult.error(e.toString());
    }
  }

  /// Update expected cash setelah transaksi baru
  Future<void> refreshExpectedCash() async {
    if (state.currentShift == null) return;
    try {
      final response = await apiService.get('/api/shift/current');
      state = state.copyWith(expectedCash: response['expectedCash'] ?? 0);
    } catch (_) {}
  }
}

class ShiftState {
  final bool hasActiveShift;
  final Shift? currentShift;
  final int expectedCash;
  final bool isLoading;
  final String? error;

  ShiftState({
    required this.hasActiveShift,
    required this.currentShift,
    required this.expectedCash,
    required this.isLoading,
    this.error,
  });

  factory ShiftState.initial() => ShiftState(
    hasActiveShift: false,
    currentShift: null,
    expectedCash: 0,
    isLoading: true,
  );

  ShiftState copyWith({bool? hasActiveShift, Shift? currentShift, int? expectedCash, bool? isLoading, String? error}) =>
      ShiftState(
        hasActiveShift: hasActiveShift ?? this.hasActiveShift,
        currentShift: currentShift ?? this.currentShift,
        expectedCash: expectedCash ?? this.expectedCash,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
```

---

## 3. Algoritma Layar: Buka Shift

```
┌─────────────────────────────────┐
│         SPLASH SCREEN           │
│                                 │
│  1. GET /api/shift/current     │
│     ↓                           │
│  2. hasActiveShift == true?     │
│     ├─ YES → Home Kasir        │
│     └─ NO  → Buka Shift Screen │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│       BUKA SHIFT SCREEN         │
│                                 │
│  1. Input modal awal (startCash)│
│     - Bisa numeric input        │
│     - Bisa breakdown pecahan:   │
│       100rb x 5 = 500.000      │
│       50rb  x 0 = 0            │
│       20rb  x 0 = 0            │
│       Total = 500.000           │
│                                 │
│  2. Tap "Buka Shift"           │
│     ↓                           │
│  3. POST /api/shift/open       │
│     { startCash: 500000 }      │
│     ↓                           │
│  4. Success?                   │
│     ├─ YES → simpan shiftId    │
│     │         ke state         │
│     │         → Home Kasir     │
│     └─ NO  → tampilkan error   │
│        (409 = shift sudah ada) │
└─────────────────────────────────┘
```

**Dart:**
```dart
class OpenShiftScreen extends StatefulWidget { ... }

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final _controller = TextEditingController();
  final _denominations = <DenominationEntry>[];

  int get _totalFromDenominations =>
      _denominations.fold(0, (sum, d) => sum + (d.value * d.count));

  int get _startCash => _denominations.isNotEmpty
      ? _totalFromDenominations
      : (int.tryParse(_controller.text) ?? 0);

  Future<void> _openShift() async {
    if (_startCash < 0) return;

    final success = await ref.read(shiftProvider.notifier).openShift(_startCash);
    if (success && mounted) {
      context.go('/home');
    }
  }
}

class DenominationEntry {
  final int value;
  int count;
  DenominationEntry(this.value, this.count);
}
```

---

## 4. Algoritma: Home Kasir (Input Uang Diterima)

```
┌─────────────────────────────────────────────────┐
│               HOME KASIR                         │
│                                                  │
│  Saat user tap "Bayar" → muncul Payment Dialog  │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │         PAYMENT DIALOG                       │ │
│  │                                              │ │
│  │  Pilih metode:                               │ │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────────┐   │ │
│  │  │ CASH │ │ QRIS │ │DEBIT │ │ TRANSFER │   │ │
│  │  └──────┘ └──────┘ └──────┘ └──────────┘   │ │
│  │                                              │ │
│  │  [Jika CASH dipilih]                         │ │
│  │  Total Tagihan:  Rp 25.000                  │ │
│  │  Uang Diterima:  Rp ______  ← INPUT         │ │
│  │  Kembalian:      Rp _____   ← AUTO HITUNG   │ │
│  │                                              │ │
│  │  ┌────────────────────────────────────┐      │ │
│  │  │ Quick Amount Buttons:              │      │ │
│  │  │ [25rb] [50rb] [100rb] [Uang Pas]  │      │ │
│  │  └────────────────────────────────────┘      │ │
│  │                                              │ │
│  │  [Jika non-CASH]                             │ │
│  │  → Tidak perlu uangDiterima/kembalian        │ │
│  │  → Langsung call /api/tokenizer              │ │
│  │                                              │ │
│  │  Tap "Proses Pembayaran"                     │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

**Dart — Algoritma hitung kembalian real-time:**
```dart
class PaymentDialog extends StatefulWidget { ... }

class _PaymentDialogState extends State<PaymentDialog> {
  String selectedMethod = 'CASH';
  final _uangDiterimaController = TextEditingController();
  int totalTagihan = 25000;

  int get _uangDiterima => int.tryParse(_uangDiterimaController.text) ?? 0;
  int get _kembalian => _uangDiterima - totalTagihan;
  bool get _isValid => selectedMethod != 'CASH' || _uangDiterima >= totalTagihan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (selectedMethod == 'CASH') ...[
          Text('Total: ${formatMoney(totalTagihan)}'),
          TextField(
            controller: _uangDiterimaController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Uang Diterima'),
          ),
          Text('Kembalian: ${formatMoney(_kembalian)}'),
        ],
        ElevatedButton(
          onPressed: _isValid ? _processPayment : null,
          child: const Text('Proses Pembayaran'),
        ),
      ],
    );
  }

  Future<void> _processPayment() async {
    final shiftId = ref.read(shiftProvider).currentShift?.id;
    if (shiftId == null) return;

    if (selectedMethod == 'CASH') {
      final clientTxnId = const Uuid().v4();
      final response = await apiService.post('/api/cash-order', body: {
        'shiftId': shiftId,
        'customerName': 'Customer POS',
        'whatsapp': 'N/A',
        'orderType': 'DINE_IN',
        'items': widget.cartItems.map((i) => i.toJson()).toList(),
        'totalAmount': totalTagihan,
        'subtotal': totalTagihan,
        'discountAmount': 0,
        'shiftId': shiftId,
        'uangDiterima': _uangDiterima,
        'clientTransactionId': clientTxnId,
      });

      final kembalian = response['kembalian'] ?? 0;

      // Tampilkan kembalian ke kasir sebelum print struk
      _showChangeDialog(kembalian);

      // Refresh expected cash
      await ref.read(shiftProvider.notifier).refreshExpectedCash();

    } else {
      // Non-CASH: QRIS / Debit / Transfer
      final response = await apiService.post('/api/tokenizer', body: {
        'shiftId': shiftId,
        'customerName': 'Customer POS',
        'whatsapp': 'N/A',
        'orderType': 'DINE_IN',
        'items': widget.cartItems.map((i) => i.toJson()).toList(),
        'subtotal': totalTagihan,
        'discountAmount': 0,
        'paymentMethod': selectedMethod == 'QRIS' ? 'SP' : selectedMethod,
      });

      // Handle QRIS / payment redirect
      final paymentUrl = response['paymentUrl'];
      final qrString = response['qrString'];
      if (qrString != null) {
        _showQRCode(qrString);
      } else if (paymentUrl != null) {
        _redirectPayment(paymentUrl);
      }
    }
  }
}
```

---

## 5. Algoritma: Catat Kas Keluar/Masuk (Manual Entry)

```
┌─────────────────────────────────────────┐
│     CATAT KAS KELUAR/MASUK MODAL        │
│                                         │
│  Jenis:  [CASH_OUT ▼]  / [CASH_IN ▼]  │
│  Jumlah: Rp ______                      │
│  Catatan: _____________________________ │
│           (WAJIB untuk kas keluar/masuk)│
│                                         │
│  [Batal]              [Simpan]          │
└─────────────────────────────────────────┘

Flow:
1. User tap "Catat Kas" di Home Kasir
2. Modal muncul → pilih jenis, isi jumlah + catatan
3. Generate clientTxnId = uuid.v4()
4. POST /api/cash-ledger
5. Success → tutup modal, refresh expected cash
```

**Dart:**
```dart
Future<void> _recordManualCash() async {
  final shiftId = ref.read(shiftProvider).currentShift?.id;
  if (shiftId == null) return;

  // Show dialog, get user input
  final result = await showDialog<CashManualEntry>(
    context: context,
    builder: (_) => ManualCashDialog(),
  );
  if (result == null) return;

  final clientTxnId = const Uuid().v4();

  final response = await apiService.post('/api/cash-ledger', body: {
    'type': result.type.name,
    'amount': result.amount,
    'note': result.note,
    'clientTxnId': clientTxnId,
  });

  if (response != null) {
    await ref.read(shiftProvider.notifier).refreshExpectedCash();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kas berhasil dicatat')),
    );
  }
}

class CashManualEntry {
  final CashLedgerType type;
  final int amount;
  final String note;
  CashManualEntry(this.type, this.amount, this.note);
}
```

---

## 6. Algoritma: Tutup Shift (2-Step Blind Count)

```
┌───────────────────────────────────────────────┐
│            TUTUP SHIFT - STEP 1               │
│         (JANGAN tampilkan expected!)          │
│                                               │
│  Hitung fisik kas:                            │
│  ┌──────────────────────────────────────────┐ │
│  │  100.000 x ___  = Rp _______             │ │
│  │   50.000 x ___  = Rp _______             │ │
│  │   20.000 x ___  = Rp _______             │ │
│  │   10.000 x ___  = Rp _______             │ │
│  │    5.000 x ___  = Rp _______             │ │
│  │    2.000 x ___  = Rp _______             │ │
│  │    1.000 x ___  = Rp _______             │ │
│  │    500   x ___  = Rp _______             │ │
│  │    200   x ___  = Rp _______             │ │
│  │    100   x ___  = Rp _______             │ │
│  ├──────────────────────────────────────────┤ │
│  │  TOTAL FISIK:  Rp 1.300.000             │ │
│  └──────────────────────────────────────────┘ │
│                                               │
│  [Batal]              [Lihat Selisih →]      │
│                                               │
│  Tap "Lihat Selisih" → POST step=1          │
└───────────────────────────────────────────────┘
                        ↓
┌───────────────────────────────────────────────┐
│            TUTUP SHIFT - STEP 2               │
│               (REVIEW)                        │
│                                               │
│  Expected Cash:   Rp 1.250.000              │ │
│  Actual Cash:     Rp 1.300.000              │ │
│  ─────────────────────────────────────        │ │
│  Selisih:         Rp    50.000  ⚠️           │ │
│                                               │ │
│  Catatan (opsional):                          │ │
│  [____________________________________]       │ │
│                                               │ │
│  [← Kembali]       [Konfirmasi Tutup Shift]  │ │
└───────────────────────────────────────────────┘
                        ↓
              POST step=2 + closingNotes
                        ↓
              Success?
              ├─ YES → Navigate ke splash → check shift
              └─ NO  → Error snackbar
```

**Dart:**
```dart
class CloseShiftScreen extends StatefulWidget { ... }

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  int _currentStep = 1;
  int _physicalCount = 0;
  int? _expectedCash;
  int? _difference;
  String? _message;
  bool _isFlagged = false;
  final _closingNotesController = TextEditingController();
  final _denominations = <DenominationEntry>[];

  // Step 1 denominations
  static const _denominationValues = [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100];

  int get _totalPhysicalCount =>
      _denominations.fold(0, (sum, d) => sum + (d.value * d.count));

  Future<void> _submitStep1() async {
    _physicalCount = _totalPhysicalCount;
    final shiftId = ref.read(shiftProvider).currentShift!.id;

    final result = await ref.read(shiftProvider.notifier).closeShift(
      shiftId: shiftId,
      physicalCount: _physicalCount,
      step: 1,
    );

    if (result is ShiftCloseReviewResult) {
      setState(() {
        _currentStep = 2;
        _expectedCash = result.expectedCash;
        _difference = result.difference;
        _message = result.message;
      });
    }
  }

  Future<void> _confirmClose() async {
    final shiftId = ref.read(shiftProvider).currentShift!.id;

    final result = await ref.read(shiftProvider.notifier).closeShift(
      shiftId: shiftId,
      physicalCount: _physicalCount,
      step: 2,
      closingNotes: _closingNotesController.text.isNotEmpty
          ? _closingNotesController.text
          : null,
    );

    if (result is ShiftClosedResult) {
      if (result.isFlagged) {
        // Show warning dialog
        _showFlaggedWarning(result.difference);
      }
      // Navigate back to splash
      context.go('/splash');
    }
  }
}
```

---

## 7. Algoritma: Offline Queue & Sync

```
┌────────────────────────────────────────────┐
│          OFFLINE TRANSACTION FLOW           │
│                                            │
│  User proses transaksi                    │
│     ↓                                      │
│  Internet check:                           │
│  ├─ ONLINE → POST langsung ke API         │
│  └─ OFFLINE → simpan ke local queue       │
│               (Hive / SQLite / Isar)      │
│                                            │
│  Background sync (saat online kembali):   │
│     ↓                                      │
│  Ambil semua unsynced transactions        │
│     ↓                                      │
│  POST /api/order/sync                     │
│  { transactions: [...] }                  │
│     ↓                                      │
│  Response: { synced: 5, skipped: 2 }     │
│     ↓                                      │
│  Mark synced → hapus dari queue          │
│  Mark skipped → hapus dari queue (duplikat)│
└────────────────────────────────────────────┘
```

**Dart:**
```dart
class OfflineQueueService {
  final Box<OfflineTransaction> _box;

  OfflineQueueService(this._box);

  /// Simpan transaksi ke queue saat offline
  Future<void> enqueue(OfflineTransaction transaction) async {
    await _box.add(transaction);
  }

  /// Sync batch saat online
  Future<SyncResult> syncPending(ApiService api) async {
    final unsynced = _box.values.where((t) => !t.isSynced).toList();
    if (unsynced.isEmpty) return SyncResult(0, 0, 0);

    final batch = unsynced.map((t) => t.toJson()).toList();

    final response = await api.post('/api/order/sync', body: {
      'transactions': batch,
    });

    final synced = response['synced'] ?? 0;
    final skipped = response['skipped'] ?? 0;

    // Mark synced & skipped as synced (remove dari queue)
    for (final trx in unsynced) {
      trx.isSynced = true;
      await _box.put(trx);
    }

    // Clean up
    await _box.deleteAll(
      _box.values.where((t) => t.isSynced).map((t) => t.key),
    );

    return SyncResult(synced, skipped, batch.length);
  }
}

class ConnectivityService {
  /// Listen connectivity changes
  Stream<bool> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged.map((result) {
        return result != ConnectivityResult.none;
      });

  /// Periodic sync trigger
  void startSyncListener(OfflineQueueService queue, ApiService api) {
    onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        queue.syncPending(api);
      }
    });
  }
}

class SyncResult {
  final int synced;
  final int skipped;
  final int total;
  SyncResult(this.synced, this.skipped, this.total);
}
```

---

## 8. Algoritma: Cash Order dengan Offline Fallback

```
┌─────────────────────────────────────────────┐
│         PROSES PEMBAYARAN CASH              │
│                                             │
│  1. Generate clientTransactionId = uuid()  │
│                                             │
│  2. Check connectivity                     │
│     ├─ ONLINE:                             │
│     │   POST /api/cash-order              │
│     │   { shiftId, uangDiterima,           │
│     │     clientTransactionId, ... }       │
│     │   ↓                                  │
│     │   Success → tampilkan kembalian     │
│     │   ↓                                  │
│     │   Refresh expected cash              │
│     │                                      │
│     └─ OFFLINE:                            │
│         Simpan ke offline queue:           │
│         {                                  │
│           clientTransactionId: uuid(),     │
│           shiftId: currentShiftId,         │
│           orderData: {                     │
│             totalAmount: 25000,            │
│             uangDiterima: 50000,           │
│             paymentType: 'CASH',           │
│             items: [...]                   │
│           }                                │
│         }                                  │
│         ↓                                  │
│         Hitung kembalian LOCALLY:          │
│         kembalian = uangDiterima - total   │
│         ↓                                  │
│         Tampilkan kembalian ke kasir      │
│         ↓                                  │
│         Tampilkan indikator "Offline"     │
└─────────────────────────────────────────────┘
```

**Dart:**
```dart
Future<void> processCashPayment({
  required int totalAmount,
  required int uangDiterima,
  required List<CartItem> items,
}) async {
  final shiftId = ref.read(shiftProvider).currentShift?.id;
  final isOnline = await Connectivity().checkConnectivity() != ConnectivityResult.none;

  final clientTxnId = const Uuid().v4();
  final kembalian = uangDiterima - totalAmount;

  if (isOnline && shiftId != null) {
    // Online: langsung ke server
    try {
      final response = await apiService.post('/api/cash-order', body: {
        'customerName': 'Customer POS',
        'whatsapp': 'N/A',
        'orderType': 'DINE_IN',
        'items': items.map((i) => i.toJson()).toList(),
        'totalAmount': totalAmount,
        'subtotal': totalAmount,
        'discountAmount': 0,
        'shiftId': shiftId,
        'uangDiterima': uangDiterima,
        'clientTransactionId': clientTxnId,
      });

      await ref.read(shiftProvider.notifier).refreshExpectedCash();
      _showReceipt(response, kembalian);
    } catch (e) {
      // Fallback ke offline
      await _saveOfflineAndShowReceipt(clientTxnId, shiftId, totalAmount, uangDiterima, kembalian, items);
    }
  } else {
    // Offline: simpan ke queue
    await _saveOfflineAndShowReceipt(clientTxnId, shiftId, totalAmount, uangDiterima, kembalian, items);
  }
}

Future<void> _saveOfflineAndShowReceipt(
  String clientTxnId,
  String? shiftId,
  int totalAmount,
  int uangDiterima,
  int kembalian,
  List<CartItem> items,
) async {
  final offlineTx = OfflineTransaction(
    clientTransactionId: clientTxnId,
    shiftId: shiftId ?? 'pending',
    orderData: {
      'totalAmount': totalAmount,
      'uangDiterima': uangDiterima,
      'paymentType': 'CASH',
      'items': items.map((i) => i.toJson()).toList(),
      'customerName': 'Customer POS',
    },
    createdAt: DateTime.now(),
  );

  await ref.read(offlineQueueProvider).enqueue(offlineTx);
  _showReceiptOffline(clientTxnId, kembalian);
}
```

---

## 9. Screen Navigation Flow

```
App Start
    ↓
SplashScreen
    ↓
GET /api/shift/current
    ↓
┌─── hasActiveShift? ───┐
│                        │
YES                     NO
│                        │
↓                        ↓
HomeKasir           OpenShiftScreen
(shiftId loaded)         │
    │                    ↓
    │              POST /api/shift/open
    │                    │
    │                    ↓
    │              HomeKasir
    │                    │
    ├────────────────────┤
    │                    │
    ├── Bayar CASH → PaymentDialog (input uangDiterima → kembalian)
    ├── Bayar QRIS → PaymentDialog → /api/tokenizer → QR screen
    ├── Catat Kas → ManualCashDialog → /api/cash-ledger
    └── Tutup Shift → CloseShiftScreen (step 1 → step 2)
                              │
                              ↓
                        Navigate ke SplashScreen
```

---

## 10. Ringkasan Implementasi Flutter

| No | Komponen | Endpoint | Estimasi |
|----|----------|----------|----------|
| 1 | Splash + check shift | `GET /api/shift/current` | 1 jam |
| 2 | Screen: Buka Shift | `POST /api/shift/open` | 2 jam |
| 3 | Payment Dialog (uangDiterima + kembalian) | `POST /api/cash-order` | 3 jam |
| 4 | Non-CASH payment flow | `POST /api/tokenizer` | 2 jam |
| 5 | Manual cash entry modal | `POST /api/cash-ledger` | 1 jam |
| 6 | Screen: Tutup Shift (2-step) | `POST /api/shift/close` | 3 jam |
| 7 | Offline queue + sync | `POST /api/order/sync` | 3 jam |
| 8 | Connectivity listener + auto-sync | Background | 1 jam |
| **Total** | | | **~16 jam** |

---

**Document Version**: 1.0
**Date**: 2026-08-11
**Status**: Ready for Flutter implementation
