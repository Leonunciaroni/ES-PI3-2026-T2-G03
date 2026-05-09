import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/session_persistence_service.dart';
import 'login_screen.dart';

/// Primeira rota após o splash do [MaterialApp]: em cold start remove a sessão Firebase
/// para exigir novo login (processo reciclado ou app fechado).
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _ready = false;

  static bool _firebaseAvailable() {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(Duration.zero);
    if (!_firebaseAvailable()) {
      if (mounted) {
        setState(() => _ready = true);
      }
      return;
    }
    try {
      if (Firebase.apps.isNotEmpty) {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseAuth.instance.signOut();
        }
        await SessionPersistenceService.clearSessionDeadline();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthGateScreen] bootstrap: $e');
      }
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const LoginScreen();
  }
}
