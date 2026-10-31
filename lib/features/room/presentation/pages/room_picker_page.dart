import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/features/room/data/room_repository.dart';
import 'package:flatsplit/features/flat/data/flat_repository.dart';
import 'package:flatsplit/features/home/presentation/pages/home_page.dart';
import 'package:flatsplit/features/flat/presentation/pages/create_flat_page.dart';
import 'package:flatsplit/features/flat/presentation/pages/join_flat_page.dart';

/// Room picker shown after sign-in or when switching rooms.
class RoomPickerPage extends StatefulWidget {
  final bool isAdmin;
  final String? currentFlatId;

  const RoomPickerPage({
    super.key,
    this.isAdmin = false,
    this.currentFlatId,
  });

  @override
  State<RoomPickerPage> createState() => _RoomPickerPageState();
}

class _RoomPickerPageState extends State<RoomPickerPage>
    with SingleTickerProviderStateMixin {
  final RoomRepository _roomRepo = RoomRepository();
  final FlatRepository _flatRepo = FlatRepository();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String? _activeFlatId;
  bool _isLoading = false;

  // Signature Forest Emerald gradient reserved exclusively for the currently active room
  static const List<Color> _activeRoomGradient = [
    Color(0xFF0F382C),
    Color(0xFF165944),
  ];

  // Curated, non-green dark gradients for other rooms so they never conflict
  // with or mimic the active room's green indicator.
  static const List<List<Color>> _roomGradients = [
    [Color(0xFF0F172A), Color(0xFF1E293B)], // Obsidian Slate
    [Color(0xFF1E293B), Color(0xFF334155)], // Deep Charcoal
    [Color(0xFF1E3A5F), Color(0xFF2563EB)], // Royal Sapphire
    [Color(0xFF3B1D54), Color(0xFF6B21A8)], // Deep Violet
    [Color(0xFF4A1D24), Color(0xFF881337)], // Deep Wine
    [Color(0xFF2D241E), Color(0xFF78350F)], // Warm Amber-Walnut
  ];

  // Room emoji icons for visual variety
  static const List<String> _roomEmojis = [
    '🏠', '🏡', '✈️', '🏖️', '🎒', '🏢', '🌴', '⛺',
  ];

  @override
  void initState() {
    super.initState();
    _activeFlatId = widget.currentFlatId?.toUpperCase().trim();
    _loadActiveFlatId();

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

  Future<void> _loadActiveFlatId() async {
    if (_activeFlatId != null && _activeFlatId!.isNotEmpty) return;
    try {
      final profile = await _flatRepo.getLocalProfile();
      final localId = profile['flatId'];
      if (localId != null && localId.trim().isNotEmpty && mounted) {
        setState(() {
          _activeFlatId = localId.toUpperCase().trim();
        });
      }
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final remoteId = (doc.data()?['flatId'] as String?)?.toUpperCase().trim();
        if (remoteId != null && remoteId.isNotEmpty && mounted) {
          setState(() {
            _activeFlatId = remoteId;
          });
        }
      } catch (_) {}
    }
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
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

                          // Room grid from real-time stream
                          StreamBuilder<UserRoomsState>(
                            stream: _roomRepo.getUserRoomsStateStream(user.uid),
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

                              final state = snapshot.data;
                              final rooms = state?.rooms ?? [];
                              final activeIdFromStream = state?.activeFlatId;
                              final effectiveActiveId = (activeIdFromStream != null &&
                                      activeIdFromStream.isNotEmpty)
                                  ? activeIdFromStream
                                  : _activeFlatId;

                              if (rooms.isEmpty) {
                                return _buildEmptyState();
                              }

                              return _buildRoomGrid(rooms, effectiveActiveId);
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomGrid(List<UserRoom> rooms, String? activeFlatId) {
    return Column(
      children: [
        for (int i = 0; i < rooms.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRoomCard(rooms[i], i, activeFlatId),
          ),
      ],
    );
  }

  Widget _buildRoomCard(UserRoom room, int index, String? activeFlatId) {
    final isCurrent = activeFlatId != null &&
        activeFlatId.isNotEmpty &&
        room.flatId.toUpperCase().trim() == activeFlatId.toUpperCase().trim();

    // The active room gets the signature Forest Emerald theme.
    // Inactive rooms get stable, deterministic dark gradients so green is never confused.
    final gradient = isCurrent
        ? _activeRoomGradient
        : _roomGradients[room.flatId.hashCode.abs() % _roomGradients.length];

    final emoji = room.icon.isNotEmpty
        ? room.icon
        : _roomEmojis[room.flatId.hashCode.abs() % _roomEmojis.length];

    final isAdmin = room.role == 'admin';

    return GestureDetector(
      onTap: () => _selectRoom(room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF34D399).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.12),
            width: isCurrent ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : gradient[0].withValues(alpha: 0.22),
              blurRadius: isCurrent ? 18 : 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Room emoji avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isCurrent ? 0.22 : 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF6EE7B7).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.2),
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

            // Room info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title + Badges
                  Row(
                    children: [
                      Flexible(
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
                        _buildAdminBadge(),
                      ],
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        _buildCurrentBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Metadata row: Flat ID and Member count
                  Row(
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        room.flatId,
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Member count
                      FutureBuilder<int>(
                        future: _roomRepo.getRoomMemberCount(room.flatId),
                        builder: (context, snap) {
                          final count = snap.data ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$count ${count == 1 ? 'member' : 'members'}',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.65),
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

            // Guaranteed breathing room before the action button
            const SizedBox(width: 14),

            // Redesigned Action Button (Circle with clear contrast & alignment)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF34D399).withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF34D399).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.18),
                  width: 1.2,
                ),
              ),
              child: Icon(
                isCurrent ? Icons.check_rounded : Icons.arrow_forward_rounded,
                color: isCurrent
                    ? const Color(0xFF34D399)
                    : Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Redesigned Admin Badge: Sleek amber pill capsule that harmonizes with dark cards
  Widget _buildAdminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.shield_rounded,
            size: 11,
            color: Color(0xFFFBBF24),
          ),
          SizedBox(width: 3.5),
          Text(
            'Admin',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFDE68A),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Current Room Badge: Vibrant emerald pill with a glowing indicator dot
  Widget _buildCurrentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: const BoxDecoration(
              color: Color(0xFF34D399),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF34D399),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Current',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA7F3D0),
              letterSpacing: 0.2,
            ),
          ),
        ],
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
