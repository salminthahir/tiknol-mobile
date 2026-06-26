import 'dart:convert';

enum ReceiptFontSize { small, medium, large }

enum ReceiptAlignment { left, center, right }

enum ReceiptItemFormat { qtyXprice, qtyXpriceTotal }

class ReceiptTemplate {
  // Header
  final String storeName;
  final String storeAddress;
  final String storeContact;
  final String? logoPath;
  final bool showLogo;
  final bool showStoreName;
  final bool showStoreAddress;
  final bool showStoreContact;

  // Body
  final ReceiptFontSize fontSize;
  final bool bold;
  final ReceiptAlignment alignment;
  final ReceiptItemFormat itemFormat;

  // Footer
  final String thankYouText;
  final bool showThankYou;

  // Visibility toggles
  final bool showOrderId;
  final bool showDate;
  final bool showCashier;
  final bool showCustomer;
  final bool showSubtotal;
  final bool showDiscount;
  final bool showTotal;
  final bool showPaymentType;

  // Printer
  final String? savedDeviceId;
  final String? savedDeviceName;

  const ReceiptTemplate({
    this.storeName = 'TITIK NOL CAFE',
    this.storeAddress = '',
    this.storeContact = '',
    this.logoPath,
    this.showLogo = false,
    this.showStoreName = true,
    this.showStoreAddress = false,
    this.showStoreContact = false,
    this.fontSize = ReceiptFontSize.small,
    this.bold = false,
    this.alignment = ReceiptAlignment.center,
    this.itemFormat = ReceiptItemFormat.qtyXpriceTotal,
    this.thankYouText = 'TERIMA KASIH\nSampai jumpa kembali!',
    this.showThankYou = true,
    this.showOrderId = true,
    this.showDate = true,
    this.showCashier = true,
    this.showCustomer = true,
    this.showSubtotal = true,
    this.showDiscount = true,
    this.showTotal = true,
    this.showPaymentType = true,
    this.savedDeviceId,
    this.savedDeviceName,
  });

  ReceiptTemplate copyWith({
    String? storeName,
    String? storeAddress,
    String? storeContact,
    String? logoPath,
    bool? showLogo,
    bool? showStoreName,
    bool? showStoreAddress,
    bool? showStoreContact,
    ReceiptFontSize? fontSize,
    bool? bold,
    ReceiptAlignment? alignment,
    ReceiptItemFormat? itemFormat,
    String? thankYouText,
    bool? showThankYou,
    bool? showOrderId,
    bool? showDate,
    bool? showCashier,
    bool? showCustomer,
    bool? showSubtotal,
    bool? showDiscount,
    bool? showTotal,
    bool? showPaymentType,
    String? savedDeviceId,
    String? savedDeviceName,
  }) {
    return ReceiptTemplate(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storeContact: storeContact ?? this.storeContact,
      logoPath: logoPath ?? this.logoPath,
      showLogo: showLogo ?? this.showLogo,
      showStoreName: showStoreName ?? this.showStoreName,
      showStoreAddress: showStoreAddress ?? this.showStoreAddress,
      showStoreContact: showStoreContact ?? this.showStoreContact,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      alignment: alignment ?? this.alignment,
      itemFormat: itemFormat ?? this.itemFormat,
      thankYouText: thankYouText ?? this.thankYouText,
      showThankYou: showThankYou ?? this.showThankYou,
      showOrderId: showOrderId ?? this.showOrderId,
      showDate: showDate ?? this.showDate,
      showCashier: showCashier ?? this.showCashier,
      showCustomer: showCustomer ?? this.showCustomer,
      showSubtotal: showSubtotal ?? this.showSubtotal,
      showDiscount: showDiscount ?? this.showDiscount,
      showTotal: showTotal ?? this.showTotal,
      showPaymentType: showPaymentType ?? this.showPaymentType,
      savedDeviceId: savedDeviceId ?? this.savedDeviceId,
      savedDeviceName: savedDeviceName ?? this.savedDeviceName,
    );
  }

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'storeAddress': storeAddress,
        'storeContact': storeContact,
        'logoPath': logoPath,
        'showLogo': showLogo,
        'showStoreName': showStoreName,
        'showStoreAddress': showStoreAddress,
        'showStoreContact': showStoreContact,
        'fontSize': fontSize.name,
        'bold': bold,
        'alignment': alignment.name,
        'itemFormat': itemFormat.name,
        'thankYouText': thankYouText,
        'showThankYou': showThankYou,
        'showOrderId': showOrderId,
        'showDate': showDate,
        'showCashier': showCashier,
        'showCustomer': showCustomer,
        'showSubtotal': showSubtotal,
        'showDiscount': showDiscount,
        'showTotal': showTotal,
        'showPaymentType': showPaymentType,
        'savedDeviceId': savedDeviceId,
        'savedDeviceName': savedDeviceName,
      };

  factory ReceiptTemplate.fromJson(Map<String, dynamic> json) {
    return ReceiptTemplate(
      storeName: json['storeName'] ?? 'TITIK NOL CAFE',
      storeAddress: json['storeAddress'] ?? '',
      storeContact: json['storeContact'] ?? '',
      logoPath: json['logoPath'],
      showLogo: json['showLogo'] ?? false,
      showStoreName: json['showStoreName'] ?? true,
      showStoreAddress: json['showStoreAddress'] ?? false,
      showStoreContact: json['showStoreContact'] ?? false,
      fontSize: ReceiptFontSize.values.byName(json['fontSize'] ?? 'small'),
      bold: json['bold'] ?? false,
      alignment: ReceiptAlignment.values.byName(json['alignment'] ?? 'center'),
      itemFormat: ReceiptItemFormat.values.byName(json['itemFormat'] ?? 'qtyXpriceTotal'),
      thankYouText: json['thankYouText'] ?? 'TERIMA KASIH\nSampai jumpa kembali!',
      showThankYou: json['showThankYou'] ?? true,
      showOrderId: json['showOrderId'] ?? true,
      showDate: json['showDate'] ?? true,
      showCashier: json['showCashier'] ?? true,
      showCustomer: json['showCustomer'] ?? true,
      showSubtotal: json['showSubtotal'] ?? true,
      showDiscount: json['showDiscount'] ?? true,
      showTotal: json['showTotal'] ?? true,
      showPaymentType: json['showPaymentType'] ?? true,
      savedDeviceId: json['savedDeviceId'],
      savedDeviceName: json['savedDeviceName'],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ReceiptTemplate.fromJsonString(String jsonString) {
    return ReceiptTemplate.fromJson(jsonDecode(jsonString));
  }
}
