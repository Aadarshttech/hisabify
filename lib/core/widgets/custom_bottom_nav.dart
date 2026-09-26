import 'package:flutter/material.dart';
import 'package:flatsplit/core/theme/app_theme.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int index) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              4,
              (index) {
                final isSelected = widget.currentIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => widget.onTap(index),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconForIndex(index),
                            size: 22,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.deactivatedText,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getLabelForIndex(index),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.deactivatedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.grid_view_rounded;
      case 1:
        return Icons.receipt_long_rounded;
      case 2:
        return Icons.bar_chart_rounded;
      case 3:
        return Icons.people_alt_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  String _getLabelForIndex(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Activity';
      case 2:
        return 'Analytics';
      case 3:
        return 'Flatmates';
      default:
        return 'Home';
    }
  }
}