import 'package:fl_clash/common/brand.dart';

class AccountSubscription {
  const AccountSubscription({
    required this.email,
    required this.planId,
    required this.planName,
    required this.expiredAt,
    required this.used,
    required this.total,
    required this.subscribeUrl,
  });

  final String email;
  final int? planId;
  final String? planName;

  /// Null for a plan that never expires.
  final DateTime? expiredAt;
  final int used;
  final int total;
  final String subscribeUrl;

  factory AccountSubscription.fromJson(Map<String, Object?> json) {
    final plan = json['plan'];
    final expiredAt = (json['expired_at'] as num?)?.toInt();
    return AccountSubscription(
      email: json['email'] as String? ?? '',
      planId: (json['plan_id'] as num?)?.toInt(),
      planName: plan is Map ? plan['name'] as String? : null,
      expiredAt: expiredAt == null || expiredAt <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000),
      used:
          ((json['u'] as num?)?.toInt() ?? 0) +
          ((json['d'] as num?)?.toInt() ?? 0),
      total: (json['transfer_enable'] as num?)?.toInt() ?? 0,
      subscribeUrl: json['subscribe_url'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'email': email,
    'plan_id': planId,
    'plan': planName == null ? null : {'name': planName},
    'expired_at': expiredAt == null
        ? null
        : expiredAt!.millisecondsSinceEpoch ~/ 1000,
    'u': used,
    'd': 0,
    'transfer_enable': total,
    'subscribe_url': subscribeUrl,
  };

  bool get hasPlan => planName != null;

  bool get expired => expiredAt?.isBefore(DateTime.now()) ?? false;

  /// The link the profile downloads, pinned to the Clash.Meta format.
  String get profileUrl {
    final uri = Uri.tryParse(subscribeUrl);
    if (uri == null || brandSubscribeFlag.isEmpty) return subscribeUrl;
    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'flag': brandSubscribeFlag},
        )
        .toString();
  }
}

/// `config.json` lets a release keep working after its built-in addresses are
/// blocked: every field is optional and falls back to the build defaults.
class BrandConfig {
  const BrandConfig({
    required this.apiUrls,
    required this.siteUrl,
    this.latestVersion,
    this.downloadUrls = const {},
    this.releaseNotes,
  });

  final List<String> apiUrls;
  final String siteUrl;
  final String? latestVersion;

  /// Keyed by `Platform.operatingSystem`.
  final Map<String, String> downloadUrls;
  final String? releaseNotes;

  static final defaults = BrandConfig(
    apiUrls: splitBrandUrls(brandApiUrls),
    siteUrl: brandSiteUrl,
  );

  factory BrandConfig.fromJson(Map<String, Object?> json) {
    final latest = json['latest'];
    final urls = latest is Map ? latest['url'] : null;
    final apis = [
      for (final api in json['api'] as List? ?? const [])
        if (api is String) ...splitBrandUrls(api),
    ];
    final site = json['site'];
    return BrandConfig(
      apiUrls: {...apis, ...defaults.apiUrls}.toList(),
      siteUrl: site is String && site.isNotEmpty
          ? site.replaceFirst(RegExp(r'/+$'), '')
          : defaults.siteUrl,
      latestVersion: latest is Map ? latest['version'] as String? : null,
      downloadUrls: {
        if (urls is Map)
          for (final MapEntry(:key, :value) in urls.entries)
            if (key is String && value is String) key: value,
      },
      releaseNotes: latest is Map ? latest['notes'] as String? : null,
    );
  }

  String get shopUrl => '$siteUrl/#/shop';
  String get registerUrl => '$siteUrl/#/register';
  String get forgotPasswordUrl => '$siteUrl/#/forgot-password';
}

class AccountNotice {
  const AccountNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.updatedAt,
    required this.show,
  });

  final int id;
  final String title;
  final String content;
  final List<String> tags;
  final int updatedAt;
  final bool show;

  factory AccountNotice.fromJson(Map<String, Object?> json) {
    return AccountNotice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: [
        for (final tag in json['tags'] as List? ?? const [])
          if (tag is String) tag,
      ],
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      show: json['show'] != false,
    );
  }

  /// The panel's 弹窗 tag marks a popup; editing a notice changes [seenKey].
  bool get popup => show && tags.contains('弹窗');

  String get seenKey => '$id:$updatedAt';
}

