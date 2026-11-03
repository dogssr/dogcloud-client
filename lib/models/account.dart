import 'package:fl_clash/common/brand.dart';

class AccountSubscription {
  const AccountSubscription({
    required this.email,
    required this.planName,
    required this.expiredAt,
    required this.used,
    required this.total,
    required this.subscribeUrl,
  });

  final String email;
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
