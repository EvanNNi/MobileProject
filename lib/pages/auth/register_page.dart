import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_components.dart';
import '../market/market_home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  String _registerMode = 'email';
  String? _verificationId;
  int? _resendToken;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isBusy = false;
  bool _isSendingCode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_registerMode == 'phone') {
      if (_verificationId == null) {
        await _sendPhoneCode();
      } else {
        await _registerWithPhoneCode();
      }
      return;
    }

    await _registerWithEmail();
  }

  Future<void> _registerWithEmail() async {
    final name = _nameController.text.trim();
    final email = _contactController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      await _showMessage('还差一点', '请补全昵称、邮箱和密码。');
      return;
    }
    if (password != confirm) {
      await _showMessage('密码不一致', '两次输入的密码需要保持一致。');
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AuthService.instance.registerWithEmail(
        name: name,
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('注册失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _sendPhoneCode() async {
    final name = _nameController.text.trim();
    final phone = _contactController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      await _showMessage('还差一点', '请填写昵称和手机号。');
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      await AuthService.instance.sendPhoneCode(
        phoneNumber: phone,
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          await _registerWithPhoneCredential(credential);
        },
        verificationFailed: (error) {
          if (mounted) {
            setState(() {
              _isBusy = false;
              _isSendingCode = false;
            });
            _showMessage('验证码发送失败', authErrorMessage(error));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
            });
            _showMessage('验证码已发送', '请输入短信中的 6 位验证码完成注册。');
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (mounted && _verificationId == null) {
            setState(() => _verificationId = verificationId);
          }
        },
      );
    } catch (error) {
      await _showMessage('验证码发送失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _registerWithPhoneCode() async {
    final verificationId = _verificationId;
    final code = _smsCodeController.text.trim();
    if (verificationId == null) {
      await _showMessage('请先获取验证码', '发送短信验证码后再继续注册。');
      return;
    }
    if (code.isEmpty) {
      await _showMessage('还差一点', '请输入短信验证码。');
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AuthService.instance.signInWithPhoneCode(
        verificationId: verificationId,
        smsCode: code,
      );
      await AuthService.instance.updateDisplayName(_nameController.text);
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('注册失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _registerWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    if (mounted) {
      setState(() => _isBusy = true);
    }
    try {
      await AuthService.instance.signInWithPhoneCredential(credential);
      await AuthService.instance.updateDisplayName(_nameController.text);
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('注册失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isBusy = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('Google 注册失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _openMarket() {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute<void>(builder: (_) => const MarketHomePage()),
      (route) => false,
    );
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

  String get _primaryLabel {
    if (_isBusy) {
      return '创建中...';
    }
    if (_registerMode == 'phone') {
      if (_isSendingCode) {
        return '发送中...';
      }
      return _verificationId == null ? '发送短信验证码' : '验证并创建账号';
    }
    return '创建账号';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppPageScaffold(
      title: '注册',
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
                    title: '创建你的账号',
                    subtitle: '一个账号即可浏览、购买和发布闲置商品。',
                  ),
                  const SizedBox(height: 18),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _registerMode,
                    thumbColor: AppPalette.brand,
                    backgroundColor: AppPalette.brandLight,
                    children: {
                      'email': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(l10n.ui('邮箱注册')),
                      ),
                      'phone': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(l10n.ui('手机号注册')),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _registerMode = value;
                          _verificationId = null;
                          _resendToken = null;
                          _contactController.clear();
                          _passwordController.clear();
                          _confirmController.clear();
                          _smsCodeController.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: _nameController,
                    placeholder: '昵称或姓名',
                    prefix: const Icon(
                      CupertinoIcons.person,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _contactController,
                    placeholder: _registerMode == 'phone'
                        ? '手机号，例如 +86 138...'
                        : '邮箱',
                    keyboardType: _registerMode == 'phone'
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    prefix: Icon(
                      _registerMode == 'phone'
                          ? CupertinoIcons.phone
                          : CupertinoIcons.mail,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_registerMode == 'phone') ...[
                    AppTextField(
                      controller: _smsCodeController,
                      placeholder: _verificationId == null
                          ? '验证码会发送到这个手机号'
                          : '输入短信验证码',
                      keyboardType: TextInputType.number,
                      readOnly: _verificationId == null,
                      prefix: const Icon(
                        CupertinoIcons.number,
                        color: AppPalette.mutedText,
                        size: 20,
                      ),
                    ),
                  ] else ...[
                    AppTextField(
                      controller: _passwordController,
                      placeholder: '设置密码',
                      obscureText: _obscurePassword,
                      prefix: const Icon(
                        CupertinoIcons.lock,
                        color: AppPalette.mutedText,
                        size: 20,
                      ),
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        child: Icon(
                          _obscurePassword
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                          color: AppPalette.mutedText,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _confirmController,
                      placeholder: '确认密码',
                      obscureText: _obscureConfirm,
                      prefix: const Icon(
                        CupertinoIcons.lock_shield,
                        color: AppPalette.mutedText,
                        size: 20,
                      ),
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                        child: Icon(
                          _obscureConfirm
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                          color: AppPalette.mutedText,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppTag(label: '收藏好物'),
                      AppTag(label: '收货地址'),
                      AppTag(label: '订单保障'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppPrimaryButton(
                    label: _primaryLabel,
                    onPressed: _isBusy || _isSendingCode ? null : _submit,
                  ),
                  if (_registerMode == 'phone' && _verificationId != null) ...[
                    const SizedBox(height: 10),
                    AppSecondaryButton(
                      label: _isSendingCode ? '重新发送中...' : '重新发送验证码',
                      onPressed: _isSendingCode ? null : _sendPhoneCode,
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppSecondaryButton(
                    label: _isBusy ? '处理中...' : '使用 Google 继续注册',
                    onPressed: _isBusy ? null : _registerWithGoogle,
                    leading: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppPalette.brandLight,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
