import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flatsplit/features/expenses/data/expense_model.dart';

class UserFlatDiscovery {
  final String? flatId;
  final String role; // 'admin' or 'user'
  final String? flatName;

  const UserFlatDiscovery({this.flatId, required this.role, this.flatName});
}

class FlatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _keyFlatId = 'cached_flat_id';
  static const String _keyRole = 'cached_user_role';
  static const String _keyFlatName = 'cached_flat_name';

  /// Cache flat ID, role, and flat name locally for instant zero-latency startup
  Future<void> saveLocalProfile({required String flatId, required String role, String? flatName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFlatId, flatId.trim());
      await prefs.setString(_keyRole, role.trim());
      if (flatName != null && flatName.isNotEmpty) {
        await prefs.setString(_keyFlatName, flatName.trim());
      }
    } catch (_) {}
  }

  /// Retrieve cached local profile
  Future<Map<String, String?>> getLocalProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'flatId': prefs.getString(_keyFlatId),
        'role': prefs.getString(_keyRole),
        'flatName': prefs.getString(_keyFlatName),
      };
    } catch (_) {
      return {'flatId': null, 'role': null, 'flatName': null};
    }
  }

  /// Clear cached local profile on sign-out
  Future<void> clearLocalProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFlatId);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyFlatName);
    } catch (_) {}
  }

  /// Save only role locally before auth state changes
  Future<void> saveLocalRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRole, role.trim());
    } catch (_) {}
  }

  Future<UserFlatDiscovery> discoverFlatAndRole({
    required String uid,
    String? email,
    String? fallbackRole,
    String? currentFlatId,
  }) async {
    final cleanEmail = (email ?? '').toLowerCase().trim();
    String detectedRole = fallbackRole ?? 'user';

    // Helper to accurately resolve role in a specific flat
    Future<UserFlatDiscovery?> checkRoleInFlat(String targetFlatId) async {
      try {
        final flatDoc = await _firestore.collection('flats').doc(targetFlatId).get().timeout(const Duration(seconds: 6));
        if (!flatDoc.exists) return null;

        final createdBy = flatDoc.data()?['createdBy'] as String?;
        final adminEmail = flatDoc.data()?['adminEmail'] as String?;
        final flatName = flatDoc.data()?['name'] as String?;

        final bool isMasterAdmin = cleanEmail == 'aadarshapandit17@gmail.com' || cleanEmail == 'aadarshapandit@gmail.com';
        if (isMasterAdmin || createdBy == uid || (adminEmail != null && cleanEmail.isNotEmpty && adminEmail.toLowerCase() == cleanEmail)) {
          return UserFlatDiscovery(flatId: targetFlatId, role: 'admin', flatName: flatName);
        }

        // Check members subcollection
        if (cleanEmail.isNotEmpty || uid.isNotEmpty) {
          final memberDocId = cleanEmail.isNotEmpty
              ? cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
              : uid;

          DocumentSnapshot<Map<String, dynamic>>? mDoc;
          try {
            final doc = await _firestore.collection('flats').doc(targetFlatId).collection('members').doc(memberDocId).get();
            if (doc.exists) mDoc = doc;
          } catch (_) {}

          if (mDoc == null && cleanEmail.isNotEmpty) {
            try {
              final q = await _firestore.collection('flats').doc(targetFlatId).collection('members').where('email', isEqualTo: cleanEmail).limit(1).get();
              if (q.docs.isNotEmpty) mDoc = q.docs.first;
            } catch (_) {}
          }

          if (mDoc != null && mDoc.exists) {
            final mRole = mDoc.data()?['role'] as String? ?? 'Flatmate';
            final isAdmin = mRole.toLowerCase() == 'admin';
            return UserFlatDiscovery(
              flatId: targetFlatId,
              role: isAdmin ? 'admin' : 'user',
              flatName: flatName,
            );
          }
        }

        return UserFlatDiscovery(flatId: targetFlatId, role: 'user', flatName: flatName);
      } catch (_) {
        return null;
      }
    }

    // 0. Check their current flat role if currentFlatId is provided
    if (currentFlatId != null && currentFlatId.isNotEmpty) {
      final currentRes = await checkRoleInFlat(currentFlatId);
      if (currentRes != null) return currentRes;
    }

    // 1. Check user's direct profile doc first (fastest and most direct)
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final docRole = data['role'] as String?;
        if (docRole != null && docRole.isNotEmpty) {
          detectedRole = docRole;
        }
        final docFlatId = data['flatId'] as String?;
        if (docFlatId != null && docFlatId.isNotEmpty) {
          final flatRes = await checkRoleInFlat(docFlatId);
          if (flatRes != null) return flatRes;
        }
      }
    } catch (_) {}

    // 2. Check if user is the creator of any flat -> Guaranteed Admin!
    try {
      final adminFlats = await _firestore
          .collection('flats')
          .where('createdBy', isEqualTo: uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));
      if (adminFlats.docs.isNotEmpty) {
        final doc = adminFlats.docs.first;
        return UserFlatDiscovery(
          flatId: doc.id,
          role: 'admin',
          flatName: doc.data()['name'] as String?,
        );
      }
    } catch (_) {}

    // 3. Check if user email is registered as adminEmail on any flat -> Guaranteed Admin!
    if (cleanEmail.isNotEmpty) {
      try {
        final emailFlats = await _firestore
            .collection('flats')
            .where('adminEmail', isEqualTo: cleanEmail)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
        if (emailFlats.docs.isNotEmpty) {
          final doc = emailFlats.docs.first;
          return UserFlatDiscovery(
            flatId: doc.id,
            role: 'admin',
            flatName: doc.data()['name'] as String?,
          );
        }
      } catch (_) {}
    }

    // 4. Check if user is a member of any flat
    if (cleanEmail.isNotEmpty) {
      try {
        final memberDocs = await _firestore
            .collectionGroup('members')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
        if (memberDocs.docs.isNotEmpty) {
          final memberDoc = memberDocs.docs.first;
          final parentFlat = memberDoc.reference.parent.parent;
          final memberRole = memberDoc.data()['role'] as String? ?? 'Flatmate';
          final isAdmin = memberRole.toLowerCase() == 'admin';
          String? parentName;
          if (parentFlat != null) {
            try {
              final pDoc = await parentFlat.get().timeout(const Duration(seconds: 5));
              parentName = pDoc.data()?['name'] as String?;
            } catch (_) {}
          }
          return UserFlatDiscovery(
            flatId: parentFlat?.id,
            role: isAdmin ? 'admin' : 'user',
            flatName: parentName,
          );
        }
      } catch (_) {}
    }

    return UserFlatDiscovery(flatId: null, role: detectedRole);
  }

  /// Automatically discover if this user has an existing flat in Firestore
  Future<String?> findFlatForUser({required String uid, String? email}) async {
    final discovery = await discoverFlatAndRole(uid: uid, email: email);
    return discovery.flatId;
  }

  // ──────────────────────────────────────────────
  // Flat Code Generation
  // ──────────────────────────────────────────────

  /// Generate a unique 6-character alphanumeric flat code (e.g., "7X3KMP")
  /// 30 chars ^ 6 = 729 million combinations — random collision probability is negligible.
  String generateFlatCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I confusion
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ──────────────────────────────────────────────
  // Create Flat (Admin flow)
  // ──────────────────────────────────────────────

  /// Admin creates a new flat. Returns the generated flat code.
  Future<String> createFlat({
    required String flatName,
    required String adminUid,
    required String adminEmail,
    required String adminDisplayName,
  }) async {
    final code = generateFlatCode();

    final batch = _firestore.batch();

    // 1. Create the flat document
    batch.set(_firestore.collection('flats').doc(code), {
      'name': flatName.trim(),
      'createdBy': adminUid,
      'adminEmail': adminEmail.toLowerCase().trim(),
      'adminName': adminDisplayName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Add admin as first member of the flat
    final adminDocId = adminEmail.isNotEmpty
        ? adminEmail.toLowerCase().trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        : adminUid;
    batch.set(
      _firestore.collection('flats').doc(code).collection('members').doc(adminDocId),
      {
        'name': adminDisplayName.trim(),
        'email': adminEmail.toLowerCase().trim(),
        'uid': adminUid,
        'role': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    // 3. Write/update the user profile
    batch.set(
      _firestore.collection('users').doc(adminUid),
      {
        'email': adminEmail.toLowerCase().trim(),
        'displayName': adminDisplayName.trim(),
        'role': 'admin',
        'flatId': code,
        'flatName': flatName.trim(),
        'joinedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit().timeout(const Duration(seconds: 15), onTimeout: () {
      throw Exception('Network timeout. Please check your connection and try again.');
    });
    await saveLocalProfile(flatId: code, role: 'admin', flatName: flatName.trim());
    return code;
  }

  // ──────────────────────────────────────────────
  // Join Flat (User flow)
  // ──────────────────────────────────────────────

  /// Check if a flat exists
  Future<bool> flatExists(String flatId) async {
    final doc = await _firestore.collection('flats').doc(flatId.toUpperCase().trim()).get();
    return doc.exists;
  }

  /// Get flat name by ID
  Future<String?> getFlatName(String flatId) async {
    final doc = await _firestore.collection('flats').doc(flatId.toUpperCase().trim()).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    return data['name'] as String?;
  }

  /// User joins an existing flat by code. Returns the flat name.
  Future<String> joinFlat({
    required String flatId,
    required String userUid,
    required String userEmail,
    required String displayName,
  }) async {
    final code = flatId.toUpperCase().trim();

    // Validate flat exists
    DocumentSnapshot<Map<String, dynamic>> flatDoc;
    try {
      flatDoc = await _firestore.collection('flats').doc(code).get().timeout(const Duration(seconds: 8));
    } catch (e) {
      throw Exception('Could not connect to verify flat code. Please try again.');
    }

    if (!flatDoc.exists) {
      throw Exception('Flat code "$code" not found. Please check the code and try again.');
    }

    final flatName = flatDoc.data()?['name'] as String? ?? code;
    
    // Check if the user is already the admin/creator of this flat
    final createdBy = flatDoc.data()?['createdBy'] as String?;
    final adminEmail = flatDoc.data()?['adminEmail'] as String?;
    final bool isOwnFlat = (createdBy == userUid) || 
                           (adminEmail != null && adminEmail.toLowerCase() == userEmail.toLowerCase().trim());

    final batch = _firestore.batch();

    if (!isOwnFlat) {
      // 1. Check if a member document already exists in this flat with this email, name, or uid
      DocumentReference? targetMemberRef;
      final cleanEmail = userEmail.toLowerCase().trim();
      final cleanName = displayName.trim().toLowerCase();

      try {
        final existingMembers = await _firestore
            .collection('flats')
            .doc(code)
            .collection('members')
            .get()
            .timeout(const Duration(seconds: 5));

        for (var doc in existingMembers.docs) {
          final data = doc.data();
          final mEmail = (data['email'] as String?)?.toLowerCase().trim();
          final mName = (data['name'] as String?)?.toLowerCase().trim();
          final mUid = data['uid'] as String?;

          if ((cleanEmail.isNotEmpty && mEmail == cleanEmail) ||
              (mUid != null && mUid == userUid) ||
              (cleanName.isNotEmpty && mName == cleanName)) {
            targetMemberRef = doc.reference;
            break;
          }
        }
      } catch (_) {}

      final memberDocId = cleanEmail.isNotEmpty 
          ? cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          : userUid;
      targetMemberRef ??= _firestore.collection('flats').doc(code).collection('members').doc(memberDocId);

      batch.set(
        targetMemberRef,
        {
          'name': displayName.trim(),
          'email': cleanEmail,
          'uid': userUid,
          'role': 'Flatmate',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    // 2. Write/update the user profile (set active flatId to this code)
    batch.set(
      _firestore.collection('users').doc(userUid),
      {
        'email': userEmail.toLowerCase().trim(),
        'displayName': displayName.trim(),
        'role': isOwnFlat ? 'admin' : 'user', // Re-joining own flat preserves admin
        'flatId': code,
        'flatName': flatName,
        'joinedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit().timeout(const Duration(seconds: 15), onTimeout: () {
      throw Exception('Network timeout. Please check your connection and try again.');
    });

    await saveLocalProfile(
      flatId: code,
      role: isOwnFlat ? 'admin' : 'user',
      flatName: flatName,
    );
    return flatName;
  }

  // ──────────────────────────────────────────────
  // User Profile
  // ──────────────────────────────────────────────

  /// Get user profile from Firestore (role + flatId)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Save the user's chosen role (admin/user) to Firestore
  Future<void> saveUserRole({
    required String uid,
    required String role,
    required String email,
    String? displayName,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email.toLowerCase().trim(),
      'role': role,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 3)).catchError((_) {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRole, role.trim());
    } catch (_) {}
  }

  /// Leave current flat (clears flatId & flatName from user profile)
  Future<void> leaveFlat({
    required String uid,
    String? flatId,
    String? email,
    String? memberName,
  }) async {
    // 1. Remove member doc from the flat so auto-discovery does not re-link them
    if (flatId != null && flatId.isNotEmpty) {
      try {
        final membersCol = _firestore.collection('flats').doc(flatId.trim()).collection('members');
        // Delete by uid
        final uidDocs = await membersCol.where('uid', isEqualTo: uid).get();
        for (var doc in uidDocs.docs) {
          await doc.reference.delete();
        }
        // Delete by email
        if (email != null && email.isNotEmpty) {
          final cleanEmail = email.toLowerCase().trim();
          final emailDocs = await membersCol.where('email', isEqualTo: cleanEmail).get();
          for (var doc in emailDocs.docs) {
            await doc.reference.delete();
          }
          final emailDocId = cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          try {
            await membersCol.doc(emailDocId).delete();
          } catch (_) {}
        }
        // Delete by name
        if (memberName != null && memberName.isNotEmpty) {
          final nameDocs = await membersCol.where('name', isEqualTo: memberName.trim()).get();
          for (var doc in nameDocs.docs) {
            await doc.reference.delete();
          }
        }
      } catch (_) {}
    }

    // 2. Clear user document
    try {
      await _firestore.collection('users').doc(uid).update({
        'flatId': FieldValue.delete(),
        'flatName': FieldValue.delete(),
      });
    } catch (_) {}

    // 3. Clear local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFlatId);
      await prefs.remove(_keyFlatName);
    } catch (_) {}
  }

  /// Transfer admin role to another flatmate and leave the flat
  Future<void> transferAdminAndLeaveFlat({
    required String flatId,
    required String oldAdminUid,
    required Flatmate newAdmin,
  }) async {
    final batch = _firestore.batch();
    final flatRef = _firestore.collection('flats').doc(flatId.trim());

    // 1. Update the flat doc's designated admin
    final Map<String, dynamic> flatUpdates = {
      'adminName': newAdmin.name.trim(),
    };
    if (newAdmin.uid != null && newAdmin.uid!.isNotEmpty) {
      flatUpdates['createdBy'] = newAdmin.uid;
    }
    if (newAdmin.email != null && newAdmin.email!.isNotEmpty) {
      flatUpdates['adminEmail'] = newAdmin.email!.toLowerCase().trim();
    }
    batch.set(flatRef, flatUpdates, SetOptions(merge: true));

    // 2. Promote the new admin in the members subcollection
    final memberDocId = newAdmin.id.isNotEmpty
        ? newAdmin.id
        : (newAdmin.email != null && newAdmin.email!.isNotEmpty
            ? newAdmin.email!.toLowerCase().trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            : (newAdmin.uid ?? newAdmin.name.replaceAll(' ', '_')));
    final newMemberRef = flatRef.collection('members').doc(memberDocId);
    batch.set(newMemberRef, {
      'role': 'Admin',
      'name': newAdmin.name.trim(),
      if (newAdmin.email != null && newAdmin.email!.isNotEmpty)
        'email': newAdmin.email!.toLowerCase().trim(),
      if (newAdmin.uid != null && newAdmin.uid!.isNotEmpty)
        'uid': newAdmin.uid,
    }, SetOptions(merge: true));

    // 3. If new admin has a uid, update their users/{uid} document role to 'admin'
    if (newAdmin.uid != null && newAdmin.uid!.isNotEmpty) {
      final newUserRef = _firestore.collection('users').doc(newAdmin.uid);
      batch.set(newUserRef, {
        'role': 'admin',
        'flatId': flatId.trim(),
      }, SetOptions(merge: true));
    }

    // 4. Detach old admin from users/{oldAdminUid}
    final oldUserRef = _firestore.collection('users').doc(oldAdminUid);
    batch.set(oldUserRef, {
      'flatId': FieldValue.delete(),
      'flatName': FieldValue.delete(),
    }, SetOptions(merge: true));

    // Also delete old admin member doc from flats/{flatId}/members
    try {
      final oldMembers = await flatRef.collection('members').where('uid', isEqualTo: oldAdminUid).get();
      for (var doc in oldMembers.docs) {
        batch.delete(doc.reference);
      }
    } catch (_) {}

    await batch.commit().timeout(const Duration(seconds: 12));

    // Clear old admin local preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFlatId);
      await prefs.remove(_keyFlatName);
    } catch (_) {}
  }

  /// Stream the user profile for real-time updates
  Stream<Map<String, dynamic>?> getUserProfileStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }
}