/// Xboard's order API still names periods by their legacy price columns.
enum PlanPeriod {
  month('month_price', 1),
  quarter('quarter_price', 3),
  halfYear('half_year_price', 6),
  year('year_price', 12),
  twoYear('two_year_price', 24),
  threeYear('three_year_price', 36),
  onetime('onetime_price', 0),
  reset('reset_price', 0);

  const PlanPeriod(this.key, this.months);

  final String key;
  final int months;
}

class AccountPlan {
  const AccountPlan({
    required this.id,
    required this.name,
    required this.tags,
    required this.content,
    required this.transferGb,
    required this.deviceLimit,
    required this.prices,
  });

  final int id;
  final String name;
  final List<String> tags;
  final String content;
  final int transferGb;
  final int? deviceLimit;

  /// Cents, in [PlanPeriod] order; periods the plan does not sell are absent.
  final Map<PlanPeriod, int> prices;

  factory AccountPlan.fromJson(Map<String, Object?> json) {
    return AccountPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      tags: [
        for (final tag in json['tags'] as List? ?? const [])
          if (tag is String) tag,
      ],
      content: json['content'] as String? ?? '',
      transferGb: (json['transfer_enable'] as num?)?.toInt() ?? 0,
      deviceLimit: (json['device_limit'] as num?)?.toInt(),
      prices: {
        for (final period in PlanPeriod.values)
          if ((json[period.key] as num?)?.round() case final cents?
              when cents > 0)
            period: cents,
      },
    );
  }

  /// The lowest price per month among the periods a plan renews by.
  int? get monthlyFrom {
    final monthly = [
      for (final MapEntry(key: period, value: cents) in prices.entries)
        if (period.months > 0) cents ~/ period.months,
    ];
    return monthly.isEmpty ? null : monthly.reduce((a, b) => a < b ? a : b);
  }
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.feePercent,
    required this.feeFixed,
  });

  final int id;
  final String name;
  final double feePercent;
  final int feeFixed;

  factory PaymentMethod.fromJson(Map<String, Object?> json) {
    return PaymentMethod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      feePercent: double.tryParse('${json['handling_fee_percent'] ?? 0}') ?? 0,
      feeFixed: (json['handling_fee_fixed'] as num?)?.toInt() ?? 0,
    );
  }

  int feeFor(int cents) =>
      cents <= 0 ? 0 : (cents * feePercent / 100).round() + feeFixed;
}

class AccountCoupon {
  const AccountCoupon({
    required this.code,
    required this.name,
    required this.type,
    required this.value,
  });

  final String code;
  final String name;

  /// 1 takes [value] cents off, 2 takes [value] percent off.
  final int type;
  final int value;

  factory AccountCoupon.fromJson(Map<String, Object?> json) {
    return AccountCoupon(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: (json['type'] as num?)?.toInt() ?? 1,
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }

  int discountFor(int cents) => type == 2
      ? (cents * value / 100).round().clamp(0, cents)
      : value.clamp(0, cents);
}

class AccountOrder {
  const AccountOrder({
    required this.tradeNo,
    required this.planId,
    required this.period,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
  });

  final String tradeNo;
  final int planId;
  final String period;

  /// 0 unpaid, 1 opening, 2 cancelled, 3 done, 4 credited to a later order.
  final int status;
  final int totalAmount;
  final DateTime createdAt;

  factory AccountOrder.fromJson(Map<String, Object?> json) {
    return AccountOrder(
      tradeNo: json['trade_no'] as String? ?? '',
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      period: json['period'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['created_at'] as num?)?.toInt() ?? 0) * 1000,
      ),
    );
  }

  bool get unpaid => status == 0;
}

class CheckinStatus {
  const CheckinStatus({
    required this.enabled,
    required this.checkedToday,
    required this.reason,
  });

  final bool enabled;
  final bool checkedToday;

  /// Why this account cannot check in, as the panel words it.
  final String? reason;

  factory CheckinStatus.fromJson(Map<String, Object?> json) {
    return CheckinStatus(
      enabled: json['enabled'] == true,
      checkedToday: json['checked_today'] == true,
      reason: json['reason'] as String?,
    );
  }
}

class GuestConfig {
  const GuestConfig({
    required this.emailSuffixes,
    required this.inviteRequired,
    required this.captchaRequired,
    required this.turnstileSiteKey,
  });

  final List<String> emailSuffixes;
  final bool inviteRequired;
  final bool captchaRequired;

  /// Null unless the captcha is a Turnstile, the only kind the app can show.
  final String? turnstileSiteKey;

