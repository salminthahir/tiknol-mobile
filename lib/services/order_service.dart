import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/cart_item.dart';
import '../models/payment_status.dart';

final orderServiceProvider = Provider((ref) => OrderService(ref));

class OrderService {
  final Ref ref;
  OrderService(this.ref);

  Future<Map<String, dynamic>> createCashOrder({
    required String customerName,
    required String orderType,
    required List<CartItem> items,
    required int totalAmount,
    required int subtotal,
    required int discountAmount,
    String? voucherId,
  }) async {
    final api = ref.read(apiClientProvider);

    final response = await api.client.post(
      '/api/cash-order',
      data: {
        'customerName': customerName.isEmpty ? 'Customer POS' : customerName,
        'whatsapp': 'N/A',
        'orderType': orderType,
        'items': items.map((item) => {
          'id': item.product.id,
          'name': item.displayName,
          'price': item.product.price,
          'qty': item.qty,
        }).toList(),
        'totalAmount': totalAmount,
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'voucherId': voucherId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );

    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }

    throw Exception(response.data['error'] ?? 'Gagal membuat order');
  }

  Future<Map<String, String>> createOnlinePayment({
    required String customerName,
    required String orderType,
    required List<CartItem> items,
    required int subtotal,
    required int discountAmount,
    String? paymentMethod,
    required String branchId,
    String? voucherId,
  }) async {
    final api = ref.read(apiClientProvider);

    final response = await api.client.post(
      '/api/tokenizer',
      data: {
        'customerName': customerName.isEmpty ? 'Customer POS' : customerName,
        'whatsapp': 'N/A',
        'orderType': orderType,
        'items': items.map((item) => {
          'id': item.product.id,
          'name': item.displayName,
          'price': item.product.price,
          'qty': item.qty,
        }).toList(),
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'voucherId': voucherId,
        'paymentMethod': paymentMethod ?? '',
        'branchId': branchId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );

    if (response.statusCode == 200 && response.data['orderId'] != null) {
      return {
        'paymentUrl': (response.data['paymentUrl'] ?? '') as String,
        'orderId': (response.data['orderId'] ?? '') as String,
        'qrString': (response.data['qrString'] ?? '') as String,
        'amount': (response.data['amount'] ?? 0).toString(),
        'expiryPeriod': (response.data['expiryPeriod'] ?? 10).toString(),
      };
    }

    throw Exception(response.data['details'] ?? 'Gagal memproses pembayaran');
  }

  Future<void> cancelOrder(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.client.post('/api/payment/reset', data: {'orderId': orderId});
    } catch (_) {
      // Best-effort — don't crash if cancel fails
    }
  }

  /// Returns the server-verified payment status for [orderId].
  ///
  /// Security (PV-1/PV-2/PV-5): payment success must come only from the
  /// backend, which is expected to verify the transaction against Duitku
  /// `transactionStatus` using HMAC-SHA256. This method fails closed: on any
  /// transport error, invalid response, or unrecognized status it throws
  /// [PaymentCheckException] instead of silently returning a pending/paid
  /// state. Callers must distinguish "not yet paid" from "could not verify".
  Future<PaymentStatus> checkPaymentStatus(String orderId) async {
    if (orderId.isEmpty) {
      throw ArgumentError('orderId kosong');
    }
    final api = ref.read(apiClientProvider);
    try {
      final response = await api.client.post(
        '/api/payment/check-status',
        data: {'orderId': orderId},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final status = paymentStatusFromString(
          (response.data as Map)['status']?.toString(),
        );
        if (status == PaymentStatus.unknown) {
          throw PaymentCheckException('Status tidak dikenal dari server');
        }
        return status;
      }
      throw PaymentCheckException(
        'Respons tidak valid (HTTP ${response.statusCode})',
      );
    } on DioException catch (e) {
      throw PaymentCheckException('Gangguan jaringan: ${e.type.name}');
    }
  }
}
