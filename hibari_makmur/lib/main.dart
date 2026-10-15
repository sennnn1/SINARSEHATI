import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_service.dart';
import 'auth/demo_auth_service.dart';
import 'auth/login_page.dart';
import 'auth/supabase_auth_service.dart';
import 'config.dart';
import 'data/app_state.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  final AuthService auth;
  if (Config.pakaiSupabase) {
    await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
    auth = SupabaseAuthService();
  } else {
    auth = DemoAuthService(state);
  }
  runApp(SinarSehatiApp(state: state, auth: auth));
}

class SinarSehatiApp extends StatelessWidget {
  const SinarSehatiApp({super.key, required this.state, required this.auth});

  final AppState state;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: auth,
      child: AppScope(
        state: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sinar Sehati',
          theme: buildTheme(),
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Menampilkan halaman Login kalau belum masuk, dashboard kalau sudah.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: user == null
          ? const LoginPage(key: ValueKey('login'))
          : HomeShell(key: ValueKey(user.email), role: user.role),
    );
  }
}
