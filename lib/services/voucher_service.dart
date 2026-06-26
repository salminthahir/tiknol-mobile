import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

final voucherServiceProvider = Provider((ref) => VoucherService(ref));

class VoucherService {
  final Ref ref;
  VoucherService(this.ref);

  Future<VoucherResult> validate({
    required String code,
    required int cartTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    final api = ref.read(apiClientProvider);

    final response = await api.client.post(
      '/api/vouchers/validate',
      data: {
        'code': code.toUpperCase(),
        'cartTotal': cartTotal,
        'items': items,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data['valid'] == true) {
        return VoucherResult(
          valid: true,
          voucherId: data['voucher']?['id'],
          voucherCode: data['voucher']?['code'],
          voucherName: data['voucher']?['name'],
          discount: (data['discount'] as num?)?.toInt() ?? 0,
        );
      } else {
        return VoucherResult(
          valid: false,
          errorMessage: data['message'] ?? 'Voucher tidak valid',
        );
      }
    }

    throw Exception('Gagal validasi voucher');
  }
}

class VoucherResult {
  final bool valid;
  final String? voucherId;
  final String? voucherCode;
  final String? voucherName;
  final int discount;
  final String? errorMessage;

  const VoucherResult({
    required this.valid,
    this.voucherId,
    this.voucherCode,
    this.voucherName,
    this.discount = 0,
    this.errorMessage,
  });
}
