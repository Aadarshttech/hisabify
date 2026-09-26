import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String flatId;

  ExpenseRepository({required this.flatId});

  CollectionReference get _expensesRef => _firestore
      .collection('flats')
      .doc(flatId)
      .collection('expenses');

  CollectionReference get _settlementsRef => _firestore
      .collection('flats')
      .doc(flatId)
      .collection('settlements');

  CollectionReference get _membersRef => _firestore
      .collection('flats')
      .doc(flatId)
      .collection('members');

  static List<Flatmate> _cachedMembers = [];
  static List<Flatmate> get cachedMembers =>
      _cachedMembers.isNotEmpty ? _cachedMembers : [];

  // Resolve canonical member name for any string from Admin-configured members
  static String resolveCanonicalMemberName(String rawName, List<Flatmate> flatmates) {
    if (rawName.trim().isEmpty) return rawName;
    final clean = rawName.trim().toLowerCase();

    // 1. Exact matches first across all flatmates
    for (var f in flatmates) {
      if (f.name.trim().toLowerCase() == clean) return f.name;
      if (f.id.trim().toLowerCase() == clean) return f.name;
      if (f.email != null && f.email!.trim().toLowerCase() == clean) return f.name;
    }

    // 2. Email username prefix match (e.g. 'yudhin' matching 'yudhin@gmail.com')
    final cleanNoSpace = clean.replaceAll(' ', '');
    for (var f in flatmates) {
      if (f.email != null) {
        final emailPrefix = f.email!.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        if (emailPrefix.isNotEmpty && emailPrefix == cleanNoSpace) return f.name;
      }
    }

    // 3. Fallback substring match only if clean length is at least 3 chars
    if (clean.length >= 3) {
      for (var f in flatmates) {
        final fClean = f.name.trim().toLowerCase();
        if (fClean.length >= 3 && (fClean.contains(clean) || clean.contains(fClean))) {
          return f.name;
        }
      }
    }

    return rawName;
  }

  // Resolve the logged-in Firebase user to the canonical member created/configured by Admin
  static String resolveMemberForUser(User? user, List<Flatmate> flatmates) {
    if (user == null) return 'User';
    final userEmail = user.email?.toLowerCase().trim() ?? '';
    final userUid = user.uid;
    final userName = user.displayName?.trim() ?? '';

    // 1. UID match
    if (userUid.isNotEmpty) {
      for (var f in flatmates) {
        if (f.uid != null && f.uid == userUid) {
          return f.name;
        }
      }
    }

    // 2. Exact email match
    if (userEmail.isNotEmpty) {
      for (var f in flatmates) {
        if (f.email != null && f.email!.toLowerCase().trim() == userEmail) {
          return f.name;
        }
      }
      // Doc ID matches email
      final emailDocId = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      for (var f in flatmates) {
        if (f.id.toLowerCase() == emailDocId) {
          return f.name;
        }
      }
    }

    // 3. User display name match with flatmate name
    if (userName.isNotEmpty) {
      final cleanUserName = userName.toLowerCase();
      for (var f in flatmates) {
        if (f.name.toLowerCase().trim() == cleanUserName) {
          return f.name;
        }
      }
      for (var f in flatmates) {
        final fClean = f.name.toLowerCase().trim();
        if (fClean.contains(cleanUserName) || cleanUserName.contains(fClean)) {
          return f.name;
        }
      }
    }

    // 4. Email username part match
    if (userEmail.isNotEmpty) {
      final emailPrefix = userEmail.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      for (var f in flatmates) {
        final fClean = f.name.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        if (fClean.isNotEmpty && emailPrefix.isNotEmpty &&
            (fClean == emailPrefix || emailPrefix.contains(fClean) || fClean.contains(emailPrefix))) {
          return f.name;
        }
      }
    }

    // Fallback: If not matched in flatmates, return auth display name or email username
    if (userName.isNotEmpty) return userName;
    if (userEmail.isNotEmpty) return userEmail.split('@').first;
    return 'Flatmate';
  }

  // Real-time stream of flatmate members with multi-attribute deduplication
  Stream<List<Flatmate>> getMembersStream() {
    return _membersRef.snapshots().map((snapshot) {
      final List<Flatmate> rawList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final email = (data['email'] as String?)?.toLowerCase().trim();
        final name = (data['name'] as String?)?.trim() ?? '';
        final role = (data['role'] as String?)?.trim() ?? 'Flatmate';
        final uid = data['uid'] as String?;

        if (name.isEmpty) continue;

        rawList.add(Flatmate(
          id: doc.id,
          name: name,
          role: role,
          email: (email != null && email.isNotEmpty) ? email : null,
          uid: (uid != null && uid.isNotEmpty) ? uid : null,
        ));
      }

      // Merge duplicates: Group by canonical identity
      final List<Flatmate> mergedList = [];
      for (var raw in rawList) {
        int matchIdx = -1;
        for (int i = 0; i < mergedList.length; i++) {
          final m = mergedList[i];
          // Check UID
          if (raw.uid != null && m.uid != null && raw.uid == m.uid) {
            matchIdx = i;
            break;
          }
          // Check Email
          if (raw.email != null && m.email != null && raw.email == m.email) {
            matchIdx = i;
            break;
          }
          // Check Name (case-insensitive)
          if (raw.name.toLowerCase().trim() == m.name.toLowerCase().trim()) {
            matchIdx = i;
            break;
          }
          // Check Email prefix vs Name (exact normalized match only)
          if (raw.email != null) {
            final pref = raw.email!.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            final mClean = m.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            if (pref.isNotEmpty && mClean.isNotEmpty && pref == mClean) {
              matchIdx = i;
              break;
            }
          }
          if (m.email != null) {
            final pref = m.email!.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            final rawClean = raw.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            if (pref.isNotEmpty && rawClean.isNotEmpty && pref == rawClean) {
              matchIdx = i;
              break;
            }
          }
        }

        if (matchIdx >= 0) {
          final existing = mergedList[matchIdx];
          final existingEmail = existing.email?.toLowerCase().trim() ?? '';
          final rawEmail = raw.email?.toLowerCase().trim() ?? '';
          final isMasterAdmin = existingEmail == 'aadarshapandit17@gmail.com' ||
              existingEmail == 'aadarshapandit@gmail.com' ||
              rawEmail == 'aadarshapandit17@gmail.com' ||
              rawEmail == 'aadarshapandit@gmail.com';
          final isAnyAdmin = existing.role.toLowerCase() == 'admin' ||
              raw.role.toLowerCase() == 'admin' ||
              isMasterAdmin;
          final email = raw.email ?? existing.email;
          mergedList[matchIdx] = Flatmate(
            id: existing.id,
            name: existing.name.isNotEmpty ? existing.name : raw.name,
            role: isAnyAdmin ? 'Admin' : existing.role,
            email: email,
            uid: existing.uid ?? raw.uid,
          );
        } else {
          mergedList.add(raw);
        }
      }

      _cachedMembers = mergedList;
      return mergedList;
    }).asBroadcastStream();
  }

  // Ensure user is registered as a member with proper role (repairs admin status if deleted)
  Future<void> ensureMemberExists(
    String defaultName, {
    String? email,
    String? uid,
    bool asAdmin = false,
  }) async {
    final cleanEmail = email?.toLowerCase().trim();
    if (defaultName.trim().isEmpty && (cleanEmail == null || cleanEmail.isEmpty)) return;

    final isMasterAdmin = cleanEmail == 'aadarshapandit17@gmail.com' ||
        cleanEmail == 'aadarshapandit@gmail.com';
    final shouldBeAdmin = asAdmin || isMasterAdmin;
    final roleToSet = shouldBeAdmin ? 'Admin' : 'Flatmate';

    try {
      final snapshot = await _membersRef.get().timeout(const Duration(seconds: 4));
      DocumentSnapshot? matchedDoc;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final mEmail = (data['email'] as String?)?.toLowerCase().trim();
        final mUid = data['uid'] as String?;
        final mName = (data['name'] as String?)?.toLowerCase().trim() ?? '';
        final mDocId = doc.id.toLowerCase();

        // 1. Email match
        if (cleanEmail != null && cleanEmail.isNotEmpty && mEmail == cleanEmail) {
          matchedDoc = doc;
          break;
        }

        // 2. UID match
        if (uid != null && uid.isNotEmpty && mUid == uid) {
          matchedDoc = doc;
          break;
        }

        // 3. Document ID matches email-safe ID
        if (cleanEmail != null && mDocId == cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')) {
          matchedDoc = doc;
          break;
        }

        // 4. Name match (case-insensitive)
        final cleanDefault = defaultName.toLowerCase().trim();
        if (cleanDefault.isNotEmpty && mName == cleanDefault) {
          matchedDoc = doc;
          break;
        }

        // 5. Email prefix match with name
        if (cleanEmail != null && mName.isNotEmpty) {
          final emailUser = cleanEmail.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          final nameClean = mName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          if (emailUser.isNotEmpty && (nameClean == emailUser || emailUser.contains(nameClean) || nameClean.contains(emailUser))) {
            matchedDoc = doc;
            break;
          }
        }
      }

      if (matchedDoc != null) {
        // Member exists — attach email, uid, and repair role to Admin if needed
        final data = matchedDoc.data() as Map<String, dynamic>? ?? {};
        final currentRole = data['role'] as String? ?? 'Flatmate';
        final updateData = <String, dynamic>{};
        if (cleanEmail != null && cleanEmail.isNotEmpty && data['email'] != cleanEmail) {
          updateData['email'] = cleanEmail;
        }
        if (uid != null && uid.isNotEmpty && data['uid'] != uid) {
          updateData['uid'] = uid;
        }
        if (shouldBeAdmin && currentRole.toLowerCase() != 'admin') {
          updateData['role'] = 'Admin';
        }
        if (updateData.isNotEmpty) {
          await matchedDoc.reference.set(updateData, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
        }
      } else {
        // No existing member found (e.g. deleted), recreate with correct role!
        final docId = (cleanEmail != null && cleanEmail.isNotEmpty)
            ? cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            : defaultName.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

        final Map<String, dynamic> docData = {
          'name': defaultName.trim().isNotEmpty ? defaultName.trim() : (cleanEmail?.split('@').first ?? (shouldBeAdmin ? 'Admin' : 'Flatmate')),
          'role': roleToSet,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (cleanEmail != null && cleanEmail.isNotEmpty) {
          docData['email'] = cleanEmail;
        }
        if (uid != null && uid.isNotEmpty) {
          docData['uid'] = uid;
        }
        await _membersRef.doc(docId).set(docData).timeout(const Duration(seconds: 3));
      }

      // If user should be admin, make sure flat document reflects it
      if (shouldBeAdmin && cleanEmail != null && cleanEmail.isNotEmpty) {
        await _firestore.collection('flats').doc(flatId).set({
          'adminEmail': cleanEmail,
          if (uid != null && uid.isNotEmpty) 'createdBy': uid,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3)).catchError((_) {});

        if (uid != null && uid.isNotEmpty) {
          await _firestore.collection('users').doc(uid).set({
            'role': 'admin',
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 3)).catchError((_) {});
        }
      }
    } catch (_) {}
  }

  // Add a new flatmate member
  Future<void> addMember(String name, {String? email, String? uid, String role = 'Flatmate'}) async {
    if (name.trim().isEmpty) return;
    final cleanEmail = email?.toLowerCase().trim();

    final docId = (cleanEmail != null && cleanEmail.isNotEmpty)
        ? cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        : name.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    try {
      final Map<String, dynamic> docData = {
        'name': name.trim(),
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (cleanEmail != null && cleanEmail.isNotEmpty) {
        docData['email'] = cleanEmail;
      }
      if (uid != null) {
        docData['uid'] = uid;
      }
      await _membersRef.doc(docId).set(docData, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  // High-performance atomic batch sync for members
  Future<int> syncBatchMembers(List<Map<String, String>> members) async {
    QuerySnapshot? existing;
    try {
      existing = await _membersRef.get().timeout(const Duration(seconds: 5));
    } catch (_) {}

    final batch = _firestore.batch();
    final existingMap = <String, DocumentReference>{};
    final existingNames = <String, String>{};

    if (existing != null) {
      for (var doc in existing.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final docEmail = (data['email'] as String?)?.toLowerCase().trim();
        final docName = (data['name'] as String?)?.trim();
        if (docEmail != null && docEmail.isNotEmpty) {
          existingMap[docEmail] = doc.reference;
          if (docName != null && docName.isNotEmpty) {
            existingNames[docEmail] = docName;
          }
        }
      }
    }

    int count = 0;
    for (var member in members) {
      final defaultName = member['name']?.trim() ?? '';
      final email = member['email']?.toLowerCase().trim();
      final role = member['role'] ?? 'Flatmate';
      if (defaultName.isEmpty) continue;

      final docId = (email != null && email.isNotEmpty)
          ? email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          : defaultName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      // Clean up any legacy random-ID documents for this email or name
      if (email != null && existingMap.containsKey(email) && existingMap[email]!.id != docId) {
        batch.delete(existingMap[email]!);
      }

      // Preserve existing customized name
      final finalName = (email != null && existingNames.containsKey(email))
          ? existingNames[email]!
          : defaultName;

      final docRef = _membersRef.doc(docId);
      batch.set(
        docRef,
        {
          'name': finalName,
          if (email != null && email.isNotEmpty) 'email': email,
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      count++;
    }

    await batch.commit().timeout(const Duration(seconds: 5));
    return count;
  }

  // Remove a flatmate member and detach user account if registered
  Future<void> removeMember(String memberId, {String? uid, String? email}) async {
    // 1. Delete member document from flat
    await _membersRef.doc(memberId).delete().catchError((_) {});

    // 2. If UID is known, clear flatId & flatName from users/{uid}
    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).update({
          'flatId': FieldValue.delete(),
          'flatName': FieldValue.delete(),
        });
      } catch (_) {}
    }

    // 3. If email is known, find and clear matching user docs
    if (email != null && email.isNotEmpty) {
      final cleanEmail = email.toLowerCase().trim();
      try {
        final emailDocId = cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        await _membersRef.doc(emailDocId).delete().catchError((_) {});

        final usersQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: cleanEmail)
            .get()
            .timeout(const Duration(seconds: 4));
        for (var doc in usersQuery.docs) {
          await doc.reference.update({
            'flatId': FieldValue.delete(),
            'flatName': FieldValue.delete(),
          }).catchError((_) {});
        }
      } catch (_) {}
    }
  }

  // Update a flatmate member's name and cascade rename to expenses & settlements
  Future<void> updateMemberName(String memberId, String oldName, String newName, {String? email}) async {
    final trimmedNew = newName.trim();
    if (trimmedNew.isEmpty || trimmedNew == oldName) return;

    final cleanEmail = email?.toLowerCase().trim();
    final docId = (cleanEmail != null && cleanEmail.isNotEmpty)
        ? cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        : (memberId.isNotEmpty
            ? memberId
            : oldName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'));

    // 1. Set/Merge member document in Firestore
    await _membersRef.doc(docId).set({
      'name': trimmedNew,
      if (cleanEmail != null && cleanEmail.isNotEmpty) 'email': cleanEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also update memberId doc if different
    if (memberId.isNotEmpty && memberId != docId) {
      try {
        await _membersRef.doc(memberId).set({
          'name': trimmedNew,
          if (cleanEmail != null && cleanEmail.isNotEmpty) 'email': cleanEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    // 2. Cascade rename across expenses & settlements
    await _cascadeRename(oldName, trimmedNew);
  }

  Future<void> _cascadeRename(String oldName, String newName) async {
    try {
      WriteBatch batch = _firestore.batch();
      int batchOpsCount = 0;
      final cleanOld = oldName.trim().toLowerCase();

      final expSnapshot = await _expensesRef.get();
      for (var doc in expSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final paidByName = (data['paidByName'] as String? ?? '').trim();
        final splitAmong = List<String>.from(data['splitAmong'] as List? ?? []);

        bool needsUpdate = false;
        final updateData = <String, dynamic>{};

        if (paidByName.toLowerCase() == cleanOld) {
          updateData['paidByName'] = newName;
          updateData['paidById'] = newName.toLowerCase().replaceAll(' ', '_');
          needsUpdate = true;
        }

        if (splitAmong.any((s) => s.trim().toLowerCase() == cleanOld)) {
          final newSplit = splitAmong.map((s) => s.trim().toLowerCase() == cleanOld ? newName : s).toList();
          updateData['splitAmong'] = newSplit;
          needsUpdate = true;
        }

        if (needsUpdate) {
          batch.update(doc.reference, updateData);
          batchOpsCount++;
          if (batchOpsCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            batchOpsCount = 0;
          }
        }
      }

      final setSnapshot = await _settlementsRef.get();
      for (var doc in setSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final fromPerson = (data['fromPerson'] as String? ?? '').trim();
        final toPerson = (data['toPerson'] as String? ?? '').trim();

        bool needsUpdate = false;
        final updateData = <String, dynamic>{};

        if (fromPerson.toLowerCase() == cleanOld) {
          updateData['fromPerson'] = newName;
          needsUpdate = true;
        }
        if (toPerson.toLowerCase() == cleanOld) {
          updateData['toPerson'] = newName;
          needsUpdate = true;
        }

        if (needsUpdate) {
          batch.update(doc.reference, updateData);
          batchOpsCount++;
          if (batchOpsCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            batchOpsCount = 0;
          }
        }
      }

      if (batchOpsCount > 0) {
        await batch.commit();
      }
    } catch (_) {}
  }

  // Real-time stream of all flat expenses sorted newest first
  Stream<List<Expense>> getExpensesStream() {
    return _expensesRef
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          return Expense.fromFirestore(doc);
        } catch (_) {
          return null;
        }
      }).whereType<Expense>().toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }).asBroadcastStream();
  }

  // Real-time stream of settlements
  Stream<List<Settlement>> getSettlementsStream() {
    return _settlementsRef
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          return Settlement.fromFirestore(doc);
        } catch (_) {
          return null;
        }
      }).whereType<Settlement>().toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }).asBroadcastStream();
  }

  // Add new expense
  Future<void> addExpense({
    required String title,
    required double amount,
    required String paidByName,
    required String category,
    required List<String> splitAmong,
    String? notes,
  }) async {
    try {
      await _expensesRef.add({
        'title': title.trim(),
        'amount': amount,
        'paidById': paidByName.toLowerCase().replaceAll(' ', '_'),
        'paidByName': paidByName.trim(),
        'date': Timestamp.now(),
        'category': category,
        'splitAmong': splitAmong,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Soft-delete single expense so it remains visible in the Activity Feed audit trail
  Future<void> deleteExpense(String expenseId, {String? deletedByName}) async {
    _expensesRef.doc(expenseId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      if (deletedByName != null && deletedByName.isNotEmpty)
        'deletedByName': deletedByName,
    }).catchError((_) {});
  }

  // Restore a previously deleted expense back into active roomie balances
  Future<void> restoreExpense(String expenseId) async {
    _expensesRef.doc(expenseId).update({
      'isDeleted': false,
      'deletedAt': FieldValue.delete(),
      'deletedByName': FieldValue.delete(),
    }).catchError((_) {});
  }

  // Update split members for an existing expense
  Future<void> updateExpenseSplit(String expenseId, List<String> newSplitAmong) async {
    try {
      await _expensesRef.doc(expenseId).update({
        'splitAmong': newSplitAmong,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Permanently purge an expense document from Firestore (Admin tool)
  Future<void> permanentlyDeleteExpense(String expenseId) async {
    _expensesRef.doc(expenseId).delete().catchError((_) {});
  }

  // Record a settlement payment
  Future<void> recordSettlement({
    required String fromPerson,
    required String toPerson,
    required double amount,
    String? note,
  }) async {
    try {
      await _settlementsRef.add({
        'fromPerson': fromPerson.trim(),
        'toPerson': toPerson.trim(),
        'amount': amount,
        'date': Timestamp.now(),
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Permanently delete a single settlement
  Future<void> deleteSettlement(String settlementId) async {
    _settlementsRef.doc(settlementId).delete().catchError((_) {});
  }

  Future<void> _batchedDelete(List<DocumentSnapshot> docs) async {
    for (int i = 0; i < docs.length; i += 400) {
      final chunk = docs.skip(i).take(400);
      final batch = _firestore.batch();
      for (var doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit().catchError((_) {});
    }
  }

  // Clear all settlements only (Settlement History)
  Future<void> clearAllSettlements() async {
    final setDocs = await _settlementsRef.get();
    await _batchedDelete(setDocs.docs);
  }

  // Permanently purge all soft-deleted expenses from Firestore (Empty Trash)
  Future<int> permanentlyDeleteAllDeletedExpenses() async {
    final deletedDocs = await _expensesRef.where('isDeleted', isEqualTo: true).get();
    await _batchedDelete(deletedDocs.docs);
    return deletedDocs.docs.length;
  }

  // Admin Tool: Clear all test expenses and settlements
  Future<void> clearAllExpensesAndSettlements() async {
    final expDocs = await _expensesRef.get();
    await _batchedDelete(expDocs.docs);

    final setDocs = await _settlementsRef.get();
    await _batchedDelete(setDocs.docs);
  }

  // =================== CALCULATION ENGINE ===================

  // 1. Total Spend (only active, non-deleted expenses)
  static double calculateTotalSpend(List<Expense> expenses) {
    return expenses
        .where((e) => !e.isDeleted)
        .fold(0.0, (total, item) => total + item.amount);
  }

  // 2. Per-person equal share (statistical average across all members)
  static double calculateEqualShare(List<Expense> expenses, {int personCount = 1}) {
    if (personCount <= 0 || expenses.isEmpty) return 0.0;
    return calculateTotalSpend(expenses) / personCount;
  }

  // 2b. Exact fair share per person based on custom item splits (who was actually included)
  static Map<String, double> calculateFairShareByPerson(
    List<Expense> expenses,
    List<Flatmate> flatmates,
  ) {
    final Map<String, double> shareMap = {
      for (var f in flatmates) f.name: 0.0,
    };

    final activeExpenses = expenses.where((e) => !e.isDeleted);
    for (var expense in activeExpenses) {
      final splitList = expense.splitAmong.isNotEmpty
          ? expense.splitAmong.map((p) => resolveCanonicalMemberName(p, flatmates)).toList()
          : flatmates.map((f) => f.name).toList();
      final splitCount = splitList.isNotEmpty ? splitList.length : 1;

      final int totalCents = (expense.amount * 100).round();
      final int baseShareCents = totalCents ~/ splitCount;
      final int remainderCents = totalCents % splitCount;

      for (int i = 0; i < splitList.length; i++) {
        final person = splitList[i];
        final int shareCents = baseShareCents + (i < remainderCents ? 1 : 0);
        final double share = shareCents / 100.0;
        shareMap[person] = (shareMap[person] ?? 0.0) + share;
      }
    }

    // Clean up floating point
    shareMap.updateAll((k, v) => (v * 100).round() / 100.0);
    return shareMap;
  }

  // 3. Total amount paid by each person (only active, non-deleted expenses)
  static Map<String, double> calculateTotalPaidByPerson(
      List<Expense> expenses, List<Flatmate> flatmates) {
    final Map<String, double> paidMap = {
      for (var f in flatmates) f.name: 0.0,
    };

    for (var expense in expenses.where((e) => !e.isDeleted)) {
      final canonicalPayer = resolveCanonicalMemberName(expense.paidByName, flatmates);
      final current = paidMap[canonicalPayer] ?? 0.0;
      paidMap[canonicalPayer] = current + expense.amount;
    }

    return paidMap;
  }

  // 3b. Effective net amount paid out-of-pocket by each person factoring in settlements
  // Formula: Store Bills Fronted + Settlements Sent - Settlements Received
  static Map<String, double> calculateEffectivePaidByPerson(
    List<Expense> expenses,
    List<Settlement> settlements,
    List<Flatmate> flatmates,
  ) {
    final Map<String, double> paidMap = calculateTotalPaidByPerson(expenses, flatmates);
    final activeSettlements = settlements.where((s) => !s.isDeleted);

    for (var s in activeSettlements) {
      final canonicalFrom = resolveCanonicalMemberName(s.fromPerson, flatmates);
      final canonicalTo = resolveCanonicalMemberName(s.toPerson, flatmates);
      paidMap[canonicalFrom] = (paidMap[canonicalFrom] ?? 0.0) + s.amount;
      paidMap[canonicalTo] = (paidMap[canonicalTo] ?? 0.0) - s.amount;
    }

    // Round to 2 decimals to prevent floating point artifacts
    paidMap.updateAll((k, v) => (v * 100).round() / 100.0);
    return paidMap;
  }

  // 4. Net balance for each person (Paid - Fair Share + Settlements; excludes deleted items)
  static Map<String, double> calculateNetBalances(
    List<Expense> expenses,
    List<Settlement> settlements,
    List<Flatmate> flatmates,
  ) {
    final Map<String, double> netBalances = {
      for (var f in flatmates) f.name: 0.0,
    };

    final activeExpenses = expenses.where((e) => !e.isDeleted);
    final activeSettlements = settlements.where((s) => !s.isDeleted);

    // Calculate spend and split with exact cent allocation
    for (var expense in activeExpenses) {
      final canonicalPayer = resolveCanonicalMemberName(expense.paidByName, flatmates);
      final splitList = expense.splitAmong.isNotEmpty
          ? expense.splitAmong.map((p) => resolveCanonicalMemberName(p, flatmates)).toList()
          : flatmates.map((f) => f.name).toList();
      final splitCount = splitList.isNotEmpty ? splitList.length : 1;

      // Credit payer with the full amount
      netBalances[canonicalPayer] =
          (netBalances[canonicalPayer] ?? 0.0) + expense.amount;

      // Distribute cents so sum(shares) == expense.amount exactly (no leftover 1-cent discrepancy)
      final int totalCents = (expense.amount * 100).round();
      final int baseShareCents = totalCents ~/ splitCount;
      final int remainderCents = totalCents % splitCount;

      for (int i = 0; i < splitList.length; i++) {
        final person = splitList[i];
        final int shareCents = baseShareCents + (i < remainderCents ? 1 : 0);
        final double share = shareCents / 100.0;
        netBalances[person] = (netBalances[person] ?? 0.0) - share;
      }
    }

    // Adjust for settlements
    for (var s in activeSettlements) {
      final canonicalFrom = resolveCanonicalMemberName(s.fromPerson, flatmates);
      final canonicalTo = resolveCanonicalMemberName(s.toPerson, flatmates);
      netBalances[canonicalFrom] = (netBalances[canonicalFrom] ?? 0.0) + s.amount;
      netBalances[canonicalTo] = (netBalances[canonicalTo] ?? 0.0) - s.amount;
    }

    // Clean up floating-point noise and eliminate sub-cent leftovers when settled
    netBalances.updateAll((key, val) {
      final inCents = (val * 100).round() / 100.0;
      if (inCents.abs() < 0.02) return 0.0;
      return inCents;
    });

    return netBalances;
  }

  // 5. Debt Simplification Matrix: "Who owes whom how much"
  static List<DebtTransfer> calculateDebtTransfers(Map<String, double> netBalances) {
    final List<DebtTransfer> transfers = [];

    final List<MapEntry<String, double>> creditors = [];
    final List<MapEntry<String, double>> debtors = [];

    netBalances.forEach((person, balance) {
      final rounded = (balance * 100).round() / 100;
      if (rounded > 0.01) {
        creditors.add(MapEntry(person, rounded));
      } else if (rounded < -0.01) {
        debtors.add(MapEntry(person, -rounded));
      }
    });

    int cIndex = 0;
    int dIndex = 0;

    while (cIndex < creditors.length && dIndex < debtors.length) {
      final creditor = creditors[cIndex];
      final debtor = debtors[dIndex];

      final double settleAmount =
          creditor.value < debtor.value ? creditor.value : debtor.value;

      if (settleAmount > 0.01) {
        transfers.add(
          DebtTransfer(
            fromPerson: debtor.key,
            toPerson: creditor.key,
            amount: settleAmount,
          ),
        );
      }

      creditors[cIndex] = MapEntry(creditor.key, creditor.value - settleAmount);
      debtors[dIndex] = MapEntry(debtor.key, debtor.value - settleAmount);

      if (creditors[cIndex].value <= 0.01) cIndex++;
      if (debtors[dIndex].value <= 0.01) dIndex++;
    }

    return transfers;
  }

  // 6. Category breakdown (only active, non-deleted expenses)
  static Map<String, double> calculateCategoryBreakdown(List<Expense> expenses) {
    final Map<String, double> categories = {};
    for (var expense in expenses.where((e) => !e.isDeleted)) {
      final current = categories[expense.category] ?? 0.0;
      categories[expense.category] = current + expense.amount;
    }
    return categories;
  }
}
