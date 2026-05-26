import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'theme/brand.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't hang the UI fetching fonts at runtime — on flaky networks (e.g.
  // Android emulator) the TLS handshake to fonts.gstatic.com can stall and
  // freeze the login screen. With this off, google_fonts falls back to the
  // platform default font silently. To get the branded fonts in release,
  // bundle them as assets and register them via the font family API.
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: QaramiaApp()));
}

class QaramiaApp extends ConsumerWidget {
  const QaramiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Qaramia',
      debugShowCheckedModeBanner: false,
      theme: QBrand.themeData(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When the user transitions from signed-out → signed-in, reap any
    // streams that previous sessions left in status='live' (crashes, force
    // quits, hot restarts). Best-effort; the service swallows its own
    // errors so a flaky network at startup doesn't block the UI.
    ref.listen(authStateProvider, (prev, next) {
      final newUid = next.valueOrNull?.uid;
      if (newUid != null && prev?.valueOrNull?.uid != newUid) {
        ref.read(streamServiceProvider).endStaleStreams(newUid);
      }
    });

    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: QBrand.peach)),
      ),
      error: (_, _) => const AuthScreen(),
      data: (user) => user != null ? const HomeScreen() : const AuthScreen(),
    );
  }
}
