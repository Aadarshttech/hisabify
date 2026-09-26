import 'package:flutter/material.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/home/presentation/widgets/balance_card.dart';
import 'package:flatsplit/features/home/presentation/widgets/expense_card.dart';

class DashboardTab extends StatelessWidget {
  final List<Expense> expenses;
  final List<Settlement> settlements;
  final List<Flatmate> flatmates;
  final String currentUserName;
  final double netBalance;
  final double owedToYou;
  final double youOwe;
  final double totalSpend;
  final double equalShare;
  final double? userFairShare;
  final VoidCallback onAddExpenseTap;
  final VoidCallback onSettleUpTap;
  final VoidCallback onAnalyticsTap;
  final VoidCallback onActivityTap;
  final Function(String id) onDeleteExpense;
  final Function(String id, List<String> newSplit)? onUpdateSplit;

  static const Color darkText = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFFFFFDF7);
  static const Color cardBorder = Color(0xFFF3EAD3);
  static const Color avatarBg = Color(0xFFFAF2DA);
  static const Color goldBtn = Color(0xFFF2B749);

  const DashboardTab({
    super.key,
    required this.expenses,
    required this.settlements,
    required this.flatmates,
    required this.currentUserName,
    required this.netBalance,
    required this.owedToYou,
    required this.youOwe,
    required this.totalSpend,
    required this.equalShare,
    this.userFairShare,
    required this.onAddExpenseTap,
    required this.onSettleUpTap,
    required this.onAnalyticsTap,
    required this.onActivityTap,
    required this.onDeleteExpense,
    this.onUpdateSplit,
  });

  @override
  Widget build(BuildContext context) {
    final recentExpenses = expenses.where((e) => !e.isDeleted).take(5).toList();
    final int memberCount = flatmates.isNotEmpty ? flatmates.length : 1;
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 8,
      ),
      children: [
        // 1. Hero Balance Card (Obsidian with cute wallet character & organic dark waves)
        BalanceCard(
          netBalance: netBalance,
          owedToYou: owedToYou,
          youOwe: youOwe,
          totalSpend: totalSpend,
          equalShare: equalShare,
          memberCount: memberCount,
          onTap: onSettleUpTap,
        ),
        const SizedBox(height: 16),

        // 2. Primary Quick Action Buttons (Gold Add Expense, Cream Settle Up, Cream Analytics)
        Row(
          children: [
            _buildActionButton(
              icon: Icons.add_rounded,
              label: 'Add Expense',
              isPrimary: true,
              onTap: onAddExpenseTap,
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              icon: Icons.handshake_outlined,
              label: 'Settle Up',
              isPrimary: false,
              onTap: onSettleUpTap,
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              isPrimary: false,
              onTap: onAnalyticsTap,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Key Metrics Container (Single unified card with 3 segments separated by dividers)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 14,
            vertical: isSmallScreen ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildSingleMetric(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Spend',
                value: CurrencyUtils.formatCurrency(totalSpend),
                isSmallScreen: isSmallScreen,
              ),
              _buildMetricDivider(isSmallScreen),
              _buildSingleMetric(
                icon: Icons.person_outline_rounded,
                label: 'Your Share',
                value: CurrencyUtils.formatCurrency(userFairShare ?? equalShare),
                isSmallScreen: isSmallScreen,
              ),
              _buildMetricDivider(isSmallScreen),
              _buildSingleMetric(
                icon: Icons.group_outlined,
                label: 'Group Size',
                value: '$memberCount Roomies',
                isSmallScreen: isSmallScreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4. Recent Activity (Unified card with header, view all, and list or empty state inside)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row Inside Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                  GestureDetector(
                    onTap: onActivityTap,
                    child: Row(
                      children: const [
                        Text(
                          'View all ',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Color(0xFF475569),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Empty or List State
              if (recentExpenses.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: avatarBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            size: 22,
                            color: Color(0xFF8C6E3D),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No expenses logged yet.',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recentExpenses.map((expense) {
                  return ExpenseCard(
                    expense: expense,
                    currentUserName: currentUserName,
                    memberCount: memberCount,
                    flatmates: flatmates,
                    onDelete: () => onDeleteExpense(expense.id),
                    onUpdateSplit: onUpdateSplit,
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: isPrimary ? goldBtn : cardBg,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPrimary ? const Color(0xFFE5A934) : const Color(0xFFE5D7B7),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isPrimary ? darkText : const Color(0xFF475569),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: darkText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleMetric({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallScreen,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isSmallScreen ? 30 : 36,
            height: isSmallScreen ? 30 : 36,
            decoration: const BoxDecoration(
              color: avatarBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: isSmallScreen ? 15 : 18,
              color: const Color(0xFF6B532F),
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: isSmallScreen ? 10.5 : 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: isSmallScreen ? 14.5 : 17,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider([bool isSmallScreen = false]) {
    return Container(
      width: 1,
      height: 28,
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4),
      color: const Color(0xFFF3EAD3),
    );
  }
}
