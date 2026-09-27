import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatsplit/features/flat/data/flat_repository.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final _flatRepo = FlatRepository();
  bool _isSaving = false;
  String? _errorMessage;

  static const Color creamBg = Color(0xFFFEF9E7);
  static const Color forestGreen = Color(0xFF164E3D);
  static const Color goldAccent = Color(0xFFF2B749);

  Future<void> _selectRole(String role) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User is not signed in.');
      }

      await _flatRepo.saveUserRole(
        uid: user.uid,
        role: role,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
      );
      // AuthGate stream will automatically pick up the new role and route appropriately
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to select role: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: creamBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? (size.width - 460) / 2 : 24.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo / Icon
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: goldAccent.withValues(alpha: 0.15),
                      border: Border.all(color: goldAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      size: 38,
                      color: forestGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Welcome Header
                const Text(
                  'Welcome to Hisabify!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: forestGreen,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How would you like to use the app?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 15,
                    color: forestGreen.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                // Error Message if any
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                      ),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Card 1: Admin
                _RoleCard(
                  title: 'I am an Admin',
                  subtitle: 'Create a new flat, generate a flat code, and manage expenses & flatmates.',
                  icon: Icons.shield_rounded,
                  badgeText: 'CREATE FLAT',
                  badgeColor: goldAccent,
                  isLoading: _isSaving,
                  onTap: () => _selectRole('admin'),
                ),
                const SizedBox(height: 18),

                // Card 2: Flatmate / User
                _RoleCard(
                  title: 'I am a Flatmate',
                  subtitle: 'Join an existing flat using a 6-character code shared by your admin.',
                  icon: Icons.group_rounded,
                  badgeText: 'JOIN FLAT',
                  badgeColor: const Color(0xFF10B981),
                  isLoading: _isSaving,
                  onTap: () => _selectRole('user'),
                ),
                const SizedBox(height: 32),

                // User Info & Sign Out
                if (user?.email != null)
                  Center(
                    child: Text(
                      'Signed in as ${user!.email}',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 13,
                        color: forestGreen.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                Center(
                  child: TextButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout_rounded, size: 16, color: forestGreen),
                    label: const Text(
                      'Sign out / Switch account',
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
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final Color badgeColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.badgeColor,
    required this.isLoading,
    required this.onTap,
  });

  static const Color forestGreen = Color(0xFF164E3D);
  static const Color cardBg = Color(0xFFFFFDF7);
  static const Color cardBorder = Color(0xFFFDE68A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: forestGreen.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: Icon(icon, color: forestGreen, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: forestGreen,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: forestGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 13,
                        color: forestGreen.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: forestGreen),
            ],
          ),
        ),
      ),
    );
  }
}
