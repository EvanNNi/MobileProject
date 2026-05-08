import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../widgets/app_components.dart';

const Object _filterValueUnset = Object();
const double _priceSliderMin = 0;
const double _priceSliderMax = 2000;
const double _priceStep = 10;

class MarketFilter {
  const MarketFilter({
    this.minPrice,
    this.maxPrice,
    this.distance = 5,
    this.condition = '全部',
    this.brand = '全部',
  });

  final double? minPrice;
  final double? maxPrice;
  final double distance;
  final String condition;
  final String brand;

  factory MarketFilter.fromJson(Map<String, dynamic> json) {
    final rawMinPrice = _doubleValue(json['minPrice']);
    final rawMaxPrice = _doubleValue(json['maxPrice']);
    final isLegacyDefaultMax =
        !json.containsKey('minPrice') && rawMaxPrice == 500;
    final minPrice = _normalizedMinPriceBoundary(rawMinPrice);
    final maxPrice = isLegacyDefaultMax
        ? null
        : _normalizedMaxPriceBoundary(rawMaxPrice);

    return MarketFilter(
      minPrice: minPrice,
      maxPrice: maxPrice != null && minPrice != null && maxPrice < minPrice
          ? minPrice
          : maxPrice,
      distance: _doubleValue(json['distance']) ?? 5,
      condition: _stringValue(json['condition']) ?? '全部',
      brand: _stringValue(json['brand']) ?? '全部',
    );
  }

  MarketFilter copyWith({
    Object? minPrice = _filterValueUnset,
    Object? maxPrice = _filterValueUnset,
    double? distance,
    String? condition,
    String? brand,
  }) {
    return MarketFilter(
      minPrice: identical(minPrice, _filterValueUnset)
          ? this.minPrice
          : minPrice as double?,
      maxPrice: identical(maxPrice, _filterValueUnset)
          ? this.maxPrice
          : maxPrice as double?,
      distance: distance ?? this.distance,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'distance': distance,
      'condition': condition,
      'brand': brand,
    };
  }

  bool matchesPrice(int price) {
    final min = minPrice;
    if (min != null && price < min.round()) {
      return false;
    }
    final max = maxPrice;
    if (max != null && price > max.round()) {
      return false;
    }
    return true;
  }

  static double? _doubleValue(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _normalizedMinPriceBoundary(double? value) {
    if (value == null || value <= _priceSliderMin) {
      return null;
    }
    return _snapPrice(value).clamp(_priceSliderMin, _priceSliderMax).toDouble();
  }

  static double? _normalizedMaxPriceBoundary(double? value) {
    if (value == null || value >= _priceSliderMax) {
      return null;
    }
    return _snapPrice(value).clamp(_priceSliderMin, _priceSliderMax).toDouble();
  }
}

Future<MarketFilter?> showMarketFilterSheet(
  BuildContext context, {
  required MarketFilter initialFilter,
}) {
  return showCupertinoModalPopup<MarketFilter>(
    context: context,
    builder: (context) => _MarketFilterSheet(initialFilter: initialFilter),
  );
}

class _MarketFilterSheet extends StatefulWidget {
  const _MarketFilterSheet({required this.initialFilter});

  final MarketFilter initialFilter;

