import 'package:flutter/material.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';

class BalanceCard extends StatelessWidget {
  final double netBalance;
  final double owedToYou;
  final double youOwe;
  final double totalSpend;
  final double? equalShare;
  final int? memberCount;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    required this.netBalance,
    required this.owedToYou,
    required this.youOwe,
    required this.totalSpend,
    this.equalShare,
    this.memberCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSettled = netBalance.abs() < 0.01;
    final bool isPositive = netBalance >= 0.01;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Deep Obsidian / Dark Slate
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Subtle organic contour wave in the bottom right corner
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HeroCardWavesPainter(),
                  ),
                ),

                // Card Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Header label + Chevron
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isSettled
                                      ? const Color(0xFF94A3B8)
                                      : (isPositive
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFFB7185)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'YOUR NET BALANCE',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          if (onTap != null)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8),
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Middle Section: Bigger Balance on Left + Cute Wallet on Right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left text column (flexibly takes all remaining space)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                    child: Text(
                                      isSettled ? '₹0' : CurrencyUtils.formatSignedCurrency(netBalance),
                                      style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        fontSize: isDesktop ? 40 : 34,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.6,
                                        color: isSettled
                                            ? Colors.white
                                            : (isPositive
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFFB7185)),
                                      ),
                                    ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isSettled
                                            ? const Color(0xFF64748B)
                                            : (isPositive
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFFB7185)))
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (isSettled
                                              ? const Color(0xFF64748B)
                                              : (isPositive
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFFB7185)))
                                          .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    isSettled
                                        ? 'All settled up'
                                        : (isPositive
                                            ? 'You are owed'
                                            : 'You owe'),
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isSettled
                                          ? const Color(0xFFCBD5E1)
                                          : (isPositive
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFFFDA4AF)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Transparent cute smiling wallet illustration
                          Image.asset(
                            'assets/images/dashboard_wallet.png',
                            height: isDesktop ? 104 : 76,
                            width: isDesktop ? 124 : 92,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Thin Horizontal Divider
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      const SizedBox(height: 14),

                      // Bottom Stats Row
                      Row(
                        children: [
                          // Total Group Spend
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Group Spend',
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyUtils.formatCurrency(totalSpend),
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: isDesktop ? 20 : 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Vertical divider
                          Container(
                            height: 24,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            color: Colors.white.withValues(alpha: 0.12),
                          ),

                          // You are Owed / You Owe
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSettled
                                      ? 'Status'
                                      : (isPositive ? 'You are Owed' : 'You Owe'),
                                  style: const TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSettled
                                      ? 'Settled Up'
                                      : (isPositive
                                          ? CurrencyUtils.formatSignedCurrency(owedToYou)
                                          : CurrencyUtils.formatSignedCurrency(-youOwe)),
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: isDesktop ? 20 : 17,
                                    fontWeight: FontWeight.w700,
                                    color: isSettled
                                        ? const Color(0xFF94A3B8)
                                        : (isPositive
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFFB7185)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCardWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF16202E).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(size.width * 0.55, size.height);
    path1.quadraticBezierTo(
      size.width * 0.72,
      size.height * 0.45,
      size.width,
      size.height * 0.62,
    );
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = const Color(0xFF101722).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(size.width * 0.75, size.height);
    path2.quadraticBezierTo(
      size.width * 0.88,
      size.height * 0.75,
      size.width,
      size.height * 0.84,
    );
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}