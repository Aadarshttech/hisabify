import 'package:flutter_test/flutter_test.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/expenses/data/expense_repository.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('formats whole amounts without decimals', () {
      expect(CurrencyUtils.formatAmount(250.0), '250');
      expect(CurrencyUtils.formatCurrency(250.0), '₹250');
      expect(CurrencyUtils.formatAmount(0.0), '0');
      expect(CurrencyUtils.formatCurrency(0.0), '₹0');
      expect(CurrencyUtils.formatAmount(1000.0), '1000');
      expect(CurrencyUtils.formatCurrency(1000.0), '₹1000');
    });

    test('formats floating-point precision issues cleanly to 2 decimals', () {
      final double splitAmount = 700.0 / 3;
      expect(splitAmount.toString(), contains('233.33333333333334'));
      expect(CurrencyUtils.formatAmount(splitAmount), '233.33');
      expect(CurrencyUtils.formatCurrency(splitAmount), '₹233.33');

      expect(CurrencyUtils.formatCurrency(100.0 / 3), '₹33.33');
      expect(CurrencyUtils.formatCurrency(50.0 / 6), '₹8.33');
    });

    test('formats standard fractional amounts with two decimals', () {
      expect(CurrencyUtils.formatAmount(233.5), '233.50');
      expect(CurrencyUtils.formatCurrency(233.5), '₹233.50');
      expect(CurrencyUtils.formatAmount(99.99), '99.99');
      expect(CurrencyUtils.formatCurrency(99.99), '₹99.99');
    });

    test('formats signed currency correctly and eliminates -₹0.00 and +₹0.00', () {
      expect(CurrencyUtils.formatSignedCurrency(233.33333333333334), '+₹233.33');
      expect(CurrencyUtils.formatSignedCurrency(-233.33333333333334), '-₹233.33');
      expect(CurrencyUtils.formatSignedCurrency(250.0), '+₹250');
      expect(CurrencyUtils.formatSignedCurrency(-250.0), '-₹250');
      expect(CurrencyUtils.formatSignedCurrency(0.0), '₹0');
      expect(CurrencyUtils.formatSignedCurrency(-0.0), '₹0');

      // Sub-cent floating point residues that previously caused "-₹0.00"
      expect(CurrencyUtils.formatSignedCurrency(-0.0033333333333334), '₹0');
      expect(CurrencyUtils.formatSignedCurrency(0.0033333333333334), '₹0');
      expect(CurrencyUtils.formatSignedCurrency(-0.0066666666666667), '₹0');
      expect(CurrencyUtils.formatSignedCurrency(0.0066666666666667), '₹0');
      expect(CurrencyUtils.formatSignedCurrency(-0.001), '₹0');
      expect(CurrencyUtils.formatSignedCurrency(0.001), '₹0');
    });

    test('formats button label without precision issues', () {
      final double amount = 700.0;
      final int splitCount = 3;
      final double perPersonShare = amount / splitCount;

      final label = 'Add Expense • Split among $splitCount (${CurrencyUtils.formatCurrency(perPersonShare)}/ea)';
      expect(label, 'Add Expense • Split among 3 (₹233.33/ea)');
      expect(label, isNot(contains('233.33333333333334')));
    });

    test('3-way split of 1000 settles to exact 0.0 without +0.01 or -0.00 residue', () {
      final flatmates = [
        Flatmate(id: '1', name: 'Aadarsh Pandit'),
        Flatmate(id: '2', name: 'Ishan Pandey'),
        Flatmate(id: '3', name: 'Yudhin Khanal'),
      ];

      // 1000 paid by Aadarsh, split among all 3
      final expenses = [
        Expense(
          id: 'exp1',
          title: 'Groceries',
          amount: 1000.0,
          paidById: '1',
          paidByName: 'Aadarsh Pandit',
          date: DateTime.now(),
          category: 'Groceries',
          splitAmong: ['Aadarsh Pandit', 'Ishan Pandey', 'Yudhin Khanal'],
        ),
      ];

      // Initial net balances before settlement
      var net = ExpenseRepository.calculateNetBalances(expenses, [], flatmates);
      expect(net['Aadarsh Pandit'], 666.66);
      expect(net['Ishan Pandey'], -333.33);
      expect(net['Yudhin Khanal'], -333.33);

      // Now Ishan pays Aadarsh 333.33 and Yudhin pays Aadarsh 333.33
      final settlements = [
        Settlement(
          id: 's1',
          fromPerson: 'Ishan Pandey',
          toPerson: 'Aadarsh Pandit',
          amount: 333.33,
          date: DateTime.now(),
        ),
        Settlement(
          id: 's2',
          fromPerson: 'Yudhin Khanal',
          toPerson: 'Aadarsh Pandit',
          amount: 333.33,
          date: DateTime.now(),
        ),
      ];

      net = ExpenseRepository.calculateNetBalances(expenses, settlements, flatmates);

      // Everyone should be EXACTLY 0.0! Not 0.01 or -0.00!
      expect(net['Aadarsh Pandit'], 0.0);
      expect(net['Ishan Pandey'], 0.0);
      expect(net['Yudhin Khanal'], 0.0);
    });
  });
}
