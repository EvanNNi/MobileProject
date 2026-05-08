import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../services/auth_service.dart';
import '../market/market_home_page.dart';
import 'auth_welcome_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return StreamBuilder(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CupertinoPageScaffold(
              backgroundColor: AppPalette.background,
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const MarketHomePage();
          }

          return const AuthWelcomePage();
        },
      );
    } on FirebaseException {
      return const AuthWelcomePage();
    }
  }
}
