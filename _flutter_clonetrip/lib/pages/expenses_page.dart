import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data_service_scope.dart';
import '../widgets/add_expense_sheet.dart';

import '../models/expense.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({
    super.key,
    required this.groupName,
    required this.expenses,
    this.groupId,
  });

  final String groupName;
  final String? groupId;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final totals = _computeBalances(expenses);
    return Scaffold(
      appBar: AppBar(title: Text('Expenses • $groupName')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balances',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final entry in totals.entries)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(entry.value.toStringAsFixed(2)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Recent Expenses',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final e in expenses)
            Card(
              elevation: 0,
              color: Theme.of(context).cardColor,
              child: ListTile(
                title: Text(e.description),
                subtitle: Text('${e.currency} ${e.amount.toStringAsFixed(2)}'),
                trailing: const Icon(Icons.receipt_long),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';
          final service = DataServiceScope.of(context);
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) {
              return AddExpenseSheet(
                onSubmit:
                    ({
                      required double amount,
                      required String currency,
                      required String description,
                    }) async {
                      final gid =
                          groupId ??
                          (expenses.isNotEmpty
                              ? expenses.first.groupId
                              : groupName);
                      await service.createExpense(
                        groupId: gid,
                        payerUserId: userId,
                        amount: amount,
                        currency: currency,
                        splits: {userId: amount},
                        description: description,
                      );
                    },
              );
            },
          );
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Map<String, double> _computeBalances(List<Expense> expenses) {
    final totals = <String, double>{};
    for (final e in expenses) {
      totals[e.payerUserId] = (totals[e.payerUserId] ?? 0) + e.amount;
      for (final entry in e.splits.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) - entry.value;
      }
    }
    return totals;
  }
}
