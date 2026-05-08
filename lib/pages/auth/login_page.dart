import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_components.dart';
import '../market/market_home_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  String _loginMode = 'email';
  String? _verificationId;
  int? _resendToken;
  bool _obscurePassword = true;
  bool _isBusy = false;
  bool _isSendingCode = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _openMarket() {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(builder: (_) => const MarketHomePage()),
    );
  }

  Future<void> _submit() async {
    if (_loginMode == 'phone') {
      if (_verificationId == null) {
        await _sendPhoneCode();
      } else {
        await _signInWithPhoneCode();
      }
      return;
    }

    await _signInWithEmail();
  }

  Future<void> _signInWithEmail() async {
    final email = _accountController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      await _showMessage('还差一点', '请输入邮箱和密码。');
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AuthService.instance.signInWithEmail(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('登录失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _sendPhoneCode() async {
    final phone = _accountController.text.trim();
    if (phone.isEmpty) {
      await _showMessage('还差一点', '请输入手机号，建议带国家区号。');
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      await AuthService.instance.sendPhoneCode(
        phoneNumber: phone,
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          await _signInWithPhoneCredential(credential);
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
            _showMessage('验证码已发送', '请输入短信中的 6 位验证码完成登录。');
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

  Future<void> _signInWithPhoneCode() async {
    final verificationId = _verificationId;
    final smsCode = _smsCodeController.text.trim();
    if (verificationId == null) {
      await _showMessage('请先获取验证码', '发送短信验证码后再继续登录。');
      return;
    }
    if (smsCode.isEmpty) {
      await _showMessage('还差一点', '请输入短信验证码。');
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AuthService.instance.signInWithPhoneCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('登录失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    if (mounted) {
      setState(() => _isBusy = true);
    }
    try {
      await AuthService.instance.signInWithPhoneCredential(credential);
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('登录失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isBusy = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) {
        return;
      }
      _openMarket();
    } catch (error) {
      await _showMessage('Google 登录失败', authErrorMessage(error));
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

  String get _primaryLabel {
    if (_isBusy) {
      return '登录中...';
    }
    if (_loginMode == 'phone') {
      if (_isSendingCode) {
        return '发送中...';
      }
      return _verificationId == null ? '发送短信验证码' : '验证码登录并进入市场';
    }
    return '登录并进入市场';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CupertinoPageScaffold(
      backgroundColor: AppPalette.background,
      child: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              if (Navigator.of(context).canPop()) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppNavIconButton(
                    icon: CupertinoIcons.chevron_left,
                    semanticLabel: '返回',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Row(
                children: [
                  AppQuickAction(
                    icon: CupertinoIcons.camera_viewfinder,
                    label: '拍照识别',
                    color: AppPalette.mint,
                  ),
                  SizedBox(width: 10),
                  AppQuickAction(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    label: 'AI 估价',
                    color: AppPalette.yellow,
                  ),
                  SizedBox(width: 10),
                  AppQuickAction(
                    icon: CupertinoIcons.paperplane_fill,
                    label: '快速发布',
                    color: AppPalette.warmAccent,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(
                      title: '欢迎回来',
                      subtitle: '用手机号、邮箱或 Google 进入 Luma。',
                    ),
                    const SizedBox(height: 18),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: _loginMode,
                      thumbColor: AppPalette.brand,
                      backgroundColor: AppPalette.brandLight,
                      children: {
                        'email': Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(l10n.ui('邮箱')),
                        ),
                        'phone': Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(l10n.ui('手机号')),
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _loginMode = value;
                            _verificationId = null;
                            _resendToken = null;
                            _accountController.clear();
                            _passwordController.clear();
                            _smsCodeController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _accountController,
                      placeholder: _loginMode == 'phone'
                          ? '手机号，例如 +86 138...'
                          : '输入邮箱地址',
                      keyboardType: _loginMode == 'phone'
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      prefix: Icon(
                        _loginMode == 'phone'
                            ? CupertinoIcons.phone
                            : CupertinoIcons.mail,
                        color: AppPalette.mutedText,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_loginMode == 'phone') ...[
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
                        placeholder: '输入密码',
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
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.ui(
                              _loginMode == 'phone'
                                  ? '短信登录需要手机号可以接收验证码。'
                                  : '登录即代表同意平台服务协议与隐私政策',
                            ),
                            style: const TextStyle(
                              color: AppPalette.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: _isBusy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute<void>(
                                      builder: (_) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                          child: Text(
                            l10n.ui('忘记密码'),
                            style: const TextStyle(
                              color: AppPalette.brand,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppPrimaryButton(
                      label: _primaryLabel,
                      onPressed: _isBusy || _isSendingCode ? null : _submit,
                    ),
                    if (_loginMode == 'phone' && _verificationId != null) ...[
                      const SizedBox(height: 10),
                      AppSecondaryButton(
                        label: _isSendingCode ? '重新发送中...' : '重新发送验证码',
                        onPressed: _isSendingCode ? null : _sendPhoneCode,
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppSecondaryButton(
                      label: _isBusy ? '处理中...' : '使用 Google 继续',
                      onPressed: _isBusy ? null : _signInWithGoogle,
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
              const SizedBox(height: 18),
              const AppSectionCard(
                child: Row(
                  children: [
                    AppMetricTile(
                      label: 'AI 发布效率',
                      value: '快',
                      caption: '少花时间写标题和定价',
                      highlight: true,
                    ),
                    SizedBox(width: 12),
                    AppMetricTile(
                      label: '交易体验',
                      value: '稳',
                      caption: '聊天、收藏和发布统一管理',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.ui('还没有账号？'),
                    style: TextStyle(color: AppPalette.mutedText, fontSize: 14),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 6),
                    minimumSize: Size.zero,
                    onPressed: _isBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                    child: Text(
                      l10n.ui('立即注册'),
                      style: const TextStyle(
                        color: AppPalette.brand,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
