import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_components.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthWelcomePage extends StatelessWidget {
  const AuthWelcomePage({super.key});

  void _openLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const LoginPage()));
  }

  void _openRegister(BuildContext context) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const RegisterPage()));
  }

  Future<void> _setLanguage(BuildContext context, AppLanguage language) async {
    await AppLanguageScope.read(context).setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageController = AppLanguageScope.controllerOf(context);

    return CupertinoPageScaffold(
      backgroundColor: AppPalette.background,
      child: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoSlidingSegmentedControl<AppLanguage>(
                  groupValue: languageController.language,
                  thumbColor: AppPalette.surface,
                  backgroundColor: AppPalette.brandLight,
                  children: const {
                    AppLanguage.zh: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text('中文'),
                    ),
                    AppLanguage.en: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text('EN'),
                    ),
                  },
                  onValueChanged: (language) {
                    if (language != null) {
                      _setLanguage(context, language);
                    }
                  },
                ),
              ),
              const SizedBox(height: 42),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppPalette.brand,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.brand.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Text(
                    'L',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.ui('开始使用 Luma'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.ui('让 AI 帮你更快卖出闲置物品。'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 34),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionTitle(
                      title: '登录或注册账号',
                      subtitle: '已有账号就直接登录，新用户可以先注册。',
                    ),
                    const SizedBox(height: 20),
                    AppPrimaryButton(
                      label: '登录账号',
                      onPressed: () => _openLogin(context),
                    ),
                    const SizedBox(height: 12),
                    AppSecondaryButton(
                      label: '注册账号',
                      onPressed: () => _openRegister(context),
                      leading: const Icon(
                        CupertinoIcons.person_add,
                        color: AppPalette.brand,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const AppSectionCard(
                child: Row(
                  children: [
                    AppMetricTile(
                      label: '拍照识别',
                      value: 'AI',
                      caption: '识别标题、描述和分类',
                      highlight: true,
                    ),
                    SizedBox(width: 12),
                    AppMetricTile(
                      label: '快速交易',
                      value: 'Chat',
                      caption: '收藏、地图和消息',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.ui('拍照识别、AI 估价、聊天交易都在这里开始。'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