  @override
  State<_MarketFilterSheet> createState() => _MarketFilterSheetState();
}

class _MarketFilterSheetState extends State<_MarketFilterSheet> {
  late MarketFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          color: AppPalette.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.ui('筛选商品'),
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppPalette.mutedText,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _PriceRangeBlock(
                filter: _filter,
                onMinChanged: (value) {
                  final minPrice = _priceFromLowerSlider(value);
                  final maxPrice = _filter.maxPrice;
                  setState(() {
                    _filter = _filter.copyWith(
                      minPrice:
                          minPrice != null &&
                              maxPrice != null &&
                              minPrice > maxPrice
                          ? maxPrice
                          : minPrice,
                    );
                  });
                },
                onMaxChanged: (value) {
                  final maxPrice = _priceFromUpperSlider(value);
                  final minPrice = _filter.minPrice;
                  setState(() {
                    _filter = _filter.copyWith(
                      maxPrice:
                          maxPrice != null &&
                              minPrice != null &&
                              maxPrice < minPrice
                          ? minPrice
                          : maxPrice,
                    );
                  });
                },
              ),
              const SizedBox(height: 18),
              _SliderBlock(
                label: '距离范围',
                valueLabel: '${_filter.distance.toStringAsFixed(1)} km',
                value: _filter.distance,
                min: 0.5,
                max: 10,
                onChanged: (value) {
                  setState(() {
                    _filter = _filter.copyWith(distance: value);
                  });
                },
              ),
              const SizedBox(height: 18),
              _ChoiceBlock(
                title: '成色',
                values: marketConditions,
                selected: _filter.condition,
                onSelected: (value) {
                  setState(() {
                    _filter = _filter.copyWith(condition: value);
                  });
                },
              ),
              const SizedBox(height: 18),
              _ChoiceBlock(
                title: '品牌',
                values: marketBrands,
                selected: _filter.brand,
                onSelected: (value) {
                  setState(() {
                    _filter = _filter.copyWith(brand: value);
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: '重置',
                      onPressed: () {
                        setState(() {
                          _filter = const MarketFilter();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryButton(
                      label: '应用筛选',
                      onPressed: () => Navigator.of(context).pop(_filter),
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

double? _priceFromLowerSlider(double value) {
  final snapped = _snapPrice(value);
  return snapped <= _priceSliderMin ? null : snapped;
}

double? _priceFromUpperSlider(double value) {
  final snapped = _snapPrice(value);
  return snapped >= _priceSliderMax ? null : snapped;
}

double _snapPrice(double value) {
  final clamped = value.clamp(_priceSliderMin, _priceSliderMax).toDouble();
  return (clamped / _priceStep).round() * _priceStep;
}

String _priceLabel(BuildContext context, double? value, String unboundedLabel) {
  if (value == null) {
    return context.l10n.ui(unboundedLabel);
  }
  return '£${value.round()}';
}

class _PriceRangeBlock extends StatelessWidget {
  const _PriceRangeBlock({
    required this.filter,
    required this.onMinChanged,
    required this.onMaxChanged,
  });

  final MarketFilter filter;
  final ValueChanged<double> onMinChanged;
  final ValueChanged<double> onMaxChanged;

  @override
  Widget build(BuildContext context) {
    final minValue = filter.minPrice ?? _priceSliderMin;
    final maxValue = filter.maxPrice ?? _priceSliderMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.ui('价格范围'),
          style: const TextStyle(
            color: AppPalette.strongText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _SliderBlock(
          label: '最低价格',
          valueLabel: _priceLabel(context, filter.minPrice, '无下限'),
          value: minValue,
          min: _priceSliderMin,
          max: _priceSliderMax,
          divisions: (_priceSliderMax / _priceStep).round(),
          onChanged: onMinChanged,
        ),
        const SizedBox(height: 8),
        _SliderBlock(
          label: '最高价格',
          valueLabel: _priceLabel(context, filter.maxPrice, '无上限'),
          value: maxValue,
          min: _priceSliderMin,
          max: _priceSliderMax,
          divisions: (_priceSliderMax / _priceStep).round(),
          onChanged: onMaxChanged,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.ui('最低价拖到最左为无下限，最高价拖到最右为无上限。'),
          style: const TextStyle(
            color: AppPalette.mutedText,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SliderBlock extends StatelessWidget {
  const _SliderBlock({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.ui(label),
              style: const TextStyle(
                color: AppPalette.strongText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                color: AppPalette.brand,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        CupertinoSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppPalette.brand,
          thumbColor: AppPalette.yellow,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.ui(title),
          style: const TextStyle(
            color: AppPalette.strongText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
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
        ),
      ],
    );
  }
}
