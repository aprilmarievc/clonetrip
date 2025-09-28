import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadGroupReceipt({
    required String groupId,
    required String expenseId,
    required File file,
  }) async {
    final ref = _storage
        .ref()
        .child('groups')
        .child(groupId)
        .child('expenses')
        .child(expenseId)
        .child('receipt.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  Future<String> uploadItineraryPhoto({
    required String itineraryId,
    required String fileName,
    required File file,
  }) async {
    final ref = _storage
        .ref()
        .child('itineraries')
        .child(itineraryId)
        .child('photos')
        .child(fileName);
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}
