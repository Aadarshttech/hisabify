import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/flat/data/flat_repository.dart';
import 'package:flatsplit/features/home/presentation/pages/admin_page.dart';
import 'package:flatsplit/main.dart';

class ProfileMenuBottomSheet extends StatefulWidget {
  final String displayName;
  final String? email;
  final String flatId;
  final String flatName;
  final bool isUserAdmin;
  final List<Flatmate> flatmates;

  const ProfileMenuBottomSheet({
    super.key,
    required this.displayName,
    required this.email,
    required this.flatId,
    required this.flatName,
    required this.isUserAdmin,
    required this.flatmates,
  });

  static void show(
    BuildContext context, {
    required String displayName,
    required String? email,
    required String flatId,
    required String flatName,
    required bool isUserAdmin,
    required List<Flatmate> flatmates,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileMenuBottomSheet(
        displayName: displayName,
        email: email,
        flatId: flatId,
        flatName: flatName,
        isUserAdmin: isUserAdmin,
        flatmates: flatmates,
      ),
    );
  }

  @override
  State<ProfileMenuBottomSheet> createState() => _ProfileMenuBottomSheetState();
}

class _ProfileMenuBottomSheetState extends State<ProfileMenuBottomSheet> {
  bool _copied = false;
  final FlatRepository _flatRepo = FlatRepository();

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.flatId));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Room code "${widget.flatId}" copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _confirmLeaveFlat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final remainingFlatmates = widget.flatmates.where((f) {
      final nameMatch = f.name.toLowerCase().trim() == widget.displayName.toLowerCase().trim();
      final emailMatch = widget.email != null && f.email != null && f.email!.toLowerCase().trim() == widget.email!.toLowerCase().trim();
      return !nameMatch && !emailMatch;
    }).toList();

    // Check if user is Admin and is the SOLE admin
    final bool isSoleAdmin = widget.isUserAdmin &&
        !remainingFlatmates.any((f) => f.role.toLowerCase() == 'admin');

    if (isSoleAdmin && remainingFlatmates.isNotEmpty) {
      // Show Transfer Ownership Dialog
      Flatmate? selectedNewAdmin = remainingFlatmates.first;

      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (dialogCtx, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: const [
                    Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Transfer Admin Role',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are the Admin of "${widget.flatName}". Choose who takes over as Admin before you leave:',
                        style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.darkText),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: remainingFlatmates.map((f) {
                            final isChosen = selectedNewAdmin?.id == f.id || selectedNewAdmin?.name == f.name;
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedNewAdmin = f;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isChosen ? AppTheme.positiveLight : Colors.transparent,
                                  border: Border(
                                    bottom: f != remainingFlatmates.last
                                        ? const BorderSide(color: AppTheme.border)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // ignore: deprecated_member_use
                                    Radio<String>(
                                      value: f.name,
                                      // ignore: deprecated_member_use
                                      groupValue: selectedNewAdmin?.name,
                                      activeColor: const Color(0xFFD97706),
                                      // ignore: deprecated_member_use
                                      onChanged: (_) {
                                        setDialogState(() {
                                          selectedNewAdmin = f;
                                        });
                                      },
                                    ),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isChosen ? const Color(0xFFFEF3C7) : AppTheme.surfaceMuted,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        f.name.isNotEmpty ? f.name.substring(0, 1).toUpperCase() : 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isChosen ? const Color(0xFFB45309) : AppTheme.darkerText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                              color: AppTheme.darkerText,
                                            ),
                                          ),
                                          if (f.email != null && f.email!.isNotEmpty)
                                            Text(
                                              f.email!,
                                              style: const TextStyle(fontSize: 11, color: AppTheme.lightText),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isChosen)
                                      const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 18),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '💡 The new Admin will have full access to flat settings and member controls.',
                        style: TextStyle(fontSize: 11, color: AppTheme.lightText),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: selectedNewAdmin != null
                        ? () => Navigator.pop(ctx, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('Transfer & Leave Flat'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (proceed == true && selectedNewAdmin != null && mounted) {
        Navigator.pop(context); // Close profile bottom sheet
        await _flatRepo.transferAdminAndLeaveFlat(
          flatId: widget.flatId,
          oldAdminUid: user.uid,
          newAdmin: selectedNewAdmin!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admin transferred to ${selectedNewAdmin!.name}. You have left "${widget.flatName}".',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
          );
        }
      }
      return;
    }

    // Default Leave confirmation (for regular flatmates, or if another admin already exists)
    final bool isLastMember = remainingFlatmates.isEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.meeting_room_outlined, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Leave Room?'),
          ],
        ),
        content: Text(
          isLastMember
              ? 'You are the only member left in "${widget.flatName}". Leaving will leave this flat empty. Are you sure?'
              : 'Are you sure you want to leave "${widget.flatName}"? You will lose access to this flat until you rejoin with code "${widget.flatId}".',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Leave Room'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _flatRepo.leaveFlat(
        uid: user.uid,
        flatId: widget.flatId,
        email: user.email,
        memberName: widget.displayName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left "${widget.flatName}". Join or create a flat to continue.'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    }
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
        content: Text(
          'Sign out of your account (${widget.displayName})?',
          style: const TextStyle(fontSize: 13.5),
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
      Navigator.pop(context); // Close bottom sheet
      await FirebaseAuth.instance.signOut();
      await _flatRepo.clearLocalProfile();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String initial = widget.displayName.trim().isNotEmpty
        ? widget.displayName.trim().substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header title & close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile & Room Menu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkerText,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.grey, size: 22),
                  splashRadius: 18,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. User Identity Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // User Avatar Squircle
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name, email, and role badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.isUserAdmin
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.isUserAdmin
                                        ? Icons.shield_rounded
                                        : Icons.person_outline_rounded,
                                    size: 11,
                                    color: widget.isUserAdmin
                                        ? const Color(0xFFB45309)
                                        : const Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.isUserAdmin ? 'Admin' : 'Flatmate',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isUserAdmin
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.email != null && widget.email!.isNotEmpty
                              ? widget.email!
                              : 'Signed In User',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Room & Flat Information Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.home_work_rounded, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            widget.flatName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkerText,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '${widget.flatmates.length} Members',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room Code Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF2B749), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ROOM / FLAT CODE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.flatId,
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _copyCode,
                          icon: Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 14,
                          ),
                          label: Text(_copied ? 'Copied!' : 'Copy'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _copied ? AppTheme.positive : AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '💡 Share this code with your roommates so they can join this flat.',
                    style: TextStyle(fontSize: 11, color: AppTheme.lightText),
                  ),

                  // Flatmates preview
                  if (widget.flatmates.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Flatmates in this room:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.flatmates.map((f) {
                        final isMe = f.name.toLowerCase().trim() == widget.displayName.toLowerCase().trim();
                        final isAdmin = f.role.toLowerCase() == 'admin';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.positiveLight : AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isMe
                                  ? AppTheme.positive.withValues(alpha: 0.4)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isMe ? '${f.name} (You)' : f.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                                  color: isMe ? AppTheme.positive : AppTheme.darkerText,
                                ),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.shield_rounded, size: 10, color: Color(0xFFD97706)),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Admin Console Quick Link (if Admin)
            if (widget.isUserAdmin) ...[
              _buildActionTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Console & Flat Settings',
                subtitle: 'Manage members, activity logs, and flat config',
                iconColor: const Color(0xFF164E3D),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminPage(flatId: widget.flatId)),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],

            // 4. Leave Room
            _buildActionTile(
              icon: Icons.meeting_room_outlined,
              title: 'Leave Room',
              subtitle: 'Disconnect your account from "${widget.flatName}"',
              iconColor: AppTheme.warning,
              onTap: _confirmLeaveFlat,
            ),
            const SizedBox(height: 8),

            // 5. Sign Out
            _buildActionTile(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              subtitle: 'Log out of your account on this device',
              iconColor: AppTheme.negative,
              onTap: _confirmSignOut,
            ),
            const SizedBox(height: 18),

            // Footer
            Center(
              child: Text(
                'Hisab Milau • Flat Expense Manager',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.lightText.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: iconColor == AppTheme.negative ? AppTheme.negative : AppTheme.darkerText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.grey,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
