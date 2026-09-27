import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/features/auth/data/auth_repository.dart';
import 'package:flatsplit/features/flat/data/flat_repository.dart';
import 'package:flatsplit/main.dart';
import 'package:flatsplit/features/auth/presentation/pages/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Thematic colors
  static const Color creamBg = Color(0xFFFEF9E7);
  static const Color forestGreen = Color(0xFF164E3D);
  static const Color cardBg = Color(0xFFFFFDF7);
  static const Color cardBorder = Color(0xFFFDE68A);
  static const Color fieldFill = Color(0xFFFEF6D8);
  static const Color fieldBorder = Color(0xFFEAD8B1);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak (min 6 chars).';
      case 'network-request-failed':
        return 'Network connection error.';
      default:
        return e.message ?? 'Registration failed (${e.code}).';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepository =
        Provider.of<AuthRepository>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final flatRepo = FlatRepository();
      // Default to user role; auto-upgrades to admin if creating a new flat
      await flatRepo.saveLocalRole('user');

      final email = _emailController.text.trim().toLowerCase();
      final name = _nameController.text.trim();

      final cred = await authRepository.createUserWithEmailPassword(
        email,
        _passwordController.text,
        name,
      );

      // Save the user profile to Firestore
      if (cred?.user != null) {
        await flatRepo.saveUserRole(
          uid: cred!.user!.uid,
          role: 'user',
          email: email,
          displayName: name,
        );
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseAuthErrorMessage(e);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
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
          // 1. Organic golden corner canvas blobs
          Positioned.fill(
            child: CustomPaint(
              painter: _RegisterBackgroundPainter(),
            ),
          ),

          // 2. Perfectly Centered Content Area
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? (size.width - 440) / 2 : 24.0,
                          vertical: 24.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Brand Logo
                            Center(
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: forestGreen.withValues(alpha: 0.08),
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
                            const SizedBox(height: 12),

                            // Heading
                            const Text(
                              'Join Hisabify',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: forestGreen,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Subtitle
                            const Text(
                              'Create your account to start\nmanaging shared expenses',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 13,
                                color: forestGreen,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 24),

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
                                      'Create Account',
                                      style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: forestGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Enter your details to get started',
                                      style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        fontSize: 13.5,
                                        color: forestGreen.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 18),

                                    // Full Name Field
                                    TextFormField(
                                      controller: _nameController,
                                      style: const TextStyle(
                                        fontFamily: 'Fredoka',
                                        color: forestGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Full Name',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Fredoka',
                                          color: forestGreen.withValues(alpha: 0.55),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: const Icon(Icons.person_outline_rounded, color: forestGreen, size: 20),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                      ),
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Enter your name';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Email Address Field
                                    TextFormField(
                                      controller: _emailController,
                                      style: const TextStyle(
                                        fontFamily: 'Fredoka',
                                        color: forestGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Email Address',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Fredoka',
                                          color: forestGreen.withValues(alpha: 0.55),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: const Icon(Icons.email_outlined, color: forestGreen, size: 20),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Enter your email';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Password Field
                                    TextFormField(
                                      controller: _passwordController,
                                      style: const TextStyle(
                                        fontFamily: 'Fredoka',
                                        color: forestGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Password (min 6 chars)',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Fredoka',
                                          color: forestGreen.withValues(alpha: 0.55),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: forestGreen, size: 20),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                            color: forestGreen,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                      ),
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      validator: (value) {
                                        if (value == null || value.length < 6) return 'Password must be at least 6 characters';
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _register(),
                                    ),
                                    const SizedBox(height: 18),

                                    // Error Banner
                                    if (_errorMessage != null)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.negativeLight,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: AppTheme.negative.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: AppTheme.negative, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: const TextStyle(
                                                  fontFamily: 'Fredoka',
                                                  color: AppTheme.negative,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Register Button
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _register,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: forestGreen,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(26),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Create Account',
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

                            const SizedBox(height: 22),

                            // Back to Sign In Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    color: forestGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const LoginPage()),
                                    );
                                  },
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      color: forestGreen,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Floating Back Button
          if (Navigator.of(context).canPop())
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: forestGreen,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for organic corner shapes on register page
class _RegisterBackgroundPainter extends CustomPainter {
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
      tlW * 0.12, tlH * 0.98, tlW * 0.26, tlH * 0.62, tlW * 0.48, tlH * 0.56,
    );
    pathTL.cubicTo(
      tlW * 0.68, tlH * 0.52, tlW * 0.88, tlH * 0.30, tlW, 0,
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}