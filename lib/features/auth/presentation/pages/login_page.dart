import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/features/auth/data/auth_repository.dart';
import 'package:flatsplit/features/auth/presentation/pages/register_page.dart';
import 'package:flatsplit/features/flat/data/flat_repository.dart';
import 'package:flatsplit/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Thematic colors matching reference design
  static const Color creamBg = Color(0xFFFEF9E7);
  static const Color forestGreen = Color(0xFF164E3D);
  static const Color cardBg = Color(0xFFFFFDF7);
  static const Color cardBorder = Color(0xFFFDE68A);
  static const Color fieldFill = Color(0xFFFEF6D8);
  static const Color fieldBorder = Color(0xFFEAD8B1);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please check your credentials and try again.';
      case 'invalid-email':
        return 'The email address is formatted incorrectly.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few minutes before trying again.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        if (e.message != null && e.message!.isNotEmpty && e.message != 'Error') {
          return e.message!;
        }
        return 'Sign-in failed (${e.code}). Please try again.';
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepository =
        Provider.of<AuthRepository>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final flatRepo = FlatRepository();
      final cred = await authRepository.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Determine true role from Firestore & Flat Membership
      if (cred?.user != null) {
        final uid = cred!.user!.uid;
        final cleanEmail = (cred.user!.email ?? '').toLowerCase().trim();

        try {
          // 1. Fetch user doc from Firestore with timeout
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get()
              .timeout(const Duration(seconds: 5));
          String roleToSave = 'user';
          String? existingFlatId;
          String? existingFlatName;

          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            roleToSave = data['role'] as String? ?? 'user';
            existingFlatId = data['flatId'] as String?;
            existingFlatName = data['flatName'] as String?;
          }

          // 2. Discover true flat and role (checks flat creator, adminEmail, and member role)
          final discovery = await flatRepo.discoverFlatAndRole(
            uid: uid,
            email: cleanEmail,
            fallbackRole: roleToSave,
            currentFlatId: existingFlatId,
          );

          roleToSave = discovery.role;
          final finalFlatId = discovery.flatId ?? existingFlatId;
          final finalFlatName = discovery.flatName ?? existingFlatName;

          // 3. Save to Firestore
          await flatRepo.saveUserRole(
            uid: uid,
            role: roleToSave,
            email: cleanEmail,
            displayName: cred.user!.displayName,
          );

          // 4. Cache locally
          if (finalFlatId != null && finalFlatId.isNotEmpty) {
            await flatRepo.saveLocalProfile(
              flatId: finalFlatId,
              role: roleToSave,
              flatName: finalFlatName,
            );
          } else {
            await flatRepo.saveLocalRole(roleToSave);
          }
        } catch (_) {
          // If Firestore discovery times out, AuthGate will discover in background
        }
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getFirebaseAuthErrorMessage(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: cardBorder, width: 1.5),
            ),
            title: const Text(
              'Reset Password',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: forestGreen,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your email address and we will send you a secure password reset link.',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 13,
                    color: forestGreen,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'name@example.com',
                    hintStyle: TextStyle(
                      fontFamily: 'Fredoka',
                      color: forestGreen.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: fieldBorder, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: fieldBorder, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: forestGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      color: AppTheme.negative,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    color: forestGreen.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(() {
                            dialogError = 'Please enter a valid email address.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });

                        try {
                          final messenger = ScaffoldMessenger.of(context);
                          final authRepo = Provider.of<AuthRepository>(context, listen: false);
                          await authRepo.sendPasswordReset(email);
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Password reset link sent to $email!',
                                  style: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: forestGreen,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            dialogError = _getFirebaseAuthErrorMessage(e);
                          });
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            dialogError = 'Failed to send reset email. Please try again.';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  elevation: 0,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Send Link',
                        style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Scaffold(
      backgroundColor: creamBg,
      body: Stack(
        children: [
          // 1. Clean Decorative Canvas Background
          Positioned.fill(
            child: CustomPaint(
              painter: _LoginBackgroundPainter(),
            ),
          ),

          // 2. Bottom Right Wallet Graphic
          Positioned(
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/wallet_illustration.png',
                width: isDesktop ? 230 : (size.width * 0.44).clamp(170.0, 230.0),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 3. Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? (size.width - 440) / 2 : 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // Brand Logo Emblem
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: forestGreen.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
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

                    // Clean "Hisab Milau" Title
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
                    const SizedBox(height: 4),

                    // Friendly Subtitle
                    const Text(
                      'Shared expense management\nmade effortless',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 14,
                        color: forestGreen,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Sign In Rounded Cream Card
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
                              'Welcome Back',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: forestGreen,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter your credentials to access your flat',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 13.5,
                                color: forestGreen.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),

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
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
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
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.negative, width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.negative, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
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
                                hintText: 'Password',
                                hintStyle: TextStyle(
                                  fontFamily: 'Fredoka',
                                  color: forestGreen.withValues(alpha: 0.55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: forestGreen,
                                  size: 20,
                                ),
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
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.negative, width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.negative, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _signIn(),
                            ),
                            const SizedBox(height: 8),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: _showForgotPasswordDialog,
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      color: forestGreen,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

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

                            // Sign In Button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
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
                                        'Sign In',
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

                    // "New flatmate? Create Account"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'New here? ',
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
                              MaterialPageRoute(builder: (context) => const RegisterPage()),
                            );
                          },
                          child: const Text(
                            'Create Account',
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

                    const SizedBox(height: 70),
                  ],
                ),
              ),
            ),
          ),

          // 4. Floating Back Button
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

/// Custom painter for authentic organic corner shapes
class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFBD66A)
      ..style = PaintingStyle.fill;

    // 1. Top-left organic wave
    final double tlH = (size.height * 0.16).clamp(115.0, 145.0);
    final double tlW = (size.width * 0.28).clamp(175.0, 240.0);
    final pathTL = Path();
    pathTL.moveTo(0, 0);
    pathTL.lineTo(0, tlH);
    pathTL.cubicTo(
      tlW * 0.12,
      tlH * 0.98,
      tlW * 0.26,
      tlH * 0.62,
      tlW * 0.48,
      tlH * 0.56,
    );
    pathTL.cubicTo(
      tlW * 0.68,
      tlH * 0.52,
      tlW * 0.88,
      tlH * 0.30,
      tlW,
      0,
    );
    pathTL.close();
    canvas.drawPath(pathTL, goldPaint);

    // 2. Top-right organic lobe
    final double trTop = (size.height * 0.055).clamp(38.0, 65.0);
    const double trH = 135.0;
    final double trWidth = (size.width * 0.12).clamp(58.0, 78.0);

    final pathTR = Path();
    pathTR.moveTo(size.width, trTop);
    pathTR.cubicTo(
      size.width - trWidth * 0.40,
      trTop + trH * 0.08,
      size.width - trWidth,
      trTop + trH * 0.28,
      size.width - trWidth,
      trTop + trH * 0.50,
    );
    pathTR.cubicTo(
      size.width - trWidth,
      trTop + trH * 0.72,
      size.width - trWidth * 0.40,
      trTop + trH * 0.92,
      size.width,
      trTop + trH,
    );
    pathTR.close();
    canvas.drawPath(pathTR, goldPaint);

    // 3. Bottom-left organic golden blob
    final double blH = (size.height * 0.10).clamp(70.0, 95.0);
    final double blW = (size.width * 0.22).clamp(110.0, 160.0);
    final pathBL = Path();
    pathBL.moveTo(0, size.height);
    pathBL.lineTo(0, size.height - blH);
    pathBL.quadraticBezierTo(
      blW * 0.50,
      size.height - blH * 0.55,
      blW,
      size.height,
    );
    pathBL.close();
    canvas.drawPath(pathBL, goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}