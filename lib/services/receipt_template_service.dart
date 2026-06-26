import 'package:shared_preferences/shared_preferences.dart';
import '../models/receipt_template.dart';

class ReceiptTemplateService {
  static const _key = 'receipt_template_v1';

  static Future<ReceiptTemplate> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return const ReceiptTemplate();
    }
    try {
      return ReceiptTemplate.fromJsonString(jsonString);
    } catch (_) {
      return const ReceiptTemplate();
    }
  }

  static Future<void> save(ReceiptTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, template.toJsonString());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
