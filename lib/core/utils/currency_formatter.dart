/// Reusable currency and number formatting utilities for FlatExpense.
class CurrencyUtils {
  /// Formats a numeric amount.
  /// If it is effectively an integer (e.g., 250.0), formats without decimal places: "250".
  /// If it has fractional cents/paise (e.g., 233.33), formats to 2 decimal places: "233.33".
  static String formatAmount(double amount) {
    if (amount.isNaN || amount.isInfinite || amount.abs() < 0.005) return '0';
    final rounded = amount.roundToDouble();
    if ((amount - rounded).abs() < 0.005) {
      return rounded.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  /// Formats with standard rupee currency prefix: e.g., "₹250" or "₹233.33".
  static String formatCurrency(double amount) {
    if (amount.isNaN || amount.isInfinite || amount.abs() < 0.005) return '₹0';
    return '₹${formatAmount(amount)}';
  }

  /// Formats signed currency: e.g., "+₹233.33", "-₹50", or "₹0".
  static String formatSignedCurrency(double amount) {
    if (amount.isNaN || amount.isInfinite || amount.abs() < 0.009) {
      return '₹0';
    }
    if (amount >= 0.009) {
      return '+₹${formatAmount(amount)}';
    } else if (amount <= -0.009) {
      return '-₹${formatAmount(-amount)}';
    }
    return '₹0';
  }
}
