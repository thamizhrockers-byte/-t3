class TransactionModel {
  final String date;
  final String time;
  final String transaction;
  final double amount;
  final String to;
  final String bank;
  final String status;
  final String category;

  TransactionModel({
    required this.date,
    required this.time,
    required this.transaction,
    required this.amount,
    required this.to,
    required this.bank,
    required this.status,
    required this.category,
  });

  factory TransactionModel.fromJson(Map<String,dynamic> j) {
    return TransactionModel(
      date: '${j['Date'] ?? ''}',
      time: '${j['Time'] ?? ''}',
      transaction: '${j['Transaction'] ?? ''}',
      amount: double.tryParse('${j['Amount'] ?? 0}') ?? 0,
      to: '${j['TO'] ?? ''}',
      bank: '${j['My Bank'] ?? ''}',
      status: '${j['Status'] ?? ''}',
      category: '${j['Category'] ?? ''}',
    );
  }

  Map<String,dynamic> toJson() => {
    'date': date,
    'time': time,
    'transaction': transaction,
    'amount': amount,
    'to': to,
    'bank': bank,
    'status': status,
    'category': category,
  };
}
