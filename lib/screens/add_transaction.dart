import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/google_sheet_api.dart';

class AddTransaction extends StatefulWidget {
  const AddTransaction({super.key});

  @override
  State<AddTransaction> createState() => _AddState();
}

class _AddState extends State<AddTransaction> {
  final amount = TextEditingController();
  final to = TextEditingController();
  final notes = TextEditingController();

  String type = 'Paid';
  String category = 'Others';
  String bank = 'XXXXXXXX01';
  String status = 'Completed';
  String mode = 'UPI';

  bool saving = false;

  @override
  void dispose() {
    amount.dispose();
    to.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final value = double.tryParse(amount.text.trim());

    if (value == null || value <= 0 || to.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount and recipient'),
        ),
      );

      return;
    }

    setState(() {
      saving = true;
    });

    final now = DateTime.now();

    try {
      await GoogleSheetApi.addTransaction(
        TransactionModel(
          date: DateFormat('yyyy-MM-dd').format(now),
          time: DateFormat('h:mm:ss a').format(now),
          transaction: type,
          amount: value,
          to: to.text.trim(),
          bank: bank,
          status: status,
          category: category,
          mode: mode,
          notes: notes.text.trim(),
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Widget drop(
    String label,
    String currentValue,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (x) => DropdownMenuItem(
              value: x,
              child: Text(x),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          drop(
            'Type',
            type,
            [
              'Paid',
              'Received',
            ],
            (v) => setState(() => type = v!),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: to,
            decoration: const InputDecoration(
              labelText: 'To / From',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          drop(
            'Category',
            category,
            [
              'Food',
              'Travel',
              'Bills',
              'Shopping',
              'Entertainment',
              'Family',
              'Health',
              'Salary',
              'Others',
            ],
            (v) => setState(() => category = v!),
          ),

          const SizedBox(height: 14),

          drop(
            'Bank',
            bank,
            [
              'XXXXXXXX01',
              'XXXXXXXX02',
              'XXXXXXXX03',
            ],
            (v) => setState(() => bank = v!),
          ),

          const SizedBox(height: 14),

          drop(
            'Payment Mode',
            mode,
            [
              'UPI',
              'Cash',
              'Card',
              'Net Banking',
            ],
            (v) => setState(() => mode = v!),
          ),

          const SizedBox(height: 14),

          drop(
            'Status',
            status,
            [
              'Completed',
              'Failed',
              'Cancelled',
            ],
            (v) => setState(() => status = v!),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              saving ? 'Saving...' : 'Save Transaction',
            ),
          ),
        ],
      ),
    );
  }
}