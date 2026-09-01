import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/google_sheet_api.dart';
import '../services/payment_detection_service.dart';
import 'add_transaction.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  static const List<String> _periods = [
    'This Month',
    'Last Month',
    'This Year',
    'All Time',
  ];

  static const List<String> _categories = [
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Entertainment',
    'Family',
    'Health',
    'Salary',
    'Others',
  ];

  static const List<String> _banks = [
    'Unknown',
    'XXXXXXXX01',
    'XXXXXXXX02',
    'XXXXXXXX03',
  ];

  static const List<String> _modes = [
    'UPI',
    'Cash',
    'Card',
    'Net Banking',
    'Unknown',
  ];

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

  List<TransactionModel> rows = [];
  bool loading = true;
  String? error;
  String selectedPeriod = 'This Month';

  bool notificationAccessEnabled = false;
  bool notificationAccessChecked = false;
  bool _checkingDetectedPayments = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshNotificationAccess();
      await _checkDetectedPayments();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationAccess().then((_) => _checkDetectedPayments());
    }
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

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
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _refreshNotificationAccess() async {
    final enabled = await PaymentDetectionService.isNotificationAccessEnabled();

    if (!mounted) return;

    setState(() {
      notificationAccessEnabled = enabled;
      notificationAccessChecked = true;
    });
  }

  Future<void> _openNotificationSettings() async {
    await PaymentDetectionService.openNotificationAccessSettings();
  }

  Future<void> _checkDetectedPayments() async {
    if (!mounted || !notificationAccessEnabled || _checkingDetectedPayments) {
      return;
    }

    _checkingDetectedPayments = true;

    try {
      final pending = await PaymentDetectionService.getPendingPayments();

      if (!mounted || pending.isEmpty) return;

      await _reviewDetectedPayment(pending.first);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-capture check failed: $e'),
          ),
        );
      }
    } finally {
      _checkingDetectedPayments = false;
    }
  }

  Future<void> _reviewDetectedPayment(DetectedPayment payment) async {
    final detectedAt = DateTime.fromMillisecondsSinceEpoch(
      payment.timestamp,
    );

    final amountController = TextEditingController(
      text: payment.amount.toStringAsFixed(
        payment.amount == payment.amount.roundToDouble() ? 0 : 2,
      ),
    );

    final toController = TextEditingController(
      text: payment.to,
    );

    final notesController = TextEditingController(
      text: 'Auto-detected from ${payment.sourceApp}',
    );

    String type = payment.transaction == 'Received' ? 'Received' : 'Paid';

    String category = 'Others';

    String bank = 'Unknown';

    String mode = _modes.contains(payment.mode) ? payment.mode : 'Unknown';

    String? validationError;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Payment detected'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment.sourceApp,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('dd MMM yyyy · h:mm a')
                                  .format(detectedAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (payment.detectedBank.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Detected account: ${payment.detectedBank}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Text(
                              'Confidence: ${payment.confidence}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Paid',
                            child: Text('Paid'),
                          ),
                          DropdownMenuItem(
                            value: 'Received',
                            child: Text('Received'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => type = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: toController,
                        decoration: const InputDecoration(
                          labelText: 'To / From',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => category = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: bank,
                        decoration: const InputDecoration(
                          labelText: 'Bank',
                          border: OutlineInputBorder(),
                        ),
                        items: _banks
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => bank = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: mode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode',
                          border: OutlineInputBorder(),
                        ),
                        items: _modes
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => mode = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (validationError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          validationError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text(
                          'Detected notification text',
                          style: TextStyle(fontSize: 13),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              payment.rawText,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, 'later');
                  },
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, 'ignore');
                  },
                  child: const Text('Ignore'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim().replaceAll(',', ''),
                    );

                    if (amount == null || amount <= 0) {
                      setDialogState(() {
                        validationError = 'Enter a valid amount.';
                      });
                      return;
                    }

                    if (toController.text.trim().isEmpty) {
                      setDialogState(() {
                        validationError = 'Enter the recipient or sender.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, 'save');
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) {
      amountController.dispose();
      toController.dispose();
      notesController.dispose();
      return;
    }

    if (action == 'ignore') {
      await PaymentDetectionService.removePayment(payment.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detected payment ignored.'),
          ),
        );
      }
    }

    if (action == 'save') {
      final amount = double.tryParse(
        amountController.text.trim().replaceAll(',', ''),
      );

      if (amount != null && amount > 0) {
        try {
          await GoogleSheetApi.addTransaction(
            TransactionModel(
              date: DateFormat('yyyy-MM-dd').format(detectedAt),
              time: DateFormat('h:mm:ss a').format(detectedAt),
              transaction: type,
              amount: amount,
              to: toController.text.trim(),
              bank: bank,
              status: 'Completed',
              category: category,
              mode: mode,
              notes: notesController.text.trim(),
            ),
          );

          await PaymentDetectionService.removePayment(payment.id);
          await load();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Detected payment saved to Google Sheets.',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not save detected payment: $e'),
              ),
            );
          }
        }
      }
    }

    amountController.dispose();
    toController.dispose();
    notesController.dispose();
  }

  DateTime? _dateOf(TransactionModel item) {
    final raw = item.date.trim();

    if (raw.isEmpty) return null;

    final direct = DateTime.tryParse(raw);

    if (direct != null) return direct;

    const formats = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'MM/dd/yyyy',
      'd MMM yyyy',
      'MMM d, yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(raw);
      } catch (_) {
        // Try the next supported format.
      }
    }

    return null;
  }

  bool _isCompleted(TransactionModel item) {
    final status = item.status.trim().toLowerCase();
    return status.isEmpty || status == 'completed';
  }

  bool _isPaid(TransactionModel item) =>
      item.transaction.trim().toLowerCase() == 'paid';

  bool _isReceived(TransactionModel item) =>
      item.transaction.trim().toLowerCase() == 'received';

  bool _matchesSelectedPeriod(TransactionModel item) {
    if (selectedPeriod == 'All Time') return true;

    final date = _dateOf(item);

    if (date == null) return false;

    final now = DateTime.now();

    if (selectedPeriod == 'This Month') {
      return date.year == now.year && date.month == now.month;
    }

    if (selectedPeriod == 'Last Month') {
      final previousMonth = DateTime(
        now.year,
        now.month - 1,
        1,
      );

      return date.year == previousMonth.year &&
          date.month == previousMonth.month;
    }

    if (selectedPeriod == 'This Year') {
      return date.year == now.year;
    }

    return true;
  }

  List<TransactionModel> get filteredRows =>
      rows.where(_matchesSelectedPeriod).toList();

  List<TransactionModel> get analyticsRows =>
      filteredRows.where(_isCompleted).toList();

  double get totalPaid =>
      analyticsRows.where(_isPaid).fold(0.0, (sum, item) => sum + item.amount);

  double get totalReceived => analyticsRows
      .where(_isReceived)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get balance => totalReceived - totalPaid;

  Map<String, double> _aggregatePaidBy(
    String Function(TransactionModel) keyOf,
  ) {
    final data = <String, double>{};

    for (final item in analyticsRows.where(_isPaid)) {
      final rawKey = keyOf(item).trim();
      final key = rawKey.isEmpty ? 'Unknown' : rawKey;

      data[key] = (data[key] ?? 0) + item.amount;
    }

    final sorted = data.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    return Map<String, double>.fromEntries(sorted);
  }

  Map<String, double> get categoryData => _aggregatePaidBy(
        (item) => item.category.trim().isEmpty ? 'Others' : item.category,
      );

  Map<String, double> get bankData => _aggregatePaidBy((item) => item.bank);

  Map<String, double> get modeData => _aggregatePaidBy((item) => item.mode);

  double _paidForMonth(int year, int month) {
    return rows.where((item) {
      if (!_isCompleted(item) || !_isPaid(item)) {
        return false;
      }

      final date = _dateOf(item);

      return date != null && date.year == year && date.month == month;
    }).fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
  }

  double get thisMonthPaid {
    final now = DateTime.now();

    return _paidForMonth(
      now.year,
      now.month,
    );
  }

  double get lastMonthPaid {
    final now = DateTime.now();

    final previous = DateTime(
      now.year,
      now.month - 1,
      1,
    );

    return _paidForMonth(
      previous.year,
      previous.month,
    );
  }

  TransactionModel? get largestExpense {
    TransactionModel? largest;

    for (final item in analyticsRows.where(_isPaid)) {
      if (largest == null || item.amount > largest.amount) {
        largest = item;
      }
    }

    return largest;
  }

  MapEntry<String, double>? get topCategory {
    if (categoryData.isEmpty) return null;

    return categoryData.entries.first;
  }

  List<_MonthSpend> get monthlyTrend {
    final now = DateTime.now();

    final points = <_MonthSpend>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(
        now.year,
        now.month - i,
        1,
      );

      points.add(
        _MonthSpend(
          date: month,
          amount: _paidForMonth(
            month.year,
            month.month,
          ),
        ),
      );
    }

    return points;
  }

  Color colorForIndex(int index) => chartColors[index % chartColors.length];

  String money(double value) {
    final formatted = NumberFormat.decimalPattern(
      'en_IN',
    ).format(value.round());

    return '₹$formatted';
  }

  String _shortLabel(
    String value, {
    int max = 10,
  }) {
    if (value.length <= max) return value;

    return '${value.substring(0, max - 1)}…';
  }

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
            tooltip: notificationAccessEnabled
                ? 'Check detected payments'
                : 'Enable automatic capture',
            onPressed: () async {
              if (notificationAccessEnabled) {
                await _checkDetectedPayments();
              } else {
                await _openNotificationSettings();
              }
            },
            icon: Icon(
              notificationAccessEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: load,
            icon: const Icon(
              Icons.sync_rounded,
            ),
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
                      _autoCaptureBanner(),
                      const SizedBox(height: 14),
                      _periodFilter(),
                      const SizedBox(height: 14),
                      _summaryCards(),
                      const SizedBox(height: 14),
                      _monthComparisonCard(),
                      const SizedBox(height: 14),
                      _insightCards(),
                      const SizedBox(height: 16),
                      _categoryChart(),
                      const SizedBox(height: 16),
                      _monthlyTrendChart(),
                      const SizedBox(height: 16),
                      _incomeExpenseChart(),
                      const SizedBox(height: 16),
                      _paymentModeChart(),
                      const SizedBox(height: 16),
                      _bankChart(),
                      const SizedBox(height: 22),
                      _recentTransactions(),
                    ],
                  ),
                ),
    );
  }

  Widget _autoCaptureBanner() {
    if (!notificationAccessChecked) {
      return const SizedBox.shrink();
    }

    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: notificationAccessEnabled
            ? Colors.green.withValues(alpha: 0.08)
            : primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notificationAccessEnabled
              ? Colors.green.withValues(alpha: 0.20)
              : primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: notificationAccessEnabled
                ? Colors.green.withValues(alpha: 0.12)
                : primary.withValues(alpha: 0.12),
            child: Icon(
              notificationAccessEnabled
                  ? Icons.auto_awesome_rounded
                  : Icons.notifications_active_outlined,
              color: notificationAccessEnabled ? Colors.green : primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationAccessEnabled
                      ? 'Automatic payment capture is on'
                      : 'Enable automatic payment capture',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notificationAccessEnabled
                      ? 'Matching payment notifications stay on-device until you confirm them.'
                      : 'Detect UPI/bank payment notifications and review before saving.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (notificationAccessEnabled)
            IconButton(
              tooltip: 'Check now',
              onPressed: _checkDetectedPayments,
              icon: const Icon(
                Icons.search_rounded,
              ),
            )
          else
            FilledButton.tonal(
              onPressed: _openNotificationSettings,
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  Widget _periodFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _periods.map((period) {
              final selected = selectedPeriod == period;

              return Padding(
                padding: const EdgeInsets.only(
                  right: 8,
                ),
                child: ChoiceChip(
                  label: Text(period),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      selectedPeriod = period;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

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
              backgroundColor: iconColor.withValues(alpha: 0.12),
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
    final color = positive ? Colors.green : Colors.red;

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
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                positive
                    ? Icons.account_balance_wallet_rounded
                    : Icons.warning_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance · $selectedPeriod',
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
              '${filteredRows.length} txns',
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

  Widget _monthComparisonCard() {
    final previous = lastMonthPaid;
    final current = thisMonthPaid;

    String message;
    IconData icon;
    Color color;

    if (previous == 0 && current == 0) {
      message = 'No spending recorded in either month';
      icon = Icons.remove_rounded;
      color = Colors.blueGrey;
    } else if (previous == 0) {
      message = 'No previous-month baseline';
      icon = Icons.trending_up_rounded;
      color = Colors.orange;
    } else {
      final change = ((current - previous) / previous) * 100;

      if (change > 0.5) {
        message = '${change.abs().toStringAsFixed(0)}% higher than last month';
        icon = Icons.trending_up_rounded;
        color = Colors.red;
      } else if (change < -0.5) {
        message = '${change.abs().toStringAsFixed(0)}% lower than last month';
        icon = Icons.trending_down_rounded;
        color = Colors.green;
      } else {
        message = 'About the same as last month';
        icon = Icons.trending_flat_rounded;
        color = Colors.blueGrey;
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This month spending',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    money(current),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Last month',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
                Text(
                  money(previous),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightCards() {
    final category = topCategory;
    final largest = largestExpense;

    return Row(
      children: [
        Expanded(
          child: _insightCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Top Category',
            value: category?.key ?? '—',
            subtitle: category == null ? 'No expenses' : money(category.value),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _insightCard(
            icon: Icons.local_fire_department_rounded,
            title: 'Largest Expense',
            value: largest == null ? '—' : money(largest.amount),
            subtitle: largest == null
                ? 'No expenses'
                : (largest.to.trim().isEmpty ? 'Unknown' : largest.to.trim()),
          ),
        ),
      ],
    );
  }

  Widget _insightCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: primary,
              size: 20,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChart() {
    return _donutCard(
      title: 'Spending by Category',
      subtitle: '$selectedPeriod · Where your money is going',
      data: categoryData,
      emptyText: 'No category spending for this period',
      height: 220,
    );
  }

  Widget _paymentModeChart() {
    return _donutCard(
      title: 'Payment Modes',
      subtitle: '$selectedPeriod · UPI, cash, card and more',
      data: modeData,
      emptyText: 'No payment-mode spending for this period',
      height: 200,
    );
  }

  Widget _donutCard({
    required String title,
    required String subtitle,
    required Map<String, double> data,
    required String emptyText,
    required double height,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            if (data.isEmpty)
              _emptyChart(emptyText)
            else
              SizedBox(
                height: height,
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                          sections: data.entries.toList().asMap().entries.map(
                            (entry) {
                              return PieChartSectionData(
                                value: entry.value.value,
                                color: colorForIndex(
                                  entry.key,
                                ),
                                radius: 50,
                                title: '',
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: ListView(
                        children: data.entries.toList().asMap().entries.map(
                          (entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: colorForIndex(
                                        entry.key,
                                      ),
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
                                    money(
                                      entry.value.value,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ).toList(),
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

  Widget _monthlyTrendChart() {
    final data = monthlyTrend;

    final maxAmount = data.fold<double>(
      0,
      (max, item) => item.amount > max ? item.amount : max,
    );

    final maxY = maxAmount <= 0 ? 1.0 : maxAmount * 1.2;

    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '6-Month Spending Trend',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed expenses by month',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
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
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();

                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(
                              top: 6,
                            ),
                            child: Text(
                              DateFormat('MMM').format(
                                data[index].date,
                              ),
                              style: const TextStyle(
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data
                          .asMap()
                          .entries
                          .map(
                            (entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value.amount,
                            ),
                          )
                          .toList(),
                      isCurved: true,
                      color: primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: primary.withValues(
                          alpha: 0.08,
                        ),
                      ),
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

  Widget _incomeExpenseChart() {
    final maxValue = [
      totalPaid,
      totalReceived,
      1.0,
    ].reduce(
      (a, b) => a > b ? a : b,
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
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
              '$selectedPeriod · Received vs spent',
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
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const Text(
                              'Received',
                              style: TextStyle(
                                fontSize: 11,
                              ),
                            );
                          }

                          if (value == 1) {
                            return const Text(
                              'Expense',
                              style: TextStyle(
                                fontSize: 11,
                              ),
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

  Widget _bankChart() {
    final entries = bankData.entries.take(5).toList();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
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
              '$selectedPeriod · Which account funded your expenses',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            if (entries.isEmpty)
              _emptyChart(
                'No bank spending for this period',
              )
            else
              SizedBox(
                height: 175,
                child: BarChart(
                  BarChartData(
                    maxY: entries.first.value * 1.25,
                    minY: 0,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(
                      show: false,
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false,
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();

                            if (index < 0 || index >= entries.length) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 6,
                              ),
                              child: Text(
                                _shortLabel(
                                  entries[index].key,
                                  max: 9,
                                ),
                                style: const TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: entries.asMap().entries.map(
                      (entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.value,
                              width: 24,
                              borderRadius: BorderRadius.circular(7),
                              color: colorForIndex(
                                entry.key,
                              ),
                            ),
                          ],
                        );
                      },
                    ).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyChart(String text) {
    return SizedBox(
      height: 90,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _recentTransactions() {
    final recent = filteredRows.reversed.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              selectedPeriod,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          _emptyTransactions()
        else
          ...recent.map(_transactionCard),
      ],
    );
  }

  Widget _emptyTransactions() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No transactions for $selectedPeriod',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _transactionCard(
    TransactionModel item,
  ) {
    final paid = _isPaid(item);

    final status =
        item.status.trim().isEmpty ? 'Completed' : item.status.trim();

    final completed = status.toLowerCase() == 'completed';

    final mode = item.mode.trim();

    final category =
        item.category.trim().isEmpty ? 'Others' : item.category.trim();

    final bank = item.bank.trim();

    final details = <String>[
      item.date.trim(),
      category,
      if (bank.isNotEmpty) bank,
      if (mode.isNotEmpty) mode,
    ].where((value) => value.isNotEmpty).join(' · ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        leading: CircleAvatar(
          backgroundColor:
              (paid ? Colors.red : Colors.green).withValues(alpha: 0.10),
          child: Icon(
            paid ? Icons.north_east_rounded : Icons.south_west_rounded,
            color: paid ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          item.to.trim().isEmpty ? 'Unknown' : item.to.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
            if (!completed)
              Text(
                status,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        trailing: Text(
          '${paid ? '-' : '+'}${money(item.amount)}',
          style: TextStyle(
            color: paid ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _MonthSpend {
  final DateTime date;
  final double amount;

  const _MonthSpend({
    required this.date,
    required this.amount,
  });
}
