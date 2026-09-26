import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';

import 'package:flatsplit/features/expenses/data/expense_repository.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String currentUserName;
  final int memberCount;
  final List<Flatmate> flatmates;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPermanentlyDelete;
  final Function(String expenseId, List<String> newSplitAmong)? onUpdateSplit;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.currentUserName,
    required this.memberCount,
    this.flatmates = const [],
    this.onTap,
    this.onDelete,
    this.onRestore,
    this.onPermanentlyDelete,
    this.onUpdateSplit,
  });

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
      case 'supermarket':
        return Icons.shopping_bag_outlined;
      case 'rent':
      case 'house':
        return Icons.home_outlined;
      case 'internet':
      case 'utilities':
      case 'bills':
      case 'electricity':
        return Icons.bolt_outlined;
      case 'dining':
      case 'food':
      case 'coffee':
      case 'pizza':
        return Icons.restaurant_outlined;
      case 'entertainment':
      case 'movies':
        return Icons.movie_outlined;
      case 'transport':
      case 'fuel':
        return Icons.directions_car_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  void _showDetailsModal(BuildContext context) {
    final String resolvedPaidBy = flatmates.isNotEmpty
        ? ExpenseRepository.resolveCanonicalMemberName(expense.paidByName, flatmates)
        : expense.paidByName;

    final allMemberNames = flatmates.isNotEmpty
        ? flatmates.map((f) => f.name).toList()
        : [currentUserName];

    final initialSplit = expense.splitAmong.isNotEmpty
        ? expense.splitAmong.map((p) => ExpenseRepository.resolveCanonicalMemberName(p, flatmates)).toList()
        : List<String>.from(allMemberNames);

    List<String> currentSplit = List<String>.from(initialSplit);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int splitCount = currentSplit.isNotEmpty ? currentSplit.length : 1;
          final double perPersonShare = expense.amount / splitCount;

          final excludedMembers = allMemberNames
              .where((name) => !currentSplit.contains(name))
              .toList();

          final bool hasChanged = currentSplit.length != initialSplit.length ||
              currentSplit.any((p) => !initialSplit.contains(p));

          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Icon(
                        _getCategoryIcon(expense.category),
                        size: 22,
                        color: AppTheme.darkerText,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkerText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${expense.category} • ${DateFormat('MMM d, yyyy • h:mm a').format(expense.date)}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyUtils.formatCurrency(expense.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkerText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: AppTheme.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Paid by $resolvedPaidBy',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.darkerText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Split Breakdown',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkerText),
                        ),
                        if (allMemberNames.length > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: currentSplit.length == allMemberNames.length
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${currentSplit.length} of ${allMemberNames.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: currentSplit.length == allMemberNames.length
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${CurrencyUtils.formatCurrency(perPersonShare)} each',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.positive),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap flatmates below to include or exclude from this split',
                  style: TextStyle(fontSize: 11, color: AppTheme.lightText),
                ),
                const SizedBox(height: 10),

                // Included members (Tappable to exclude)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: currentSplit.map((name) {
                    return InkWell(
                      onTap: expense.isDeleted
                          ? null
                          : () {
                              if (currentSplit.length <= 1) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('At least 1 flatmate must share this expense'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setModalState(() {
                                currentSplit.remove(name);
                              });
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.positiveLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.positive.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.positive),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkerText),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${CurrencyUtils.formatCurrency(perPersonShare)})',
                              style: const TextStyle(fontSize: 11, color: AppTheme.positive),
                            ),
                            if (!expense.isDeleted && currentSplit.length > 1) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.close_rounded, size: 13, color: AppTheme.grey),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Excluded members (Tappable to include)
                if (excludedMembers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Excluded (Away / Didn\'t Eat):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.lightText),
                      ),
                      if (!expense.isDeleted)
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              currentSplit = List<String>.from(allMemberNames);
                            });
                          },
                          child: const Text(
                            'Include All',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: excludedMembers.map((name) {
                      return InkWell(
                        onTap: expense.isDeleted
                            ? null
                            : () {
                                setModalState(() {
                                  currentSplit.add(name);
                                });
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.deactivatedText,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '(Tap to add)',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 20),

                // Action Buttons: Save & Reset if changed, or Close if unchanged
                if (hasChanged)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              currentSplit = List<String>.from(initialSplit);
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Reset', style: TextStyle(color: AppTheme.darkerText)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setModalState(() => isSaving = true);
                                  if (onUpdateSplit != null) {
                                    await onUpdateSplit!(expense.id, currentSplit);
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Updated split for "${expense.title}" (${CurrencyUtils.formatCurrency(perPersonShare)}/ea)',
                                        ),
                                        backgroundColor: AppTheme.positive,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Save Split (${CurrencyUtils.formatCurrency(perPersonShare)}/ea)',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDeleted = expense.isDeleted;
    final String resolvedPaidBy = flatmates.isNotEmpty
        ? ExpenseRepository.resolveCanonicalMemberName(expense.paidByName, flatmates)
        : expense.paidByName;
    final bool isMine = resolvedPaidBy.toLowerCase() == currentUserName.toLowerCase();
    final categoryIcon = isDeleted ? Icons.delete_outline_rounded : _getCategoryIcon(expense.category);
    final formattedDate = DateFormat('MMM d, h:mm a').format(expense.date);
    final splitCount = expense.splitAmong.isNotEmpty ? expense.splitAmong.length : memberCount;
    final perPersonShare = expense.amount / splitCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDeleted
            ? AppTheme.surfaceMuted.withValues(alpha: 0.5)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDeleted ? [] : AppTheme.cardShadow,
        border: Border.all(
          color: isDeleted
              ? AppTheme.negative.withValues(alpha: 0.25)
              : AppTheme.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => _showDetailsModal(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Minimal Slate Category Icon Container
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? AppTheme.negativeLight.withValues(alpha: 0.5)
                        : AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDeleted
                          ? AppTheme.negative.withValues(alpha: 0.2)
                          : AppTheme.border,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    categoryIcon,
                    size: 20,
                    color: isDeleted ? AppTheme.negative : AppTheme.darkerText,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDeleted ? AppTheme.lightText : AppTheme.darkerText,
                                letterSpacing: -0.2,
                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDeleted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.negativeLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppTheme.negative.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                expense.deletedByName != null && expense.deletedByName!.isNotEmpty
                                    ? 'DELETED (${expense.deletedByName})'
                                    : 'DELETED',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.negative,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDeleted
                                  ? AppTheme.surfaceMuted
                                  : (isMine
                                      ? AppTheme.positiveLight
                                      : AppTheme.surfaceMuted),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isMine ? 'You paid' : 'Paid by $resolvedPaidBy',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDeleted
                                    ? AppTheme.deactivatedText
                                    : (isMine ? AppTheme.positive : AppTheme.grey),
                              ),
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.deactivatedText,
                            ),
                          ),
                          if (!isDeleted && memberCount > 0 && splitCount < memberCount)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '$splitCount of $memberCount split',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Amount & Per-Person Tag
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyUtils.formatCurrency(expense.amount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDeleted ? AppTheme.deactivatedText : AppTheme.darkerText,
                        decoration: isDeleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDeleted
                          ? 'Cancelled'
                          : '${CurrencyUtils.formatCurrency(perPersonShare)} / ea',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDeleted
                            ? AppTheme.negative
                            : (isMine ? AppTheme.positive : AppTheme.lightText),
                      ),
                    ),
                  ],
                ),

                // Actions: Restore / Permanently Delete if deleted, Delete if active
                if (isDeleted) ...[
                  if (onRestore != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.restore_rounded,
                        color: AppTheme.primary,
                        size: 19,
                      ),
                      splashRadius: 18,
                      tooltip: 'Restore Expense',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Restore Expense'),
                            content: Text('Restore "${expense.title}" back to active transactions?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  onRestore!();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Restore'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  if (onPermanentlyDelete != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppTheme.negative,
                        size: 20,
                      ),
                      splashRadius: 18,
                      tooltip: 'Permanently Delete',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.delete_forever_rounded, color: AppTheme.negative),
                                SizedBox(width: 8),
                                Text('Delete Permanently?'),
                              ],
                            ),
                            content: Text('Permanently remove "${expense.title}" from history? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  onPermanentlyDelete!();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.negative,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete Forever'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ] else if (!isDeleted && onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.deactivatedText,
                      size: 16,
                    ),
                    splashRadius: 18,
                    tooltip: 'Delete Expense',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Expense'),
                          content: const Text('Are you sure you want to delete this expense? It will still be visible in the Activity Feed audit log.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onDelete!();
                              },
                              style: TextButton.styleFrom(foregroundColor: AppTheme.negative),
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
          ),
        ),
      ),
    );
  }
}