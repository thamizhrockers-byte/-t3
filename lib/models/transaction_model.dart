class TransactionModel {
  final String date;
  final String time;
  final String transaction;
  final double amount;
  final String to;
  final String bank;
  final String status;
  final String category;
  final String mode;
  final String notes;

  TransactionModel({
    required this.date,
    required this.time,
    required this.transaction,
    required this.amount,
    required this.to,
    required this.bank,
    required this.status,
    required this.category,
    this.mode = '',
    this.notes = '',
  });

  factory TransactionModel.fromJson(Map<String, dynamic> j) {
    String firstValue(List<String> keys) {
      for (final key in keys) {
        final value = j[key];

        if (value != null && '$value'.trim().isNotEmpty) {
          return '$value'.trim();
        }
      }

      return '';
    }

    return TransactionModel(
      date: firstValue([
        'Date',
        'date',
      ]),
      time: firstValue([
        'Time',
        'time',
      ]),
      transaction: firstValue([
        'Transaction',
        'Type',
        'transaction',
        'type',
      ]),
      amount: double.tryParse(
            firstValue([
              'Amount',
              'amount',
            ]),
          ) ??
          0,
      to: firstValue([
        'TO',
        'To',
        'Receiver',
        'to',
        'receiver',
      ]),
      bank: firstValue([
        'My Bank',
        'Bank',
        'bank',
      ]),
      status: firstValue([
        'Status',
        'status',
      ]),
      category: firstValue([
        'Category',
        'category',
      ]),
      mode: firstValue([
        'Payment Mode',
        'Mode',
        'mode',
      ]),
      notes: firstValue([
        'Notes',
        'notes',
      ]),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'time': time,
        'transaction': transaction,
        'amount': amount,
        'to': to,
        'bank': bank,
        'status': status,
        'category': category,
        'mode': mode,
        'notes': notes,
      };
}