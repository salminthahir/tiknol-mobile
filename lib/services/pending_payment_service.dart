import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PendingPayment {
  final String orderId;
  final String qrString;
  final int amount;
  final int expiryMinutes;
  final String customerName;
  final DateTime createdAt;

  const PendingPayment({
    required this.orderId,
    required this.qrString,
    required this.amount,
    required this.expiryMinutes,
    required this.customerName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'qrString': qrString,
        'amount': amount,
        'expiryMinutes': expiryMinutes,
        'customerName': customerName,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory PendingPayment.fromJson(Map<String, dynamic> json) => PendingPayment(
        orderId: json['orderId']?.toString() ?? '',
        qrString: json['qrString']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        expiryMinutes: (json['expiryMinutes'] as num?)?.toInt() ?? 10,
        customerName: json['customerName']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class PendingPaymentService {
  static const _key = 'pending_payments';

  static Future<List<PendingPayment>> getPendingPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingPayment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePendingPayment(PendingPayment payment) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getPendingPayments();
    existing.removeWhere((p) => p.orderId == payment.orderId);
    existing.add(payment);
    await prefs.setString(
      _key,
      jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> removePendingPayment(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getPendingPayments();
    existing.removeWhere((p) => p.orderId == orderId);
    await prefs.setString(
      _key,
      jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  static Future<PendingPayment?> getPendingPayment(String orderId) async {
    final list = await getPendingPayments();
    try {
      return list.firstWhere((p) => p.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
