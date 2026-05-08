import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../onboarding/language_onboarding_page.dart';
import 'auth_gate.dart';

class StartupGate extends StatelessWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    final languageController = AppLanguageScope.controllerOf(context);
    if (!languageController.hasCompletedInitialLanguageChoice) {
      return const LanguageOnboardingPage();
    }
    return const AuthGate();
  }
}
