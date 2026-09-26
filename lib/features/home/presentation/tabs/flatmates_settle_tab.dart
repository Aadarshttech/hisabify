import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/expenses/data/expense_repository.dart';

class FlatmatesSettleTab extends StatelessWidget {
  final List<Expense> expenses;
  final List<Settlement> settlements;
  final List<Flatmate> flatmates;
  final String currentUserName;
  final Function(String from, String to, double amount, String? note) onRecordSettlement;
  final Function(String settlementId)? onDeleteSettlement;
  const FlatmatesSettleTab({
    super.key,
    required this.expenses,
    required this.settlements,
    required this.flatmates,
    required this.currentUserName,
    required this.onRecordSettlement,
    this.onDeleteSettlement,
  });

  void _showRecordSettlementModal(BuildContext context, {String? defaultFrom, String? defaultTo, double? defaultAmount}) {
    final memberNames = flatmates.map((f) => f.name).toList();
    if (memberNames.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 2 flatmates are required to record a settlement.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    String? fromPerson = defaultFrom != null && memberNames.contains(defaultFrom)
        ? defaultFrom
        : memberNames.first;
    String? toPerson = defaultTo != null && memberNames.contains(defaultTo)
        ? defaultTo
        : memberNames[1];
    final amountController = TextEditingController(
      text: defaultAmount != null && defaultAmount > 0 ? CurrencyUtils.formatAmount(defaultAmount) : '',
    );
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Record Settle-Up Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkerText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Log cash or UPI payment between two flatmates',
                style: TextStyle(fontSize: 12, color: AppTheme.lightText),
              ),
              const SizedBox(height: 18),

              // From (Who Paid)
              const Text(
                'Payer (Who sent money)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkerText),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: fromPerson,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: flatmates.map((f) {
                  return DropdownMenuItem(value: f.name, child: Text(f.name, style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => fromPerson = val);
                },
              ),
              const SizedBox(height: 14),

              // To (Who Received)
              const Text(
                'Recipient (Who received money)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkerText),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: toPerson,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: flatmates.map((f) {
                  return DropdownMenuItem(value: f.name, child: Text(f.name, style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => toPerson = val);
                },
              ),
              const SizedBox(height: 14),

              // Amount
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppTheme.primary, size: 18),
                  filled: true,
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm Button
              ElevatedButton(
                onPressed: () {
                  final double? amount = double.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }
                  if (fromPerson == null || toPerson == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both sender and recipient')),
                    );
                    return;
                  }
                  if (fromPerson == toPerson) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sender and recipient must be different')),
                    );
                    return;
                  }

                  onRecordSettlement(fromPerson!, toPerson!, amount, noteController.text.trim());
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Record Settlement',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, double> netBalances =
        ExpenseRepository.calculateNetBalances(expenses, settlements, flatmates);
    final Map<String, double> totalPaidByPerson =
        ExpenseRepository.calculateTotalPaidByPerson(expenses, flatmates);
    final Map<String, double> effectivePaidByPerson =
        ExpenseRepository.calculateEffectivePaidByPerson(expenses, settlements, flatmates);
    final List<DebtTransfer> debtTransfers =
        ExpenseRepository.calculateDebtTransfers(netBalances);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Header
        const Text(
          'Settle Balances',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppTheme.darkerText,
          ),
        ),
        const SizedBox(height: 16),

        // Automated Debt Transfers Section (Who Owes Whom)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Direct Settle-Up Transfers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkerText,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      '${debtTransfers.length} payments to settle',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Simplest payments to square off all ${flatmates.length} flatmates completely',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.lightText),
              ),
              const SizedBox(height: 14),

              if (flatmates.length < 2)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_add_outlined, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Add flatmates to this room to track shared balances',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkerText,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                )
              else if (debtTransfers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.positiveLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.positive, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'All Flatmate Accounts are Settled Up!',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.positive,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...debtTransfers.map((transfer) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkerText,
                                fontFamily: AppTheme.fontName,
                              ),
                              children: [
                                TextSpan(
                                  text: transfer.fromPerson,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(text: ' owes '),
                                TextSpan(
                                  text: transfer.toPerson,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          CurrencyUtils.formatCurrency(transfer.amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkerText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showRecordSettlementModal(
                              context,
                              defaultFrom: transfer.fromPerson,
                              defaultTo: transfer.toPerson,
                              defaultAmount: transfer.amount,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Settle',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5-Flatmates Individual Balances
        const Text(
          'Flatmate Standings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppTheme.darkerText,
          ),
        ),
        const SizedBox(height: 10),

        ...flatmates.map((f) {
          final double net = netBalances[f.name] ?? 0.0;
          final double paid = totalPaidByPerson[f.name] ?? 0.0;
          final double effectivePaid = effectivePaidByPerson[f.name] ?? 0.0;
          final bool isSettled = net.abs() < 0.01;
          final bool isOwed = net >= 0.01;
          final bool hasSettlementDifference = (effectivePaid - paid).abs() >= 0.01;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.surfaceMuted,
                  child: Text(
                    f.name[0],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkerText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              f.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkerText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (f.role.toLowerCase() == 'admin' ||
                              f.email?.toLowerCase().trim() == 'aadarshapandit17@gmail.com' ||
                              f.email?.toLowerCase().trim() == 'aadarshapandit@gmail.com')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF164E3D).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFF164E3D), width: 0.8),
                              ),
                              child: const Text(
                                'Admin',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF164E3D),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'Flatmate',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSettlementDifference
                            ? 'Net: ${CurrencyUtils.formatCurrency(effectivePaid)} • Bills: ${CurrencyUtils.formatCurrency(paid)}'
                            : 'Total paid: ${CurrencyUtils.formatCurrency(paid)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isSettled ? '₹0' : CurrencyUtils.formatSignedCurrency(net),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isSettled
                            ? AppTheme.darkerText
                            : (isOwed ? AppTheme.positive : AppTheme.negative),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isSettled
                          ? 'settled'
                          : (isOwed ? 'gets back' : 'owes'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isSettled
                            ? AppTheme.lightText
                            : (isOwed ? AppTheme.positive : AppTheme.negative),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        // Settlement History
        if (settlements.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Settlement History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkerText,
            ),
          ),
          const SizedBox(height: 8),
          ...settlements.map((s) {
            final dateStr = DateFormat('MMM d, h:mm a').format(s.date);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.fromPerson} paid ${s.toPerson} ${CurrencyUtils.formatCurrency(s.amount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkerText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppTheme.deactivatedText),
                        ),
                      ],
                    ),
                  ),
                  if (onDeleteSettlement != null) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTheme.negative,
                      ),
                      splashRadius: 18,
                      tooltip: 'Delete Settlement',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Settlement Record?'),
                            content: Text(
                              'Delete payment record of ${CurrencyUtils.formatCurrency(s.amount)} from ${s.fromPerson} to ${s.toPerson}? This will update balances accordingly.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  onDeleteSettlement!(s.id);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.negative,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}
