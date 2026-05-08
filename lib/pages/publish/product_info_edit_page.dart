import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../services/ai_listing_analysis_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_components.dart';
import 'ai_price_result_page.dart';
import 'publish_flow_menu.dart';
import 'publish_location_picker_page.dart';

class ProductInfoEditPage extends StatefulWidget {
  const ProductInfoEditPage({super.key, required this.draft});

  final ListingDraft draft;

  @override
  State<ProductInfoEditPage> createState() => _ProductInfoEditPageState();
}

class _ProductInfoEditPageState extends State<ProductInfoEditPage> {
  late String _category;
  late String _condition;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _titleEnController;
  late final TextEditingController _descriptionEnController;
  late final TextEditingController _supplementController;
  late final TextEditingController _locationController;
  late double _selectedLatitude;
  late double _selectedLongitude;
  late String _selectedLocationDetail;
  bool _isAnalyzing = false;
  bool _isLocating = false;
  double _analysisProgress = 0;
  String? _locationMessage;

  final List<String> _categories = const ['数码', '球鞋', '箱包', '相机', '家具', '其他'];
  final List<String> _conditions = const ['全新', '几乎全新', '轻微使用', '明显使用', '无法判断'];

  @override
  void initState() {
    super.initState();
    _category = widget.draft.category;
    _condition = widget.draft.condition;
    _brandController = TextEditingController(text: widget.draft.brand);
    _modelController = TextEditingController(text: widget.draft.model);
    _titleController = TextEditingController(text: widget.draft.title);
    _descriptionController = TextEditingController(
      text: widget.draft.description,
    );
    _titleEnController = TextEditingController(
      text: _englishDraftText(widget.draft.titleEn, widget.draft.title),
    );
    _descriptionEnController = TextEditingController(
      text: _englishDraftText(
        widget.draft.descriptionEn,
        widget.draft.description,
      ),
    );
    _supplementController = TextEditingController(
      text: widget.draft.aiSupplement,
    );
    _locationController = TextEditingController(
      text: widget.draft.locationLabel,
    );
    _selectedLatitude = widget.draft.latitude;
    _selectedLongitude = widget.draft.longitude;
    _selectedLocationDetail = _hasSelectedLocation
        ? '${widget.draft.latitude.toStringAsFixed(4)}, ${widget.draft.longitude.toStringAsFixed(4)}'
        : '尚未选择发布地址';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasSelectedLocation) {
        _useCurrentLocation(isAutomatic: true);
      }
    });
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _titleEnController.dispose();
    _descriptionEnController.dispose();
    _supplementController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  ListingDraft _currentDraft() {
    return widget.draft.copyWith(
      category: _category,
      condition: _condition,
      brand: _brandController.text,
      model: _modelController.text,
      title: _titleController.text,
      description: _descriptionController.text,
      titleEn: _titleEnController.text,
      descriptionEn: _descriptionEnController.text,
      aiSupplement: _supplementController.text,
      locationLabel: _locationController.text,
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
    );
  }

  String _englishDraftText(String englishValue, String chineseValue) {
    final trimmedEnglish = englishValue.trim();
    if (trimmedEnglish.isNotEmpty) {
      return trimmedEnglish;
    }
    return const AppLocalizations(AppLanguage.en).ui(chineseValue);
  }

  Future<void> _openLocationPicker() async {
    final location = await Navigator.of(context).push<AppLocation>(
      CupertinoPageRoute<AppLocation>(
        builder: (_) => PublishLocationPickerPage(
          initialLocation: AppLocation(
            latitude: _selectedLatitude,
            longitude: _selectedLongitude,
            name: _locationController.text.trim().isEmpty
                ? '待选择位置'
                : _locationController.text.trim(),
            detail: _hasSelectedLocation
                ? _selectedLocationDetail
                : '请使用 GPS 或点击地图选择',
          ),
          geocodingLanguage: _geocodingLanguage(context),
        ),
      ),
    );

    if (!mounted || location == null) {
      return;
    }

    _applyLocation(location, message: '已手动选择发布位置');
  }

  bool get _hasSelectedLocation =>
      _locationController.text.trim().isNotEmpty ||
      _selectedLatitude != 0 ||
      _selectedLongitude != 0;

  Future<void> _useCurrentLocation({bool isAutomatic = false}) async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
      _locationMessage = isAutomatic ? '正在自动识别当前位置...' : '正在重新定位...';
    });

    try {
      final l10n = context.l10n;
      final location = await LocationService.instance.getCurrentLocation(
        language: _geocodingLanguage(context),
        fallbackName: l10n.ui('当前位置'),
      );
      if (!mounted) {
        return;
      }
      _applyLocation(
        location,
        message: isAutomatic ? '已自动识别当前位置，可手动更改' : '已更新为当前位置',
      );
    } on LocationServiceException catch (error) {
      if (mounted) {
        setState(() => _locationMessage = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _locationMessage = '定位失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _applyLocation(AppLocation location, {required String message}) {
    setState(() {
      _locationController.text = location.name;
      _selectedLatitude = location.latitude;
      _selectedLongitude = location.longitude;
      _selectedLocationDetail = location.detail;
      _locationMessage = message;
    });
  }

  Future<void> _openEstimate() async {
    final draft = _currentDraft();
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0;
    });

    try {
      final analyzedDraft = await AiListingAnalysisService.instance
          .analyzeDraft(
            draft,
            stage: AiListingAnalysisStage.pricing,
            userConditionHint: _pricingHint(),
            onProgress: (progress) {
              if (mounted) {
                setState(() => _analysisProgress = progress);
              }
            },
          );
      if (!mounted) {
        return;
      }
      _navigateToEstimate(analyzedDraft);
    } on AiListingAnalysisException catch (error) {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('AI 估价失败')),
          content: Text(error.message),
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
        setState(() {
          _isAnalyzing = false;
          _analysisProgress = 0;
        });
      }
    }
  }

  void _navigateToEstimate(ListingDraft draft) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => AiPriceResultPage(draft: draft)),
    );
  }

  String _pricingHint() {
    final supplement = _supplementController.text.trim();
    return [
      '用户确认成色：$_condition',
      if (supplement.isNotEmpty) '用户补充：$supplement',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleController = l10n.isEnglish
        ? _titleEnController
        : _titleController;
    final descriptionController = l10n.isEnglish
        ? _descriptionEnController
        : _descriptionController;
    final visibleTags = l10n.listingTags(
      widget.draft.tags,
      widget.draft.tagsEn,
    );

    return AppPageScaffold(
      title: '商品信息',
      previousPageTitle: '图片预览',
      trailing: PublishFlowMenuButton(
        draftBuilder: _currentDraft,
        stage: ListingDraftResumeStage.info,
      ),
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: AppSectionTitle(
                          title: '图片识别结果',
                          subtitle: '如果识别有误，可以在这里修改或补充。',
                        ),
                      ),
                      AppTag(
                        label: '${widget.draft.confidence}%',
                        icon: CupertinoIcons.check_mark_circled_solid,
                        color: AppPalette.yellow,
                        textColor: AppPalette.ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in visibleTags) AppTag(label: tag),
                    ],
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
                    controller: titleController,
                    placeholder: '商品标题',
                    prefix: const Icon(
                      CupertinoIcons.textformat,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: descriptionController,
                    placeholder: '商品描述',
                    maxLines: 4,
                    prefix: const Icon(
                      CupertinoIcons.doc_text_fill,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _supplementController,
                    placeholder: '补充给 AI 的信息，例如：有原盒、无划痕、电池健康 92%',
                    maxLines: 3,
                    prefix: const Icon(
                      CupertinoIcons.sparkles,
                      color: AppPalette.mutedText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const AppSectionTitle(
                    title: '发布位置',
                    subtitle: '自动定位或在地图上选择大致位置。',
                  ),
                  const SizedBox(height: 12),
                  _LocationSummary(
                    name: _locationController.text,
                    detail: _selectedLocationDetail,
                    hasLocation: _hasSelectedLocation,
                  ),
                  if (_locationMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.ui(_locationMessage!),
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppSecondaryButton(
                          label: _isLocating ? '定位中' : '自动定位',
                          onPressed: _isLocating
                              ? null
                              : () => _useCurrentLocation(),
                          leading: _isLocating
                              ? const CupertinoActivityIndicator(radius: 9)
                              : const Icon(
                                  CupertinoIcons.scope,
                                  color: AppPalette.brand,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppSecondaryButton(
                          label: '手动选择',
                          onPressed: _openLocationPicker,
                          leading: const Icon(
                            CupertinoIcons.map_pin_ellipse,
                            color: AppPalette.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_isAnalyzing) ...[
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(
                      title: '正在调用 AI 估价',
                      subtitle: '会根据你修正后的识别信息、补充说明和图片生成建议售价。',
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8,
                        color: AppPalette.surfaceWarm,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _analysisProgress == 0
                              ? 0.12
                              : _analysisProgress.clamp(0.08, 1.0).toDouble(),
                          child: Container(color: AppPalette.brand),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            AppPrimaryButton(
              label: _isAnalyzing ? 'AI 估价中...' : '确认信息，开始 AI 估价',
              onPressed: _isAnalyzing ? null : _openEstimate,
            ),
          ],
        ),
      ),
    );
  }
}

String _geocodingLanguage(BuildContext context) {
  return context.l10n.isEnglish ? 'en' : 'zh-Hans';
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.name,
    required this.detail,
    required this.hasLocation,
  });

  final String name;
  final String detail;
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
                  _displayName(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _displayDetail(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  String _displayName(BuildContext context) {
    if (!hasLocation) {
      return context.l10n.ui('发布位置');
    }
    final value = name.trim();
    if (value.isEmpty) {
      return context.l10n.ui('大致位置已选择');
    }
    return _localizedOrGeneric(context, value, '发布位置');
  }

  String _displayDetail(BuildContext context) {
    if (!hasLocation) {
      return context.l10n.ui('请使用自动定位或手动选择发布位置');
    }
    final value = detail.trim();
    if (value.isEmpty || _isCoordinatePair(value)) {
      return context.l10n.ui('大致位置已选择');
    }
    return _localizedOrGeneric(context, value, '大致位置已选择');
  }

  String _localizedOrGeneric(
    BuildContext context,
    String value,
    String genericChineseKey,
  ) {
    final localized = context.l10n.ui(value);
    if (context.l10n.isEnglish &&
        localized == value &&
        _containsCjk(localized)) {
      return context.l10n.ui(genericChineseKey);
    }
    return localized;
  }

  bool _isCoordinatePair(String value) {
    return RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(value);
  }

  bool _containsCjk(String value) {
    return RegExp(r'[\u3400-\u9fff]').hasMatch(value);
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
