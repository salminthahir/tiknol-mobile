import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift.dart';
import '../models/cash_ledger_entry.dart';
import '../services/shift_service.dart';

final shiftServiceProvider = Provider((ref) => ShiftService(ref));

final shiftProvider = NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);

class ShiftState {
  final bool hasActiveShift;
  final Shift? currentShift;
  final int expectedCash;
  final bool isLoading;
  final String? error;

  ShiftState({
    required this.hasActiveShift,
    this.currentShift,
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

  ShiftState copyWith({
    bool? hasActiveShift,
    Shift? currentShift,
    int? expectedCash,
    bool? isLoading,
    String? error,
  }) {
    return ShiftState(
      hasActiveShift: hasActiveShift ?? this.hasActiveShift,
      currentShift: currentShift ?? this.currentShift,
      expectedCash: expectedCash ?? this.expectedCash,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ShiftNotifier extends Notifier<ShiftState> {
  @override
  ShiftState build() => ShiftState.initial();

  Future<void> checkActiveShift() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final svc = ref.read(shiftServiceProvider);
      final result = await svc.getCurrentShift();
      if (!result.hasActiveShift) {
        state = ShiftState(
          hasActiveShift: false,
          currentShift: null,
          expectedCash: 0,
          isLoading: false,
        );
      } else {
        state = ShiftState(
          hasActiveShift: true,
          currentShift: result.shift,
          expectedCash: result.shift?.expectedCash ?? 0,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> openShift(int startCash) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final svc = ref.read(shiftServiceProvider);
      final shift = await svc.openShift(startCash: startCash);
      state = ShiftState(
        hasActiveShift: true,
        currentShift: shift,
        expectedCash: shift.expectedCash,
        isLoading: false,
      );
      return true;
    } catch (e) {
      final errMsg = e.toString();
      if (errMsg.contains('409')) {
        await checkActiveShift();
      } else {
        state = state.copyWith(isLoading: false, error: errMsg);
      }
      return false;
    }
  }

  Future<ShiftCloseResult> closeShift({
    required int physicalCount,
    required int step,
    String? closingNotes,
  }) async {
    if (state.currentShift == null) {
      return ShiftCloseResult.review(
        expectedCash: 0,
        difference: 0,
        message: 'Tidak ada shift aktif',
      );
    }

    try {
      final svc = ref.read(shiftServiceProvider);
      final result = await svc.closeShift(
        shiftId: state.currentShift!.id,
        physicalCount: physicalCount,
        step: step,
        closingNotes: closingNotes,
      );

      if (step == 2) {
        state = ShiftState.initial();
      }

      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return ShiftCloseResult.review(
        expectedCash: state.expectedCash,
        difference: 0,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  Future<void> refreshExpectedCash() async {
    if (!state.hasActiveShift || state.currentShift == null) return;
    try {
      final svc = ref.read(shiftServiceProvider);
      final result = await svc.getCurrentShift();
      if (result.hasActiveShift && result.shift != null) {
        state = state.copyWith(expectedCash: result.shift!.expectedCash);
      }
    } catch (_) {}
  }

  Future<CashLedgerEntry?> recordManualCash({
    required CashLedgerType type,
    required int amount,
    required String note,
  }) async {
    if (!state.hasActiveShift) return null;
    try {
      final svc = ref.read(shiftServiceProvider);
      final entry = await svc.recordManualCash(
        type: type,
        amount: amount,
        note: note,
      );
      await refreshExpectedCash();
      return entry;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}
