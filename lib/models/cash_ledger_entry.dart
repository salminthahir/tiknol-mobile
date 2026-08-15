enum CashLedgerType {
  cashOut,
  cashInOther,
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

  CashLedgerEntry({
    required this.id,
    required this.shiftId,
    required this.type,
    required this.amount,
    this.refOrderId,
    this.note,
    this.clientTxnId,
    required this.createdAt,
  });

  factory CashLedgerEntry.fromJson(Map<String, dynamic> json) {
    return CashLedgerEntry(
      id: json['id'] as String,
      shiftId: json['shiftId'] as String,
      type: json['type'] == 'CASH_OUT'
          ? CashLedgerType.cashOut
          : CashLedgerType.cashInOther,
      amount: (json['amount'] as num).toInt(),
      refOrderId: json['refOrderId'] as String?,
      note: json['note'] as String?,
      clientTxnId: json['clientTxnId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String get typeLabel {
    switch (type) {
      case CashLedgerType.cashOut:
        return 'Kas Keluar';
      case CashLedgerType.cashInOther:
        return 'Kas Masuk';
    }
  }
}

class ShiftLedger {
  final String shiftId;
  final String? branchId;
  final String? cashierName;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final int startCash;
  final int? expectedCash;
  final int? actualCash;
  final int? difference;
  final List<CashLedgerEntry> entries;

  ShiftLedger({
    required this.shiftId,
    this.branchId,
    this.cashierName,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.startCash,
    this.expectedCash,
    this.actualCash,
    this.difference,
    required this.entries,
  });

  factory ShiftLedger.fromJson(Map<String, dynamic> json) {
    final entriesList = (json['entries'] as List<dynamic>?)
            ?.map((e) => CashLedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ShiftLedger(
      shiftId: json['shiftId'] as String,
      branchId: json['branchId'] as String?,
      cashierName: json['cashierName'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      status: json['status'] as String,
      startCash: (json['startCash'] as num?)?.toInt() ?? 0,
      expectedCash: (json['expectedCash'] as num?)?.toInt(),
      actualCash: (json['actualCash'] as num?)?.toInt(),
      difference: (json['difference'] as num?)?.toInt(),
      entries: entriesList,
    );
  }
}
