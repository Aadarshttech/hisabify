import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single room entry stored in the user's `rooms` array.
class UserRoom {
  final String flatId;
  final String flatName;
  final String role; // 'admin' or 'user'
  final DateTime? joinedAt;

  const UserRoom({
    required this.flatId,
    required this.flatName,
    required this.role,
    this.joinedAt,
  });

  factory UserRoom.fromMap(Map<String, dynamic> map) {
    DateTime? joined;
    if (map['joinedAt'] is Timestamp) {
      joined = (map['joinedAt'] as Timestamp).toDate();
    }
    return UserRoom(
      flatId: (map['flatId'] as String?) ?? '',
      flatName: (map['flatName'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'user',
      joinedAt: joined,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flatId': flatId,
      'flatName': flatName,
      'role': role,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoom && runtimeType == other.runtimeType && flatId == other.flatId;

  @override
  int get hashCode => flatId.hashCode;
}

class RoomRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _keyFlatId = 'cached_flat_id';
  static const String _keyRole = 'cached_user_role';
  static const String _keyFlatName = 'cached_flat_name';

  // ──────────────────────────────────────────────
  // Fetch Rooms
  // ──────────────────────────────────────────────

  /// Get all rooms a user belongs to (one-shot).
  /// Falls back to the legacy single flatId if no rooms array exists.
  Future<List<UserRoom>> getUserRooms(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final roomsList = data['rooms'] as List<dynamic>?;

      if (roomsList != null && roomsList.isNotEmpty) {
        return roomsList
            .map((r) => UserRoom.fromMap(Map<String, dynamic>.from(r as Map)))
            .where((r) => r.flatId.isNotEmpty)
            .toList();
      }

      // Backward compat: user has legacy single flatId but no rooms array
      final legacyFlatId = data['flatId'] as String?;
      final legacyFlatName = data['flatName'] as String?;
      final legacyRole = data['role'] as String?;

      if (legacyFlatId != null && legacyFlatId.isNotEmpty) {
        final room = UserRoom(
          flatId: legacyFlatId,
          flatName: legacyFlatName ?? 'Room $legacyFlatId',
          role: legacyRole ?? 'user',
        );
        // Self-heal: write rooms array to Firestore so next time it's there
        _firestore.collection('users').doc(uid).set({
          'rooms': [room.toMap()],
        }, SetOptions(merge: true)).catchError((_) {});
        return [room];
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  /// Stream of all rooms the user belongs to (real-time).
  Stream<List<UserRoom>> getUserRoomsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <UserRoom>[];

      final data = doc.data() ?? {};
      final roomsList = data['rooms'] as List<dynamic>?;

      if (roomsList != null && roomsList.isNotEmpty) {
        return roomsList
            .map((r) => UserRoom.fromMap(Map<String, dynamic>.from(r as Map)))
            .where((r) => r.flatId.isNotEmpty)
            .toList();
      }

      // Backward compat fallback
      final legacyFlatId = data['flatId'] as String?;
      final legacyFlatName = data['flatName'] as String?;
      final legacyRole = data['role'] as String?;

      if (legacyFlatId != null && legacyFlatId.isNotEmpty) {
        return [
          UserRoom(
            flatId: legacyFlatId,
            flatName: legacyFlatName ?? 'Room $legacyFlatId',
            role: legacyRole ?? 'user',
          ),
        ];
      }

      return <UserRoom>[];
    });
  }

  // ──────────────────────────────────────────────
  // Switch Active Room
  // ──────────────────────────────────────────────

  /// Set a room as the user's currently active room.
  /// Updates both Firestore (legacy fields) and local cache.
  Future<void> switchRoom({
    required String uid,
    required String flatId,
    required String flatName,
    required String role,
  }) async {
    // 1. Update Firestore legacy active room fields
    try {
      await _firestore.collection('users').doc(uid).set({
        'flatId': flatId,
        'flatName': flatName,
        'role': role,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
    } catch (_) {}

    // 2. Update local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFlatId, flatId.trim());
      await prefs.setString(_keyRole, role.trim());
      await prefs.setString(_keyFlatName, flatName.trim());
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  // Add / Remove Room from User Profile
  // ──────────────────────────────────────────────

  /// Add a room to the user's rooms array. Skips if already present.
  Future<void> addRoomToUser({
    required String uid,
    required String flatId,
    required String flatName,
    required String role,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 5));

      List<Map<String, dynamic>> rooms = [];
      if (doc.exists) {
        final data = doc.data() ?? {};
        final existing = data['rooms'] as List<dynamic>?;
        if (existing != null) {
          rooms = existing
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        }
      }

      // Check if room already exists in the array
      final alreadyExists = rooms.any((r) => r['flatId'] == flatId);
      if (alreadyExists) {
        // Update role/name in case they changed
        rooms = rooms.map((r) {
          if (r['flatId'] == flatId) {
            return {
              ...r,
              'flatName': flatName,
              'role': role,
            };
          }
          return r;
        }).toList();
      } else {
        rooms.add(UserRoom(
          flatId: flatId,
          flatName: flatName,
          role: role,
        ).toMap());
      }

      await docRef.set({
        'rooms': rooms,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Remove a room from the user's rooms array.
  Future<void> removeRoomFromUser({
    required String uid,
    required String flatId,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 5));

      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final existing = data['rooms'] as List<dynamic>?;
      if (existing == null || existing.isEmpty) return;

      final rooms = existing
          .map((r) => Map<String, dynamic>.from(r as Map))
          .where((r) => r['flatId'] != flatId)
          .toList();

      await docRef.set({
        'rooms': rooms,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Get the room name for a given flatId (from the flat document).
  Future<String> getRoomName(String flatId) async {
    try {
      final doc = await _firestore
          .collection('flats')
          .doc(flatId.toUpperCase().trim())
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists) {
        return (doc.data()?['name'] as String?) ?? 'Room $flatId';
      }
    } catch (_) {}
    return 'Room $flatId';
  }

  /// Get member count for a flat (for room picker display).
  Future<int> getRoomMemberCount(String flatId) async {
    try {
      final snapshot = await _firestore
          .collection('flats')
          .doc(flatId.toUpperCase().trim())
          .collection('members')
          .get()
          .timeout(const Duration(seconds: 5));
      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }
}
