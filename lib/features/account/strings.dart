import 'package:material_ui/material_ui.dart';

/// Kept out of the arb files so the brand layer merges cleanly with upstream.
class AccountStrings {
  AccountStrings.of(BuildContext context)
    : _zh = Localizations.localeOf(context).languageCode == 'zh';

  final bool _zh;

  String get account => _zh ? '账户' : 'Account';
  String get loginSubtitle => _zh ? '登录你的账号开始使用' : 'Sign in to get started';
  String get email => _zh ? '邮箱' : 'Email';
  String get password => _zh ? '密码' : 'Password';
  String get login => _zh ? '登录' : 'Sign in';
  String get register => _zh ? '注册账号' : 'Create account';
  String get forgotPassword => _zh ? '忘记密码' : 'Forgot password';
  String get emailRequired => _zh ? '请输入邮箱' : 'Enter your email';
  String get passwordRequired => _zh ? '请输入密码' : 'Enter your password';
  String get noPlan => _zh ? '暂无套餐' : 'No plan';
  String get renew => _zh ? '续费' : 'Renew';
  String get buyPlan => _zh ? '购买套餐' : 'Get a plan';
  String get refresh => _zh ? '刷新' : 'Refresh';
  String get logout => _zh ? '退出登录' : 'Sign out';
  String get logoutMessage => _zh
      ? '退出后会删除本机上这个账号的订阅，需要重新登录才能使用。'
      : 'Signing out removes this account\'s subscription from this device.';
  String get refreshed => _zh ? '已更新' : 'Updated';
  String get neverExpires => _zh ? '长期有效' : 'Never expires';
  String get download => _zh ? '下载' : 'Download';
  String get later => _zh ? '以后再说' : 'Later';

  String expiresOn(String date, int days) =>
      _zh ? '$date 到期（剩 $days 天）' : 'Expires $date ($days days left)';

  String expiredOn(String date) => _zh ? '已于 $date 到期' : 'Expired on $date';

  String updateTitle(String version) =>
      _zh ? '发现新版本 $version' : 'Version $version is available';

  String get updateMessage => _zh
      ? '新版本修复了问题并改进了体验，建议更新。'
      : 'This update brings fixes and improvements.';
}
