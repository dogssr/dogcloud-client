import 'package:fl_clash/models/account.dart';
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

  String expiresOn(String date, int days) =>
      _zh ? '$date 到期（剩 $days 天）' : 'Expires $date ($days days left)';

  String expiredOn(String date) => _zh ? '已于 $date 到期' : 'Expired on $date';

  String get currentPlan => _zh ? '当前套餐' : 'Current';
  String get loadFailed => _zh ? '加载失败' : 'Could not load';
  String get retry => _zh ? '重试' : 'Retry';
  String get period => _zh ? '购买时长' : 'Billing period';
  String get coupon => _zh ? '优惠码' : 'Coupon';
  String get apply => _zh ? '使用' : 'Apply';
  String get paymentMethod => _zh ? '支付方式' : 'Payment method';
  String get price => _zh ? '价格' : 'Price';
  String get discount => _zh ? '优惠' : 'Discount';
  String get fee => _zh ? '手续费' : 'Fee';
  String get total => _zh ? '应付' : 'Total';
  String get payment => _zh ? '支付' : 'Payment';
  String get iPaid => _zh ? '我已支付' : 'I have paid';
  String get cancel => _zh ? '取消' : 'Cancel';
  String get paid => _zh ? '支付成功，套餐已开通' : 'Paid. Your plan is active.';
  String get notPaidYet => _zh
      ? '还没有收到支付结果。如果已经付款，请稍等片刻后在账户里刷新。'
      : 'No payment received yet. If you paid, refresh your account shortly.';
  String get waitingPayment => _zh
      ? '请在打开的页面完成支付，支付成功后会自动开通。'
      : 'Finish paying on the page that opened; the plan activates on its own.';
  String get unpaidTitle => _zh ? '有未完成的订单' : 'Unpaid order';
  String get continuePay => _zh ? '继续支付' : 'Pay it';
  String get cancelAndNew => _zh ? '取消并重新下单' : 'Cancel it';

  String unpaidMessage(String amount) => _zh
      ? '你还有一个 $amount 的订单没有支付。继续支付这个订单，还是取消它重新下单？'
      : 'An order of $amount is still unpaid. Pay it, or cancel it and order again?';

  String payNow(String amount) => _zh ? '立即支付 $amount' : 'Pay $amount';

  String fromPerMonth(String amount) => _zh ? '$amount/月 起' : 'From $amount/mo';

  String perMonth(String amount) => _zh ? '约 $amount/月' : '$amount/mo';

  String traffic(int gb) => _zh ? '$gb GB 流量' : '$gb GB data';

  String devices(int? count) => count == null || count <= 0
      ? (_zh ? '不限设备数' : 'Any number of devices')
      : (_zh ? '$count 台设备同时在线' : '$count devices at once');

  String periodName(PlanPeriod period) => switch (period) {
    PlanPeriod.month => _zh ? '月付' : 'Monthly',
    PlanPeriod.quarter => _zh ? '季付' : 'Quarterly',
    PlanPeriod.halfYear => _zh ? '半年付' : 'Half-yearly',
    PlanPeriod.year => _zh ? '年付' : 'Yearly',
    PlanPeriod.twoYear => _zh ? '两年付' : 'Two years',
    PlanPeriod.threeYear => _zh ? '三年付' : 'Three years',
    PlanPeriod.onetime => _zh ? '一次性' : 'One-time',
    PlanPeriod.reset => _zh ? '流量重置包' : 'Data reset',
  };

  String get emailCode => _zh ? '邮箱验证码' : 'Email code';
  String get sendCode => _zh ? '获取验证码' : 'Send code';
  String get codeSent => _zh ? '验证码已发送，请查收邮箱' : 'Code sent; check your email';
  String get codeRequired => _zh ? '请输入验证码' : 'Enter the code';
  String get newPassword => _zh ? '新密码' : 'New password';
  String get confirmPassword => _zh ? '确认密码' : 'Confirm password';
  String get passwordTooShort => _zh ? '密码至少 8 位' : 'At least 8 characters';
  String get passwordMismatch => _zh ? '两次输入的密码不一致' : 'Passwords do not match';
  String get registered => _zh ? '注册成功，欢迎使用' : 'Welcome aboard';
  String get passwordReset => _zh ? '密码已重置' : 'Password reset';
  String get captchaTitle => _zh ? '安全验证' : 'Verification';
  String get captchaUnavailable => _zh
      ? '当前设备无法完成安全验证，请在官网操作'
      : 'This device cannot show the check; use the website instead';

  String inviteCode({required bool required}) => required
      ? (_zh ? '邀请码' : 'Invite code')
      : (_zh ? '邀请码（选填）' : 'Invite code (optional)');

  String resendIn(int seconds) =>
      _zh ? '$seconds 秒后重发' : 'Resend in ${seconds}s';

  String emailSuffixes(List<String> suffixes) => _zh
      ? '支持 ${suffixes.join('、')} 邮箱'
      : 'Use an address at ${suffixes.join(', ')}';

  String get notices => _zh ? '网站公告' : 'Announcements';
  String get guides => _zh ? '使用教程' : 'Guides';
  String get coupons => _zh ? '我的优惠券' : 'My coupons';
  String get useCoupon => _zh ? '去使用' : 'Use';
  String get exclusiveCoupon => _zh ? '专属优惠券' : 'Just for you';

  String couponName(String label) => _zh ? '$label优惠券' : '$label coupon';

  String get invite => _zh ? '邀请返利' : 'Invite friends';
  String get inviteLink => _zh ? '邀请链接' : 'Invite link';
  String get copy => _zh ? '复制' : 'Copy';
  String get copied => _zh ? '已复制' : 'Copied';
  String get earned => _zh ? '累计返利' : 'Earned';
  String get balance => _zh ? '返利余额' : 'Balance';
  String get tickets => _zh ? '工单' : 'Support tickets';
  String get newTicket => _zh ? '新建工单' : 'New ticket';
  String get subject => _zh ? '标题' : 'Subject';
  String get message => _zh ? '描述你的问题' : 'Describe the problem';
  String get send => _zh ? '发送' : 'Send';
  String get closeTicket => _zh ? '关闭工单' : 'Close ticket';
  String get closeTicketMessage => _zh
      ? '关闭后不能再回复，确定要关闭这个工单吗？'
      : 'A closed ticket takes no more replies. Close it?';
  String get ticketCreated =>
      _zh ? '工单已提交，我们会尽快回复' : 'Sent; we will reply soon';
  String get replyHint => _zh ? '输入回复' : 'Reply';
  String get subjectRequired => _zh ? '请填写标题' : 'Add a subject';
  String get messageRequired => _zh ? '请描述你遇到的问题' : 'Describe the problem';
  String get nothingHere => _zh ? '暂时没有内容' : 'Nothing here yet';
  String get support => _zh ? '客服' : 'Support';
  String get required => _zh ? '必填' : 'Required';
  String get help => _zh ? '帮助' : 'Help';

  String ticketStatus(AccountTicket ticket) => ticket.closed
      ? (_zh ? '已关闭' : 'Closed')
      : ticket.replied
      ? (_zh ? '客服已回复' : 'Answered')
      : (_zh ? '等待客服回复' : 'Waiting for support');

  String invited(int count) => _zh ? '已邀请 $count 人' : '$count invited';

  String commissionRate(int rate) => _zh ? '返利比例 $rate%' : '$rate% commission';

  String timeLeft(Duration left) {
    final days = left.inDays;
    final hours = left.inHours % 24;
    if (_zh) return days > 0 ? '剩 $days 天 $hours 小时' : '剩 ${left.inHours} 小时';
    return days > 0 ? '${days}d ${hours}h left' : '${left.inHours}h left';
  }

  String get updateRequired => _zh ? '需要更新' : 'Update required';
  String get updateNow => _zh ? '立即更新' : 'Update now';

  String updateMessage(String version) => _zh
      ? '当前版本已停止支持，请更新到 v$version 继续使用。'
      : 'This version is no longer supported. Please update to v$version.';

  String remindIn(int days) => _zh ? '$days 天后提醒' : 'Remind me in $days days';

  String get checkin => _zh ? '签到' : 'Check in';
  String get checkedIn => _zh ? '今日已签到' : 'Checked in';

  String checkinReward(String traffic) =>
      _zh ? '签到成功，获得 $traffic 流量' : 'Checked in: +$traffic';
}

String yuan(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';
