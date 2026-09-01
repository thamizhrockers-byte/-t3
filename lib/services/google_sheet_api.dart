import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/transaction_model.dart';

class GoogleSheetApi {
  static Uri get _url => Uri.parse(
        AppConfig.googleScriptUrl,
      );

  static void _checkConfigured() {
    if (AppConfig.googleScriptUrl.contains(
      'PASTE_APPS_SCRIPT',
    )) {
      throw Exception(
        'Configure googleScriptUrl in lib/config/app_config.dart',
      );
    }
  }

  static Future<List<TransactionModel>> getTransactions() async {
    _checkConfigured();

    final url = Uri.parse(
      '${_url.toString()}?token=${Uri.encodeComponent(AppConfig.apiToken)}',
    );

    final response = await http
        .get(url)
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode != 200 &&
        response.statusCode != 302) {
      throw Exception(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(
      response.body,
    );

    if (decoded is! List) {
      throw Exception(
        'Unexpected API response',
      );
    }

    return decoded
        .map(
          (e) => TransactionModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  static Future<void> addTransaction(
    TransactionModel t,
  ) async {
    _checkConfigured();

    final response = await http
        .post(
          _url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'token': AppConfig.apiToken,
            'date': t.date,
            'time': t.time,
            'type': t.transaction,
            'amount': t.amount,
            'receiver': t.to,
            'category': t.category,
            'bank': t.bank,
            'mode': t.mode,
            'status': t.status,
            'notes': t.notes,
          }),
        )
        .timeout(
          const Duration(seconds: 20),
        );

    // Apps Script may redirect after accepting the POST.
    if (response.statusCode == 302) {
      return;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Google Sheets returned HTTP ${response.statusCode}',
      );
    }

    if (response.body.trim().isEmpty) {
      return;
    }

    final result = jsonDecode(
      response.body,
    );

    if (result is Map &&
        result['success'] == false) {
      throw Exception(
        result['error'] ??
            'Failed to save transaction',
      );
    }
  }
}