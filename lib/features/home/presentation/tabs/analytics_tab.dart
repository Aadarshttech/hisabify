import 'package:flutter/material.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/expenses/data/expense_repository.dart';

class AnalyticsTab extends StatelessWidget {
  final List<Expense> expenses;
  final List<Settlement> settlements;
  final List<Flatmate> flatmates;

  const AnalyticsTab({
    super.key,
    required this.expenses,
    required this.settlements,
    required this.flatmates,
  });

  @override
  Widget build(BuildContext context) {
    final double totalSpend = ExpenseRepository.calculateTotalSpend(expenses);
    final double equalShare = ExpenseRepository.calculateEqualShare(expenses, personCount: flatmates.length);
    final Map<String, double> fairShares = ExpenseRepository.calculateFairShareByPerson(expenses, flatmates);
    final Map<String, double> paidByPerson = ExpenseRepository.calculateEffectivePaidByPerson(expenses, settlements, flatmates);
    final Map<String, double> categoryBreakdown = ExpenseRepository.calculateCategoryBreakdown(expenses);

    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Title
        const Text(
          'Analytics & Breakdown',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppTheme.darkerText,
          ),
        ),
        const SizedBox(height: 16),

        // 3-Metric Summary Row
        Row(
          children: [
            _buildMetricCard('Total Spend', CurrencyUtils.formatCurrency(totalSpend)),
            const SizedBox(width: 8),
            _buildMetricCard('Avg / Person', CurrencyUtils.formatCurrency(equalShare)),
            const SizedBox(width: 8),
            _buildMetricCard('Logged Items', '${expenses.length}'),
          ],
        ),
        const SizedBox(height: 18),

        // Flatmate Contribution Breakdown
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
              const Text(
                'Flatmate Spending Contributions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkerText,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Net spending (bills + settle-ups) vs each roommate\'s fair share',
                style: TextStyle(fontSize: 11.5, color: AppTheme.lightText),
              ),
              const SizedBox(height: 16),

              ...flatmates.map((flatmate) {
                final paid = paidByPerson[flatmate.name] ?? 0.0;
                final fairShare = fairShares[flatmate.name] ?? 0.0;
                final double progress = totalSpend > 0 ? (paid / totalSpend).clamp(0.0, 1.0) : 0.0;
                final bool isAboveShare = paid >= (fairShare - 0.01);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              flatmate.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkerText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Paid ${CurrencyUtils.formatCurrency(paid)} • Share: ${CurrencyUtils.formatCurrency(fairShare)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isAboveShare ? AppTheme.positive : AppTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppTheme.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAboveShare ? AppTheme.positive : AppTheme.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Category Spend Breakdown
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
              const Text(
                'Spend by Category',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkerText,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),

              if (sortedCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(
                    child: Text('No spending data yet', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
                  ),
                )
              else
                ...sortedCategories.map((entry) {
                  final double percent = totalSpend > 0 ? (entry.value / totalSpend) * 100 : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkerText,
                            ),
                          ),
                        ),
                        Text(
                          CurrencyUtils.formatCurrency(entry.value),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkerText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${percent.toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.lightText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkerText,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
