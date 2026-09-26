import 'package:flutter/material.dart';
import 'package:flatsplit/features/auth/presentation/pages/login_page.dart';
import 'package:flatsplit/features/auth/presentation/pages/register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  // Thematic colors
  static const Color creamBg = Color(0xFFFEF9E7);
  static const Color forestGreen = Color(0xFF164E3D);
  static const Color goldAccent = Color(0xFFF2B749);
  static const Color cardBg = Color(0xFFFFFDF7);
  static const Color cardBorder = Color(0xFFFDE68A);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Scaffold(
      backgroundColor: creamBg,
      body: Stack(
        children: [
          // 1. Organic golden background decoration
          Positioned.fill(
            child: CustomPaint(
              painter: _WelcomeBackgroundPainter(),
            ),
          ),

          // 2. Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? (size.width - 480) / 2 : 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo + Title Header
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: forestGreen.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // App Title
                    const Text(
                      'Hisab Milau',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: forestGreen,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // App Subtitle
                    Text(
                      'Shared flat expenses, settled simply.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: forestGreen.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Hero Illustration Card
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: forestGreen.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: 16 / 10.5,
                        child: Image.asset(
                          'assets/images/welcome_friends.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Quick Value Props Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildFeaturePill(
                          icon: Icons.restaurant_rounded,
                          label: 'Meal Absences',
                        ),
                        _buildFeaturePill(
                          icon: Icons.bolt_rounded,
                          label: 'Instant Splits',
                        ),
                        _buildFeaturePill(
                          icon: Icons.handshake_rounded,
                          label: 'Fair Settle Up',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Primary Action: Get Started / Create Account
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                          shadowColor: forestGreen.withValues(alpha: 0.3),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Secondary Action: Sign In
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: forestGreen,
                          side: const BorderSide(
                            color: forestGreen,
                            width: 1.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtle footer footnote
                    Center(
                      child: Text(
                        '100% Free • No hidden fees • Built for flatmates',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: forestGreen.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: forestGreen,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: forestGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for organic corner shapes on welcome page
class _WelcomeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFBD66A)
      ..style = PaintingStyle.fill;

    // Top-left organic wave
    final double tlH = (size.height * 0.16).clamp(115.0, 145.0);
    final double tlW = (size.width * 0.28).clamp(175.0, 240.0);
    final pathTL = Path();
    pathTL.moveTo(0, 0);
    pathTL.lineTo(0, tlH);
    pathTL.cubicTo(
      tlW * 0.12, tlH * 0.98,
      tlW * 0.26, tlH * 0.62,
      tlW * 0.48, tlH * 0.56,
    );
    pathTL.cubicTo(
      tlW * 0.68, tlH * 0.52,
      tlW * 0.88, tlH * 0.30,
      tlW, 0,
    );
    pathTL.close();
    canvas.drawPath(pathTL, goldPaint);

    // Top-right organic lobe
    final double trTop = (size.height * 0.055).clamp(38.0, 65.0);
    const double trH = 135.0;
    final double trWidth = (size.width * 0.12).clamp(58.0, 78.0);

    final pathTR = Path();
    pathTR.moveTo(size.width, trTop);
    pathTR.cubicTo(
      size.width - trWidth * 0.40, trTop + trH * 0.08,
      size.width - trWidth, trTop + trH * 0.28,
      size.width - trWidth, trTop + trH * 0.50,
    );
    pathTR.cubicTo(
      size.width - trWidth, trTop + trH * 0.72,
      size.width - trWidth * 0.40, trTop + trH * 0.92,
      size.width, trTop + trH,
    );
    pathTR.close();
    canvas.drawPath(pathTR, goldPaint);

    // Bottom-left subtle splash
    final double blH = (size.height * 0.10).clamp(70.0, 95.0);
    final double blW = (size.width * 0.20).clamp(100.0, 150.0);
    final pathBL = Path();
    pathBL.moveTo(0, size.height);
    pathBL.lineTo(0, size.height - blH);
    pathBL.quadraticBezierTo(
      blW * 0.50, size.height - blH * 0.55,
      blW, size.height,
    );
    pathBL.close();
    canvas.drawPath(pathBL, goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
