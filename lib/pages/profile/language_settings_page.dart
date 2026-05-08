import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_components.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppLanguageScope.controllerOf(context);
    final l10n = context.l10n;

    return AppPageScaffold(
      title: '语言设置',
      previousPageTitle: '个人中心',
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: '选择应用显示语言',
                    subtitle: '切换后会立即应用到主要页面。',
                  ),
                  const SizedBox(height: 20),
                  CupertinoSlidingSegmentedControl<AppLanguage>(
                    groupValue: controller.language,
                    backgroundColor: AppPalette.surfaceWarm,
                    thumbColor: AppPalette.surface,
                    children: {
                      AppLanguage.zh: _LanguageSegment(
                        label: '中文',
                        selected: controller.language == AppLanguage.zh,
                      ),
                      AppLanguage.en: _LanguageSegment(
                        label: 'English',
                        selected: controller.language == AppLanguage.en,
                      ),
                    },
                    onValueChanged: (language) {
                      if (language != null) {
                        controller.setLanguage(language);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.text(
                      '切换到英文时，商品标题、描述、分类、成色和标签会尽量转换为英文；聊天消息和用户昵称保留原文。',
                      'In English mode, item titles, descriptions, categories, conditions, and tags are translated where possible. Chat messages and usernames stay in their original language.',
                    ),
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 13,
                      height: 1.5,
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

class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppPalette.brandDark : AppPalette.mutedText,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
