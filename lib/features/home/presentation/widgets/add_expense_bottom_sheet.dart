import 'package:flutter/material.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';

class AddExpenseBottomSheet extends StatefulWidget {
  final String currentUserName;
  final List<Flatmate> flatmates;
  final Function(String title, double amount, String category, String paidByName, List<String> splitAmong) onExpenseAdded;

  const AddExpenseBottomSheet({
    super.key,
    required this.onExpenseAdded,
    required this.flatmates,
    required this.currentUserName,
  });

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Groceries';
  late String _selectedPaidBy;
  late Set<String> _selectedSplitAmong;
  bool _showOtherPayers = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Groceries', 'icon': Icons.shopping_bag_outlined},
    {'name': 'Utilities', 'icon': Icons.bolt_outlined},
    {'name': 'Dining', 'icon': Icons.restaurant_outlined},
    {'name': 'Rent', 'icon': Icons.home_outlined},
    {'name': 'Entertainment', 'icon': Icons.movie_outlined},
    {'name': 'Transport', 'icon': Icons.directions_car_outlined},
  ];

  @override
  void initState() {
    super.initState();
    // Default strictly to the current logged-in user
    _selectedPaidBy = widget.currentUserName;
    for (var f in widget.flatmates) {
      if (f.name.toLowerCase().trim() == widget.currentUserName.toLowerCase().trim()) {
        _selectedPaidBy = f.name;
        break;
      }
    }

    if (widget.flatmates.isNotEmpty) {
      _selectedSplitAmong = widget.flatmates.map((f) => f.name).toSet();
    } else {
      _selectedSplitAmong = {widget.currentUserName};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String? input) {
    if (input == null) return null;
    String clean = input.trim();
    if (clean.isEmpty) return null;
    if (clean.contains(',') && clean.contains('.')) {
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }
    return double.tryParse(clean);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final double? amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_selectedSplitAmong.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 person who shares this expense'),
          backgroundColor: AppTheme.negative,
        ),
      );
      return;
    }

    widget.onExpenseAdded(
      _titleController.text.trim(),
      amount,
      _selectedCategory,
      _selectedPaidBy,
      _selectedSplitAmong.toList(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final memberList = widget.flatmates.isNotEmpty
        ? widget.flatmates
        : [Flatmate(id: 'me', name: widget.currentUserName)];
    final int totalFlatmates = memberList.length;
    final int splitCount = _selectedSplitAmong.length;
    final double enteredAmount = _parseAmount(_amountController.text) ?? 0.0;
    final double perPersonShare = (enteredAmount > 0 && splitCount > 0)
        ? enteredAmount / splitCount
        : 0.0;
    final bool isFoodCategory = _selectedCategory == 'Groceries' || _selectedCategory == 'Dining';

    final String defaultPayer = widget.flatmates.any((f) => f.name.toLowerCase().trim() == widget.currentUserName.toLowerCase().trim())
        ? widget.flatmates.firstWhere((f) => f.name.toLowerCase().trim() == widget.currentUserName.toLowerCase().trim()).name
        : widget.currentUserName;
    final bool isPaidByMe = _selectedPaidBy.toLowerCase().trim() == defaultPayer.toLowerCase().trim();

    return Container(
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
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

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Expense',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkerText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        splitCount == totalFlatmates
                            ? 'Split equally across all $splitCount flatmates'
                            : 'Split across $splitCount of $totalFlatmates flatmates (${totalFlatmates - splitCount} away)',
                        style: TextStyle(
                          fontSize: 12,
                          color: splitCount == totalFlatmates ? AppTheme.lightText : AppTheme.brandAccent,
                          fontWeight: splitCount == totalFlatmates ? FontWeight.w400 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.grey, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Description
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Item Description',
                  hintText: 'e.g. Groceries, Dinner, Milk, Wi-Fi',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.deactivatedText),
                  filled: true,
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: '0',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.deactivatedText),
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppTheme.primary, size: 18),
                  filled: true,
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  final parsed = _parseAmount(value);
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),

              // Split Preview
              if (perPersonShare > 0 && splitCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.positiveLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.positive.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppTheme.positive,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${CurrencyUtils.formatCurrency(perPersonShare)} each ($splitCount of $totalFlatmates members)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.positive,
                          ),
                        ),
                      ),
                      if (splitCount < totalFlatmates)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${totalFlatmates - splitCount} away',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else if (splitCount == 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.negativeLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.negative.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.negative,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select at least 1 flatmate who eats/shares this.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.negative,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Paid By
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Paid By',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkerText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaidByMe ? AppTheme.positiveLight : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPaidByMe ? AppTheme.positive.withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isPaidByMe ? 'You' : 'On Behalf',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isPaidByMe ? AppTheme.positive : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        _showOtherPayers = !_showOtherPayers;
                        if (!_showOtherPayers) {
                          _selectedPaidBy = defaultPayer;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        _showOtherPayers
                            ? (isPaidByMe ? 'Hide' : 'Reset to Me')
                            : 'Paid by someone else?',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (!_showOtherPayers) ...[
                // Default Clean View: Logged-in User Paid
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isPaidByMe ? AppTheme.primary : const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          isPaidByMe ? Icons.person_rounded : Icons.people_outline_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaidByMe ? 'You ($defaultPayer)' : 'Paid by $_selectedPaidBy',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkerText,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isPaidByMe
                                  ? 'You paid for this expense from your own pocket'
                                  : 'Logged on behalf of $_selectedPaidBy',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showOtherPayers = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.brandAccent,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppTheme.brandAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Expanded View: Select Payer Chip Row
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: memberList.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final flatmate = memberList[index];
                      final isSelected = _selectedPaidBy == flatmate.name;
                      final isCurrent = flatmate.name.toLowerCase().trim() == defaultPayer.toLowerCase().trim();

                      return ChoiceChip(
                        label: Text(isCurrent ? 'You (${flatmate.name})' : flatmate.name),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.surfaceMuted,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.darkText,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 12,
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
                            setState(() {
                              _selectedPaidBy = flatmate.name;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                if (!isPaidByMe) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB45309)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Logging on behalf of $_selectedPaidBy. They will receive the credit for paying this.',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),

              // Split Among Section (Multi-select with Away toggles)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Split Among (Who Ate / Shared?)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkerText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: splitCount == totalFlatmates ? AppTheme.surfaceMuted : AppTheme.positiveLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: splitCount == totalFlatmates ? AppTheme.border : AppTheme.positive.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$splitCount of $totalFlatmates',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: splitCount == totalFlatmates ? AppTheme.lightText : AppTheme.positive,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        if (splitCount == totalFlatmates) {
                          // Toggle to only payer or current user
                          _selectedSplitAmong = {_selectedPaidBy};
                        } else {
                          // Select all
                          _selectedSplitAmong = memberList.map((f) => f.name).toSet();
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        splitCount == totalFlatmates ? 'Only Payer' : 'Select All',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isFoodCategory
                    ? '🍽️ Tap a flatmate to uncheck them if they went home or skipped this meal.'
                    : 'Uncheck any flatmate who does not share this expense.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(height: 10),

              // Member Multi-Select Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: memberList.map((flatmate) {
                  final bool isIncluded = _selectedSplitAmong.contains(flatmate.name);

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        if (isIncluded) {
                          _selectedSplitAmong.remove(flatmate.name);
                        } else {
                          _selectedSplitAmong.add(flatmate.name);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isIncluded
                            ? AppTheme.positiveLight
                            : AppTheme.surfaceMuted.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isIncluded
                              ? AppTheme.positive.withValues(alpha: 0.4)
                              : AppTheme.border,
                          width: isIncluded ? 1.3 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIncluded
                                ? Icons.check_circle_rounded
                                : Icons.remove_circle_outline_rounded,
                            size: 16,
                            color: isIncluded ? AppTheme.positive : AppTheme.deactivatedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            flatmate.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isIncluded ? FontWeight.w600 : FontWeight.w500,
                              color: isIncluded ? AppTheme.darkerText : AppTheme.deactivatedText,
                              decoration: isIncluded ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          if (!isIncluded) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Away',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.grey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Category
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkerText,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['name'];

                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 14,
                            color: isSelected ? Colors.white : AppTheme.darkText,
                          ),
                          const SizedBox(width: 5),
                          Text(cat['name'] as String),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surfaceMuted,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.darkText,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 12,
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
                          setState(() {
                            _selectedCategory = cat['name'] as String;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // Submit
              ElevatedButton(
                onPressed: splitCount > 0 ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.deactivatedText,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  splitCount == 0
                      ? 'Select who shares this expense'
                      : (splitCount == totalFlatmates
                          ? (perPersonShare > 0
                              ? 'Add Expense • Split among all $splitCount (${CurrencyUtils.formatCurrency(perPersonShare)}/ea)'
                              : 'Add Expense • Split among all $splitCount')
                          : (perPersonShare > 0
                              ? 'Add Expense • Split among $splitCount (${CurrencyUtils.formatCurrency(perPersonShare)}/ea)'
                              : 'Add Expense • Split among $splitCount')),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
