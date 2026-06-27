import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/server_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Pre-load saved server URL so ApiClient uses correct baseUrl on first request
  await ServerConfigService.getBaseUrl(); // warm up SharedPreferences

  runApp(const ProviderScope(child: TiknolPosApp()));
}

class TiknolPosApp extends ConsumerWidget {
  const TiknolPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Tiknol POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => _ForceLandscape(child: child!),
    );
  }
}

/// Forces landscape rendering even when the OS (e.g. Samsung tablets that
/// ignore native orientation locks) rotates the window to portrait.
/// When the window is portrait, RotatedBox lays the content out at landscape
/// dimensions and rotates it 90 degrees to fill the portrait window.
class _ForceLandscape extends StatelessWidget {
  final Widget child;
  const _ForceLandscape({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Already landscape (or square) — render normally.
        if (w >= h) return child;

        // Portrait window — rotate landscape content into it.
        return RotatedBox(
          quarterTurns: 1,
          child: child,
        );
      },
    );
  }
}
