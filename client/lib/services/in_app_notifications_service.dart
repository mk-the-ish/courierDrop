import "package:cloud_firestore/cloud_firestore.dart";

class InAppNotificationsService {
  InAppNotificationsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Map<String, dynamic>>> watchNotifications(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{
                  "id": doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  Stream<int> watchUnreadCount(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .where("status", isEqualTo: "unread")
        .snapshots()
        .map((snapshot) => snapshot.size);
  }
}
