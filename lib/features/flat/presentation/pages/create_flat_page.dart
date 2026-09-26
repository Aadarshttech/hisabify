import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatsplit/features/flat/data/flat_repository.dart';
import 'package:flatsplit/features/flat/presentation/pages/join_flat_page.dart';
import 'package:flatsplit/features/home/presentation/pages/home_page.dart';
import 'package:flatsplit/main.dart';

class CreateFlatPage extends StatefulWidget {
  const CreateFlatPage({super.key});

  @override
  State<CreateFlatPage> createState() => _CreateFlatPageState();
}

class _CreateFlatPageState extends State<CreateFlatPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _flatNameController = TextEditingController();
  final _flatRepo = FlatRepository();
  bool _isCreating = false;
  String? _createdCode;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color creamBg = Color(0xFFFEF9E7);
  static const Color forestGreen = Color(0xFF164E3D);
  static const Color cardBg = Color(0xFFFFFDF7);
  static const Color cardBorder = Color(0xFFFDE68A);
  static const Color fieldFill = Color(0xFFFEF6D8);
  static const Color fieldBorder = Color(0xFFEAD8B1);
  static const Color goldAccent = Color(0xFFF2B749);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flatNameController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _createFlat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final code = await _flatRepo.createFlat(
        flatName: _flatNameController.text.trim(),
        adminUid: user.uid,
        adminEmail: user.email ?? '',
        adminDisplayName: user.displayName ?? user.email?.split('@').first ?? 'Admin',
      );
      if (mounted) {
        setState(() {
          _createdCode = code;
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorMessage = 'Failed to create flat: ${e.toString()}';
        });
      }
    }
  }

  void _copyCode() {
    if (_createdCode == null) return;
    Clipboard.setData(ClipboardData(text: _createdCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Flat code copied! Share it with your flatmates 🎉',
          style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
        ),
        backgroundColor: forestGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _goToDashboard() {
    if (_createdCode != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePage(flatId: _createdCode!, isAdmin: true),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Scaffold(
      backgroundColor: creamBg,
      body: Stack(
        children: [
          // Background decorations
          Positioned.fill(
            child: CustomPaint(painter: _CreateFlatBgPainter()),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? (size.width - 440) / 2 : 24.0,
                  vertical: 24.0,
                ),
                child: _createdCode != null
                    ? _buildSuccessView()
                    : _buildCreateForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: goldAccent.withValues(alpha: 0.15),
              border: Border.all(color: goldAccent, width: 2),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              size: 42,
              color: forestGreen,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Title
        const Text(
          'Create Your Flat',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: forestGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Give your flat a name and share\nthe code with your flatmates',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 14,
            color: forestGreen,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 28),

        // Form Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: forestGreen.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Flat Name',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: forestGreen,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _flatNameController,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: forestGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., B-Tech AI Flat',
                    hintStyle: TextStyle(
                      fontFamily: 'Fredoka',
                      color: forestGreen.withValues(alpha: 0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.apartment_rounded,
                      color: forestGreen,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: fieldBorder, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: fieldBorder, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: forestGreen, width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please give your flat a name';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _createFlat(),
                ),
                const SizedBox(height: 18),

                // Error
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFE11D48), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              color: Color(0xFFE11D48),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Create Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createFlat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: forestGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Flat',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Switch to Join Flat for members
        Center(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const JoinFlatPage(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: goldAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: goldAccent.withValues(alpha: 0.45), width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_rounded, size: 20, color: forestGreen),
                  SizedBox(width: 8),
                  Text(
                    'Have a flat code? Join a Flat',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      color: forestGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Sign out option
        Center(
          child: GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Sign out',
              style: TextStyle(
                fontFamily: 'Fredoka',
                color: forestGreen,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success checkmark
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF059669).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFF059669), width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 48,
              color: Color(0xFF059669),
            ),
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'Flat Created! 🎉',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: forestGreen,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share this code with your flatmates\nso they can join your flat',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 14,
            color: forestGreen,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 28),

        // Code Display Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: goldAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: goldAccent.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'YOUR FLAT CODE',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: forestGreen,
                ),
              ),
              const SizedBox(height: 12),

              // Big code display with pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: forestGreen,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: forestGreen.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _createdCode ?? '',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Copy button
              OutlinedButton.icon(
                onPressed: _copyCode,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text(
                  'Copy Code',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: forestGreen,
                  side: const BorderSide(color: forestGreen, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Continue button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _goToDashboard,
            style: ElevatedButton.styleFrom(
              backgroundColor: forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continue to Dashboard →',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateFlatBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFBD66A)
      ..style = PaintingStyle.fill;

    final double tlH = (size.height * 0.16).clamp(115.0, 145.0);
    final double tlW = (size.width * 0.28).clamp(175.0, 240.0);
    final pathTL = Path();
    pathTL.moveTo(0, 0);
    pathTL.lineTo(0, tlH);
    pathTL.cubicTo(tlW * 0.12, tlH * 0.98, tlW * 0.26, tlH * 0.62,
        tlW * 0.48, tlH * 0.56);
    pathTL.cubicTo(
        tlW * 0.68, tlH * 0.52, tlW * 0.88, tlH * 0.30, tlW, 0);
    pathTL.close();
    canvas.drawPath(pathTL, goldPaint);

    final double trTop = (size.height * 0.055).clamp(38.0, 65.0);
    const double trH = 135.0;
    final double trWidth = (size.width * 0.12).clamp(58.0, 78.0);
    final pathTR = Path();
    pathTR.moveTo(size.width, trTop);
    pathTR.cubicTo(size.width - trWidth * 0.40, trTop + trH * 0.08,
        size.width - trWidth, trTop + trH * 0.28, size.width - trWidth, trTop + trH * 0.50);
    pathTR.cubicTo(size.width - trWidth, trTop + trH * 0.72,
        size.width - trWidth * 0.40, trTop + trH * 0.92, size.width, trTop + trH);
    pathTR.close();
    canvas.drawPath(pathTR, goldPaint);

    final double blH = (size.height * 0.10).clamp(70.0, 95.0);
    final double blW = (size.width * 0.22).clamp(110.0, 160.0);
    final pathBL = Path();
    pathBL.moveTo(0, size.height);
    pathBL.lineTo(0, size.height - blH);
    pathBL.quadraticBezierTo(blW * 0.50, size.height - blH * 0.55, blW, size.height);
    pathBL.close();
    canvas.drawPath(pathBL, goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
