import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../models/itinerary.dart';
import '../models/group.dart';
import '../models/expense.dart';

abstract class DataService {
  Stream<UserProfile> watchUserProfile(String userId);
  Stream<List<Itinerary>> watchItineraries(String userId, {bool? wishlist});
  Stream<List<GroupModel>> watchGroups(String userId);
  Stream<List<Expense>> watchExpenses(String groupId);

  Future<void> createItinerary({
    required String userId,
    required String title,
    String? countryCode,
    List<String>? cities,
    String? startDateIso,
    String? endDateIso,
    bool isWishlist = false,
  });

  Future<void> updateItinerary({
    required String itineraryId,
    required Map<String, dynamic> updates,
  });

  Future<void> deleteItinerary({required String itineraryId});

  Future<void> createExpense({
    required String groupId,
    required String payerUserId,
    required double amount,
    required String currency,
    required Map<String, double> splits,
    required String description,
    String? receiptUrl,
  });

  Future<String> createGroupInvite(String groupId);

  Future<bool> acceptGroupInvite({
    required String groupId,
    required String code,
    required String userId,
  });

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  });

  Future<void> quickAddActivityAndExpense({
    required String itineraryId,
    required String title,
    required String dayIso,
    double? priceUsd,
  });
}

class FirestoreDataService implements DataService {
  FirestoreDataService(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<UserProfile> watchUserProfile(String userId) {
    final CollectionReference<Map<String, dynamic>> users = _db.collection(
      'users',
    );
    return users.doc(userId).snapshots().map((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      return UserProfile.fromMap(snap.id, data);
    });
  }

  @override
  Stream<List<Itinerary>> watchItineraries(String userId, {bool? wishlist}) {
    final Query<Map<String, dynamic>> col = _db
        .collection('itineraries')
        .where('userId', isEqualTo: userId);
    return col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => Itinerary.fromMap(d.id, d.data()))
          .toList();
      if (wishlist == null) return items;
      return items.where((i) => i.isWishlist == wishlist).toList();
    });
  }

  @override
  Stream<List<GroupModel>> watchGroups(String userId) {
    final CollectionReference<Map<String, dynamic>> groups = _db.collection(
      'groups',
    );
    return groups
        .where('memberUserIds', arrayContains: userId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => GroupModel.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Stream<List<Expense>> watchExpenses(String groupId) {
    final CollectionReference<Map<String, dynamic>> expenses = _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses');
    return expenses
        .orderBy('createdAtIso', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Expense.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> createItinerary({
    required String userId,
    required String title,
    String? countryCode,
    List<String>? cities,
    String? startDateIso,
    String? endDateIso,
    bool isWishlist = false,
  }) async {
    final payload = <String, dynamic>{
      'userId': userId,
      'title': title,
      if (countryCode != null && countryCode.trim().isNotEmpty)
        'countryCode': countryCode.trim().toUpperCase(),
      if (cities != null && cities.isNotEmpty) 'cities': cities,
      if (startDateIso != null) 'startDateIso': startDateIso,
      if (endDateIso != null) 'endDateIso': endDateIso,
      'isWishlist': isWishlist,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('itineraries').add(payload);
  }

  @override
  Future<void> updateItinerary({
    required String itineraryId,
    required Map<String, dynamic> updates,
  }) async {
    await _db.collection('itineraries').doc(itineraryId).update(updates);
  }

  @override
  Future<void> deleteItinerary({required String itineraryId}) async {
    await _db.collection('itineraries').doc(itineraryId).delete();
  }

  @override
  Future<void> createExpense({
    required String groupId,
    required String payerUserId,
    required double amount,
    required String currency,
    required Map<String, double> splits,
    required String description,
    String? receiptUrl,
  }) async {
    await _db.collection('groups').doc(groupId).collection('expenses').add({
      'payerUserId': payerUserId,
      'amount': amount,
      'currency': currency,
      'splits': splits,
      'description': description,
      'createdAtIso': DateTime.now().toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
    });
  }

  @override
  Future<String> createGroupInvite(String groupId) async {
    final code = _randomCode();
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('invites')
        .doc(code)
        .set({'createdAt': FieldValue.serverTimestamp(), 'active': true});
    return 'https://example.com/invite/$groupId/$code';
  }

  @override
  Future<bool> acceptGroupInvite({
    required String groupId,
    required String code,
    required String userId,
  }) async {
    final inviteRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('invites')
        .doc(code);
    final invite = await inviteRef.get();
    if (!invite.exists || (invite.data()?['active'] != true)) return false;
    final groupRef = _db.collection('groups').doc(groupId);
    await _db.runTransaction((tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(
        groupRef,
      );
      final data = snap.data() ?? <String, dynamic>{};
      final members =
          (data['memberUserIds'] as List?)?.cast<String>() ?? <String>[];
      if (!members.contains(userId)) members.add(userId);
      tx.update(groupRef, {'memberUserIds': members});
      tx.update(inviteRef, {'active': false});
    });
    return true;
  }

  @override
  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .set(updates, SetOptions(merge: true));
  }

  @override
  Future<void> quickAddActivityAndExpense({
    required String itineraryId,
    required String title,
    required String dayIso,
    double? priceUsd,
  }) async {
    final ref = _db.collection('itineraries').doc(itineraryId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final List activities = (data['activities'] as List?) ?? <dynamic>[];
      activities.add({
        'title': title,
        'whenIso': dayIso,
        'mustDo': true,
        if (priceUsd != null) 'price': priceUsd,
      });
      final List expenses = (data['tripExpenses'] as List?) ?? <dynamic>[];
      if (priceUsd != null) {
        expenses.add({
          'amount': priceUsd,
          'currency': 'USD',
          'description': title,
          'source': 'quick',
          'whenIso': dayIso,
        });
      }
      tx.update(ref, {'activities': activities, 'tripExpenses': expenses});
    });
  }

  String _randomCode({int length = 8}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    int x = now;
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(chars[x % chars.length]);
    }
    return buffer.toString();
  }
}

class MockDataService implements DataService {
  MockDataService();

  @override
  Stream<UserProfile> watchUserProfile(String userId) async* {
    yield UserProfile(
      id: userId,
      displayName: 'April',
      countryCode: 'US',
      nextDestination: 'Tokyo, Japan',
    );
  }

  @override
  Stream<List<Itinerary>> watchItineraries(
    String userId, {
    bool? wishlist,
  }) async* {
    final items = <Itinerary>[
      Itinerary(
        id: '1',
        userId: userId,
        title: 'Tokyo Spring',
        countryCode: 'JP',
        startDateIso: '2025-04-12',
        endDateIso: '2025-04-21',
      ),
      Itinerary(
        id: '2',
        userId: userId,
        title: 'Lisbon Getaway',
        countryCode: 'PT',
        startDateIso: '2025-06-02',
        endDateIso: '2025-06-08',
      ),
      Itinerary(
        id: 'w1',
        userId: userId,
        title: 'Peru Trek',
        countryCode: 'PE',
        isWishlist: true,
      ),
    ];
    yield items
        .where((i) => wishlist == null ? true : i.isWishlist == wishlist)
        .toList();
  }

  @override
  Stream<List<GroupModel>> watchGroups(String userId) async* {
    yield [
      GroupModel(
        id: 'g1',
        name: 'Bali w/ Friends',
        memberUserIds: [userId],
        itineraryIds: const ['3'],
      ),
    ];
  }

  @override
  Stream<List<Expense>> watchExpenses(String groupId) async* {
    yield [
      Expense(
        id: 'e1',
        groupId: groupId,
        payerUserId: 'u1',
        amount: 120.0,
        currency: 'USD',
        splits: const {'u1': 60.0, 'u2': 60.0},
        description: 'Dinner',
        createdAtIso: DateTime.now().toIso8601String(),
      ),
    ];
  }

  @override
  Future<bool> acceptGroupInvite({
    required String groupId,
    required String code,
    required String userId,
  }) async {
    return true;
  }

  @override
  Future<void> createItinerary({
    required String userId,
    required String title,
    String? countryCode,
    List<String>? cities,
    String? startDateIso,
    String? endDateIso,
    bool isWishlist = false,
  }) async {}

  @override
  Future<void> updateItinerary({
    required String itineraryId,
    required Map<String, dynamic> updates,
  }) async {}

  @override
  Future<void> deleteItinerary({required String itineraryId}) async {}

  @override
  Future<void> createExpense({
    required String groupId,
    required String payerUserId,
    required double amount,
    required String currency,
    required Map<String, double> splits,
    required String description,
    String? receiptUrl,
  }) async {}

  @override
  Future<String> createGroupInvite(String groupId) async {
    return 'mock://invite/$groupId';
  }

  @override
  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {}

  @override
  Future<void> quickAddActivityAndExpense({
    required String itineraryId,
    required String title,
    required String dayIso,
    double? priceUsd,
  }) async {
    // No-op in mock
  }
}

Future<DataService> createDataService() async {
  try {
    // Use Firebase if available; else fallback to mock
    final db = FirebaseFirestore.instance;
    // Force an innocuous access to ensure initialization
    await db.waitForPendingWrites();
    return FirestoreDataService(db);
  } catch (e) {
    debugPrint('Using MockDataService due to error: $e');
    return MockDataService();
  }
}
