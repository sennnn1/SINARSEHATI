import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_service.dart';
import 'auth/demo_auth_service.dart';
import 'auth/login_page.dart';
import 'auth/supabase_auth_service.dart';
import 'config.dart';
import 'data/app_state.dart';
import 'data/barang_repo.dart';
import 'data/kontak_repo.dart';
import 'data/pengguna_repo.dart';
import 'data/transaksi_repo.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  final AuthService auth;
  if (Config.pakaiSupabase) {
    await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
    auth = SupabaseAuthService();
    final db = Supabase.instance.client;
    state
      ..repo = BarangRepo(db)
      ..pelangganRepo = KontakRepo(db, 'pelanggan')
      ..transaksiRepo = TransaksiRepo(db)
      ..penggunaRepo = SupabasePenggunaRepo(db);
    // Daftar pengguna contoh hanya untuk mode demo.
    state.pengguna.clear();
    // Tabel di Supabase hanya boleh dibaca pengguna yang sudah login (RLS),
    // jadi semua data diambil sekali setelah login.
    db.auth.onAuthStateChange.listen((e) {
      if (e.session != null &&
          (e.event == AuthChangeEvent.signedIn || e.event == AuthChangeEvent.initialSession)) {
        state.muatDariSupabase();
      }
    });
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (auth.menyiapkan) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: user == null
          ? const LoginPage(key: ValueKey('login'))
          : HomeShell(key: ValueKey(user.email), role: user.role),
    );
  }
}
