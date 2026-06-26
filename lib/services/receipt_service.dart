import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/cart_item.dart';
import '../models/receipt_template.dart';

class ReceiptGenerator {
  /// Generate ESC/POS bytes for thermal printer (58mm = 32 chars default).
  static Future<Uint8List> generateEscPosBytes({
    required String orderId,
    required List<CartItem> items,
    required int subtotal,
    required int discount,
    required int total,
    required String paymentType,
    required String cashierName,
    required String branchName,
    String? customerName,
    required ReceiptTemplate template,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperWidth = template.fontSize == ReceiptFontSize.large ? PaperSize.mm58 : PaperSize.mm58;
    final generator = Generator(paperWidth, profile);
    List<int> bytes = [];

    // Helper: convert alignment
    PosAlign align() {
      switch (template.alignment) {
        case ReceiptAlignment.left:
          return PosAlign.left;
        case ReceiptAlignment.right:
          return PosAlign.right;
        case ReceiptAlignment.center:
          return PosAlign.center;
      }
    }

    // Logo
    if (template.showLogo && template.logoPath != null && template.logoPath!.isNotEmpty) {
      try {
        final file = File(template.logoPath!);
        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          final decoded = img.decodeImage(imageBytes);
          if (decoded != null) {
            // Resize to max 384px width for 58mm printer
            final resized = img.copyResize(decoded, width: 384);
            bytes += generator.imageRaster(
              resized,
              align: align(),
              highDensityHorizontal: true,
              highDensityVertical: true,
            );
            bytes += generator.feed(1);
          }
        }
      } catch (_) {
        // Ignore logo errors
      }
    }

    // Header
    bytes += generator.setStyles(PosStyles(
      align: align(),
      bold: template.bold,
      height: PosTextSize.size2,
      width: PosTextSize.size1,
    ));

    if (template.showStoreName && template.storeName.isNotEmpty) {
      bytes += generator.text(template.storeName, styles: PosStyles(align: align(), bold: true, height: PosTextSize.size2));
    }

    bytes += generator.setStyles(PosStyles(align: align(), bold: template.bold));
    if (template.showStoreAddress && template.storeAddress.isNotEmpty) {
      bytes += generator.text(template.storeAddress);
    }
    if (template.showStoreContact && template.storeContact.isNotEmpty) {
      bytes += generator.text(template.storeContact);
    }
    bytes += generator.text('--------------------------------', styles: PosStyles(align: PosAlign.left));

    // Info
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    bytes += generator.setStyles(PosStyles(align: PosAlign.left, bold: template.bold));

    if (template.showOrderId) {
      bytes += generator.text('No: $orderId');
    }
    if (template.showDate) {
      bytes += generator.text('Tgl: $dateStr');
    }
    if (template.showCashier && cashierName.isNotEmpty) {
      bytes += generator.text('Kasir: $cashierName');
    }
    if (template.showCustomer && customerName != null && customerName.isNotEmpty) {
      bytes += generator.text('Pelanggan: $customerName');
    }
    bytes += generator.text('--------------------------------', styles: PosStyles(align: PosAlign.left));

    // Items
    final formatter = NumberFormat('#,###', 'id');
    for (final item in items) {
      final name = item.displayName;
      final qty = item.qty;
      final price = item.product.price;
      final itemTotal = qty * price;

      bytes += generator.text(name, styles: PosStyles(align: PosAlign.left, bold: template.bold));

      if (template.itemFormat == ReceiptItemFormat.qtyXpriceTotal) {
        bytes += generator.row([
          PosColumn(
            text: '  ${qty}x ${formatter.format(price)}',
            width: 6,
            styles: PosStyles(align: PosAlign.left, bold: template.bold),
          ),
          PosColumn(
            text: formatter.format(itemTotal),
            width: 6,
            styles: PosStyles(align: PosAlign.right, bold: template.bold),
          ),
        ]);
      } else {
        bytes += generator.text('  ${qty}x ${formatter.format(price)}', styles: PosStyles(align: PosAlign.left, bold: template.bold));
      }
    }

    bytes += generator.text('--------------------------------', styles: PosStyles(align: PosAlign.left));

    // Totals
    if (template.showSubtotal) {
      bytes += generator.row([
        PosColumn(text: 'Subtotal:', width: 6, styles: PosStyles(align: PosAlign.left, bold: template.bold)),
        PosColumn(text: 'Rp ${formatter.format(subtotal)}', width: 6, styles: PosStyles(align: PosAlign.right, bold: template.bold)),
      ]);
    }
    if (template.showDiscount && discount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Diskon:', width: 6, styles: PosStyles(align: PosAlign.left, bold: template.bold)),
        PosColumn(text: '- Rp ${formatter.format(discount)}', width: 6, styles: PosStyles(align: PosAlign.right, bold: template.bold)),
      ]);
    }
    if (template.showTotal) {
      bytes += generator.row([
        PosColumn(text: 'TOTAL:', width: 6, styles: PosStyles(align: PosAlign.left, bold: true)),
        PosColumn(text: 'Rp ${formatter.format(total)}', width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }
    if (template.showPaymentType) {
      bytes += generator.row([
        PosColumn(text: 'Bayar:', width: 6, styles: PosStyles(align: PosAlign.left, bold: template.bold)),
        PosColumn(text: paymentType, width: 6, styles: PosStyles(align: PosAlign.right, bold: template.bold)),
      ]);
    }

    bytes += generator.text('--------------------------------', styles: PosStyles(align: PosAlign.left));

    // Footer
    if (template.showThankYou && template.thankYouText.isNotEmpty) {
      bytes += generator.setStyles(PosStyles(align: align(), bold: template.bold));
      for (final line in template.thankYouText.split('\n')) {
        bytes += generator.text(line);
      }
    }

    bytes += generator.feed(3);
    // Note: P58C-NB usually has no auto-cutter, so we skip cut command.
    // If auto-cutter exists, uncomment below:
    // bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  /// Generate ASCII preview string for UI.
  static String generateAsciiPreview({
    required String orderId,
    required List<CartItem> items,
    required int subtotal,
    required int discount,
    required int total,
    required String paymentType,
    required String cashierName,
    required String branchName,
    String? customerName,
    required ReceiptTemplate template,
  }) {
    const width = 32;
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final formatter = NumberFormat('#,###', 'id');
    final buf = StringBuffer();

    String centerText(String text) {
      if (text.length >= width) return text;
      final pad = (width - text.length) ~/ 2;
      return ' ' * pad + text;
    }

    String lineDash() => '-' * width;

    String justifyText(String left, String right) {
      final space = width - left.length - right.length;
      if (space <= 0) return '$left $right';
      return '$left${' ' * space}$right';
    }

    // Header
    if (template.showStoreName && template.storeName.isNotEmpty) {
      buf.writeln(centerText(template.storeName));
    }
    if (template.showStoreAddress && template.storeAddress.isNotEmpty) {
      buf.writeln(centerText(template.storeAddress));
    }
    if (template.showStoreContact && template.storeContact.isNotEmpty) {
      buf.writeln(centerText(template.storeContact));
    }
    if (template.showLogo && template.logoPath != null) {
      buf.writeln(centerText('[LOGO]'));
    }
    buf.writeln(lineDash());

    // Info
    if (template.showOrderId) buf.writeln('No: $orderId');
    if (template.showDate) buf.writeln('Tgl: $dateStr');
    if (template.showCashier && cashierName.isNotEmpty) buf.writeln('Kasir: $cashierName');
    if (template.showCustomer && customerName != null && customerName.isNotEmpty) {
      buf.writeln('Pelanggan: $customerName');
    }
    buf.writeln(lineDash());

    // Items
    for (final item in items) {
      final name = item.displayName;
      final qty = item.qty;
      final price = item.product.price;
      final itemTotal = qty * price;
      buf.writeln(name);
      if (template.itemFormat == ReceiptItemFormat.qtyXpriceTotal) {
        buf.writeln(justifyText('  ${qty}x ${formatter.format(price)}', formatter.format(itemTotal)));
      } else {
        buf.writeln('  ${qty}x ${formatter.format(price)}');
      }
    }

    buf.writeln(lineDash());

    if (template.showSubtotal) {
      buf.writeln(justifyText('Subtotal:', 'Rp ${formatter.format(subtotal)}'));
    }
    if (template.showDiscount && discount > 0) {
      buf.writeln(justifyText('Diskon:', '- Rp ${formatter.format(discount)}'));
    }
    if (template.showTotal) {
      buf.writeln(justifyText('TOTAL:', 'Rp ${formatter.format(total)}'));
    }
    if (template.showPaymentType) {
      buf.writeln(justifyText('Bayar:', paymentType));
    }

    buf.writeln(lineDash());

    if (template.showThankYou && template.thankYouText.isNotEmpty) {
      for (final line in template.thankYouText.split('\n')) {
        buf.writeln(centerText(line));
      }
    }

    return buf.toString();
  }

  /// Generate a test print ASCII preview (no data needed).
  static String generateTestAsciiPreview(ReceiptTemplate template) {
    return generateAsciiPreview(
      orderId: 'TEST-001',
      items: [
        // Dummy items for preview
      ],
      subtotal: 50000,
      discount: 5000,
      total: 45000,
      paymentType: 'CASH',
      cashierName: 'Budi',
      branchName: 'Cabang Pusat',
      customerName: 'Andi',
      template: template,
    );
  }
}
