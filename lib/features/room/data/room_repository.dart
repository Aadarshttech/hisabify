import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single room entry stored in the user's `rooms` array.
class UserRoom {
  final String flatId;
  final String flatName;
  final String role; // 'admin' or 'user'
  final String roomType;
  final String icon;
  final DateTime? joinedAt;

  const UserRoom({
    required this.flatId,
    required this.flatName,
    required this.role,
    this.roomType = 'flat',
    this.icon = '🏠',
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
      roomType: (map['roomType'] as String?) ?? 'flat',
      icon: (map['icon'] as String?) ?? '🏠',
      joinedAt: joined,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flatId': flatId,
      'flatName': flatName,
      'role': role,
      'roomType': roomType,
      'icon': icon,
      // Firestore server timestamps cannot be used inside array elements.
      // Use a concrete timestamp so this map is safe to persist in `rooms`.
      'joinedAt': Timestamp.fromDate(joinedAt ?? DateTime.now()),
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

  List<UserRoom> _roomsFromData(Map<String, dynamic> data) {
    final byFlatId = <String, UserRoom>{};
    final rawRooms = data['rooms'];
    if (rawRooms is List) {
      for (final rawRoom in rawRooms) {
        if (rawRoom is! Map) continue;
        final room = UserRoom.fromMap(Map<String, dynamic>.from(rawRoom));
        final flatId = room.flatId.toUpperCase().trim();
        if (flatId.isEmpty) continue;
        // Keep one canonical entry per room. The last entry is the freshest
        // when repairing documents created by earlier app versions.
        byFlatId[flatId] = UserRoom(
          flatId: flatId,
          flatName: room.flatName.trim().isEmpty ? 'Room $flatId' : room.flatName.trim(),
          role: room.role == 'admin' ? 'admin' : 'user',
          roomType: room.roomType,
          icon: room.icon,
          joinedAt: room.joinedAt,
        );
      }
    }

    final legacyFlatId = (data['flatId'] as String? ?? '').toUpperCase().trim();
    if (legacyFlatId.isNotEmpty && !byFlatId.containsKey(legacyFlatId)) {
      byFlatId[legacyFlatId] = UserRoom(
        flatId: legacyFlatId,
        flatName: (data['flatName'] as String?)?.trim().isNotEmpty == true
            ? (data['flatName'] as String).trim()
            : 'Room $legacyFlatId',
        role: data['role'] == 'admin' ? 'admin' : 'user',
        roomType: (data['roomType'] as String?) ?? 'flat',
        icon: (data['icon'] as String?) ?? '🏠',
      );
    }
    return byFlatId.values.toList();
  }

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

      final rooms = _roomsFromData(doc.data() ?? {});
      // Repair legacy/duplicate entries without delaying sign-in.
      if (rooms.isNotEmpty) {
        unawaited(_firestore.collection('users').doc(uid).set(
          {'rooms': rooms.map((room) => room.toMap()).toList()},
          SetOptions(merge: true),
        ));
      }
      return rooms;
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

      return _roomsFromData(doc.data() ?? {});
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
    final normalizedFlatId = flatId.toUpperCase().trim();
    final normalizedRole = role == 'admin' ? 'admin' : 'user';
    final userRef = _firestore.collection('users').doc(uid);

    // Do not allow stale picker cards to select a room that was left on
    // another device. This also serializes concurrent add/switch operations.
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final rooms = _roomsFromData(snapshot.data() ?? {});
      final isMember = rooms.any((room) => room.flatId == normalizedFlatId);
      if (!isMember) {
        throw StateError('This room is no longer available to your account.');
      }
      transaction.set(userRef, {
        'flatId': normalizedFlatId,
        'flatName': flatName.trim(),
        'role': normalizedRole,
        'rooms': rooms.map((room) => room.toMap()).toList(),
      }, SetOptions(merge: true));
    }).timeout(const Duration(seconds: 10));

    // 2. Update local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFlatId, normalizedFlatId);
      await prefs.setString(_keyRole, normalizedRole);
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
    String roomType = 'flat',
    String icon = '🏠',
  }) async {
    final normalizedFlatId = flatId.toUpperCase().trim();
    if (normalizedFlatId.isEmpty) throw ArgumentError.value(flatId, 'flatId');
    final docRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final rooms = _roomsFromData(snapshot.data() ?? {});
      final updatedRoom = UserRoom(
        flatId: normalizedFlatId,
        flatName: flatName.trim().isEmpty ? 'Room $normalizedFlatId' : flatName.trim(),
        role: role == 'admin' ? 'admin' : 'user',
        roomType: roomType,
        icon: icon,
      );
      final updatedRooms = <String, UserRoom>{
        for (final room in rooms) room.flatId: room,
        normalizedFlatId: updatedRoom,
      }.values.toList();
      transaction.set(docRef, {
        'rooms': updatedRooms.map((room) => room.toMap()).toList(),
      }, SetOptions(merge: true));
    }).timeout(const Duration(seconds: 10));
  }

  /// Remove a room from the user's rooms array.
  Future<void> removeRoomFromUser({
    required String uid,
    required String flatId,
  }) async {
    final normalizedFlatId = flatId.toUpperCase().trim();
    final docRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final rooms = _roomsFromData(snapshot.data() ?? {})
          .where((room) => room.flatId != normalizedFlatId)
          .toList();
      final activeRoom = rooms.isEmpty ? null : rooms.first;
      transaction.set(docRef, {
        'rooms': rooms.map((room) => room.toMap()).toList(),
        if (activeRoom != null) ...{
          'flatId': activeRoom.flatId,
          'flatName': activeRoom.flatName,
          'role': activeRoom.role,
        } else ...{
          'flatId': FieldValue.delete(),
          'flatName': FieldValue.delete(),
        },
      }, SetOptions(merge: true));
    }).timeout(const Duration(seconds: 10));
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
