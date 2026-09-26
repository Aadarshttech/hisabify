import 'package:flutter/material.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/expenses/data/expense_repository.dart';
import 'package:flatsplit/features/home/presentation/widgets/expense_card.dart';

class ActivityTab extends StatefulWidget {
  final List<Expense> expenses;
  final List<Flatmate> flatmates;
  final String currentUserName;
  final int memberCount;
  final Function(String id) onDeleteExpense;
  final Function(String id)? onRestoreExpense;
  final Function(String id)? onPermanentlyDeleteExpense;
  final VoidCallback? onEmptyTrash;
  final Function(String id, List<String> newSplit)? onUpdateSplit;

  const ActivityTab({
    super.key,
    required this.expenses,
    this.flatmates = const [],
    required this.currentUserName,
    required this.memberCount,
    required this.onDeleteExpense,
    this.onRestoreExpense,
    this.onPermanentlyDeleteExpense,
    this.onEmptyTrash,
    this.onUpdateSplit,
  });

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All'; // 'All', 'Active', 'Deleted'

  final List<String> _categories = [
    'All',
    'Groceries',
    'Utilities',
    'Dining',
    'Rent',
    'Entertainment',
    'Transport',
  ];

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase().trim();

    final filteredExpenses = widget.expenses.where((expense) {
      final canonicalPayer = ExpenseRepository.resolveCanonicalMemberName(
        expense.paidByName,
        widget.flatmates,
      );

      final matchesSearch = query.isEmpty ||
          expense.title.toLowerCase().contains(query) ||
          expense.paidByName.toLowerCase().contains(query) ||
          canonicalPayer.toLowerCase().contains(query) ||
          (expense.isDeleted && 'deleted'.contains(query)) ||
          (expense.deletedByName != null &&
              expense.deletedByName!.toLowerCase().contains(query));

      final matchesCategory = _selectedCategory == 'All' ||
          expense.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesStatus = _selectedStatus == 'All' ||
          (_selectedStatus == 'Active' && !expense.isDeleted) ||
          (_selectedStatus == 'Deleted' && expense.isDeleted);

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    final double totalFilteredSpend = filteredExpenses
        .where((e) => !e.isDeleted)
        .fold(0.0, (sum, item) => sum + item.amount);

    final int totalCount = widget.expenses.length;
    final int activeCount = widget.expenses.where((e) => !e.isDeleted).length;
    final int deletedCount = widget.expenses.where((e) => e.isDeleted).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Page Title & Spend Summary
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Activity Feed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppTheme.darkerText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'Total: ${CurrencyUtils.formatCurrency(totalFilteredSpend)}${deletedCount > 0 ? ' • $deletedCount deleted' : ''}',
                        style: const TextStyle(
                          color: AppTheme.darkerText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (deletedCount > 0 && widget.onEmptyTrash != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.delete_sweep_rounded, color: AppTheme.negative),
                              SizedBox(width: 8),
                              Text('Empty Trash?'),
                            ],
                          ),
                          content: Text(
                            'Permanently delete all $deletedCount cancelled entries from history? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onEmptyTrash!();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.negative,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Purge All'),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.negativeLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.negative.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_sweep_outlined, size: 14, color: AppTheme.negative),
                          SizedBox(width: 4),
                          Text(
                            'Empty Trash',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.negative,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
        const SizedBox(height: 14),

        // Clean Search Field
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search items, flatmates, or "deleted"...',
              hintStyle: TextStyle(fontSize: 13, color: AppTheme.deactivatedText),
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.grey, size: 18),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Status Segment Pills (All / Active / Deleted)
        Row(
          children: [
            _buildStatusChip('All', 'All ($totalCount)'),
            const SizedBox(width: 8),
            _buildStatusChip('Active', 'Active ($activeCount)'),
            const SizedBox(width: 8),
            _buildStatusChip('Deleted', 'Deleted ($deletedCount)', isDeletedChip: true),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Category Filter Pills
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;

              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.darkText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                ),
                showCheckmark: false,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = cat);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // List View of Expenses (including deleted transactions)
        if (filteredExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  _selectedStatus == 'Deleted'
                      ? Icons.delete_sweep_outlined
                      : Icons.search_off_rounded,
                  size: 36,
                  color: AppTheme.deactivatedText,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedStatus == 'Deleted'
                      ? 'No deleted transactions found'
                      : 'No expenses found',
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ...filteredExpenses.map((expense) {
            return ExpenseCard(
              expense: expense,
              currentUserName: widget.currentUserName,
              memberCount: widget.memberCount,
              flatmates: widget.flatmates,
              onDelete: () => widget.onDeleteExpense(expense.id),
              onRestore: widget.onRestoreExpense != null
                  ? () => widget.onRestoreExpense!(expense.id)
                  : null,
              onPermanentlyDelete: widget.onPermanentlyDeleteExpense != null
                  ? () => widget.onPermanentlyDeleteExpense!(expense.id)
                  : null,
              onUpdateSplit: widget.onUpdateSplit,
            );
          }),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatusChip(String statusKey, String label, {bool isDeletedChip = false}) {
    final isSelected = _selectedStatus == statusKey;

    Color activeBgColor = isDeletedChip ? AppTheme.negative : AppTheme.primary;
    Color activeTextColor = Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = statusKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeBgColor : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? activeBgColor
                  : (isDeletedChip ? AppTheme.negative.withValues(alpha: 0.25) : AppTheme.border),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? activeTextColor
                    : (isDeletedChip ? AppTheme.negative : AppTheme.darkerText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
