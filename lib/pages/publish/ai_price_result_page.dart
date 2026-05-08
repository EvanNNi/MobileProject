import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../services/auth_service.dart';
import '../../services/listing_repository.dart';
import '../../widgets/app_components.dart';
import 'publish_flow_menu.dart';
import 'publish_success_page.dart';

class AiPriceResultPage extends StatefulWidget {
  const AiPriceResultPage({super.key, required this.draft});

  final ListingDraft draft;

  @override
  State<AiPriceResultPage> createState() => _AiPriceResultPageState();
}

class _AiPriceResultPageState extends State<AiPriceResultPage> {
  late double _price;
  late List<String> _selectedTags;
  bool _isPublishing = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _price = _initialPrice().toDouble();
    _selectedTags = _initialTags();
  }

  Future<void> _publish() async {
    final finalDraft = _currentDraft();
    setState(() {
      _isPublishing = true;
      _uploadProgress = 0;
    });

    try {
      final result = await ListingRepository.instance.publishListing(
        finalDraft,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => PublishSuccessPage(
            draft: finalDraft,
            listingId: result.listingId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('发布失败')),
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
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final low = widget.draft.estimatedLow;
    final high = widget.draft.estimatedHigh;
    final sliderMax = _sliderMax(low: low, high: high);
    final priceStep = _priceStep(low: low, sliderMax: sliderMax);
    final priceOptions = _priceOptions(
      low: low,
      sliderMax: sliderMax,
      step: priceStep,
    );
    final sliderIndex = _nearestPriceOptionIndex(priceOptions, _price);
    final canSlide = sliderMax > low;
    final originalPriceText = _originalPriceText(widget.draft, l10n);
    final isCustomOutOfRange = _price < low || _price > sliderMax;

    return AppPageScaffold(
      title: 'AI 估价',
      previousPageTitle: '商品信息',
      trailing: PublishFlowMenuButton(
        draftBuilder: _currentDraft,
        stage: ListingDraftResumeStage.price,
      ),
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppPalette.ink,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppTag(
                        label: '建议售价',
                        icon: CupertinoIcons.sparkles,
                        color: AppPalette.yellow,
                        textColor: AppPalette.ink,
                      ),
                      const Spacer(),
                      Text(
                        '${widget.draft.confidence}%',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '£${_price.round()}',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _priceRangeText(
                      low: low,
                      high: high,
                      sliderMax: sliderMax,
                      l10n: l10n,
                    ),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (originalPriceText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      originalPriceText,
                      style: const TextStyle(
                        color: Color(0xA6FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (canSlide) ...[
                    CupertinoSlider(
                      value: sliderIndex.toDouble(),
                      min: 0,
                      max: (priceOptions.length - 1).toDouble(),
                      divisions: priceOptions.length > 1
                          ? priceOptions.length - 1
                          : null,
                      activeColor: AppPalette.yellow,
                      thumbColor: AppPalette.mint,
                      onChanged: (value) => setState(() {
                        _price = priceOptions[value.round()].toDouble();
                      }),
                    ),
                    const SizedBox(height: 8),
                    _PriceStepControls(
                      step: priceStep,
                      canDecrease: sliderIndex > 0 && !isCustomOutOfRange,
                      canIncrease:
                          sliderIndex < priceOptions.length - 1 &&
                          !isCustomOutOfRange,
                      onDecrease: () =>
                          _setPriceFromOption(priceOptions, sliderIndex - 1),
                      onIncrease: () =>
                          _setPriceFromOption(priceOptions, sliderIndex + 1),
                    ),
                    if (isCustomOutOfRange) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.ui('当前为自定义价格，已超过滑动条范围。'),
                        style: const TextStyle(
                          color: Color(0xA6FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      l10n.text(
                        '滑动按 £$priceStep 档位调整，需要精确定价可手动输入。',
                        'Slide in £$priceStep steps. Use manual input for exact pricing.',
                      ),
                      style: const TextStyle(
                        color: Color(0xA6FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else
                    Text(
                      l10n.ui('AI 对该商品价格判断较集中，可直接使用建议价。'),
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _CustomPriceButton(onPressed: _openCustomPriceDialog),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(title: '发布文案', subtitle: '标题与描述'),
                  const SizedBox(height: 16),
                  Text(
                    l10n.listingText(widget.draft.title, widget.draft.titleEn),
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.listingText(
                      widget.draft.description,
                      widget.draft.descriptionEn,
                    ),
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const AppSectionTitle(
                    title: '商品标签',
                    subtitle: '选择已有标签，或添加自己的标签。',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _selectedTags)
                        _SelectableTag(
                          label: _displayTag(tag),
                          isSelected: true,
                          onTap: () => _removeTag(tag),
                        ),
                      _AddTagButton(onPressed: _openCustomTagDialog),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _systemTags)
                        if (!_selectedTags.contains(tag))
                          _SelectableTag(
                            label: _displayTag(tag),
                            isSelected: false,
                            onTap: () => _addTag(tag),
                          ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_isPublishing) ...[
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(
                      title: '正在上传图片',
                      subtitle: '正在同步商品图片和发布信息，请不要关闭页面。',
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8,
                        color: AppPalette.surfaceWarm,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _uploadProgress == 0
                              ? 0.18
                              : _uploadProgress.clamp(0.08, 1.0).toDouble(),
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
              label: _isPublishing ? '发布中...' : '确认发布',
              onPressed: _isPublishing ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }

  int _initialPrice() {
    final rawPrice = widget.draft.suggestedPrice > 0
        ? widget.draft.suggestedPrice
        : widget.draft.estimatedLow;
    final low = widget.draft.estimatedLow;
    final sliderMax = _sliderMax(low: low, high: widget.draft.estimatedHigh);
    if (sliderMax <= low || rawPrice < low || rawPrice > sliderMax) {
      return rawPrice;
    }
    final step = _priceStep(low: low, sliderMax: sliderMax);
    final options = _priceOptions(low: low, sliderMax: sliderMax, step: step);
    return options[_nearestPriceOptionIndex(options, rawPrice.toDouble())];
  }

  String _originalPriceText(ListingDraft draft, AppLocalizations l10n) {
    final note = draft.originalPriceNote.trim();
    if (draft.originalPrice > 0) {
      return [
        l10n.text(
          '搜索到的原价：£${draft.originalPrice}',
          'Original price found: £${draft.originalPrice}',
        ),
        if (note.isNotEmpty) note,
      ].join(' · ');
    }
    if (note.isNotEmpty) {
      return l10n.text('原价参考：$note', 'Original price reference: $note');
    }
    return '';
  }

  ListingDraft _currentDraft() {
    return widget.draft.copyWith(
      suggestedPrice: _price.round(),
      tags: _selectedTags,
      tagsEn: _selectedTags.map(_tagEnglishValue).toList(growable: false),
    );
  }

  String _tagEnglishValue(String tag) {
    for (var index = 0; index < widget.draft.tags.length; index++) {
      if (widget.draft.tags[index] == tag &&
          index < widget.draft.tagsEn.length) {
        final translated = widget.draft.tagsEn[index].trim();
        if (translated.isNotEmpty && !_containsCjk(translated)) {
          return translated;
        }
      }
    }
    return const AppLocalizations(AppLanguage.en).ui(tag);
  }

  String _displayTag(String tag) {
    final l10n = context.l10n;
    if (!l10n.isEnglish) {
      return tag;
    }

    final translated = _tagEnglishValue(tag).trim();
    if (translated.isNotEmpty && !_containsCjk(translated)) {
      return translated;
    }

    final localized = l10n.ui(tag).trim();
    if (localized.isNotEmpty && !_containsCjk(localized)) {
      return localized;
    }

    return 'Item tag';
  }

  List<String> _initialTags() {
    final candidates = [
      ...widget.draft.tags,
      widget.draft.category,
      widget.draft.condition,
      widget.draft.brand,
    ];
    return _cleanTags(candidates).take(8).toList();
  }

  List<String> get _systemTags {
    final category = widget.draft.category;
    final commonTags = [
      widget.draft.category,
      widget.draft.condition,
      widget.draft.brand,
      '功能正常',
      '成色如图',
      '支持自提',
      '当面验货',
      '可小刀',
      '有原盒',
      '无原盒',
      '配件齐全',
      '急出',
    ];

    final categoryTags = switch (category) {
      '数码' => ['通电正常', '无暗病', '轻微使用', '带线材', '学生自用'],
      '相机' => ['快门正常', '镜头干净', '含电池', '含充电器', '可试机'],
      '球鞋' => ['鞋盒还在', '鞋底正常', '可面交', '尺码准确', '少穿'],
      '箱包' => ['容量大', '通勤包', '边角正常', '五金正常', '可面交'],
      '家具' => ['需自提', '结构稳', '轻微使用', '租房适合', '可拆装'],
      _ => ['闲置转让', '可面交', '正常使用', '买前可问', '价格可谈'],
    };

    return _cleanTags([...commonTags, ...categoryTags]).take(18).toList();
  }

  List<String> _cleanTags(Iterable<String> tags) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      cleaned.add(trimmed);
    }
    return cleaned;
  }

  bool _containsCjk(String value) {
    return RegExp(r'[\u3400-\u9fff]').hasMatch(value);
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _selectedTags.contains(trimmed)) {
      return;
    }
    setState(() {
      _selectedTags = [..._selectedTags, trimmed].take(12).toList();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags = [
        for (final selectedTag in _selectedTags)
          if (selectedTag != tag) selectedTag,
      ];
    });
  }

  Future<void> _openCustomTagDialog() async {
    final controller = TextEditingController();
    String? errorText;

    try {
      final tag = await showCupertinoDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return CupertinoAlertDialog(
                title: Text(context.l10n.ui('新增标签')),
                content: Column(
                  children: [
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 12,
                      placeholder: context.l10n.ui('例如：可自提'),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(context.l10n.ui('取消')),
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        setDialogState(() {
                          errorText = context.l10n.ui('请输入标签内容');
                        });
                        return;
                      }
                      if (_selectedTags.contains(value)) {
                        setDialogState(() {
                          errorText = context.l10n.ui('这个标签已经添加过了');
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(value);
                    },
                    child: Text(context.l10n.ui('添加')),
                  ),
                ],
              );
            },
          );
        },
      );

      if (tag != null && mounted) {
        _addTag(tag);
      }
    } finally {
      controller.dispose();
    }
  }

  int _sliderMax({required int low, required int high}) {
    final rangeMax = high > low ? high : low;
    return widget.draft.originalPrice > rangeMax
        ? widget.draft.originalPrice
        : rangeMax;
  }

  int _priceStep({required int low, required int sliderMax}) {
    final range = sliderMax - low;
    if (range <= 20 || sliderMax <= 30) {
      return 1;
    }
    if (sliderMax <= 200) {
      return 5;
    }
    if (sliderMax <= 500) {
      return 10;
    }
    if (sliderMax <= 1500) {
      return 25;
    }
    if (sliderMax <= 5000) {
      return 50;
    }
    return 100;
  }

  List<int> _priceOptions({
    required int low,
    required int sliderMax,
    required int step,
  }) {
    if (sliderMax <= low) {
      return [low];
    }

    final options = <int>{low, sliderMax};
    final firstRoundedPrice = ((low + step - 1) ~/ step) * step;
    for (var price = firstRoundedPrice; price <= sliderMax; price += step) {
      options.add(price);
    }

    final sorted = options.toList()..sort();
    return sorted;
  }

  int _nearestPriceOptionIndex(List<int> options, double price) {
    if (options.isEmpty) {
      return 0;
    }

    var nearestIndex = 0;
    var nearestDistance = (options.first - price).abs();
    for (var index = 1; index < options.length; index += 1) {
      final distance = (options[index] - price).abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    return nearestIndex;
  }

  void _setPriceFromOption(List<int> priceOptions, int index) {
    if (index < 0 || index >= priceOptions.length) {
      return;
    }
    setState(() => _price = priceOptions[index].toDouble());
  }

  String _priceRangeText({
    required int low,
    required int high,
    required int sliderMax,
    required AppLocalizations l10n,
  }) {
    final aiRange = high > low
        ? l10n.text('AI 建议区间 £$low - £$high', 'AI range £$low - £$high')
        : l10n.text('AI 建议价 £$low', 'AI suggested £$low');
    if (sliderMax > high && widget.draft.originalPrice > 0) {
      return l10n.text(
        '$aiRange · 可调至原价 £$sliderMax',
        '$aiRange · adjustable to original price £$sliderMax',
      );
    }
    return aiRange;
  }

  Future<void> _openCustomPriceDialog() async {
    final controller = TextEditingController(
      text: _price.round() > 0 ? _price.round().toString() : '',
    );
    String? errorText;

    try {
      final customPrice = await showCupertinoDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return CupertinoAlertDialog(
                title: Text(context.l10n.ui('输入任意售价')),
                content: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(context.l10n.ui('可以输入超过滑动范围的价格，发布前仍建议结合买家议价空间。')),
                    const SizedBox(height: 14),
                    CupertinoTextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      placeholder: context.l10n.ui('输入价格'),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          '£',
                          style: TextStyle(
                            color: AppPalette.strongText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(context.l10n.ui('取消')),
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: () {
                      final price = _parseCustomPrice(controller.text);
                      if (price == null) {
                        setDialogState(() {
                          errorText = context.l10n.ui('请输入大于 0 的整数价格');
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(price);
                    },
                    child: Text(context.l10n.ui('使用价格')),
                  ),
                ],
              );
            },
          );
        },
      );

      if (customPrice != null && mounted) {
        setState(() => _price = customPrice.toDouble());
      }
    } finally {
      controller.dispose();
    }
  }

  int? _parseCustomPrice(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    final price = int.tryParse(normalized);
    if (price == null || price <= 0) {
      return null;
    }
    return price;
  }
}

class _PriceStepControls extends StatelessWidget {
  const _PriceStepControls({
    required this.step,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int step;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PriceStepButton(
          label: '-£$step',
          isEnabled: canDecrease,
          onPressed: onDecrease,
        ),
        Expanded(
          child: Center(
            child: Text(
              context.l10n.text('一档 £$step', '£$step step'),
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _PriceStepButton(
          label: '+£$step',
          isEnabled: canIncrease,
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

class _PriceStepButton extends StatelessWidget {
  const _PriceStepButton({
    required this.label,
    required this.isEnabled,
    required this.onPressed,
  });

  final String label;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: isEnabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: isEnabled ? 1 : 0.38,
        child: Container(
          height: 36,
          width: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CupertinoColors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: CupertinoColors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomPriceButton extends StatelessWidget {
  const _CustomPriceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: CupertinoColors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CupertinoColors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.pencil_circle_fill,
              color: AppPalette.yellow,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.ui('输入任意价格'),
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableTag extends StatelessWidget {
  const _SelectableTag({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AppTag(
        label: isSelected ? '$label ×' : '+ $label',
        color: isSelected ? AppPalette.yellow : AppPalette.brandLight,
        textColor: isSelected ? AppPalette.ink : AppPalette.brandDark,
      ),
    );
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: AppTag(
        label: '+ 自定义',
        icon: CupertinoIcons.plus_circle_fill,
        color: AppPalette.surfaceWarm,
        textColor: AppPalette.brand,
      ),
    );
  }
}
