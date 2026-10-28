import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/features/room/data/room_repository.dart';
import 'package:flatsplit/features/flat/data/flat_repository.dart';
import 'package:flatsplit/features/home/presentation/pages/home_page.dart';
import 'package:flatsplit/features/flat/presentation/pages/create_flat_page.dart';
import 'package:flatsplit/features/flat/presentation/pages/join_flat_page.dart';

/// Netflix-style "Who's Watching?" room picker shown after sign-in
/// when the user belongs to multiple rooms.
class RoomPickerPage extends StatefulWidget {
  final bool isAdmin;

  const RoomPickerPage({super.key, this.isAdmin = false});

  @override
  State<RoomPickerPage> createState() => _RoomPickerPageState();
}

class _RoomPickerPageState extends State<RoomPickerPage>
    with SingleTickerProviderStateMixin {
  final RoomRepository _roomRepo = RoomRepository();
  final FlatRepository _flatRepo = FlatRepository();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;

  // Room colors for visual differentiation (cycled through)
  static const List<List<Color>> _roomGradients = [
    [Color(0xFF0F172A), Color(0xFF1E293B)], // Slate
    [Color(0xFF164E3D), Color(0xFF1B6B4F)], // Forest Green
    [Color(0xFF7C2D12), Color(0xFFB45309)], // Warm Amber
    [Color(0xFF1E3A5F), Color(0xFF2563EB)], // Royal Blue
    [Color(0xFF581C87), Color(0xFF7C3AED)], // Purple
    [Color(0xFF831843), Color(0xFFBE185D)], // Rose
  ];

  // Room emoji icons for visual variety
  static const List<String> _roomEmojis = [
    '🏠', '🏡', '✈️', '🏖️', '🎒', '🏢', '🌴', '⛺',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _selectRoom(UserRoom room) async {
    if (_isLoading) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await _roomRepo.switchRoom(
        uid: user.uid,
        flatId: room.flatId,
        flatName: room.flatName,
        role: room.role,
      );
      await _flatRepo.saveLocalProfile(
        flatId: room.flatId,
        role: room.role,
        flatName: room.flatName,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomePage(
              flatId: room.flatId,
              isAdmin: room.role == 'admin',
            ),
          ),
          (route) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not switch rooms: $error')),
      );
    }
  }

  void _navigateToJoinRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinFlatPage()),
    );
  }

  void _navigateToCreateRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateFlatPage()),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppTheme.negative),
            SizedBox(width: 8),
            Text('Sign Out?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _flatRepo.clearLocalProfile();
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final displayName = user.displayName ?? user.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Top bar with sign out
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // App Logo
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Hisabify',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    // Sign out button
                    GestureDetector(
                      onTap: _confirmSignOut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.logout_rounded, size: 14, color: AppTheme.lightText),
                            SizedBox(width: 4),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // Welcome message
                      Text(
                        'Hey, $displayName 👋',
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Which room would you like to enter?',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.lightText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Room grid
                      StreamBuilder<List<UserRoom>>(
                        stream: _roomRepo.getUserRoomsStream(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 60),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF164E3D)),
                              ),
                            );
                          }

                          final rooms = snapshot.data ?? [];

                          if (rooms.isEmpty) {
                            return _buildEmptyState();
                          }

                          return _buildRoomGrid(rooms);
                        },
                      ),

                      const SizedBox(height: 32),

                      // Action buttons: Join or Create Room
                      _buildActionButtons(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomGrid(List<UserRoom> rooms) {
    return Column(
      children: [
        for (int i = 0; i < rooms.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRoomCard(rooms[i], i),
          ),
      ],
    );
  }

  Widget _buildRoomCard(UserRoom room, int index) {
    final gradient = _roomGradients[index % _roomGradients.length];
    final emoji = room.icon.isEmpty ? _roomEmojis[index % _roomEmojis.length] : room.icon;
    final isAdmin = room.role == 'admin';

    return GestureDetector(
      onTap: () => _selectRoom(room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Room emoji avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),

            // Room info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.flatName,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.shield_rounded, size: 10, color: Color(0xFFB45309)),
                              SizedBox(width: 2),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        room.flatId,
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Member count (fetched async)
                      FutureBuilder<int>(
                        future: _roomRepo.getRoomMemberCount(room.flatId),
                        builder: (context, snap) {
                          final count = snap.data ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Row(
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Enter arrow
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            alignment: Alignment.center,
            child: const Text('🏠', style: TextStyle(fontSize: 36)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No rooms yet',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkerText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a new room or join an existing\none with a room code.',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 13,
              color: AppTheme.lightText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Join existing room
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _navigateToJoinRoom,
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Join Existing Room'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFF2B749), width: 1.5),
              backgroundColor: const Color(0xFFFEF6D8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Create new room
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _navigateToCreateRoom,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create New Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
