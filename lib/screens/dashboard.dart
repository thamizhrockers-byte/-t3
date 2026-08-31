import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';
import '../services/google_sheet_api.dart';
import 'add_transaction.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<TransactionModel> rows = [];
  bool loading = true;
  String? error;

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await GoogleSheetApi.getTransactions();

      if (!mounted) return;

      setState(() {
        rows = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  // ------------------------------------------------------------
  // CALCULATIONS
  // ------------------------------------------------------------

  double get totalPaid {
    return rows
        .where((x) => x.transaction.toLowerCase() == 'paid')
        .fold(0.0, (sum, x) => sum + x.amount);
  }

  double get totalReceived {
    return rows
        .where((x) => x.transaction.toLowerCase() == 'received')
        .fold(0.0, (sum, x) => sum + x.amount);
  }

  double get balance {
    return totalReceived - totalPaid;
  }

  Map<String, double> get categoryData {
    final Map<String, double> data = {};

    for (final x in rows) {
      if (x.transaction.toLowerCase() == 'paid') {
        final category =
            x.category.trim().isEmpty ? 'Others' : x.category.trim();

        data[category] = (data[category] ?? 0) + x.amount;
      }
    }

    return data;
  }

  Map<String, double> get bankData {
    final Map<String, double> data = {};

    for (final x in rows) {
      if (x.transaction.toLowerCase() == 'paid') {
        final bank = x.bank.trim().isEmpty ? 'Unknown' : x.bank.trim();

        data[bank] = (data[bank] ?? 0) + x.amount;
      }
    }

    return data;
  }

  // ------------------------------------------------------------
  // COLORS
  // ------------------------------------------------------------

  final List<Color> chartColors = const [
    Color(0xFF6750A4),
    Color(0xFF3F51B5),
    Color(0xFF00897B),
    Color(0xFFFF9800),
    Color(0xFFE53935),
    Color(0xFF8E24AA),
    Color(0xFF039BE5),
    Color(0xFF43A047),
    Color(0xFFF4511E),
    Color(0xFF6D4C41),
  ];

  Color colorForIndex(int index) {
    return chartColors[index % chartColors.length];
  }

  // ------------------------------------------------------------
  // FORMAT
  // ------------------------------------------------------------

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text(
          'Money Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: load,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTransaction(),
            ),
          );

          if (result == true) {
            load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      100,
                    ),
                    children: [
                      _summaryCards(),

                      const SizedBox(height: 16),

                      _categoryChart(),

                      const SizedBox(height: 16),

                      _incomeExpenseChart(),

                      const SizedBox(height: 16),

                      _bankChart(),

                      const SizedBox(height: 20),

                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (rows.isEmpty)
                        _emptyTransactions()
                      else
                        ...rows.reversed.take(15).map(
                              (x) => _transactionCard(x),
                            ),
                    ],
                  ),
                ),
    );
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 50,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? '',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY CARDS
  // ------------------------------------------------------------

  Widget _summaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Expense',
                value: money(totalPaid),
                icon: Icons.arrow_upward_rounded,
                iconColor: Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: 'Received',
                value: money(totalReceived),
                icon: Icons.arrow_downward_rounded,
                iconColor: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _balanceCard(),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withOpacity(0.12),
              child: Icon(
                icon,
                color: iconColor,
                size: 19,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard() {
    final positive = balance >= 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor:
                  (positive ? Colors.green : Colors.red).withOpacity(0.12),
              child: Icon(
                positive
                    ? Icons.account_balance_wallet_rounded
                    : Icons.warning_rounded,
                color: positive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    money(balance),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${rows.length} transactions',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CATEGORY PIE CHART
  // ------------------------------------------------------------

  Widget _categoryChart() {
    if (categoryData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending by Category',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Where your money is going',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 42,
                        sectionsSpace: 2,
                        sections: categoryData.entries
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (entry) {
                                final index = entry.key;
                                final item = entry.value;

                                return PieChartSectionData(
                                  value: item.value,
                                  color: colorForIndex(index),
                                  radius: 52,
                                  title: '',
                                );
                              },
                            )
                            .toList(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    flex: 5,
                    child: ListView(
                      children: categoryData.entries
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: colorForIndex(entry.key),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      entry.value.key,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    money(entry.value.value),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // INCOME VS EXPENSE CHART
  // ------------------------------------------------------------

  Widget _incomeExpenseChart() {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue =
        [totalPaid, totalReceived, 1.0].reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Money Overview',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Received vs spent',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: maxValue * 1.25,
                  minY: 0,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: false,
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const Text(
                              'Received',
                              style: TextStyle(fontSize: 11),
                            );
                          }

                          if (value == 1) {
                            return const Text(
                              'Expense',
                              style: TextStyle(fontSize: 11),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: totalReceived,
                          width: 42,
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.green,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: totalPaid,
                          width: 42,
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BANK CHART
  // ------------------------------------------------------------

  Widget _bankChart() {
    if (bankData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending by Bank',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Expense distribution across banks',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index >= bankData.length) {
                            return const SizedBox.shrink();
                          }

                          final name =
                              bankData.keys.elementAt(index);

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: bankData.entries
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (entry) => BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.value,
                              width: 28,
                              borderRadius: BorderRadius.circular(7),
                              color: colorForIndex(entry.key),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TRANSACTION CARD
  // ------------------------------------------------------------

  Widget _transactionCard(TransactionModel x) {
    final paid = x.transaction.toLowerCase() == 'paid';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        leading: CircleAvatar(
          backgroundColor:
              (paid ? Colors.red : Colors.green).withOpacity(0.10),
          child: Icon(
            paid
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: paid ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          x.to.isEmpty ? 'Unknown' : x.to,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${x.date} ${x.time}\n${x.category} · ${x.bank} · ${x.status}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Text(
          '${paid ? '-' : '+'}${money(x.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: paid ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _emptyTransactions() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 45,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            const Text(
              'No transactions yet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Tap + Transaction to add your first transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}