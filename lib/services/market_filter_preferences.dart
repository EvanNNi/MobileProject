import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../pages/market/market_filter_sheet.dart';

class MarketFilterPreferences {
  MarketFilterPreferences._();

  static final instance = MarketFilterPreferences._();

  static const _homeFilterFileName = 'market_home_filter.json';

  Future<MarketFilter> loadHomeFilter() async {
    try {
      final file = await _homeFilterFile();
      if (!await file.exists()) {
        return const MarketFilter();
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return MarketFilter.fromJson(decoded);
      }
      if (decoded is Map) {
        return MarketFilter.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Corrupt local preferences should never block the marketplace.
    }

    return const MarketFilter();
  }

  Future<void> saveHomeFilter(MarketFilter filter) async {
    try {
      final file = await _homeFilterFile();
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(filter.toJson()));
    } catch (_) {
      // Keep filtering responsive even if local persistence is unavailable.
    }
  }

  Future<File> _homeFilterFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_homeFilterFileName');
  }
}
