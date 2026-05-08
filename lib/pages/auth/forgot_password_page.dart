import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_components.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _contactController = TextEditingController();

  String _resetMode = 'email';
  bool _isBusy = false;

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_resetMode == 'phone') {
      Navigator.of(context).pop();
      return;
    }

    final email = _contactController.text.trim();
    if (email.isEmpty) {
      await _showMessage('还差一点', '请输入要重置密码的邮箱。');
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      await _showMessage('重置邮件已发送', '请打开邮箱，按邮件中的链接重置密码。');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      await _showMessage('发送失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showMessage(String title, String message) async {
    if (!mounted) {
      return;
    }

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.ui(title)),
        content: Text(context.l10n.ui(message)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ui('知道了')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppPageScaffold(
      title: '忘记密码',
      previousPageTitle: '登录',
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: '找回账号访问权限',
                    subtitle: '我们会发送密码重置邮件，不在 App 内直接保存新密码。',
                  ),
                  const SizedBox(height: 18),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _resetMode,
                    thumbColor: AppPalette.brand,
                    backgroundColor: AppPalette.brandLight,
                    children: {
                      'email': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(l10n.ui('邮箱找回')),
                      ),
                      'phone': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(l10n.ui('手机号找回')),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _resetMode = value;
                          _contactController.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  if (_resetMode == 'email') ...[
                    AppTextField(
                      controller: _contactController,
                      placeholder: '输入注册邮箱',
                      keyboardType: TextInputType.emailAddress,
                      prefix: const Icon(
                        CupertinoIcons.mail,
                        color: AppPalette.mutedText,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppPrimaryButton(
                      label: _isBusy ? '发送中...' : '发送重置邮件',
                      onPressed: _isBusy ? null : _submit,
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceWarm,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppPalette.border.withValues(alpha: 0.75),
                        ),
                      ),
                      child: Text(
                        l10n.ui('手机号登录不使用固定密码。返回登录页后选择“手机号”，发送短信验证码即可进入账号。'),
                        style: const TextStyle(
                          color: AppPalette.mutedText,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppPrimaryButton(label: '返回登录页', onPressed: _submit),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
