import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../widgets/app_components.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.appUser});

  final AppUser? appUser;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _bioController;
  late final TextEditingController _campusController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authUser = AuthService.instance.currentUser;
    final appUser = widget.appUser;
    _nicknameController = TextEditingController(
      text:
          appUser?.displayName ??
          authUser?.displayName ??
          authUser?.email?.split('@').first ??
          '',
    );
    _bioController = TextEditingController(text: appUser?.bio ?? '');
    _campusController = TextEditingController(text: appUser?.location ?? '');
    _phoneController = TextEditingController(
      text: appUser?.phoneNumber ?? authUser?.phoneNumber ?? '',
    );
    _emailController = TextEditingController(
      text: appUser?.email ?? authUser?.email ?? '',
    );
    _nicknameController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _campusController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      await _showMessage('保存失败', '请先登录，再编辑资料。');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final displayName = _nicknameController.text.trim();
      if (displayName.isNotEmpty && displayName != user.displayName) {
        await user.updateDisplayName(displayName);
      }
      await UserRepository.instance.updateProfile(
        uid: user.uid,
        displayName: displayName,
        bio: _bioController.text,
        location: _campusController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      await _showMessage('保存失败', authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showMessage(String title, String message) {
    return showCupertinoDialog<void>(
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
    return AppPageScaffold(
      title: '编辑资料',
      previousPageTitle: '个人中心',
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppPalette.ink,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppPalette.mint,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _profileInitials(_nicknameController.text),
                      style: const TextStyle(
                        fontSize: 24,
                        color: AppPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTag(
                          label: '完善资料提升成交率',
                          color: AppPalette.yellow,
                          textColor: AppPalette.ink,
                        ),
                        SizedBox(height: 10),
                        Text(
                          context.l10n.ui('让买家更快相信你'),
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          context.l10n.ui('资料会显示在商品详情、聊天和订单页。'),
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _nicknameController,
                    placeholder: '昵称',
                    prefix: const Icon(
                      CupertinoIcons.person,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _bioController,
                    placeholder: '个人简介',
                    maxLines: 3,
                    prefix: const Icon(
                      CupertinoIcons.doc_text,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _campusController,
                    placeholder: '常驻区域',
                    prefix: const Icon(
                      CupertinoIcons.location,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _phoneController,
                    placeholder: '手机号',
                    keyboardType: TextInputType.phone,
                    prefix: const Icon(
                      CupertinoIcons.phone,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _emailController,
                    placeholder: '邮箱',
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(
                      CupertinoIcons.mail,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              label: _isSaving ? '保存中...' : '保存资料',
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

String _profileInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }
  return trimmed.runes.take(2).map(String.fromCharCode).join().toUpperCase();
}
