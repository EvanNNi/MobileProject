import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/address_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_components.dart';

class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  Future<void> _showAddAddressSheet() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final regionController = TextEditingController();
    final detailController = TextEditingController();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(context.l10n.ui('新增地址')),
          message: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                AppTextField(
                  controller: nameController,
                  placeholder: '收货人',
                  prefix: const Icon(
                    CupertinoIcons.person,
                    color: AppPalette.mutedText,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: phoneController,
                  placeholder: '手机号',
                  keyboardType: TextInputType.phone,
                  prefix: const Icon(
                    CupertinoIcons.phone,
                    color: AppPalette.mutedText,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: regionController,
                  placeholder: '区域',
                  prefix: const Icon(
                    CupertinoIcons.location,
                    color: AppPalette.mutedText,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: detailController,
                  placeholder: '详细地址',
                  maxLines: 2,
                  prefix: const Icon(
                    CupertinoIcons.house,
                    color: AppPalette.mutedText,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        phoneController.text.isEmpty ||
                        regionController.text.isEmpty ||
                        detailController.text.isEmpty) {
                      return;
                    }

                    try {
                      await AddressRepository.instance.addAddress(
                        name: nameController.text,
                        phone: phoneController.text,
                        region: regionController.text,
                        detail: detailController.text,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (error) {
                      if (mounted) {
                        await _showError('保存地址失败', error);
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppPalette.brand,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      context.l10n.ui('保存地址'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ui('取消')),
          ),
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    regionController.dispose();
    detailController.dispose();
  }

  Future<void> _setDefault(String id) async {
    try {
      await AddressRepository.instance.setDefault(id);
    } catch (error) {
      await _showError('设置默认地址失败', error);
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.ui('删除地址？')),
        content: Text(
          context.l10n.text(
            '确定删除“${address.region} ${address.detail}”吗？删除后不可恢复。',
            'Delete "${address.region} ${address.detail}"? This cannot be undone.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.ui('取消')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.ui('删除')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await AddressRepository.instance.deleteAddress(address.id);
    } catch (error) {
      await _showError('删除地址失败', error);
    }
  }

  Future<void> _showError(String title, Object error) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.ui(title)),
        content: Text(authErrorMessage(error)),
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
      title: '地址管理',
      previousPageTitle: '个人中心',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: _showAddAddressSheet,
        child: const Icon(
          CupertinoIcons.add,
          color: AppPalette.brand,
          size: 24,
        ),
      ),
      child: AppBackdrop(
        child: StreamBuilder<List<UserAddress>>(
          stream: AddressRepository.instance.watchAddresses(),
          builder: (context, snapshot) {
            final addresses = snapshot.data ?? const <UserAddress>[];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const AppSectionCard(
                  child: AppSectionTitle(
                    title: '收货地址与发货偏好',
                    subtitle: '地址用于后续订单、收货和发货流程。',
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    addresses.isEmpty)
                  const AppSectionCard(
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 12),
                    ),
                  )
                else if (addresses.isEmpty)
                  AppSectionCard(
                    child: Center(
                      child: Text(
                        context.l10n.ui('还没有地址，请先新增一个常用地址。'),
                        style: const TextStyle(color: AppPalette.mutedText),
                      ),
                    ),
                  )
                else
                  for (final address in addresses) ...[
                    AppSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: address.isDefault
                                      ? AppPalette.mint
                                      : AppPalette.brandLight,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  CupertinoIcons.house_fill,
                                  color: AppPalette.ink,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address.name,
                                      style: const TextStyle(
                                        color: AppPalette.strongText,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      address.phone,
                                      style: const TextStyle(
                                        color: AppPalette.mutedText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppTag(
                                label: address.tag,
                                color: address.isDefault
                                    ? AppPalette.yellow
                                    : AppPalette.brandLight,
                                textColor: AppPalette.ink,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            address.region,
                            style: const TextStyle(
                              color: AppPalette.brand,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            address.detail,
                            style: const TextStyle(
                              color: AppPalette.strongText,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppSecondaryButton(
                                  label: address.isDefault ? '默认地址' : '设为默认',
                                  onPressed: address.isDefault
                                      ? null
                                      : () => _setDefault(address.id),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppSecondaryButton(
                                  label: '删除地址',
                                  onPressed: () => _deleteAddress(address),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                AppPrimaryButton(
                  label: '新增地址',
                  onPressed: _showAddAddressSheet,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