  factory GuestConfig.fromJson(Map<String, Object?> json) {
    final captcha = json['is_captcha'] == 1 || json['is_captcha'] == true;
    final key = json['turnstile_site_key'];
    return GuestConfig(
      emailSuffixes: [
        for (final suffix
            in json['email_whitelist_suffix'] as List? ?? const [])
          if (suffix is String) suffix,
      ],
      inviteRequired:
          json['is_invite_force'] == 1 || json['is_invite_force'] == true,
      captchaRequired: captcha,
      turnstileSiteKey:
          captcha && json['captcha_type'] == 'turnstile' && key is String
          ? key
          : null,
    );
  }
}

class GuideArticle {
  const GuideArticle({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
  });

  final int id;
  final String category;
  final String title;
  final String body;

  factory GuideArticle.fromJson(Map<String, Object?> json) {
    return GuideArticle(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class TicketMessage {
  const TicketMessage({
    required this.mine,
    required this.message,
    required this.createdAt,
  });

  final bool mine;
  final String message;
  final DateTime createdAt;

  factory TicketMessage.fromJson(Map<String, Object?> json) {
    return TicketMessage(
      mine: json['is_me'] == true,
      message: json['message'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['created_at'] as num?)?.toInt() ?? 0) * 1000,
      ),
    );
  }
}

class AccountTicket {
  const AccountTicket({
    required this.id,
    required this.subject,
    required this.closed,
    required this.replied,
    required this.updatedAt,
    required this.messages,
  });

  final int id;
  final String subject;
  final bool closed;

  /// The last word is the panel's.
  final bool replied;
  final DateTime updatedAt;
  final List<TicketMessage> messages;

  factory AccountTicket.fromJson(Map<String, Object?> json) {
    return AccountTicket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? '',
      closed: (json['status'] as num?)?.toInt() == 1,
      replied: (json['reply_status'] as num?)?.toInt() == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['updated_at'] as num?)?.toInt() ?? 0) * 1000,
      ),
      messages: [
        for (final item in json['message'] as List? ?? const [])
          if (item is Map<String, Object?>) TicketMessage.fromJson(item),
      ],
    );
  }
}

class InviteInfo {
  const InviteInfo({
    required this.codes,
    required this.invited,
    required this.earned,
    required this.rate,
    required this.balance,
  });

  final List<String> codes;
  final int invited;

  /// Cents.
  final int earned;
  final int rate;
  final int balance;

  /// Xboard's stat list: invited, earned, pending, rate, balance.
  factory InviteInfo.fromJson(Map<String, Object?> json) {
    final stat = [
      for (final value in json['stat'] as List? ?? const [])
        (value as num?)?.toInt() ?? 0,
    ];
    int at(int index) => index < stat.length ? stat[index] : 0;
    return InviteInfo(
      codes: [
        for (final code in json['codes'] as List? ?? const [])
          if (code is Map && code['code'] is String) code['code'] as String,
      ],
      invited: at(0),
      earned: at(1),
      rate: at(3),
      balance: at(4),
    );
  }
}

class BrandCoupon {
  const BrandCoupon({
    required this.code,
    required this.label,
    required this.title,
    required this.endsAt,
  });

  final String code;
  final String label;
  final String title;
  final DateTime endsAt;

  factory BrandCoupon.fromJson(Map<String, Object?> json) {
    return BrandCoupon(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      title: json['title'] as String? ?? '',
      endsAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['ended_at'] as num?)?.toInt() ?? 0) * 1000,
      ),
    );
  }
}

enum AccountStatus { restoring, loggedOut, loggedIn }

class AccountState {
  const AccountState({
    this.status = AccountStatus.restoring,
    this.authData,
    this.email,
    this.subscription,
    this.profileId,
    this.config,
    this.syncing = false,
  });

  final AccountStatus status;
  final String? authData;
  final String? email;
  final AccountSubscription? subscription;

  /// The profile the account's subscription lives in.
  final int? profileId;
  final BrandConfig? config;
  final bool syncing;

  bool get loggedIn => status == AccountStatus.loggedIn;

  BrandConfig get brand => config ?? BrandConfig.defaults;

  AccountState copyWith({
    AccountStatus? status,
    AccountSubscription? subscription,
    int? profileId,
    BrandConfig? config,
    bool? syncing,
  }) {
    return AccountState(
      status: status ?? this.status,
      authData: authData,
      email: email,
      subscription: subscription ?? this.subscription,
      profileId: profileId ?? this.profileId,
      config: config ?? this.config,
      syncing: syncing ?? this.syncing,
    );
  }
}
