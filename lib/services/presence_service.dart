import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final presenceServiceProvider = Provider((ref) => PresenceService());

class PresenceService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void initializePresence() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final uid = user.uid;
    final userStatusRef = _db.ref('status/$uid');
    final connectedRef = _db.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        userStatusRef.onDisconnect().set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        }).then((_) {
          userStatusRef.set({
            'state': 'online',
            'last_changed': ServerValue.timestamp,
          });
        });
      }
    });
  }

  Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final userStatusRef = _db.ref('status/${user.uid}');
    await userStatusRef.set({
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
    });
  }
}
