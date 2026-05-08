import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

enum AppLanguage { zh, en }

class AppLanguageController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.zh;
  bool _hasCompletedInitialLanguageChoice = false;

  AppLanguage get language => _language;
  bool get hasCompletedInitialLanguageChoice =>
      _hasCompletedInitialLanguageChoice;

  Future<void> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return;
      }
      final data = jsonDecode(await file.readAsString());
      final languageName = data is Map ? data['language'] as String? : null;
      _language = AppLanguage.values.firstWhere(
        (language) => language.name == languageName,
        orElse: () => AppLanguage.zh,
      );
      _hasCompletedInitialLanguageChoice = data is Map
          ? data['hasCompletedInitialLanguageChoice'] as bool? ??
                languageName != null
          : false;
    } catch (_) {
      _language = AppLanguage.zh;
      _hasCompletedInitialLanguageChoice = false;
    }
  }

  Future<void> setLanguage(
    AppLanguage language, {
    bool completeInitialChoice = true,
  }) async {
    final shouldNotify =
        _language != language ||
        (completeInitialChoice && !_hasCompletedInitialLanguageChoice);
    _language = language;
    if (completeInitialChoice) {
      _hasCompletedInitialLanguageChoice = true;
    }
    if (shouldNotify) {
      notifyListeners();
    }

    final file = await _settingsFile();
    await file.writeAsString(
      jsonEncode({
        'language': language.name,
        'hasCompletedInitialLanguageChoice': _hasCompletedInitialLanguageChoice,
      }),
    );
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    final settingsDirectory = Directory('${directory.path}/settings');
    if (!await settingsDirectory.exists()) {
      await settingsDirectory.create(recursive: true);
    }
    return File('${settingsDirectory.path}/language.json');
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing from the widget tree.');
    return scope!.notifier!;
  }

  static AppLanguageController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppLanguageScope>();
    final scope = element?.widget as AppLanguageScope?;
    assert(scope != null, 'AppLanguageScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}

class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  bool get isEnglish => language == AppLanguage.en;

  Locale get locale =>
      isEnglish ? const Locale('en') : const Locale('zh', 'CN');

  String get appTitle => text('物光', 'Luma');

  String text(String zh, String en) => isEnglish ? en : zh;

  String listingText(String zh, String en) {
    if (isEnglish && en.trim().isNotEmpty) {
      return en.trim();
    }
    return ui(zh);
  }

  List<String> listingTags(List<String> zh, List<String> en) {
    if (isEnglish && en.isNotEmpty) {
      return en.where((tag) => tag.trim().isNotEmpty).toList(growable: false);
    }
    return zh;
  }

  String ui(String value) {
    if (!isEnglish) {
      return value;
    }
    final translated = _dictionary[value];
    if (translated != null) {
      return translated;
    }
    return _translateDynamic(value);
  }

  String _translateDynamic(String value) {
    final imageCount = RegExp(r'^(\d+) 张图$').firstMatch(value);
    if (imageCount != null) {
      return '${imageCount.group(1)} photos';
    }

    final itemCount = RegExp(r'^(\d+) 件$').firstMatch(value);
    if (itemCount != null) {
      return '${itemCount.group(1)} items';
    }

    final creditScore = RegExp(r'^信用分 (\d+)$').firstMatch(value);
    if (creditScore != null) {
      return 'Credit ${creditScore.group(1)}';
    }

    final rating = RegExp(r'^评分 ([\\d.]+)$').firstMatch(value);
    if (rating != null) {
      return 'Rating ${rating.group(1)}';
    }

    final listingCount = RegExp(r'^(\d+) 件发布$').firstMatch(value);
    if (listingCount != null) {
      return '${listingCount.group(1)} listings';
    }

    final draftCount = RegExp(r'^(\d+) 个$').firstMatch(value);
    if (draftCount != null) {
      return '${draftCount.group(1)} drafts';
    }

    final recognizedItem = RegExp(r'^物品 (\d+)$').firstMatch(value);
    if (recognizedItem != null) {
      return 'Item ${recognizedItem.group(1)}';
    }

    final recognizedCount = RegExp(r'^识别到 (\d+) 个物品$').firstMatch(value);
    if (recognizedCount != null) {
      return '${recognizedCount.group(1)} item found';
    }

    final filtered = RegExp(r'^筛选后 (\d+) 件商品$').firstMatch(value);
    if (filtered != null) {
      return '${filtered.group(1)} items after filters';
    }

    final matched = RegExp(r'^(\d+) 件匹配商品$').firstMatch(value);
    if (matched != null) {
      return '${matched.group(1)} matching items';
    }

    final savedAt = RegExp(r'^保存于 (.+)$').firstMatch(value);
    if (savedAt != null) {
      return 'Saved ${ui(savedAt.group(1)!)}';
    }

    final minutes = RegExp(r'^(\d+) 分钟前$').firstMatch(value);
    if (minutes != null) {
      return '${minutes.group(1)} min ago';
    }
    final updatedMinutes = RegExp(r'^(\d+) 分钟前更新$').firstMatch(value);
    if (updatedMinutes != null) {
      return 'Updated ${updatedMinutes.group(1)} min ago';
    }
    final hours = RegExp(r'^(\d+) 小时前$').firstMatch(value);
    if (hours != null) {
      return '${hours.group(1)} hr ago';
    }
    final updatedHours = RegExp(r'^(\d+) 小时前更新$').firstMatch(value);
    if (updatedHours != null) {
      return 'Updated ${updatedHours.group(1)} hr ago';
    }
    final days = RegExp(r'^(\d+) 天前$').firstMatch(value);
    if (days != null) {
      return '${days.group(1)} days ago';
    }
    final updatedDays = RegExp(r'^(\d+) 天前更新$').firstMatch(value);
    if (updatedDays != null) {
      return 'Updated ${updatedDays.group(1)} days ago';
    }

    if (_containsCjk(value)) {
      return _translateMarketplaceText(value);
    }

    return value;
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n {
    final scope = dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return AppLocalizations(scope?.notifier?.language ?? AppLanguage.zh);
  }

  String t(String zh, String en) => l10n.text(zh, en);
}

const Map<String, String> _dictionary = {
  '返回': 'Back',
  '知道了': 'OK',
  '取消': 'Cancel',
  '确认': 'Confirm',
  '继续': 'Continue',
  '删除': 'Delete',
  '添加': 'Add',
  '保存': 'Save',
  '首页': 'Home',
  '搜索': 'Search',
  '卖闲置': 'Sell',
  '消息': 'Messages',
  '我的': 'Me',
  '个人中心': 'Profile',
  '选择语言': 'Choose Language',
  '先选择你想使用的语言': 'Choose the language you want to use first.',
  '之后可以在个人中心随时切换。': 'You can switch it later in Profile.',
  '开始使用 Luma': 'Start Using Luma',
  '让 AI 帮你更快卖出闲置物品。': 'Let AI help you sell unused items faster.',
  '登录或注册账号': 'Sign in or Create Account',
  '登录账号': 'Sign In',
  '注册账号': 'Create Account',
  '已有账号就直接登录，新用户可以先注册。':
      'Sign in if you already have an account, or create one if you are new.',
  '拍照识别、AI 估价、聊天交易都在这里开始。':
      'Photo recognition, AI pricing, chat, and trading all start here.',
  '收藏夹': 'Favorites',
  '我的收藏': 'My Favorites',
  '关注价格变化和卖家动态': 'Track price changes and seller updates',
  '还没有收藏商品': 'No saved items yet',
  '收藏加载失败': 'Could not load favorites',
  '搜索商品、品牌、型号': 'Search item, brand, or model',
  '搜索当前分类': 'Search this category',
  '搜索结果': 'Search Results',
  '筛选结果': 'Filtered Results',
  '开始搜索': 'Start Searching',
  '输入关键词，或点上方标签快速搜索。': 'Enter a keyword, or tap a tag above to search quickly.',
  '还没有输入搜索内容': 'No search yet',
  '搜索商品名、品牌、型号，或直接点击上方标签。':
      'Search by item name, brand, model, or tap a tag above.',
  '正在同步最新商品': 'Syncing latest items',
  '没有找到匹配商品': 'No matching items found',
  '分类': 'Categories',
  '推荐': 'Recommended',
  '数码': 'Tech',
  '球鞋': 'Sneakers',
  '箱包': 'Bags',
  '相机': 'Cameras',
  '家具': 'Furniture',
  '其他': 'Other',
  '耳机': 'Headphones',
  '显示器': 'Monitor',
  '包袋': 'Bags',
  '附近优先': 'Nearby first',
  '当前分类暂无商品': 'No items in this category yet',
  '附近发布': 'Nearby Listings',
  '同步中': 'Syncing',
  '暂时无法读取商品': 'Could not load items',
  '请先选择浏览位置': 'Choose a browsing location first',
  '选择当前位置后，会保存为常用浏览位置。':
      'After choosing your current location, it will be saved for next time.',
  '附近暂时没有商品': 'No nearby items yet',
  '附近还没有人发布商品，稍后再来看看。': 'No one has listed nearby yet. Check back later.',
  '可以更换浏览位置，或放宽右侧筛选条件再看看。': 'Try another location or loosen the filters.',
  '选择浏览位置': 'Choose Location',
  '像外卖软件一样，先选位置，再看附近发布的商品。':
      'Choose a location first, then browse nearby listings.',
  '使用当前定位': 'Use current location',
  '在地图上选择位置': 'Choose on map',
  '浏览位置': 'Browsing location',
  '选择后首页会展示该位置附近的商品': 'Home will show items near this location.',
  '使用此位置': 'Use this location',
  '点击地图选择浏览位置': 'Tap the map to choose browsing location',
  '移动地图，将中心点对准浏览位置':
      'Move the map and place the center pin on your browsing location',
  '已选择浏览位置': 'Browsing location selected',
  '常用位置': 'Saved locations',
  '暂无常用位置': 'No saved locations yet',
  '点击上方“使用当前定位”后，会自动保存为常用位置。':
      'Use current location above to save it for next time.',
  '商品信息': 'Item Info',
  '品牌、型号、位置': 'Brand, model, location',
  '品牌': 'Brand',
  '型号': 'Model',
  '卖家': 'Seller',
  '位置': 'Location',
  '查看发布地点': 'View Location',
  '管理这个商品': 'Manage This Item',
  '已点赞': 'Liked',
  '点赞': 'Like',
  '联系卖家': 'Contact Seller',
  '发布地点': 'Listing Location',
  '地图查看': 'Map View',
  '附近同类商品': 'Similar Nearby Items',
  '附近类似商品': 'Similar Nearby Items',
  '在地图上查看': 'View on Map',
  '这些商品还没有发布位置': 'These items do not have listing locations yet',
  '发布商品时添加位置后，就能在地图上查看附近商品。':
      'Add a location when listing an item to view nearby items on the map.',
  '正在同步附近商品': 'Syncing nearby items',
  '可以横向比较距离和价格': 'Compare distance and price',
  '附近暂时没有同类商品': 'No similar nearby items yet',
  '卖家发布位置': 'Seller location',
  '筛选商品': 'Filter Items',
  '价格范围': 'Price range',
  '最低价格': 'Min price',
  '最高价格': 'Max price',
  '无下限': 'No minimum',
  '无上限': 'No maximum',
  '最低价拖到最左为无下限，最高价拖到最右为无上限。':
      'Drag the minimum to the far left for no minimum, and the maximum to the far right for no maximum.',
  '距离范围': 'Distance',
  '成色': 'Condition',
  '全部': 'All',
  '全新': 'New',
  '几乎全新': 'Like new',
  '轻微使用': 'Lightly used',
  '明显使用': 'Used',
  '无法判断': 'Unknown',
  '未知': 'Unknown',
  '未知品牌': 'Unknown brand',
  '未知型号': 'Unknown model',
  '未知位置': 'Unknown location',
  '未命名商品': 'Untitled item',
  '咨询商品': 'Item inquiry',
  '重置': 'Reset',
  '应用筛选': 'Apply Filters',
  '欢迎回来': 'Welcome Back',
  '用手机号、邮箱或 Google 进入 Luma。': 'Sign in to Luma with phone, email, or Google.',
  '邮箱': 'Email',
  '手机号': 'Phone',
  '输入邮箱地址': 'Email address',
  '输入密码': 'Password',
  '手机号，例如 +86 138...': 'Phone, e.g. +44 7...',
  '验证码会发送到这个手机号': 'Code will be sent to this number',
  '输入短信验证码': 'SMS code',
  '短信登录需要手机号可以接收验证码。': 'Phone sign-in requires receiving a verification code.',
  '登录即代表同意平台服务协议与隐私政策':
      'By signing in, you agree to the Terms and Privacy Policy.',
  '忘记密码': 'Forgot password',
  '登录中...': 'Signing in...',
  '发送中...': 'Sending...',
  '发送短信验证码': 'Send SMS code',
  '验证码登录并进入市场': 'Sign in with code',
  '登录并进入市场': 'Sign in',
  '重新发送中...': 'Resending...',
  '重新发送验证码': 'Resend code',
  '处理中...': 'Processing...',
  '使用 Google 继续': 'Continue with Google',
  'AI 发布效率': 'AI-assisted selling',
  '快': 'Fast',
  '少花时间写标题和定价': 'Less time writing titles and pricing',
  '交易体验': 'Trade experience',
  '稳': 'Smooth',
  '聊天、收藏和发布统一管理': 'Chats, saves, and listings in one place',
  '识别标题、描述和分类': 'Create titles, descriptions, and categories',
  '快速交易': 'Quick trading',
  '收藏、地图和消息': 'Saves, map, and messages',
  '还没有账号？': 'No account yet?',
  '立即注册': 'Sign up',
  '注册': 'Register',
  '创建你的账号': 'Create Your Account',
  '一个账号即可浏览、购买和发布闲置商品。': 'One account lets you browse, buy, and list items.',
  '邮箱注册': 'Email',
  '手机号注册': 'Phone',
  '昵称或姓名': 'Name or nickname',
  '设置密码': 'Set password',
  '确认密码': 'Confirm password',
  '收藏好物': 'Save items',
  '收货地址': 'Addresses',
  '订单保障': 'Order protection',
  '使用 Google 继续注册': 'Continue with Google',
  '找回账号访问权限': 'Recover Account Access',
  '我们会发送密码重置邮件，不在 App 内直接保存新密码。': 'We will send a password reset email.',
  '邮箱找回': 'Email',
  '手机号找回': 'Phone',
  '输入注册邮箱': 'Registered email',
  '发送重置邮件': 'Send reset email',
  '返回登录页': 'Back to sign in',
  '信用分': 'Credit',
  '高于 91% 用户': 'Above 91% users',
  '未建立': 'Not established',
  '完成交易后生成': 'Generated after completed trades',
  '基于交易履约记录': 'Based on transaction history',
  '交易评分': 'Rating',
  '来自买卖双方评价': 'From buyer and seller reviews',
  '暂无': 'None yet',
  '完成交易后显示': 'Shown after completed trades',
  '地址': 'Address',
  '草稿': 'Drafts',
  '信用未建立': 'Credit not ready',
  '评分暂无': 'No rating yet',
  '交易管理': 'Trading',
  '发布、收藏和浏览记录集中在这里。': 'Listings, saved items, and view history live here.',
  '管理在售、已售和下架商品': 'Manage active, sold, and delisted items',
  '查看已经收藏的商品': 'View saved items',
  '用于找回最近看过的商品': 'Find recently viewed items',
  '账号设置': 'Account Settings',
  '资料、地址、语言和登录方式。': 'Profile, address, language, and sign-in.',
  '昵称、简介和联系方式': 'Name, bio, and contact',
  '收货地址、默认地址和联系方式': 'Delivery address, default address, and contact',
  '登录与安全': 'Sign-in & Security',
  '暂无已绑定登录方式': 'No linked sign-in method yet',
  '账号概览': 'Account Overview',
  '浏览、收藏、发布和账号安全都在这里统一管理。':
      'Browsing, saves, listings, and account security are managed here.',
  '收藏商品': 'Saved items',
  '降价会及时提醒': 'Price drops can be noticed',
  '浏览记录': 'Viewed',
  '帮你找回看过的好物': 'Find items you viewed before',
  '手机号未绑定': 'Phone not linked',
  '手机号已绑定': 'Phone linked',
  '邮箱未绑定': 'Email not linked',
  '邮箱已绑定': 'Email linked',
  'Google 已绑定': 'Google linked',
  'Google 未绑定': 'Google not linked',
  '发布管理': 'Listing Tools',
  '管理已经发布的商品，下架、标记已售或修改信息。': 'Manage listed items, mark sold, delist, or edit.',
  '我的发布': 'My Listings',
  '查看全部发布商品，管理在售、已售和下架状态': 'View and manage active, sold, and delisted items',
  '账号与资料': 'Account & Profile',
  '这些信息会影响下单、收货和后续交易体验。': 'These details affect orders, delivery, and trading.',
  '编辑资料': 'Edit Profile',
  '头像、昵称、个人简介、联系方式': 'Avatar, nickname, bio, contact',
  '地址管理': 'Address Book',
  '收货地址、默认地址、联系方式': 'Delivery address and contact',
  '登录方式': 'Sign-in Methods',
  '这里会显示当前账号已绑定的登录方式。': 'Shows the sign-in methods linked to your account.',
  '退出登录并返回': 'Sign out',
  '退出中...': 'Signing out...',
  '最近浏览': 'Recently Viewed',
  '暂无浏览记录': 'No viewing history yet',
  '语言': 'Language',
  '语言设置': 'Language',
  '中文': 'Chinese',
  'English': 'English',
  '选择应用显示语言': 'Choose app language',
  '切换后会立即应用到主要页面。': 'Changes apply immediately.',
  '你的闲置货架': 'Your Listings',
  '这里显示你发布到平台的所有商品，可以下架、标记已售或修改信息。':
      'All your listed items. Delist, mark sold, or edit details.',
  '在售': 'Active',
  '已售': 'Sold',
  '下架': 'Delisted',
  '全部发布': 'All listings',
  '发布状态': 'Status',
  '商品编号': 'Listing ID',
  '可在我的发布管理': 'Manage it in My Listings',
  '修改': 'Edit',
  '标记已售': 'Mark sold',
  '重新上架': 'Relist',
  '还没有发布商品': 'No listings yet',
  '还没有在售商品': 'No active listings',
  '还没有已售商品': 'No sold listings',
  '还没有下架商品': 'No delisted listings',
  '发布成功后，商品会自动出现在这里。': 'After publishing, items will appear here.',
  '正在市场展示': 'Visible in market',
  '成交后可留档': 'Kept after sale',
  '读取我的发布失败': 'Could not load my listings',
  '下架这个商品？': 'Delist this item?',
  '下架后商品不会继续出现在交易市场，但你仍可以在个人中心重新上架。':
      'After delisting, this item will no longer appear in the market. You can relist it from Profile.',
  '标记为已售？': 'Mark as sold?',
  '标记后商品会从交易市场移除，并保留在你的已售记录里。':
      'After marking sold, the item is removed from market and kept in your sold records.',
  '重新上架这个商品？': 'Relist this item?',
  '重新上架后，买家可以再次在交易市场看到这个商品。':
      'After relisting, buyers can see this item in the market again.',
  '操作失败': 'Action failed',
  '刚刚更新': 'Updated just now',
  '已下架': 'Delisted',
  '修改商品': 'Edit Listing',
  '商品状态': 'Listing Status',
  '这里只修改已经发布的商品信息。': 'Edit the details of this published listing.',
  '售价': 'Price',
  '在地图上重新选择': 'Choose on map again',
  '保存修改': 'Save changes',
  '无法保存': 'Cannot save',
  '请填写商品标题，并输入大于 0 的整数价格。':
      'Enter an item title and an integer price greater than 0.',
  '修改后会影响商品详情页和地图上的展示位置。':
      'Changes affect the item detail page and map location.',
  '常用交易地点，例如学校附近 / 地铁站附近': 'Pickup area, e.g. near campus / station',
  '完善资料提升成交率': 'Complete profile to improve trust',
  '让买家更快相信你': 'Help buyers trust you faster',
  '资料会显示在商品详情、聊天和订单页。':
      'Profile info appears on item details, chat, and orders.',
  '昵称': 'Nickname',
  '个人简介': 'Bio',
  '常驻区域': 'Usual area',
  '保存资料': 'Save profile',
  '保存中...': 'Saving...',
  '请先登录，再编辑资料。': 'Sign in before editing your profile.',
  '收货地址与发货偏好': 'Addresses & Delivery',
  '地址用于后续订单、收货和发货流程。': 'Addresses are used for orders, delivery, and shipping.',
  '新增地址': 'Add address',
  '收货人': 'Recipient',
  '区域': 'Area',
  '详细地址': 'Full address',
  '保存地址': 'Save address',
  '保存地址失败': 'Could not save address',
  '设置默认地址失败': 'Could not set default address',
  '删除地址失败': 'Could not delete address',
  '删除地址？': 'Delete address?',
  '默认地址': 'Default',
  '设为默认': 'Set default',
  '删除地址': 'Delete address',
  '还没有地址，请先新增一个常用地址。': 'No address yet. Add one first.',
  '拍照添加': 'Take Photos',
  '实时拍摄商品': 'Shoot the item now',
  '相册上传': 'Upload Photos',
  '正在打开相册': 'Opening album',
  '多图选择': 'Choose multiple photos',
  '常卖分类': 'Popular Categories',
  '数码、球鞋、箱包、摄影器材': 'Tech, sneakers, bags, camera gear',
  '拍照': 'Camera',
  '图片预览': 'Photo Preview',
  '选择物品': 'Choose Item',
  '识别结果': 'Recognition Result',
  '识别到多个物品': 'Multiple Items Found',
  '识别到 1 个物品': '1 Item Found',
  '请选择这次要发布的商品。后续仍然可以手动修改品牌、型号和描述。':
      'Choose the item to list this time. You can still edit brand, model, and description later.',
  '这是 AI 当前识别到的商品。如果图片里还有其他物品，可以返回补拍或手动填写。':
      'This is what AI found. If there are other items in the photo, go back to add more photos or fill manually.',
  '多物品识别': 'Multi-item recognition',
  'AI 识别结果': 'AI recognition result',
  '选择这个物品': 'Choose this item',
  '都不对，手动填写': 'None of these, fill manually',
  '未命名物品': 'Untitled item',
  '系统全屏相机': 'Full-screen Camera',
  '打开 iPhone 全屏拍照界面，拍完后会回到这里继续发布。':
      'Open the iPhone camera, then return here to continue.',
  '正在打开相机...': 'Opening camera...',
  '全屏原生拍摄': 'Full-screen capture',
  '近距离拍摄时请在系统相机里点按商品主体对焦':
      'Tap the item in camera view to focus close-up shots',
  '打开中': 'Opening',
  '打开相机': 'Open camera',
  '近距离拍摄时，可以在相机里点按商品主体对焦；拍完后可继续补拍细节图。':
      'For close-ups, tap the item to focus. You can add detail photos after.',
  '主图': 'Cover',
  '细节': 'Detail',
  '配件': 'Accessories',
  '补充': 'Extra',
  '商品图片': 'Item Photos',
  '主图、细节、配件': 'Cover, details, accessories',
  '继续拍照': 'Take more',
  'AI 正在识别商品': 'AI is identifying the item',
  '正在上传图片并识别类别、品牌、型号和成色。':
      'Uploading photos and identifying category, brand, model, and condition.',
  'AI 识别中...': 'Identifying...',
  '上传并识别': 'Upload & Identify',
  '图片识别结果': 'Recognition Result',
  '如果识别有误，可以在这里修改或补充。': 'If anything looks wrong, edit or add details here.',
  '商品分类': 'Category',
  '商品标题': 'Title',
  '商品描述': 'Description',
  '补充给 AI 的信息，例如：有原盒、无划痕、电池健康 92%':
      'Extra notes for AI, e.g. box included, no scratches',
  '发布地点，例如学校附近、地铁站附近': 'Listing location, e.g. near campus or station',
  '自动定位': 'Auto locate',
  '手动选择': 'Choose manually',
  '正在调用 AI 估价': 'Getting AI estimate',
  '会根据你修正后的识别信息、补充说明和图片生成建议售价。':
      'Uses your edits, notes, and photos to suggest a price.',
  'AI 估价中...': 'Estimating...',
  '确认信息，开始 AI 估价': 'Confirm & Estimate',
  'AI 估价': 'AI Estimate',
  '建议售价': 'Suggested Price',
  '发布文案': 'Listing Copy',
  '标题与描述': 'Title and description',
  '商品标签': 'Tags',
  '选择已有标签，或添加自己的标签。': 'Choose suggested tags or add your own.',
  '正在上传图片': 'Uploading Photos',
  '正在同步商品图片和发布信息，请不要关闭页面。':
      'Syncing item photos and details. Please keep this page open.',
  '发布中...': 'Publishing...',
  '确认发布': 'Publish',
  '输入任意价格': 'Enter custom price',
  '新增标签': 'Add Tag',
  '例如：可自提': 'e.g. pickup available',
  '+ 自定义': '+ Custom',
  '输入任意售价': 'Enter Custom Price',
  '输入价格': 'Enter price',
  '使用价格': 'Use price',
  '发布成功': 'Published',
  '商品已发布': 'Item Published',
  '已加入“我的发布”，买家现在可以在附近商品中看到它。':
      'Added to My Listings. Buyers can now find it nearby.',
  '已进入市场': 'Visible in market',
  '返回首页': 'Back Home',
  '继续发布': 'List another',
  '草稿箱': 'Drafts',
  '本地草稿': 'Local Drafts',
  '草稿只保存在当前设备，不会自动同步到云端。':
      'Drafts stay on this device and do not sync automatically.',
  '继续编辑': 'Continue editing',
  '还没有本地草稿': 'No local drafts yet',
  '发布商品时点击右上角按钮，就可以把当前图片和填写内容保存到这里。':
      'Use the top-right menu while listing to save your progress here.',
  '去发布商品': 'List an item',
  '发布操作': 'Listing Actions',
  '可以先保存当前进度，或者退出并删除本次上传内容。':
      'Save your progress, or exit and delete this upload.',
  '保存到草稿箱': 'Save draft',
  '退出并删除': 'Exit and delete',
  '还没有可保存内容': 'Nothing to save yet',
  '请先添加商品图片，或填写商品信息后再保存草稿。':
      'Add photos or item details before saving a draft.',
  '已保存到草稿箱': 'Draft saved',
  '当前图片和填写内容已经保存，之后可以继续完善。':
      'Photos and details are saved. You can continue later.',
  '退出并删除？': 'Exit and delete?',
  '本次上传的照片和填写内容会被清空，已经保存到草稿箱的副本不会受影响。':
      'This upload will be cleared. Saved drafts will not be affected.',
  '删除并退出': 'Delete and exit',
  '买家': 'Buyer',
  '卖家咨询': 'Seller chats',
  '来自买家的询价': 'Inquiries from buyers',
  '未读消息': 'Unread',
  '暂无待处理': 'Nothing pending',
  '需要及时回复': 'Reply soon',
  '这里还没有会话': 'No conversations yet',
  '去商品详情页点击“联系卖家”，就能开启一条商品会话。':
      'Open an item and tap Contact Seller to start a chat.',
  '实时消息': 'Live chat',
  '图片': 'Photo',
  '按标价': 'Offer asking price',
  '输入消息，询问成色、配件或取货时间': 'Ask about condition, accessories, or pickup time',
  '无法获取当前位置': 'Could not get current location',
  '定位中': 'Locating',
  '刚刚': 'Just now',
  '位置待确认': 'Location pending',
  '收藏': 'Save',
  '取消收藏': 'Unsave',
  '收藏失败': 'Save failed',
  '点赞失败': 'Like failed',
  '消息加载失败': 'Could not load messages',
  '系统提醒': 'System notice',
  '发送失败': 'Send failed',
  '图片加载失败': 'Image failed to load',
  '我': 'Me',
  '咨询中': 'Chatting',
  '拍照识别': 'Photo recognition',
  '快速发布': 'Quick listing',
  '还差一点': 'Almost there',
  '请输入邮箱和密码。': 'Please enter your email and password.',
  '登录失败': 'Sign-in failed',
  '请输入手机号，建议带国家区号。':
      'Please enter your phone number, preferably with country code.',
  '验证码发送失败': 'Could not send code',
  '验证码已发送': 'Code sent',
  '请输入短信中的 6 位验证码完成登录。': 'Enter the 6-digit SMS code to sign in.',
  '请先获取验证码': 'Get a code first',
  '发送短信验证码后再继续登录。': 'Send an SMS code before signing in.',
  '请输入短信验证码。': 'Please enter the SMS code.',
  'Google 登录失败': 'Google sign-in failed',
  '创建中...': 'Creating...',
  '创建账号': 'Create account',
  '验证并创建账号': 'Verify & create account',
  '请补全昵称、邮箱和密码。': 'Please complete your name, email, and password.',
  '密码不一致': 'Passwords do not match',
  '两次输入的密码需要保持一致。': 'Both passwords need to match.',
  '注册失败': 'Sign-up failed',
  '请填写昵称和手机号。': 'Please enter your name and phone number.',
  '请输入短信中的 6 位验证码完成注册。': 'Enter the 6-digit SMS code to finish sign-up.',
  'Google 注册失败': 'Google sign-up failed',
  '请输入要重置密码的邮箱。': 'Please enter the email for password reset.',
  '重置邮件已发送': 'Reset email sent',
  '请打开邮箱，按邮件中的链接重置密码。': 'Open your email and follow the reset link.',
  '手机号登录不使用固定密码。返回登录页后选择“手机号”，发送短信验证码即可进入账号。':
      'Phone sign-in does not use a fixed password. Go back, choose Phone, and sign in with an SMS code.',
  '退出失败': 'Sign-out failed',
  '未绑定': 'Not linked',
  '已绑定': 'Linked',
  '新用户': 'New user',
  'Google 账号已登录': 'Signed in with Google',
  '邮箱账号已登录': 'Signed in with email',
  '手机号账号已登录': 'Signed in with phone',
  '欢迎完善资料，提高交易信任度': 'Complete your profile to build trading trust',
  'AI 识别失败': 'AI recognition failed',
  '稍后再试': 'Try later',
  '手动填写': 'Fill manually',
  '无法读取相册': 'Could not read album',
  'AI 估价失败': 'AI estimate failed',
  '尚未选择发布地址': 'No listing address selected',
  '当前位置': 'Current location',
  '待选择位置': 'Choose location',
  '请使用 GPS 或点击地图选择': 'Use GPS or tap the map',
  '发布位置': 'Listing Location',
  '自动定位或在地图上选择大致位置。': 'Auto locate or choose an approximate area on the map.',
  '大致位置已选择': 'Approximate location selected',
  '请使用自动定位或手动选择发布位置': 'Use auto locate or choose a listing location manually',
  '已手动选择发布位置': 'Listing location selected manually',
  '正在自动识别当前位置...': 'Detecting current location...',
  '正在重新定位...': 'Refreshing location...',
  '已自动识别当前位置，可手动更改': 'Current location detected. You can change it manually.',
  '已更新为当前位置': 'Updated to current location',
  '请在发布前选择一个大致位置': 'Choose an approximate location before listing',
  '当前为自定义价格，已超过滑动条范围。': 'This is a custom price outside the slider range.',
  'AI 对该商品价格判断较集中，可直接使用建议价。':
      'AI confidence is concentrated; you can use the suggested price.',
  '请输入标签内容': 'Enter a tag',
  '这个标签已经添加过了': 'This tag has already been added',
  '可以输入超过滑动范围的价格，发布前仍建议结合买家议价空间。':
      'You can enter a price outside the slider range. Consider room for negotiation before publishing.',
  '请输入大于 0 的整数价格': 'Enter an integer price greater than 0',
  '保存失败': 'Save failed',
  '发布失败': 'Publish failed',
  '已创建': 'Created',
  '删除草稿？': 'Delete draft?',
  '未命名商品草稿': 'Untitled item draft',
  '拍照中': 'Taking photos',
  '信息编辑': 'Editing info',
  '选择发布地址': 'Choose Listing Address',
  '发布地址': 'Listing Address',
  '买家会看到大致位置，方便同城交易': 'Buyers see an approximate area for local trading.',
  '已定位到当前位置': 'Located current position',
  '地图选择位置': 'Map selected location',
  '正在识别地图位置...': 'Resolving map location...',
  '正在识别中心位置...': 'Resolving center location...',
  '已选择发布位置': 'Listing location selected',
  '地图标记加载失败，请稍后重试': 'Map marker failed to load. Try again later.',
  '地图加载失败，请检查网络或 Mapbox Token':
      'Map failed to load. Check network or Mapbox token.',
  '点击地图选择发布位置': 'Tap the map to choose listing location',
  '移动地图，将中心点对准发布位置':
      'Move the map and place the center pin on your listing location',
  'GPS 定位': 'GPS locate',
  '使用此地址': 'Use this address',
  '功能正常': 'Works normally',
  '成色如图': 'Condition as shown',
  '支持自提': 'Pickup available',
  '当面验货': 'Inspect in person',
  '可小刀': 'Open to offers',
  '有原盒': 'Box included',
  '无原盒': 'No original box',
  '配件齐全': 'Accessories included',
  '急出': 'Quick sale',
  '通电正常': 'Powers on normally',
  '无暗病': 'No known issues',
  '带线材': 'Cable included',
  '学生自用': 'Student-owned',
  '快门正常': 'Shutter works',
  '镜头干净': 'Clean lens',
  '含电池': 'Battery included',
  '含充电器': 'Charger included',
  '可试机': 'Can test',
  '鞋盒还在': 'Shoe box included',
  '鞋底正常': 'Sole in good shape',
  '可面交': 'Meetup available',
  '尺码准确': 'True to size',
  '少穿': 'Lightly worn',
  '容量大': 'Large capacity',
  '通勤包': 'Commuter bag',
  '边角正常': 'Corners look fine',
  '五金正常': 'Hardware works',
  '需自提': 'Pickup required',
  '结构稳': 'Stable structure',
  '租房适合': 'Good for renting',
  '可拆装': 'Can disassemble',
  '闲置转让': 'Second-hand sale',
  '正常使用': 'Normal use',
  '买前可问': 'Ask before buying',
  '价格可谈': 'Price negotiable',
  '计算器': 'Calculator',
  '科学计算器': 'Scientific calculator',
  '函数计算器': 'Scientific calculator',
  '图形计算器': 'Graphing calculator',
  '学习用品': 'Study supplies',
  '学生用品': 'Student supplies',
  '文具': 'Stationery',
  '中文菜单': 'Chinese menu',
  '英文菜单': 'English menu',
  '适合考试': 'Exam suitable',
  '考试适用': 'Exam suitable',
  '轻便': 'Portable',
  '可议价': 'Negotiable',
  '面交': 'Meetup',
  '自提': 'Pickup',
  '原装': 'Original',
  '原装配件': 'Original accessories',
  '无包装': 'No packaging',
  '包装盒': 'Box included',
  '保修': 'Warranty',
  '未测试': 'Untested',
  '可检查': 'Can inspect',
  '电池正常': 'Battery works',
};

bool _containsCjk(String value) {
  return RegExp('[\u3400-\u9fff]').hasMatch(value);
}

String _translateMarketplaceText(String value) {
  var result = value.trim();
  if (result.isEmpty) {
    return result;
  }

  for (final entry in _marketplacePhraseDictionary.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }

  result = result
      .replaceAll('（', ' (')
      .replaceAll('）', ') ')
      .replaceAll('，', ', ')
      .replaceAll('。', '. ')
      .replaceAll('；', '; ')
      .replaceAll('：', ': ')
      .replaceAll('、', ', ')
      .replaceAll('「', '"')
      .replaceAll('」', '"')
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('·', ' · ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  result = result
      .replaceAllMapped(RegExp(r'\s+([,.;:)])'), (match) => match.group(1)!)
      .replaceAllMapped(RegExp(r'([(])\s+'), (match) => match.group(1)!);

  return result;
}

const Map<String, String> _marketplacePhraseDictionary = {
  'Razer BlackWidow V4 75% 机械键盘': 'Razer BlackWidow V4 75% mechanical keyboard',
  'Razer Orange switches': 'Razer Orange switches',
  '紧凑机械键盘': 'compact mechanical keyboard',
  '机械键盘': 'mechanical keyboard',
  '科学计算器': 'scientific calculator',
  '函数计算器': 'scientific calculator',
  '图形计算器': 'graphing calculator',
  '计算器': 'calculator',
  '学习用品': 'study supplies',
  '学生用品': 'student supplies',
  '文具': 'stationery',
  '中文菜单': 'Chinese menu',
  '英文菜单': 'English menu',
  '适合考试': 'exam suitable',
  '考试适用': 'exam suitable',
  '轻便': 'portable',
  '蓝牙耳机': 'Bluetooth headphones',
  '无线耳机': 'wireless headphones',
  '头戴式耳机': 'over-ear headphones',
  '降噪耳机': 'noise-cancelling headphones',
  '显示器': 'monitor',
  '键盘': 'keyboard',
  '鼠标': 'mouse',
  '手机': 'phone',
  '笔记本电脑': 'laptop',
  '笔记本': 'laptop',
  '平板电脑': 'tablet',
  '平板': 'tablet',
  '相机': 'camera',
  '镜头': 'lens',
  '球鞋': 'sneakers',
  '运动鞋': 'trainers',
  '箱包': 'bags',
  '包袋': 'bags',
  '背包': 'backpack',
  '手提包': 'handbag',
  '家具': 'furniture',
  '椅子': 'chair',
  '桌子': 'table',
  '台灯': 'desk lamp',
  '行李箱': 'suitcase',
  '数码': 'tech',
  '摄影器材': 'camera gear',
  '其他': 'other',
  '橙轴': 'orange switches',
  '青轴': 'blue switches',
  '茶轴': 'brown switches',
  '红轴': 'red switches',
  '黑色': 'black',
  '白色': 'white',
  '银色': 'silver',
  '灰色': 'grey',
  '全新未拆': 'brand new and sealed',
  '几乎全新': 'like new',
  '轻微使用': 'lightly used',
  '明显使用': 'used',
  '无法判断': 'unknown condition',
  '成色轻微使用': 'lightly used condition',
  '成色如图': 'condition as shown',
  '成色': 'condition',
  '轻微磨损': 'light wear',
  '轻微划痕': 'light scratches',
  '明显划痕': 'visible scratches',
  '使用痕迹': 'signs of use',
  '少量灰尘': 'minor dust',
  '无明显划痕': 'no obvious scratches',
  '无划痕': 'no scratches',
  '无暗病': 'no known issues',
  '功能正常': 'works normally',
  '通电正常': 'powers on normally',
  '快门正常': 'shutter works',
  '灯效正常': 'lighting works normally',
  '键帽与框体': 'keycaps and frame',
  '键帽': 'keycaps',
  '框体': 'frame',
  '标注': 'marked as',
  '含线材': 'cable included',
  '含线': 'cable included',
  '带线材': 'cable included',
  '带腕托': 'wrist rest included',
  '含电池': 'battery included',
  '含充电器': 'charger included',
  '配件齐全': 'accessories included',
  '有原盒': 'original box included',
  '无原盒': 'no original box',
  '未含原包装': 'no original packaging',
  '原包装': 'original packaging',
  '原盒': 'original box',
  '盒子': 'box',
  '未逐项测试所有功能': 'not every function has been individually tested',
  '实物验货为准': 'please inspect in person',
  '买前可问': 'ask before buying',
  '价格可谈': 'price negotiable',
  '可小刀': 'open to reasonable offers',
  '支持自提': 'pickup available',
  '需自提': 'pickup required',
  '可面交': 'meetup available',
  '面交': 'meetup',
  '自提': 'pickup',
  '当面验货': 'inspect in person',
  '学生自用': 'student-owned',
  '急出': 'quick sale',
  '正常使用': 'normal use',
  '可试机': 'can test before buying',
  '镜头干净': 'clean lens',
  '鞋盒还在': 'shoe box included',
  '鞋底正常': 'sole in good shape',
  '尺码准确': 'true to size',
  '少穿': 'lightly worn',
  '容量大': 'large capacity',
  '通勤包': 'commuter bag',
  '边角正常': 'corners look fine',
  '五金正常': 'hardware works',
  '结构稳': 'stable structure',
  '租房适合': 'good for renting',
  '可拆装': 'can be disassembled',
  '闲置转让': 'second-hand sale',
  '可议价': 'negotiable',
  '原装配件': 'original accessories',
  '原装': 'original',
  '无包装': 'no packaging',
  '包装盒': 'box included',
  '保修': 'warranty',
  '未测试': 'untested',
  '可检查': 'can inspect',
  '电池正常': 'battery works',
  '发布地点': 'listing location',
  '你正在咨询': 'You are asking about',
  '交易前建议先确认成色、配件和取货方式':
      'confirm condition, accessories, and pickup method before trading',
  '商品描述': 'description',
  '商品标题': 'title',
  '商品': 'item',
  '标题': 'title',
  '描述': 'description',
  '品牌': 'brand',
  '型号': 'model',
  '卖家': 'seller',
  '位置': 'location',
  '未知品牌': 'unknown brand',
  '未知型号': 'unknown model',
  '未知位置': 'unknown location',
  '未命名商品草稿': 'untitled item draft',
  '未命名商品': 'untitled item',
  '未命名物品': 'untitled item',
};
