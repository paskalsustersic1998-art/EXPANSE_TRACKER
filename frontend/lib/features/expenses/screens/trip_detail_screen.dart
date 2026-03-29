import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trips/models/trip_model.dart';
import '../../trips/providers/trips_provider.dart';
import '../models/expense_model.dart';
import '../providers/expenses_provider.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  final int tripId;
  final String tripName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expensesProvider(tripId));
    final tripsState = ref.watch(tripsProvider);

    ref.listen<ExpensesState>(expensesProvider(tripId), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    ref.listen<TripsState>(tripsProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    final matches = tripsState.trips.where((t) => t.id == tripId);
    final trip = matches.isEmpty ? null : matches.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip?.name ?? tripName),
        actions: [
          if (trip != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit trip',
              onPressed: () => _showEditTripDialog(context, ref, trip),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete trip',
            onPressed: () => _confirmDeleteTrip(context, ref),
          ),
        ],
      ),
      body: _buildBody(context, state, trip, ref),
      floatingActionButton: FloatingActionButton(
        onPressed: trip == null ? null : () => _showAddExpenseDialog(context, ref, trip),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ExpensesState state, TripModel? trip, WidgetRef ref) {
    if (state.isLoading && state.balances.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (trip != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Participants', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () => _showAddParticipantDialog(context, ref),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final p in trip.participants)
                  Chip(
                    avatar: Icon(Icons.person, size: 16),
                    label: Text(p.email),
                    onDeleted: state.balances.any(
                            (b) => b.email == p.email && b.net != 0)
                        ? null
                        : () => _confirmRemoveParticipant(context, ref, p),
                  ),
              ],
            ),
          ),
          const Divider(height: 24),
        ],
        if (state.expenses.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Expenses', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final expense in state.expenses)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Opacity(
                opacity: expense.isSettled ? 0.5 : 1.0,
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      expense.isSettled ? Icons.check_circle : Icons.receipt,
                      color: expense.isSettled ? Colors.green : null,
                    ),
                    title: Text(
                      expense.description,
                      style: expense.isSettled
                          ? const TextStyle(decoration: TextDecoration.lineThrough)
                          : null,
                    ),
                    subtitle: Text('\$${expense.amount.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!expense.isSettled)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            tooltip: 'Edit expense',
                            onPressed: trip == null
                                ? null
                                : () => _showEditExpenseDialog(context, ref, trip, expense),
                          ),
                        IconButton(
                          icon: Icon(
                            expense.isSettled
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          tooltip: expense.isSettled ? 'Already settled' : 'Settle this expense',
                          onPressed: expense.isSettled
                              ? null
                              : () => _confirmSettleExpense(context, ref, expense),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDeleteExpense(context, ref, expense),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Divider(height: 24),
        ],
        if (state.expenses.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No expenses yet. Tap + to add one.'),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balances', style: Theme.of(context).textTheme.titleMedium),
                if (state.balances.any((b) => b.net != 0))
                  TextButton.icon(
                    onPressed: () => _showSettleUpDialog(context, ref),
                    icon: Icon(Icons.handshake, size: 18),
                    label: Text('Settle Up'),
                  ),
              ],
            ),
          ),
          for (final entry in state.balances)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(entry.email),
                  trailing: Text(
                    '${entry.net >= 0 ? '+' : ''}\$${entry.net.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: entry.net >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(entry.net >= 0 ? 'is owed' : 'owes'),
                ),
              ),
            ),
        ],
        if (state.settlements.isNotEmpty) ...[
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Past Settlements', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final settlement in state.settlements)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.history),
                  title: Text(_formatSettlementDate(settlement.createdAt.toLocal())),
                  subtitle: Text(
                    settlement.transactions.isEmpty
                        ? 'All balanced'
                        : '${settlement.transactions.length} transaction${settlement.transactions.length == 1 ? '' : 's'}',
                  ),
                  children: [
                    for (final t in settlement.transactions)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.arrow_forward, size: 18),
                        title: Text('${t.fromEmail} → ${t.toEmail}'),
                        trailing: Text(
                          '\$${t.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _confirmDeleteTrip(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
          'This will permanently delete the trip and all its data. '
          'You can only delete a trip that has no expenses, or has been settled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) async {
                final ok = await ref.read(tripsProvider.notifier).deleteTrip(tripId);
                if (ok && context.mounted) context.go('/trips');
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveParticipant(BuildContext context, WidgetRef ref, ParticipantModel p) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text('Remove ${p.email} from this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ref.read(tripsProvider.notifier).removeParticipant(tripId, p.id);
              });
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmSettleExpense(BuildContext context, WidgetRef ref, ExpenseModel expense) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settle Expense'),
        content: Text(
          'Mark "${expense.description}" (\$${expense.amount.toStringAsFixed(2)}) as settled? '
          'It will be removed from active balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ref.read(expensesProvider(tripId).notifier).settleExpense(expense.id);
              });
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, WidgetRef ref, ExpenseModel expense) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.description}" (\$${expense.amount.toStringAsFixed(2)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ref.read(expensesProvider(tripId).notifier).deleteExpense(expense.id);
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddParticipantDialog(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Participant'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email address',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Email is required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final email = emailCtrl.text.trim();
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ref.read(tripsProvider.notifier).addParticipant(tripId, email);
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showSettleUpDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settle Up'),
        content: const Text('Calculate the minimum payments to zero out all balances?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) async {
                final settlement =
                    await ref.read(expensesProvider(tripId).notifier).settleUp();
                if (settlement != null && context.mounted) {
                  _showSettlementResult(context, settlement);
                }
              });
            },
            child: const Text('Calculate'),
          ),
        ],
      ),
    );
  }

  void _showSettlementResult(BuildContext context, Settlement settlement) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settlement Plan'),
        content: settlement.transactions.isEmpty
            ? const Text('Everyone is already balanced!')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in settlement.transactions)
                    ListTile(
                      leading: const Icon(Icons.arrow_forward),
                      title: Text('${t.fromEmail} → ${t.toEmail}'),
                      trailing: Text(
                        '\$${t.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showEditTripDialog(BuildContext context, WidgetRef ref, TripModel trip) {
    final nameCtrl = TextEditingController(text: trip.name);
    final descCtrl = TextEditingController(text: trip.description ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Trip'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Trip name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtrl.text.trim();
              final desc = descCtrl.text.trim();
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ref.read(tripsProvider.notifier).updateTrip(
                      tripId,
                      name: name,
                      description: desc.isEmpty ? null : desc,
                    );
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref, TripModel trip) {
    final currentUser = ref.read(authProvider).user;
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Mutable state lives outside StatefulBuilder so it survives rebuilds
    final defaultPayer = trip.participants.firstWhere(
      (p) => p.email == currentUser?.email,
      orElse: () => trip.participants.first,
    );
    int selectedPayerId = defaultPayer.id;
    final Set<int> selectedSplitIds = {for (final p in trip.participants) p.id};

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final parsed = double.tryParse(v ?? '');
                      if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Paid by', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedPayerId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: [
                      for (final p in trip.participants)
                        DropdownMenuItem(value: p.id, child: Text(p.email)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedPayerId = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Split among', style: Theme.of(context).textTheme.labelLarge),
                  for (final p in trip.participants)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.email),
                      value: selectedSplitIds.contains(p.id),
                      onChanged: (v) => setState(() =>
                          v == true
                              ? selectedSplitIds.add(p.id)
                              : selectedSplitIds.remove(p.id)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (selectedSplitIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Select at least one participant to split among')),
                  );
                  return;
                }
                final desc = descCtrl.text.trim();
                final amount = double.parse(amountCtrl.text);
                final payerId = selectedPayerId;
                final splitIds = selectedSplitIds.toList();
                Navigator.of(dialogContext).pop();
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  ref.read(expensesProvider(tripId).notifier).addExpense(
                        desc,
                        amount,
                        paidBy: payerId,
                        splitAmong: splitIds,
                      );
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSettlementDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} – $h:$m';
  }

  void _showEditExpenseDialog(
      BuildContext context, WidgetRef ref, TripModel trip, ExpenseModel expense) {
    final descCtrl = TextEditingController(text: expense.description);
    final amountCtrl = TextEditingController(text: expense.amount.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    int selectedPayerId = expense.paidBy;
    final Set<int> selectedSplitIds = expense.splits.map((s) => s.userId).toSet();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final parsed = double.tryParse(v ?? '');
                      if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Paid by', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedPayerId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: [
                      for (final p in trip.participants)
                        DropdownMenuItem(value: p.id, child: Text(p.email)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedPayerId = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Split among', style: Theme.of(context).textTheme.labelLarge),
                  for (final p in trip.participants)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.email),
                      value: selectedSplitIds.contains(p.id),
                      onChanged: (v) => setState(() =>
                          v == true
                              ? selectedSplitIds.add(p.id)
                              : selectedSplitIds.remove(p.id)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (selectedSplitIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Select at least one participant to split among')),
                  );
                  return;
                }
                final desc = descCtrl.text.trim();
                final amount = double.parse(amountCtrl.text);
                final payerId = selectedPayerId;
                final splitIds = selectedSplitIds.toList();
                Navigator.of(dialogContext).pop();
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  ref.read(expensesProvider(tripId).notifier).updateExpense(
                        expense.id,
                        description: desc,
                        amount: amount,
                        paidBy: payerId,
                        splitAmong: splitIds,
                      );
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
