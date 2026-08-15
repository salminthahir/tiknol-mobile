enum ShiftStatus { open, closed }

class Shift {
  final String id;
  final int startCash;
  final DateTime startTime;
  final DateTime? endTime;
  final ShiftStatus status;
  final int expectedCash;
  final String? branchId;
  final String? cashierName;
  final int? actualCash;
  final int? difference;
  final String? closingNotes;

  Shift({
    required this.id,
    required this.startCash,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.expectedCash,
    this.branchId,
    this.cashierName,
    this.actualCash,
    this.difference,
    this.closingNotes,
  });

  factory Shift.fromCurrentJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      startCash: (json['startCash'] as num?)?.toInt() ?? 0,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      status: json['status'] == 'OPEN' ? ShiftStatus.open : ShiftStatus.closed,
      expectedCash: (json['expectedCash'] as num?)?.toInt() ?? 0,
    );
  }

  factory Shift.fromLedgerJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      startCash: (json['startCash'] as num?)?.toInt() ?? 0,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      status: json['status'] == 'OPEN' ? ShiftStatus.open : ShiftStatus.closed,
      expectedCash: (json['expectedCash'] as num?)?.toInt() ?? 0,
      branchId: json['branchId'] as String?,
      cashierName: json['cashierName'] as String?,
      actualCash: (json['actualCash'] as num?)?.toInt(),
      difference: (json['difference'] as num?)?.toInt(),
      closingNotes: json['closingNotes'] as String?,
    );
  }

  Shift copyWith({
    String? id,
    int? startCash,
    DateTime? startTime,
    DateTime? endTime,
    ShiftStatus? status,
    int? expectedCash,
    String? branchId,
    String? cashierName,
    int? actualCash,
    int? difference,
    String? closingNotes,
  }) {
    return Shift(
      id: id ?? this.id,
      startCash: startCash ?? this.startCash,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      expectedCash: expectedCash ?? this.expectedCash,
      branchId: branchId ?? this.branchId,
      cashierName: cashierName ?? this.cashierName,
      actualCash: actualCash ?? this.actualCash,
      difference: difference ?? this.difference,
      closingNotes: closingNotes ?? this.closingNotes,
    );
  }
}

class ShiftCurrentResponse {
  final bool hasActiveShift;
  final Shift? shift;

  ShiftCurrentResponse({required this.hasActiveShift, this.shift});

  factory ShiftCurrentResponse.fromJson(Map<String, dynamic> json) {
    if (json['hasActiveShift'] == false) {
      return ShiftCurrentResponse(hasActiveShift: false);
    }
    return ShiftCurrentResponse(
      hasActiveShift: true,
      shift: Shift.fromCurrentJson(json),
    );
  }
}

class ShiftSummary {
  final String shiftId;
  final int totalTransactions;
  final int totalOmzet;
  final int totalCash;
  final int totalQris;

  ShiftSummary({
    required this.shiftId,
    required this.totalTransactions,
    required this.totalOmzet,
    required this.totalCash,
    required this.totalQris,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      shiftId: json['shiftId'] as String,
      totalTransactions: (json['totalTransactions'] as num?)?.toInt() ?? 0,
      totalOmzet: (json['totalOmzet'] as num?)?.toInt() ?? 0,
      totalCash: (json['totalCash'] as num?)?.toInt() ?? 0,
      totalQris: (json['totalQris'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShiftCloseResult {
  final int step;
  final int? expectedCash;
  final int? difference;
  final String? message;
  final bool? isFlagged;

  ShiftCloseResult._({
    required this.step,
    this.expectedCash,
    this.difference,
    this.message,
    this.isFlagged,
  });

  factory ShiftCloseResult.review({
    required int expectedCash,
    required int difference,
    required String message,
  }) {
    return ShiftCloseResult._(
      step: 1,
      expectedCash: expectedCash,
      difference: difference,
      message: message,
    );
  }

  factory ShiftCloseResult.closed({
    required bool isFlagged,
    required int difference,
  }) {
    return ShiftCloseResult._(
      step: 2,
      isFlagged: isFlagged,
      difference: difference,
    );
  }
}
