import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../widgets/app_components.dart';
import '../auth/login_page.dart';
import '../chat/conversations_page.dart';
import '../market/favorites_page.dart';
import '../publish/draft_box_page.dart';
import 'address_management_page.dart';
import 'edit_profile_page.dart';
import 'language_settings_page.dart';
import 'my_listings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await AuthService.instance.signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute<void>(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('退出失败')),
          content: Text(authErrorMessage(error)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.ui('知道了')),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _showLoginMethods(User? user) {
    final methods = _loginMethodLabels(user);
    final l10n = context.l10n;
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.ui('登录与安全')),
        content: Text(_loginMethodDialogText(methods, l10n)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ui('知道了')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = AuthService.instance.currentUser;

    return AppPageScaffold(
      title: '个人中心',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () {
          Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => const EditProfilePage()),
          );
        },
        child: const Icon(
          CupertinoIcons.pencil,
          color: AppPalette.brand,
          size: 22,
        ),
      ),
      child: AppBackdrop(
        child: StreamBuilder<AppUser?>(
          stream: UserRepository.instance.watchCurrentUser(),
          builder: (context, snapshot) {
            final appUser = snapshot.data;
            final displayName = appUser?.displayName ?? _displayName(user);
            final subtitle = _profileSubtitle(user, appUser);
            final creditScore = appUser?.creditScore;
            final rating = appUser?.rating;
            final favoriteCount = appUser?.favoriteCount ?? 0;
            final viewedCount = appUser?.viewedCount ?? 0;
            final listingCount = appUser?.listingCount ?? 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppPalette.brandLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppPalette.brand.withValues(alpha: 0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.brand.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppPalette.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppPalette.brand.withValues(alpha: 0.16),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(displayName),
                              style: const TextStyle(
                                color: AppPalette.brandDark,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: AppPalette.strongText,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.ui(subtitle),
                                  style: const TextStyle(
                                    color: AppPalette.mutedText,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _TrustStatusStrip(
                        creditScore: creditScore,
                        rating: rating,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileShortcutGrid(
                  actions: [
                    _ProfileShortcutAction(
                      icon: CupertinoIcons.square_list_fill,
                      label: '我的发布',
                      accent: AppPalette.brand,
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const MyListingsPage(),
                          ),
                        );
                      },
                    ),
                    _ProfileShortcutAction(
                      icon: CupertinoIcons.tray_fill,
                      label: '草稿箱',
                      accent: AppPalette.yellow,
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const DraftBoxPage(),
                          ),
                        );
                      },
                    ),
                    _ProfileShortcutAction(
                      icon: CupertinoIcons.heart_fill,
                      label: '我的收藏',
                      accent: AppPalette.warmAccent,
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const FavoritesPage(),
                          ),
                        );
                      },
                    ),
                    _ProfileShortcutAction(
                      icon: CupertinoIcons.chat_bubble_2_fill,
                      label: '消息',
                      accent: AppPalette.mint,
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const ConversationsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: '交易管理',
                        subtitle: '发布、收藏和浏览记录集中在这里。',
                      ),
                      const SizedBox(height: 18),
                      AppListRow(
                        icon: CupertinoIcons.square_list_fill,
                        title: '我的发布',
                        subtitle: '管理在售、已售和下架商品',
                        trailing: AppTag(
                          label: '$listingCount 件',
                          color: AppPalette.mint,
                          textColor: AppPalette.ink,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const MyListingsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AppListRow(
                        icon: CupertinoIcons.heart_fill,
                        title: '收藏商品',
                        subtitle: '查看已经收藏的商品',
                        trailing: AppTag(
                          label: '$favoriteCount 件',
                          color: AppPalette.brandLight,
                          textColor: AppPalette.brandDark,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const FavoritesPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AppListRow(
                        icon: CupertinoIcons.clock_fill,
                        title: '浏览记录',
                        subtitle: '用于找回最近看过的商品',
                        trailing: AppTag(label: '$viewedCount 件'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: '账号设置',
                        subtitle: '资料、地址、语言和登录方式。',
                      ),
                      const SizedBox(height: 18),
                      AppListRow(
                        icon: CupertinoIcons.person_crop_circle,
                        title: '编辑资料',
                        subtitle: '昵称、简介和联系方式',
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => EditProfilePage(appUser: appUser),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AppListRow(
                        icon: CupertinoIcons.location_solid,
                        title: '地址管理',
                        subtitle: '收货地址、默认地址和联系方式',
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const AddressManagementPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AppListRow(
                        icon: CupertinoIcons.globe,
                        title: '语言',
                        subtitle: l10n.isEnglish ? 'English' : '中文',
                        trailing: AppTag(
                          label: l10n.isEnglish ? 'English' : '中文',
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const LanguageSettingsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AppListRow(
                        icon: CupertinoIcons.lock_shield_fill,
                        title: '登录与安全',
                        subtitle: _loginMethodSummary(user, l10n),
                        onTap: () => _showLoginMethods(user),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppSecondaryButton(
                  label: _isSigningOut ? '退出中...' : '退出登录并返回',
                  onPressed: _isSigningOut ? null : _signOut,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _displayName(User? user) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }

  final email = user?.email;
  if (email != null && email.isNotEmpty) {
    return email.split('@').first;
  }

  final phone = user?.phoneNumber;
  if (phone != null && phone.isNotEmpty) {
    return phone;
  }

  return '新用户';
}

String _profileSubtitle(User? user, AppUser? appUser) {
  if (appUser?.bio.isNotEmpty == true) {
    return appUser!.bio;
  }
  if (_hasProvider(user, 'google.com')) {
    return 'Google 账号已登录';
  }
  if (user?.email != null) {
    return '邮箱账号已登录';
  }
  if (user?.phoneNumber != null) {
    return '手机号账号已登录';
  }
  return '欢迎完善资料，提高交易信任度';
}

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }
  final chars = trimmed.runes.take(2).map(String.fromCharCode).join();
  return chars.toUpperCase();
}

bool _hasProvider(User? user, String providerId) {
  return user?.providerData.any(
        (provider) => provider.providerId == providerId,
      ) ??
      false;
}

String _loginMethodSummary(User? user, AppLocalizations l10n) {
  final methods = _loginMethodLabels(user);
  if (methods.isEmpty) {
    return l10n.ui('暂无已绑定登录方式');
  }
  return l10n.text(
    '${methods.join(' / ')} 已绑定',
    '${methods.map(l10n.ui).join(' / ')} linked',
  );
}

String _loginMethodDialogText(List<String> methods, AppLocalizations l10n) {
  if (methods.isEmpty) {
    return l10n.ui('暂无已绑定登录方式');
  }
  return l10n.text(
    '当前账号已绑定：${methods.join('、')}',
    'Linked methods: ${methods.map(l10n.ui).join(', ')}',
  );
}

List<String> _loginMethodLabels(User? user) {
  if (user == null) {
    return const [];
  }

  final methods = <String>[];
  if (user.phoneNumber?.isNotEmpty == true) {
    methods.add('手机号');
  }
  if (user.email?.isNotEmpty == true) {
    methods.add('邮箱');
  }
  if (_hasProvider(user, 'google.com')) {
    methods.add('Google');
  }
  return methods;
}

class _ProfileShortcutAction {
  const _ProfileShortcutAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
}

class _ProfileShortcutGrid extends StatelessWidget {
  const _ProfileShortcutGrid({required this.actions});

  final List<_ProfileShortcutAction> actions;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          for (var row = 0; row < actions.length; row += 2) ...[
            Row(
              children: [
                for (var column = 0; column < 2; column++) ...[
                  Expanded(
                    child: _ProfileShortcutTile(action: actions[row + column]),
                  ),
                  if (column == 0) const SizedBox(width: 10),
                ],
              ],
            ),
            if (row + 2 < actions.length) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ProfileShortcutTile extends StatelessWidget {
  const _ProfileShortcutTile({required this.action});

  final _ProfileShortcutAction action;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: action.onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: action.accent.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: action.accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CupertinoColors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(action.icon, color: AppPalette.brandDark, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.ui(action.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.strongText,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppPalette.mutedText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustStatusStrip extends StatelessWidget {
  const _TrustStatusStrip({required this.creditScore, required this.rating});

  final int? creditScore;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TrustPill(
          icon: CupertinoIcons.shield_lefthalf_fill,
          label: creditScore == null ? '信用未建立' : '信用分 $creditScore',
          isActive: creditScore != null,
        ),
        _TrustPill(
          icon: CupertinoIcons.star_fill,
          label: rating == null ? '评分暂无' : '评分 ${rating!.toStringAsFixed(1)}',
          isActive: rating != null,
        ),
      ],
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppPalette.surface : AppPalette.surfaceWarm,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? AppPalette.brand.withValues(alpha: 0.16)
              : AppPalette.border.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppPalette.brand : AppPalette.mutedText,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.ui(label),
            style: TextStyle(
              color: isActive ? AppPalette.brandDark : AppPalette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
