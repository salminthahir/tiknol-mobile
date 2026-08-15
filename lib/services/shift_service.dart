import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/shift.dart';
import '../models/cash_ledger_entry.dart';

final shiftServiceProvider = Provider((ref) => ShiftService(ref));

class ShiftService {
  final Ref ref;
  ShiftService(this.ref);

  Future<ShiftCurrentResponse> getCurrentShift() async {
    final api = ref.read(apiClientProvider);
    final response = await api.client.get('/api/shift/current');
    return ShiftCurrentResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Shift> openShift({required int startCash}) async {
    final api = ref.read(apiClientProvider);
    final response = await api.client.post(
      '/api/shift/open',
      data: {'startCash': startCash},
    );
    return Shift.fromCurrentJson(response.data as Map<String, dynamic>);
  }

  Future<ShiftCloseResult> closeShift({
    required String shiftId,
    required int physicalCount,
    required int step,
    String? closingNotes,
  }) async {
    final api = ref.read(apiClientProvider);
    final response = await api.client.post(
      '/api/shift/close',
      data: {
        'step': step,
        'shiftId': shiftId,
        'physicalCount': physicalCount,
        if (closingNotes != null && closingNotes.isNotEmpty)
          'closingNotes': closingNotes,
      },
    );

    final data = response.data as Map<String, dynamic>;

    if (step == 1) {
      return ShiftCloseResult.review(
        expectedCash: (data['expectedCash'] as num).toInt(),
        difference: (data['difference'] as num).toInt(),
        message: data['message'] as String? ?? '',
      );
    } else {
      return ShiftCloseResult.closed(
        isFlagged: data['isFlagged'] as bool? ?? false,
        difference: (data['difference'] as num?)?.toInt() ?? 0,
      );
    }
  }

  Future<ShiftLedger> getShiftLedger(String shiftId) async {
    final api = ref.read(apiClientProvider);
    final response = await api.client.get('/api/shift/$shiftId/ledger');
    return ShiftLedger.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ShiftSummary> getShiftSummary(String shiftId) async {
    final api = ref.read(apiClientProvider);
    final response = await api.client.get('/api/shift/$shiftId/summary');
    return ShiftSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CashLedgerEntry> recordManualCash({
    required CashLedgerType type,
    required int amount,
    required String note,
    String? clientTxnId,
  }) async {
    final api = ref.read(apiClientProvider);
    final backendType = type == CashLedgerType.cashOut ? 'CASH_OUT' : 'CASH_IN_OTHER';

    final response = await api.client.post(
      '/api/cash-ledger',
      data: {
        'type': backendType,
        'amount': amount,
        'note': note,
        if (clientTxnId != null) 'clientTxnId': clientTxnId,
      },
    );

    return CashLedgerEntry.fromJson(response.data as Map<String, dynamic>);
  }
}
