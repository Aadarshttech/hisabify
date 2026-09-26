import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/expenses/data/expense_repository.dart';
import 'package:flatsplit/features/home/presentation/pages/home_page.dart';
import 'package:flatsplit/main.dart';

class AdminPage extends StatefulWidget {
  final String flatId;

  const AdminPage({super.key, required this.flatId});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final ExpenseRepository _expenseRepository;
  final _nameController = TextEditingController();
  final _resetEmailController = TextEditingController();
  bool _isResettingPassword = false;
  String? _resetStatusMessage;
  bool _isResetSuccess = false;
  late final Stream<List<Flatmate>> _membersStream;
  late final Stream<List<Expense>> _expensesStream;
  late final Stream<List<Settlement>> _settlementsStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _flatStream;
  String _activityFilter = 'all'; // 'all', 'deleted', 'active'

  @override
  void initState() {
    super.initState();
    _expenseRepository = ExpenseRepository(flatId: widget.flatId);
    _membersStream = _expenseRepository.getMembersStream();
    _expensesStream = _expenseRepository.getExpensesStream();
    _settlementsStream = _expenseRepository.getSettlementsStream();
    _flatStream = FirebaseFirestore.instance.collection('flats').doc(widget.flatId).snapshots();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetForEmail([String? targetEmail]) async {
    final email = (targetEmail ?? _resetEmailController.text).trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _resetStatusMessage = 'Please enter a valid email address.';
        _isResetSuccess = false;
      });
      return;
    }

    setState(() {
      _isResettingPassword = true;
      _resetStatusMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _isResettingPassword = false;
        _isResetSuccess = true;
        _resetStatusMessage = 'Password reset email successfully sent to $email!';
      });
      _resetEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset link sent to $email!'),
          backgroundColor: AppTheme.positive,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isResettingPassword = false;
        _isResetSuccess = false;
        _resetStatusMessage = e.message ?? 'Failed to send reset link (${e.code}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResettingPassword = false;
        _isResetSuccess = false;
        _resetStatusMessage = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  void _showResetForMemberDialog(Flatmate member) {
    final memberEmailController = TextEditingController(text: member.email ?? '');
    bool isDialogSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.lock_reset_rounded, color: AppTheme.brandAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reset for ${member.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.darkerText),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send an instant password recovery link to ${member.name}\'s email address.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.lightText, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: memberEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: member.email == null || member.email!.isEmpty,
                  decoration: InputDecoration(
                    labelText: '${member.name}\'s Email',
                    hintText: 'e.g. ${member.name.toLowerCase()}@example.com',
                    filled: true,
                    fillColor: AppTheme.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: AppTheme.negative, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.grey)),
              ),
              ElevatedButton(
                onPressed: isDialogSubmitting
                    ? null
                    : () async {
                        final email = memberEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(() {
                            dialogError = 'Please enter a valid email address.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isDialogSubmitting = true;
                          dialogError = null;
                        });

                        try {
                          final messenger = ScaffoldMessenger.of(context);
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Password reset link sent to $email for ${member.name}!'),
                                backgroundColor: AppTheme.positive,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() {
                            isDialogSubmitting = false;
                            dialogError = e.message ?? 'Error (${e.code})';
                          });
                        } catch (e) {
                          setDialogState(() {
                            isDialogSubmitting = false;
                            dialogError = 'Failed to send reset email.';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: isDialogSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditMemberDialog(Flatmate member) {
    final nameCtrl = TextEditingController(text: member.name);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Edit Flatmate Name',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkerText),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (member.email != null && member.email!.isNotEmpty) ...[
                Text(
                  'Registered Email: ${member.email}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'e.g. Yudhin Khanal',
                  filled: true,
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) return;
                Navigator.of(dialogCtx).pop();

                _expenseRepository.updateMemberName(
                  member.id,
                  member.name,
                  newName,
                  email: member.email,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated name to "$newName"'),
                      backgroundColor: AppTheme.positive,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveMemberDialog(Flatmate member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFDE68A), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.negativeLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.negative, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Remove Flatmate?',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF164E3D),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove "${member.name}" from this flat?',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF164E3D),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF6D8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAD8B1)),
              ),
              child: const Text(
                '⚠️ All historical expenses, settlements, and balance calculations for this member will remain safe in flat records. However, they will lose access to this room.',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 12,
                  color: Color(0xFF164E3D),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Fredoka',
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final messenger = ScaffoldMessenger.of(context);
              await _expenseRepository.removeMember(
                member.id,
                uid: member.uid,
                email: member.email,
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Removed ${member.name} from flat'),
                    backgroundColor: AppTheme.negative,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Remove',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add_outlined, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Add Flatmate',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkerText),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                hintText: 'e.g. Yudhin Khanal',
                filled: true,
                fillColor: AppTheme.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address (Optional)',
                hintText: 'e.g. yudhin@example.com',
                helperText: 'For password recovery and account linking',
                helperStyle: const TextStyle(fontSize: 11, color: AppTheme.lightText),
                filled: true,
                fillColor: AppTheme.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim().toLowerCase();
              Navigator.of(dialogCtx).pop();
              if (name.isNotEmpty) {
                _expenseRepository.addMember(
                  name,
                  email: email.isNotEmpty ? email : null,
                  role: 'Flatmate',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add Member'),
          ),
        ],
      ),
    );
  }



  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.negative),
            SizedBox(width: 8),
            Text('Clear All Expenses?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will permanently delete all logged test/seed expenses and settlements from Firestore. You will start with a completely clean slate (₹0).',
          style: TextStyle(fontSize: 13, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await _expenseRepository.clearAllExpensesAndSettlements();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All test data cleared! Clean slate.'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
  }

  void _showClearSettlementsConfirmation() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.negative),
            SizedBox(width: 8),
            Text('Clear Settlement History?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will permanently delete all recorded settlements from Firestore. Expenses will remain untouched.',
          style: TextStyle(fontSize: 13, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await _expenseRepository.clearAllSettlements();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All settlement history cleared!'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear Settlements'),
          ),
        ],
      ),
    );
  }

  void _showEmptyTrashConfirmation(int count) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppTheme.negative),
            SizedBox(width: 8),
            Text('Empty Activity Trash?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will permanently delete all $count cancelled/deleted activity entries from Firestore. This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final deletedCount = await _expenseRepository.permanentlyDeleteAllDeletedExpenses();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Permanently removed $deletedCount cancelled items!'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Purge Everything'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentEmail = currentUser?.email?.toLowerCase().trim();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _flatStream,
      builder: (context, flatSnap) {
        final flatData = flatSnap.data?.data();
        final flatName = flatData?['name'] as String? ?? 'Flat ${widget.flatId}';
        final String? createdBy = flatData?['createdBy'] as String?;
        final String? adminEmail = (flatData?['adminEmail'] as String?)?.toLowerCase().trim();

        return StreamBuilder<List<Flatmate>>(
          initialData: const [],
          stream: _membersStream,
          builder: (context, memberSnapshot) {
            final liveFlatmates = memberSnapshot.data ?? [];

            // Admin Access Security Check
            final bool isCreator = currentUser != null && createdBy != null && currentUser.uid == createdBy;
            final bool isEmailAdmin = currentEmail != null && adminEmail != null && currentEmail == adminEmail;
            final bool isMemberAdmin = liveFlatmates.any((m) {
              final matchUid = currentUser != null && m.uid != null && m.uid == currentUser.uid;
              final matchEmail = currentEmail != null && m.email != null && m.email!.toLowerCase().trim() == currentEmail;
              return (matchUid || matchEmail) && m.role.toLowerCase() == 'admin';
            });

            // If flat data has loaded and user is NOT an admin of this flat, block access!
            if (flatSnap.hasData && !isCreator && !isEmailAdmin && !isMemberAdmin) {
              return Scaffold(
                backgroundColor: AppTheme.background,
                appBar: AppBar(
                  title: const Text('Access Denied', style: TextStyle(color: AppTheme.darkerText, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.surface,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.darkerText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.negative.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_person_outlined, size: 60, color: AppTheme.negative),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Admin Access Restricted',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.darkerText),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You are logged in as a Flatmate. Only flat admins have access to the Admin Console.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppTheme.lightText, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.dashboard_outlined, size: 18),
                          label: const Text('Return to Flat Dashboard'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => HomePage(flatId: widget.flatId)),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return StreamBuilder<List<Expense>>(
              initialData: const [],
              stream: _expensesStream,
              builder: (context, expenseSnapshot) {
                final allExpenses = expenseSnapshot.data ?? [];

                return StreamBuilder<List<Settlement>>(
                  initialData: const [],
                  stream: _settlementsStream,
                  builder: (context, settlementSnapshot) {
                    final settlements = settlementSnapshot.data ?? [];

                    return DefaultTabController(
                      length: 4,
                      child: Scaffold(
                        backgroundColor: AppTheme.background,
                        appBar: AppBar(
                          title: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      flatName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.darkerText),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'Admin Console',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppTheme.surface,
                      elevation: 0,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.dashboard_outlined, color: AppTheme.primary, size: 22),
                          tooltip: 'View App Dashboard',
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => HomePage(flatId: widget.flatId, isAdmin: true)),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: AppTheme.negative, size: 20),
                          tooltip: 'Sign Out',
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const AuthGate()),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                      bottom: TabBar(
                        isScrollable: false,
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.grey,
                        indicatorColor: AppTheme.primary,
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                        tabs: const [
                          Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Members'),
                          Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Activity'),
                          Tab(icon: Icon(Icons.handshake_outlined, size: 18), text: 'Settlements'),
                          Tab(icon: Icon(Icons.build_outlined, size: 18), text: 'Tools'),
                        ],
                      ),
                    ),
                    body: TabBarView(
                      children: [
                        _buildMembersTab(liveFlatmates),
                        _buildActivityAndTrashTab(allExpenses),
                        _buildSettlementsTab(settlements),
                        _buildToolsTab(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  },
);
  }

  Widget _buildMembersTab(List<Flatmate> liveFlatmates) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Section: Flatmates Management
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flat Members',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkerText,
                  ),
                ),
                Text(
                  '${liveFlatmates.length} active flatmates',
                  style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
                ),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Add Member', style: TextStyle(fontSize: 12)),
              onPressed: _showAddMemberDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (liveFlatmates.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_outline_rounded, size: 36, color: AppTheme.grey),
                const SizedBox(height: 10),
                const Text(
                  'No flatmates added yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkerText),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap below to add flatmates to this flat:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.lightText),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Add Member', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  onPressed: _showAddMemberDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else
          ...liveFlatmates.map((member) {
            final currentUser = FirebaseAuth.instance.currentUser;
            final currentEmail = currentUser?.email?.toLowerCase().trim();
            final currentUid = currentUser?.uid;

            final memberEmail = member.email?.toLowerCase().trim();
            final isSelf = (currentEmail != null && memberEmail != null && currentEmail == memberEmail) ||
                (currentUid != null && member.uid != null && currentUid == member.uid) ||
                (currentEmail != null && member.id.toLowerCase() == currentEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'));

            final isMemberAdmin = member.role.toLowerCase() == 'admin' ||
                member.email?.toLowerCase().trim() == 'aadarshapandit17@gmail.com' ||
                member.email?.toLowerCase().trim() == 'aadarshapandit@gmail.com';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.surfaceMuted,
                          child: Text(
                            member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkerText),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkerText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMemberAdmin) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF164E3D).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFF164E3D), width: 1),
                                      ),
                                      child: const Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontFamily: 'Fredoka',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF164E3D),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF64748B).withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                      ),
                                      child: const Text(
                                        'Flatmate',
                                        style: TextStyle(
                                          fontFamily: 'Fredoka',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (member.email != null && member.email!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  member.email!,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.lightText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 19, color: AppTheme.primary),
                        tooltip: 'Edit Name for ${member.name}',
                        onPressed: () => _showEditMemberDialog(member),
                      ),
                      IconButton(
                        icon: const Icon(Icons.lock_reset_rounded, size: 20, color: AppTheme.brandAccent),
                        tooltip: 'Reset Password for ${member.name}',
                        onPressed: () => _showResetForMemberDialog(member),
                      ),
                      if (isSelf || isMemberAdmin)
                        IconButton(
                          icon: Icon(
                            Icons.shield_rounded,
                            size: 19,
                            color: isSelf ? const Color(0xFFD97706) : Colors.grey.shade400,
                          ),
                          tooltip: isSelf
                              ? 'You are the Admin (Cannot remove yourself)'
                              : 'Admin accounts cannot be deleted',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isSelf
                                      ? 'Admins cannot remove themselves. To leave this flat, transfer admin ownership from the Profile Menu.'
                                      : '${member.name} is an Admin and cannot be removed directly.',
                                  style: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: const Color(0xFF164E3D),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.negative),
                          tooltip: 'Remove ${member.name}',
                          onPressed: () => _showRemoveMemberDialog(member),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildActivityAndTrashTab(List<Expense> allExpenses) {
    final deletedExpenses = allExpenses.where((e) => e.isDeleted).toList();
    final activeExpenses = allExpenses.where((e) => !e.isDeleted).toList();

        List<Expense> displayedExpenses;
        if (_activityFilter == 'deleted') {
          displayedExpenses = deletedExpenses;
        } else if (_activityFilter == 'active') {
          displayedExpenses = activeExpenses;
        } else {
          displayedExpenses = allExpenses;
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Filter Pills
            Row(
              children: [
                _buildActivityFilterChip('all', 'All (${allExpenses.length})'),
                const SizedBox(width: 8),
                _buildActivityFilterChip('deleted', 'Trash (${deletedExpenses.length})', isDanger: true),
                const SizedBox(width: 8),
                _buildActivityFilterChip('active', 'Active (${activeExpenses.length})'),
              ],
            ),
            const SizedBox(height: 14),

            if (deletedExpenses.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.negativeLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.negative.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${deletedExpenses.length} cancelled entries in Trash',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.negative,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Empty Trash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () => _showEmptyTrashConfirmation(deletedExpenses.length),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.negative,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (displayedExpenses.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      _activityFilter == 'deleted'
                          ? Icons.delete_outline_rounded
                          : Icons.receipt_long_outlined,
                      size: 40,
                      color: AppTheme.deactivatedText,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _activityFilter == 'deleted'
                          ? 'Trash is empty! No cancelled activity items.'
                          : 'No expenses recorded yet.',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.lightText),
                    ),
                  ],
                ),
              )
            else
              ...displayedExpenses.map((expense) {
                final isDeleted = expense.isDeleted;
                final dateStr = DateFormat('MMM d, h:mm a').format(expense.date);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? AppTheme.surfaceMuted.withValues(alpha: 0.5)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDeleted
                          ? AppTheme.negative.withValues(alpha: 0.25)
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDeleted
                              ? AppTheme.negativeLight
                              : AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDeleted
                                ? AppTheme.negative.withValues(alpha: 0.2)
                                : AppTheme.border,
                          ),
                        ),
                        child: Icon(
                          isDeleted ? Icons.delete_outline_rounded : Icons.receipt_outlined,
                          size: 18,
                          color: isDeleted ? AppTheme.negative : AppTheme.darkerText,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    expense.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDeleted ? AppTheme.lightText : AppTheme.darkerText,
                                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isDeleted) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.negativeLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      expense.deletedByName != null && expense.deletedByName!.isNotEmpty
                                          ? 'DELETED (${expense.deletedByName})'
                                          : 'DELETED',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.negative,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Paid by ${expense.paidByName} • $dateStr',
                              style: const TextStyle(fontSize: 11, color: AppTheme.deactivatedText),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyUtils.formatCurrency(expense.amount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDeleted ? AppTheme.deactivatedText : AppTheme.darkerText,
                              decoration: isDeleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDeleted ? 'Cancelled' : expense.category,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: isDeleted ? AppTheme.negative : AppTheme.lightText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),

                      if (isDeleted) ...[
                        IconButton(
                          icon: const Icon(Icons.restore_rounded, size: 19, color: AppTheme.primary),
                          tooltip: 'Restore Expense',
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await _expenseRepository.restoreExpense(expense.id);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Restored "${expense.title}"'),
                                  backgroundColor: AppTheme.primary,
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, size: 20, color: AppTheme.negative),
                          tooltip: 'Permanently Delete',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.delete_forever_rounded, color: AppTheme.negative),
                                    SizedBox(width: 8),
                                    Text('Delete Permanently?'),
                                  ],
                                ),
                                content: Text(
                                  'Permanently remove "${expense.title}" from Firestore? This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      Navigator.pop(ctx);
                                      await _expenseRepository.permanentlyDeleteExpense(expense.id);
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Permanently deleted "${expense.title}"'),
                                            backgroundColor: AppTheme.primary,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.negative,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Delete Forever'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.deactivatedText),
                          tooltip: 'Soft Delete / Cancel',
                          onPressed: () => _expenseRepository.deleteExpense(expense.id, deletedByName: 'Admin'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, size: 19, color: AppTheme.negative),
                          tooltip: 'Permanently Delete',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.delete_forever_rounded, color: AppTheme.negative),
                                    SizedBox(width: 8),
                                    Text('Delete Permanently?'),
                                  ],
                                ),
                                content: Text(
                                  'Permanently delete "${expense.title}" from database completely?',
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await _expenseRepository.permanentlyDeleteExpense(expense.id);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.negative,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Delete Forever'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        );
  }

  Widget _buildActivityFilterChip(String filterKey, String label, {bool isDanger = false}) {
    final isSelected = _activityFilter == filterKey;
    final activeColor = isDanger ? AppTheme.negative : AppTheme.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activityFilter = filterKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDanger ? AppTheme.negative.withValues(alpha: 0.3) : AppTheme.border),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDanger ? AppTheme.negative : AppTheme.darkerText),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettlementsTab(List<Settlement> settlements) {
    final double totalSettled = settlements.fold(0.0, (acc, s) => acc + s.amount);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settlement History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkerText,
                      ),
                    ),
                    Text(
                      '${settlements.length} payments logged • Total: ${CurrencyUtils.formatCurrency(totalSettled)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
                    ),
                  ],
                ),
                if (settlements.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppTheme.negative),
                    label: const Text('Clear All', style: TextStyle(color: AppTheme.negative, fontSize: 12)),
                    onPressed: _showClearSettlementsConfirmation,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.negative.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (settlements.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.handshake_outlined, size: 40, color: AppTheme.deactivatedText),
                    SizedBox(height: 10),
                    Text(
                      'No settlement payments recorded yet.',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.lightText),
                    ),
                  ],
                ),
              )
            else
              ...settlements.map((s) {
                final dateStr = DateFormat('MMM d, h:mm a').format(s.date);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          size: 19,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.fromPerson} → ${s.toPerson}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkerText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 11, color: AppTheme.deactivatedText),
                            ),
                            if (s.note != null && s.note!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                s.note!,
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.lightText),
                              ),
                            ],
                          ],
                        ),
                      ),

                      Text(
                        CurrencyUtils.formatCurrency(s.amount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.positive,
                        ),
                      ),
                      const SizedBox(width: 8),

                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.negative),
                        tooltip: 'Delete Settlement',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Settlement?'),
                              content: Text(
                                'Permanently remove settlement payment of ${CurrencyUtils.formatCurrency(s.amount)} from ${s.fromPerson} to ${s.toPerson}?',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    Navigator.pop(ctx);
                                    await _expenseRepository.deleteSettlement(s.id);
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Settlement record deleted.'),
                                          backgroundColor: AppTheme.primary,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.negative,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        );
  }

  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Section: Flatmate Account & Password Management
        const Text(
          'Account & Password Recovery',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkerText,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandAccentLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, size: 20, color: AppTheme.brandAccent),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Flatmate Password',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkerText),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Admin can send password recovery links on behalf of flatmates.',
                          style: TextStyle(fontSize: 12, color: AppTheme.lightText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Flatmate\'s Registered Email',
                  hintText: 'e.g. yudhin@gmail.com',
                  hintStyle: const TextStyle(color: AppTheme.deactivatedText, fontSize: 13),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.grey, size: 18),
                  filled: true,
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (_resetStatusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isResetSuccess ? AppTheme.positiveLight : AppTheme.negativeLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isResetSuccess
                          ? AppTheme.positive.withValues(alpha: 0.2)
                          : AppTheme.negative.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isResetSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                        color: _isResetSuccess ? AppTheme.positive : AppTheme.negative,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resetStatusMessage!,
                          style: TextStyle(
                            color: _isResetSuccess ? AppTheme.positive : AppTheme.negative,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                icon: _isResettingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send Recovery Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: _isResettingPassword ? null : () => _sendPasswordResetForEmail(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Section: Reset & Clean Data
        const Text(
          'Data & Reset Tools',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkerText,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wipe Test / Mock Data',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkerText),
              ),
              const SizedBox(height: 4),
              const Text(
                'Remove all test expenses and settlements to start fresh.',
                style: TextStyle(fontSize: 12, color: AppTheme.lightText),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: AppTheme.negative),
                label: const Text('Clear All Expenses & Settlements', style: TextStyle(color: AppTheme.negative, fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: _showClearDataConfirmation,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.negative.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
