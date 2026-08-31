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

  // Different colors for each category
  final List<Color> chartColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lightGreen,
  ];

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final r = await GoogleSheetApi.getTransactions();

      if (!mounted) return;

      setState(() {
        rows = r;
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

  // ---------------------------------------------------------
  // CATEGORY DATA
  // ---------------------------------------------------------

  Map<String, double> get categoryData {
    final Map<String, double> map = {};

    for (final x in rows) {
      if (x.transaction.toLowerCase() == 'paid' &&
          x.amount > 0) {
        final category =
            x.category.trim().isEmpty ? 'Others' : x.category.trim();

        map[category] = (map[category] ?? 0) + x.amount;
      }
    }

    return map;
  }

  // ---------------------------------------------------------
  // TOTAL EXPENSE
  // ---------------------------------------------------------

  double get totalExpense {
    return rows
        .where(
          (x) =>
              x.transaction.toLowerCase() == 'paid',
        )
        .fold(0.0, (sum, x) => sum + x.amount);
  }

  // ---------------------------------------------------------
  // TOTAL RECEIVED
  // ---------------------------------------------------------

  double get totalReceived {
    return rows
        .where(
          (x) =>
              x.transaction.toLowerCase() == 'received',
        )
        .fold(0.0, (sum, x) => sum + x.amount);
  }

  // ---------------------------------------------------------
  // COLOR FOR CATEGORY
  // ---------------------------------------------------------

  Color colorForIndex(int index) {
    return chartColors[index % chartColors.length];
  }

  // ---------------------------------------------------------
  // PIE CHART
  // ---------------------------------------------------------

  Widget buildPieChart() {
    final data = categoryData;

    if (data.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No expense data available',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final entries = data.entries.toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expenses by Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 45,

                  sections: List.generate(
                    entries.length,
                    (index) {
                      final entry = entries[index];

                      return PieChartSectionData(
                        value: entry.value,
                        color: colorForIndex(index),
                        radius: 85,

                        title:
                            '${entry.key}\n₹${entry.value.toStringAsFixed(0)}',

                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // LEGEND
            Column(
              children: List.generate(
                entries.length,
                (index) {
                  final entry = entries[index];

                  final percentage =
                      totalExpense > 0
                          ? (entry.value / totalExpense) * 100
                          : 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorForIndex(index),
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        Text(
                          '₹${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(width: 8),

                        SizedBox(
                          width: 50,
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // SUMMARY CARDS
  // ---------------------------------------------------------

  Widget buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expense',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '₹${totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Received',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '₹${totalReceived.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        Card(
          elevation: 2,
          child: ListTile(
            title: const Text(
              'Transactions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Total number of transactions',
            ),
            trailing: Text(
              '${rows.length}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // TRANSACTION LIST
  // ---------------------------------------------------------

  Widget buildTransactionList() {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Text(
            'No transactions found',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    final recent = rows.reversed.take(20).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        const Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        ...recent.map(
          (x) {
            final isPaid =
                x.transaction.toLowerCase() == 'paid';

            return Card(
              elevation: 1,
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    isPaid
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                ),

                title: Text(
                  x.to.isEmpty ? 'Unknown' : x.to,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: Text(
                  '${x.date} ${x.time}\n'
                  '${x.category} · ${x.status}',
                ),

                isThreeLine: true,

                trailing: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${x.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isPaid
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      x.transaction,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Money Tracker',
        ),
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AddTransaction(),
            ),
          );

          if (ok == true) {
            load();
          }
        },
        child: const Icon(Icons.add),
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )

          : error != null
              ? Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          error!,
                          textAlign:
                              TextAlign.center,
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        ElevatedButton(
                          onPressed: load,
                          child:
                              const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )

              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.all(16),
                    children: [
                      buildSummaryCards(),

                      const SizedBox(height: 15),

                      buildPieChart(),

                      const SizedBox(height: 15),

                      buildTransactionList(),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}