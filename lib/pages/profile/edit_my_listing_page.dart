import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../services/auth_service.dart';
import '../../services/listing_repository.dart';
import '../../services/location_service.dart';
import '../../widgets/app_components.dart';
import '../publish/publish_location_picker_page.dart';

class EditMyListingPage extends StatefulWidget {
  const EditMyListingPage({super.key, required this.item});

  final MarketItem item;

  @override
  State<EditMyListingPage> createState() => _EditMyListingPageState();
}

class _EditMyListingPageState extends State<EditMyListingPage> {
  late String _category;
  late String _condition;
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late double _latitude;
  late double _longitude;
  late String _locationDetail;
  bool _isSaving = false;

  final List<String> _categories = const ['数码', '球鞋', '箱包', '相机', '家具', '其他'];
  final List<String> _conditions = const ['全新', '几乎全新', '轻微使用', '明显使用', '无法判断'];

  @override
  void initState() {
    super.initState();
    _category = widget.item.category;
    _condition = widget.item.condition;
    _titleController = TextEditingController(text: widget.item.title);
    _priceController = TextEditingController(
      text: widget.item.price.toString(),
    );
    _brandController = TextEditingController(text: widget.item.brand);
    _modelController = TextEditingController(text: widget.item.model);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _locationController = TextEditingController(text: widget.item.location);
    _latitude = widget.item.latitude;
    _longitude = widget.item.longitude;
    _locationDetail = _hasLocation
        ? '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}'
        : '尚未选择发布地址';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _hasLocation =>
      _locationController.text.trim().isNotEmpty ||
      _latitude != 0 ||
      _longitude != 0;

  Future<void> _openLocationPicker() async {
    final location = await Navigator.of(context).push<AppLocation>(
      CupertinoPageRoute<AppLocation>(
        builder: (_) => PublishLocationPickerPage(
          initialLocation: AppLocation(
            latitude: _latitude,
            longitude: _longitude,
            name: _locationController.text.trim().isEmpty
                ? '待选择位置'
                : _locationController.text.trim(),
            detail: _hasLocation ? _locationDetail : '请使用 GPS 或点击地图选择',
          ),
        ),
      ),
    );

    if (!mounted || location == null) {
      return;
    }

    setState(() {
      _locationController.text = location.name;
      _latitude = location.latitude;
      _longitude = location.longitude;
      _locationDetail = location.detail;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final price = _parsePrice(_priceController.text);

    if (title.isEmpty || price == null) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('无法保存')),
          content: Text(context.l10n.ui('请填写商品标题，并输入大于 0 的整数价格。')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.ui('知道了')),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ListingRepository.instance.updateListingDetails(
        listingId: widget.item.id,
        title: title,
        description: _descriptionController.text,
        category: _category,
        condition: _condition,
        brand: _brandController.text,
        model: _modelController.text,
        price: price,
        locationLabel: _locationController.text,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('保存失败')),
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
        setState(() => _isSaving = false);
      }
    }
  }

  int? _parsePrice(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    final price = int.tryParse(normalized);
    if (price == null || price <= 0) {
      return null;
    }
    return price;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppPageScaffold(
      title: '修改商品',
      previousPageTitle: '我的发布',
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: '商品状态',
                    subtitle: '这里只修改已经发布的商品信息。',
                  ),
                  const SizedBox(height: 14),
                  AppTag(
                    label: _listingStatusLabel(widget.item.status),
                    icon: CupertinoIcons.cube_box_fill,
                    color: _listingStatusColor(widget.item.status),
                    textColor: AppPalette.ink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ui('商品分类'),
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChoiceWrap(
                    values: _categories,
                    selected: _category,
                    onSelected: (value) => setState(() => _category = value),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.ui('成色'),
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChoiceWrap(
                    values: _conditions,
                    selected: _condition,
                    onSelected: (value) => setState(() => _condition = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _titleController,
                    placeholder: '商品标题',
                    prefix: const Icon(
                      CupertinoIcons.textformat,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _priceController,
                    placeholder: '售价',
                    keyboardType: TextInputType.number,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        '£',
                        style: TextStyle(
                          color: AppPalette.mutedText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _brandController,
                    placeholder: '品牌',
                    prefix: const Icon(
                      CupertinoIcons.tag_fill,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _modelController,
                    placeholder: '型号',
                    prefix: const Icon(
                      CupertinoIcons.barcode,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _descriptionController,
                    placeholder: '商品描述',
                    maxLines: 4,
                    prefix: const Icon(
                      CupertinoIcons.doc_text_fill,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
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
                    title: '发布地址',
                    subtitle: '修改后会影响商品详情页和地图上的展示位置。',
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _locationController,
                    placeholder: '发布地点，例如学校附近、地铁站附近',
                    prefix: const Icon(
                      CupertinoIcons.location_solid,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LocationSummary(
                    detail: _locationDetail,
                    latitude: _latitude,
                    longitude: _longitude,
                    hasLocation: _hasLocation,
                  ),
                  const SizedBox(height: 14),
                  AppSecondaryButton(
                    label: '在地图上重新选择',
                    onPressed: _openLocationPicker,
                    leading: const Icon(
                      CupertinoIcons.map_pin_ellipse,
                      color: AppPalette.brand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              label: _isSaving ? '保存中...' : '保存修改',
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.detail,
    required this.latitude,
    required this.longitude,
    required this.hasLocation,
  });

  final String detail;
  final double latitude;
  final double longitude;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.map, color: AppPalette.brand, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.ui(detail),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasLocation
                      ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
                      : context.l10n.ui('请在发布前选择一个大致位置'),
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => onSelected(value),
            child: AppTag(
              label: value,
              color: value == selected
                  ? AppPalette.yellow
                  : AppPalette.brandLight,
              textColor: AppPalette.ink,
            ),
          ),
      ],
    );
  }
}

String _listingStatusLabel(String status) {
  return switch (status) {
    'sold' => '已售',
    'inactive' => '已下架',
    _ => '在售',
  };
}

Color _listingStatusColor(String status) {
  return switch (status) {
    'sold' => AppPalette.yellow,
    'inactive' => AppPalette.surfaceWarm,
    _ => AppPalette.mint,
  };
}
