import 'dart:convert';

import 'package:flutter/services.dart';

class DetectedPayment {
  final String id;
  final int timestamp;
  final String sourcePackage;
  final String sourceApp;
  final String title;
  final String rawText;
  final String transaction;
  final double amount;
  final String to;
  final String detectedBank;
  final String mode;
  final int confidence;

  const DetectedPayment({
    required this.id,
    required this.timestamp,
    required this.sourcePackage,
    required this.sourceApp,
    required this.title,
    required this.rawText,
    required this.transaction,
    required this.amount,
    required this.to,
    required this.detectedBank,
    required this.mode,
    required this.confidence,
  });

  factory DetectedPayment.fromJson(
    Map<String, dynamic> json,
  ) {
    return DetectedPayment(
      id: '${json['id'] ?? ''}',
      timestamp: int.tryParse(
            '${json['timestamp'] ?? 0}',
          ) ??
          0,
      sourcePackage:
          '${json['sourcePackage'] ?? ''}',
      sourceApp: '${json['sourceApp'] ?? 'Unknown app'}',
      title: '${json['title'] ?? ''}',
      rawText: '${json['rawText'] ?? ''}',
      transaction:
          '${json['transaction'] ?? 'Paid'}',
      amount: double.tryParse(
            '${json['amount'] ?? 0}',
          ) ??
          0,
      to: '${json['to'] ?? ''}',
      detectedBank:
          '${json['detectedBank'] ?? ''}',
      mode: '${json['mode'] ?? 'Unknown'}',
      confidence: int.tryParse(
            '${json['confidence'] ?? 0}',
          ) ??
          0,
    );
  }
}

class PaymentDetectionService {
  static const MethodChannel _channel =
      MethodChannel(
    'money_tracker/payment_detection',
  );

  static Future<bool>
      isNotificationAccessEnabled() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isNotificationAccessEnabled',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void>
      openNotificationAccessSettings() async {
    await _channel.invokeMethod(
      'openNotificationAccessSettings',
    );
  }

  static Future<List<DetectedPayment>>
      getPendingPayments() async {
    final raw = await _channel.invokeMethod<String>(
          'getPendingPayments',
        ) ??
        '[]';

    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => DetectedPayment.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static Future<void> removePayment(
    String id,
  ) async {
    await _channel.invokeMethod(
      'removePayment',
      {
        'id': id,
      },
    );
  }

  static Future<void>
      clearPendingPayments() async {
    await _channel.invokeMethod(
      'clearPendingPayments',
    );
  }
}
