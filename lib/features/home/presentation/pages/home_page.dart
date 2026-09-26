import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flatsplit/core/theme/app_theme.dart';
import 'package:flatsplit/core/utils/currency_formatter.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';
import 'package:flatsplit/features/expenses/data/expense_repository.dart';
import 'package:flatsplit/features/home/presentation/tabs/dashboard_tab.dart';
import 'package:flatsplit/features/home/presentation/tabs/activity_tab.dart';
import 'package:flatsplit/features/home/presentation/tabs/analytics_tab.dart';
import 'package:flatsplit/features/home/presentation/tabs/flatmates_settle_tab.dart';
import 'package:flatsplit/features/home/presentation/widgets/add_expense_bottom_sheet.dart';
import 'package:flatsplit/features/home/presentation/widgets/profile_menu_bottom_sheet.dart';

class HomePage extends StatefulWidget {
  final String flatId;
  final bool? isAdmin;

  const HomePage({super.key, required this.flatId, this.isAdmin});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ExpenseRepository _expenseRepository;
  int _currentTabIndex = 0;

  late Stream<List<Flatmate>> _membersStream;
  late Stream<List<Expense>> _expensesStream;
  late Stream<List<Settlement>> _settlementsStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _flatStream;

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    setState(() {
      _membersStream = _expenseRepository.getMembersStream();
      _expensesStream = _expenseRepository.getExpensesStream();
      _settlementsStream = _expenseRepository.getSettlementsStream();
      _flatStream = FirebaseFirestore.instance.collection('flats').doc(widget.flatId).snapshots();
    });
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  void initState() {
    super.initState();
    _expenseRepository = ExpenseRepository(flatId: widget.flatId);

    // Cache streams once to prevent stream re-creation and connection state resets on every build
    _membersStream = _expenseRepository.getMembersStream();
    _expensesStream = _expenseRepository.getExpensesStream();
    _settlementsStream = _expenseRepository.getSettlementsStream();
    _flatStream = FirebaseFirestore.instance.collection('flats').doc(widget.flatId).snapshots();

    // Auto-register user as flatmate member in background (non-blocking)
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase().trim() ?? '';
    final isMaster = email == 'aadarshapandit17@gmail.com' || email == 'aadarshapandit@gmail.com';
    if (email.isNotEmpty) {
      final name = user?.displayName ??
          (email.isNotEmpty ? email.split('@').first : 'Flatmate');
      _expenseRepository.ensureMemberExists(
        name,
        email: email,
        uid: user?.uid,
        asAdmin: widget.isAdmin == true || isMaster,
      );
    }
  }

