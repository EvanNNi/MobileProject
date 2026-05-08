import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'pages/auth/startup_gate.dart';
import 'services/auth_service.dart';
import 'services/mapbox_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await AuthService.instance.initializeGoogleSignIn();
  } catch (_) {
    // The app should still start when Google OAuth is not configured yet.
  }
  final languageController = AppLanguageController();
  await languageController.load();
  runApp(
    AppLanguageScope(controller: languageController, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: l10n.appTitle,
      locale: l10n.locale,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      home: const StartupGate(),
    );
  }
}
