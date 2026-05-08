import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_components.dart';

class LanguageOnboardingPage extends StatefulWidget {
  const LanguageOnboardingPage({super.key});

  @override
  State<LanguageOnboardingPage> createState() => _LanguageOnboardingPageState();
}

class _LanguageOnboardingPageState extends State<LanguageOnboardingPage> {
  AppLanguage? _selectedLanguage;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLanguage ??= AppLanguageScope.controllerOf(context).language;
  }

  Future<void> _previewLanguage(AppLanguage language) async {
    setState(() => _selectedLanguage = language);
    await AppLanguageScope.read(
      context,
    ).setLanguage(language, completeInitialChoice: false);
  }

  Future<void> _continue() async {
    final language = _selectedLanguage ?? AppLanguage.zh;
    setState(() => _isSaving = true);
    await AppLanguageScope.read(context).setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedLanguage = _selectedLanguage ?? AppLanguage.zh;

    return CupertinoPageScaffold(
      backgroundColor: AppPalette.background,
      child: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 86,
                  height: 86,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppPalette.brand,
                    borderRadius: BorderRadius.circular(24),
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
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.ui('选择语言'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${l10n.ui('先选择你想使用的语言')}\n${l10n.ui('之后可以在个人中心随时切换。')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              AppSectionCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _LanguageChoiceTile(
                      title: '中文',
                      subtitle: '简体中文',
                      isSelected: selectedLanguage == AppLanguage.zh,
                      onPressed: _isSaving
                          ? null
                          : () => _previewLanguage(AppLanguage.zh),
                    ),
                    const SizedBox(height: 10),
                    _LanguageChoiceTile(
                      title: 'English',
                      subtitle: 'English',
                      isSelected: selectedLanguage == AppLanguage.en,
                      onPressed: _isSaving
                          ? null
                          : () => _previewLanguage(AppLanguage.en),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              AppPrimaryButton(
                label: _isSaving ? '保存中...' : '继续',
                onPressed: _isSaving ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChoiceTile extends StatelessWidget {
  const _LanguageChoiceTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.brandLight : AppPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppPalette.brand
                : AppPalette.border.withValues(alpha: 0.9),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppPalette.brand : AppPalette.brandLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? CupertinoIcons.check_mark : CupertinoIcons.globe,
                color: isSelected ? CupertinoColors.white : AppPalette.brand,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
