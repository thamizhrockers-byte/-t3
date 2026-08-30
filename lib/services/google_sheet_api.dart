import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/transaction_model.dart';

class GoogleSheetApi {
  static Uri get _url => Uri.parse(AppConfig.googleScriptUrl);

  static void _checkConfigured() {
    if (AppConfig.googleScriptUrl.contains('PASTE_APPS_SCRIPT')) {
      throw Exception('Configure googleScriptUrl in lib/config/app_config.dart');
    }
  }

  static Future<List<TransactionModel>> getTransactions() async {
    _checkConfigured();
    final response = await http.get(
      Uri.parse('${_url.toString()}?token=${Uri.encodeComponent(AppConfig.apiToken)}'),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200 && response.statusCode != 302) {
  throw Exception(
    "HTTP ${response.statusCode}: ${response.body}"
  );
}

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected API response');
    }

    return decoded
      .map((e) => TransactionModel.fromJson(Map<String,dynamic>.from(e)))
      .toList();
  }

  static Future<void> addTransaction(TransactionModel t) async {
    _checkConfigured();
    final response = await http.post(
      _url,
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({
        'token': AppConfig.apiToken,
        ...t.toJson(),
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Google Sheets returned HTTP ${response.statusCode}');
    }

    final result = jsonDecode(response.body);
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Failed to save transaction');
    }
  }
}