  void _showAddExpenseModal(String currentUserName, List<Flatmate> flatmates) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseBottomSheet(
        currentUserName: currentUserName,
        flatmates: flatmates,
        onExpenseAdded: (title, amount, category, paidByName, splitAmong) async {
          final messenger = ScaffoldMessenger.of(context);
          await _expenseRepository.addExpense(
            title: title,
            amount: amount,
            category: category,
            paidByName: paidByName,
            splitAmong: splitAmong,
          );

          messenger.showSnackBar(
            SnackBar(
              content: Text('Logged "$title" (${CurrencyUtils.formatCurrency(amount)}) by $paidByName'),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  void _copyFlatCode() {
    Clipboard.setData(ClipboardData(text: widget.flatId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Flat code "${widget.flatId}" copied!',
          style: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF164E3D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showProfileMenu({
    required String displayName,
    required String? email,
    required String flatName,
    required bool isUserAdmin,
    required List<Flatmate> flatmates,
  }) {
    ProfileMenuBottomSheet.show(
      context,
      displayName: displayName,
      email: email,
      flatId: widget.flatId,
      flatName: flatName,
      isUserAdmin: isUserAdmin,
      flatmates: flatmates,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _flatStream,
      builder: (context, flatSnapshot) {
        final flatData = flatSnapshot.data?.data();
        final flatName = flatData?['name'] as String? ?? 'Flat ${widget.flatId}';
        final String? flatCreatedBy = flatData?['createdBy'] as String?;
        final String? flatAdminEmail = (flatData?['adminEmail'] as String?)?.toLowerCase().trim();
        final String? userEmail = user?.email?.toLowerCase().trim();

        return StreamBuilder<List<Flatmate>>(
          initialData: const [],
          stream: _membersStream,
          builder: (context, memberSnapshot) {
            final flatmates = memberSnapshot.data ?? [];

            final String displayName = flatmates.isNotEmpty
                ? ExpenseRepository.resolveMemberForUser(user, flatmates)
                : (user?.displayName ?? user?.email?.split('@').first ?? 'User');

            return StreamBuilder<List<Expense>>(
              initialData: const [],
              stream: _expensesStream,
              builder: (context, expenseSnapshot) {
                return StreamBuilder<List<Settlement>>(
                  initialData: const [],
                  stream: _settlementsStream,
                  builder: (context, settlementSnapshot) {
                    final expenses = expenseSnapshot.data ?? [];
                    final settlements = settlementSnapshot.data ?? [];

                    // Live Calculation Engine
                    final double totalSpend = ExpenseRepository.calculateTotalSpend(expenses);
                    final double equalShare = ExpenseRepository.calculateEqualShare(expenses, personCount: flatmates.length);
                    final Map<String, double> fairShares = ExpenseRepository.calculateFairShareByPerson(expenses, flatmates);
                    final Map<String, double> netBalances = ExpenseRepository.calculateNetBalances(expenses, settlements, flatmates);

                    final double userFairShare = fairShares[displayName] ?? 0.0;
                    final double currentUserNet = netBalances[displayName] ?? 0.0;
                    final double owedToUser = currentUserNet >= 0.01 ? currentUserNet : 0.0;
                    final double userOwes = currentUserNet <= -0.01 ? -currentUserNet : 0.0;

                    // AUTHORITATIVE FLAT ADMIN CHECK:
                    // A user is admin of THIS flat ONLY if they are:
                    // 1. The flat's creator (createdBy == user.uid)
                    // 2. The flat's designated adminEmail
                    // 3. Listed in this flat's members with role == 'Admin'
                    final bool isMasterAdmin = userEmail == 'aadarshapandit17@gmail.com' ||
                        userEmail == 'aadarshapandit@gmail.com';
                    final bool isCreator = user != null && flatCreatedBy != null && user.uid == flatCreatedBy;
                    final bool isEmailAdmin = userEmail != null && flatAdminEmail != null && userEmail == flatAdminEmail;
                    final bool isMemberAdmin = flatmates.any((m) {
                      final matchUid = user != null && m.uid != null && m.uid == user.uid;
                      final matchEmail = userEmail != null && m.email != null && m.email!.toLowerCase().trim() == userEmail;
                      return (matchUid || matchEmail) && m.role.toLowerCase() == 'admin';
                    });

                    final bool isUserAdmin = widget.isAdmin == true ||
                        isMasterAdmin ||
                        isCreator ||
                        isEmailAdmin ||
                        isMemberAdmin;

                    return Scaffold(
                      backgroundColor: AppTheme.background,
                      body: SafeArea(
                        child: Column(
                          children: [
                            // Minimal App Bar with Logo & Flat Code
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  // App Logo Squircle Emblem
                                  Container(
                                    width: 42,
                                    height: 42,
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
                                  const SizedBox(width: 12),

                                  // Header Title & Flatmate Count (tap opens Profile Menu)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showProfileMenu(
                                        displayName: displayName,
                                        email: userEmail,
                                        flatName: flatName,
                                        isUserAdmin: isUserAdmin,
                                        flatmates: flatmates,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            flatName,
                                            style: const TextStyle(
                                              fontFamily: 'Fredoka',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.3,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '$displayName • ${flatmates.length} Flatmates',
                                            style: const TextStyle(
                                              fontFamily: 'Fredoka',
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Flat Code Chip (tap to copy)
                                  GestureDetector(
                                    onTap: _copyFlatCode,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF6D8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFF2B749), width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.tag_rounded, size: 13, color: Color(0xFFD97706)),
                                          const SizedBox(width: 3),
                                          Text(
                                            widget.flatId,
                                            style: const TextStyle(
                                              fontFamily: 'Fredoka',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFD97706),
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Effective Profile Menu Button
                                  GestureDetector(
                                    onTap: () => _showProfileMenu(
                                      displayName: displayName,
                                      email: userEmail,
                                      flatName: flatName,
                                      isUserAdmin: isUserAdmin,
                                      flatmates: flatmates,
                                    ),
                                    child: Tooltip(
                                      message: 'Profile & Room Menu',
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isUserAdmin
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFFE2E8F0),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              displayName.trim().isNotEmpty
                                                  ? displayName.trim().substring(0, 1).toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                fontFamily: 'Fredoka',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            // Mini role indicator badge
                                            Positioned(
                                              bottom: -2,
                                              right: -2,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: isUserAdmin
                                                      ? const Color(0xFFF59E0B)
                                                      : const Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 1.5),
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  isUserAdmin ? Icons.star_rounded : Icons.check,
                                                  size: 8,
                                                  color: Colors.white,
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
                            ),

                        // Active Tab with Pull-to-Refresh
                        Expanded(
                          child: RefreshIndicator(
                            color: AppTheme.primary,
                            backgroundColor: Colors.white,
                            displacement: 28,
                            onRefresh: _handleRefresh,
                            child: _buildCurrentTab(
                              expenses: expenses,
                              settlements: settlements,
                              flatmates: flatmates,
                              currentUserName: displayName,
                              netBalance: currentUserNet,
                              owedToYou: owedToUser,
                              youOwe: userOwes,
                              totalSpend: totalSpend,
                              equalShare: equalShare,
                              userFairShare: userFairShare,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Central Docked Floating Action Button
                  floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
                  floatingActionButton: Container(
                    height: 52,
                    width: 52,
                    margin: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF2B749),
                      border: Border.all(color: const Color(0xFFFEF9E7), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF2B749).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAddExpenseModal(displayName, flatmates),
                        customBorder: const CircleBorder(),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 28,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),

                  // Warm Butter Floating Bottom Navigation Bar
                  bottomNavigationBar: Container(
                    margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF8E2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF0DFB0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, Icons.home_rounded, Icons.home_rounded, 'Home'),
                            _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Activity'),
                            const SizedBox(width: 48),
                            _buildNavItem(2, Icons.bar_chart_rounded, Icons.bar_chart_rounded, 'Analytics'),
                            _buildNavItem(3, Icons.people_outline_rounded, Icons.people_alt_rounded, 'Settle Up'),
                          ],
                        ),
                      ),
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

  Widget _buildCurrentTab({
    required List<Expense> expenses,
    required List<Settlement> settlements,
    required List<Flatmate> flatmates,
    required String currentUserName,
    required double netBalance,
    required double owedToYou,
    required double youOwe,
    required double totalSpend,
    required double equalShare,
    required double userFairShare,
  }) {
    switch (_currentTabIndex) {
      case 0:
        return DashboardTab(
          expenses: expenses,
          settlements: settlements,
          flatmates: flatmates,
          currentUserName: currentUserName,
          netBalance: netBalance,
          owedToYou: owedToYou,
          youOwe: youOwe,
          totalSpend: totalSpend,
          equalShare: equalShare,
          userFairShare: userFairShare,
          onAddExpenseTap: () => _showAddExpenseModal(currentUserName, flatmates),
          onSettleUpTap: () => setState(() => _currentTabIndex = 3),
          onAnalyticsTap: () => setState(() => _currentTabIndex = 2),
          onActivityTap: () => setState(() => _currentTabIndex = 1),
          onDeleteExpense: (id) => _expenseRepository.deleteExpense(id, deletedByName: currentUserName),
          onUpdateSplit: (id, split) => _expenseRepository.updateExpenseSplit(id, split),
        );
      case 1:
        return ActivityTab(
          expenses: expenses,
          flatmates: flatmates,
          currentUserName: currentUserName,
          memberCount: flatmates.isNotEmpty ? flatmates.length : 1,
          onDeleteExpense: (id) => _expenseRepository.deleteExpense(id, deletedByName: currentUserName),
          onRestoreExpense: null,
          onPermanentlyDeleteExpense: null,
          onEmptyTrash: null,
          onUpdateSplit: (id, split) => _expenseRepository.updateExpenseSplit(id, split),
        );
      case 2:
        return AnalyticsTab(
          expenses: expenses,
          settlements: settlements,
          flatmates: flatmates,
        );
      case 3:
        return FlatmatesSettleTab(
          expenses: expenses,
          settlements: settlements,
          flatmates: flatmates,
          currentUserName: currentUserName,
          onRecordSettlement: (from, to, amount, note) {
            _expenseRepository.recordSettlement(
              fromPerson: from,
              toPerson: to,
              amount: amount,
              note: note,
            );
          },
          onDeleteSettlement: null,
        );
      default:
        return DashboardTab(
          expenses: expenses,
          settlements: settlements,
          flatmates: flatmates,
          currentUserName: currentUserName,
          netBalance: netBalance,
          owedToYou: owedToYou,
          youOwe: youOwe,
          totalSpend: totalSpend,
          equalShare: equalShare,
          onAddExpenseTap: () => _showAddExpenseModal(currentUserName, flatmates),
          onSettleUpTap: () => setState(() => _currentTabIndex = 3),
          onAnalyticsTap: () => setState(() => _currentTabIndex = 2),
          onActivityTap: () => setState(() => _currentTabIndex = 1),
          onDeleteExpense: (id) => _expenseRepository.deleteExpense(id, deletedByName: currentUserName),
        );
    }
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentTabIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              size: 22,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 3),
                height: 3,
                width: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2B749),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}