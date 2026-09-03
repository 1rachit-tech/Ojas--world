import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RealtimePresenceState {
  const RealtimePresenceState({
    required this.online,
    this.lastChanged,
  });

  final bool online;
  final DateTime? lastChanged;
}

class RealtimePresenceService {
  RealtimePresenceService._();

  static final RealtimePresenceService instance =
      RealtimePresenceService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _connectionId =
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  DatabaseReference? _connectionRef;
  String? _activeUid;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }

    _started = true;
    _activeUid = uid;

    try {
      final root = FirebaseDatabase.instance.ref();
      final connectionRef = root.child(
        'presence/$uid/$_connectionId',
      );
      _connectionRef = connectionRef;

      _connectionSubscription = root
          .child('.info/connected')
          .onValue
          .listen((event) {
        final connected = event.snapshot.value == true;
        if (connected) {
          unawaited(_markConnected(connectionRef));
        }
      });
    } catch (_) {
      _started = false;
      _connectionRef = null;
      _activeUid = null;
    }
  }

  Future<void> stop() async {
    final connectionRef = _connectionRef;

    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectionRef = null;
    _activeUid = null;
    _started = false;

    if (connectionRef == null) {
      return;
    }

    try {
      await connectionRef.set(<String, Object>{
        'online': false,
        'lastChanged': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  Future<void> setLifecycleOnline(bool online) async {
    final connectionRef = _connectionRef;
    if (connectionRef == null) {
      return;
    }

    try {
      if (online) {
        await _markConnected(connectionRef);
      } else {
        await connectionRef.set(<String, Object>{
          'online': false,
          'lastChanged': ServerValue.timestamp,
        });
      }
    } catch (_) {}
  }

  Stream<RealtimePresenceState> watch(String uid) {
    if (uid.trim().isEmpty) {
      return Stream<RealtimePresenceState>.value(
        const RealtimePresenceState(online: false),
      );
    }

    return FirebaseDatabase.instance
        .ref('presence/$uid')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) {
        return const RealtimePresenceState(online: false);
      }

      var online = false;
      DateTime? newest;

      for (final value in raw.values) {
        if (value is! Map) {
          continue;
        }

        if (value['online'] == true) {
          online = true;
        }

        final changed = value['lastChanged'];
        if (changed is num) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            changed.toInt(),
          );
          if (newest == null || date.isAfter(newest)) {
            newest = date;
          }
        }
      }

      return RealtimePresenceState(
        online: online,
        lastChanged: newest,
      );
    }).handleError((_) {
      return const RealtimePresenceState(online: false);
    });
  }

  Future<void> _markConnected(DatabaseReference connectionRef) async {
    try {
      await connectionRef.onDisconnect().set(<String, Object>{
        'online': false,
        'lastChanged': ServerValue.timestamp,
      });

      await connectionRef.set(<String, Object>{
        'online': true,
        'lastChanged': ServerValue.timestamp,
      });
    } catch (_) {}
  }
}
