```dart
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
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final result = await GoogleSheetApi.getTransactions();

      if (mounted) {
        setState(() {
          rows = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
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

  double get totalExpense {
    return rows
        .where((x) => x.transaction.toLowerCase() == 'paid')
        .fold(0.0, (sum, x) => sum + x.amount);
  }

  double get totalIncome {
    return rows
        .where((x) => x.transaction.toLowerCase() == 'received')
        .fold(0.0, (sum, x) => sum + x.amount);
  }

  double get balance {
    return totalIncome - totalExpense;
  }

  Map<String, double> get categoryData {
    final result = <String, double>{};

    for (final x in rows) {
      if (x.transaction.toLowerCase() == 'paid') {
        final category =
            x.category.trim().isEmpty ? 'Others' : x.category.trim();

        result[category] = (result[category] ?? 0) + x.amount;
      }
    }

    return result;
  }

  Map<String, double> get paymentModeData {
    final result = <String, double>{};

    // The current TransactionModel does not contain payment mode.
    // This chart will therefore remain empty until the model/API
    // is expanded to include the Mode column.
    return result;
  }

  // ------------------------------------------------------------
  // CATEGORY COLORS
  // ------------------------------------------------------------

  final Map<String, Color> categoryColors = {
    'Food': Colors.orange,
    'Travel': Colors.blue,
    'Bills': Colors.red,
    'Shopping': Colors.purple,
    'Entertainment': Colors.pink,
    'Family': Colors.green,
    'Health': Colors.teal,
    'Salary': Colors.indigo,
    'Others': Colors.grey,
  };

  Color getCategoryColor(String category, int index) {
    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }

    final colors = [
      Colors.deepOrange,
      Colors.cyan,
      Colors.amber,
      Colors.deepPurple,
      Colors.lightBlue,
      Colors.lime,
      Colors.brown,
      Colors.blueGrey,
    ];

    return colors[index % colors.length];
  }

  // ------------------------------------------------------------
  // FORMAT MONEY
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
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Money Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
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
        icon: const Icon(Icons.add_rounded),
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
                      _welcomeCard(),

                      const SizedBox(height: 14),

                      _summaryCards(),

                      const SizedBox(height: 18),

                      _sectionTitle(
                        'Spending Overview',
                        'By category',
                      ),

                      const SizedBox(height: 8),

                      _categoryChart(),

                      const SizedBox(height: 18),

                      _sectionTitle(
                        'Income vs Expense',
                        'Overall',
                      ),

                      const SizedBox(height: 8),

                      _incomeExpenseChart(),

                      const SizedBox(height: 18),

                      _sectionTitle(
                        'Recent Transactions',
                        '${rows.length} total',
                      ),

                      const SizedBox(height: 8),

                      _recentTransactions(),
                    ],
                  ),
                ),
    );
  }

  // ------------------------------------------------------------
  // WELCOME CARD
  // ------------------------------------------------------------

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Money',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  money(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY CARDS
  // ------------------------------------------------------------

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Income',
            value: totalIncome,
            icon: Icons.arrow_downward_rounded,
            iconColor: Colors.green,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _summaryCard(
            title: 'Expense',
            value: totalExpense,
            icon: Icons.arrow_upward_rounded,
            iconColor: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  money(value),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // CATEGORY CHART
  // ------------------------------------------------------------

  Widget _categoryChart() {
    if (categoryData.isEmpty) {
      return _emptyCard(
        'No expense data yet',
        Icons.pie_chart_outline_rounded,
      );
    }

    final entries = categoryData.entries.toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 52,
                sectionsSpace: 2,
                sections: entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  final color =
                      getCategoryColor(item.key, index);

                  return PieChartSectionData(
                    value: item.value,
                    color: color,
                    radius: 42,
                    title: '',
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 14,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return _legendItem(
                item.key,
                item.value,
                getCategoryColor(item.key, index),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(
    String name,
    double value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 5),

        Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(width: 3),

        Text(
          money(value),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // INCOME VS EXPENSE
  // ------------------------------------------------------------

  Widget _incomeExpenseChart() {
    final maxValue =
        [totalIncome, totalExpense].reduce(
          (a, b) => a > b ? a : b,
        );

    final chartMax =
        maxValue <= 0 ? 100.0 : maxValue * 1.25;

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(10, 15, 18, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: chartMax,
          minY: 0,

          borderData: FlBorderData(show: false),

          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMax / 4,
          ),

          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const SizedBox();
                  }

                  return Text(
                    '₹${value.toInt()}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text(
                        'Income',
                        style: TextStyle(fontSize: 11),
                      );
                    case 1:
                      return const Text(
                        'Expense',
                        style: TextStyle(fontSize: 11),
                      );
                    default:
                      return const SizedBox();
                  }
                },
              ),
            ),
          ),

          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: totalIncome,
                  width: 38,
                  borderRadius: BorderRadius.circular(7),
                  color: Colors.green,
                ),
              ],
            ),

            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: totalExpense,
                  width: 38,
                  borderRadius: BorderRadius.circular(7),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // RECENT TRANSACTIONS
  // ------------------------------------------------------------

  Widget _recentTransactions() {
    if (rows.isEmpty) {
      return _emptyCard(
        'No transactions yet',
        Icons.receipt_long_rounded,
      );
    }

    final recent = rows.reversed.take(10).toList();

    return Column(
      children: recent.map((x) {
        final isPaid =
            x.transaction.toLowerCase() == 'paid';

        final color =
            isPaid ? Colors.red : Colors.green;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(0, 3),
                color: Colors.black.withOpacity(.035),
              ),
            ],
          ),
          child: ListTile(
            dense: true,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 3,
            ),

            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPaid
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 20,
              ),
            ),

            title: Text(
              x.to.isEmpty ? 'Unknown' : x.to,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

            subtitle: Text(
              '${x.category} • ${x.date}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),

            trailing: Text(
              '${isPaid ? '-' : '+'}₹${x.amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ------------------------------------------------------------
  // EMPTY CARD
  // ------------------------------------------------------------

  Widget _emptyCard(
    String text,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ERROR VIEW
  // ------------------------------------------------------------

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.grey.shade500,
            ),

            const SizedBox(height: 12),

            const Text(
              'Unable to load transactions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
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
}
```
