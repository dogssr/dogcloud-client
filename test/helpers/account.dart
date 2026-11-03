import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [Account] that answers from fields instead of the panel and records the
/// calls that change something.
class FakeAccount extends Account {
  FakeAccount({
    this.initial = const AccountState(
      status: AccountStatus.loggedIn,
      authData: 'token',
    ),
  });

  final AccountState initial;
  final calls = <String>[];

  /// Thrown by the next call that reads it, then cleared.
  Exception? failNext;

  List<AccountPlan> plansResult = const [];
  List<PaymentMethod> methodsResult = const [];
  AccountCoupon? couponResult;
  List<AccountOrder> unpaid = const [];
  ({int type, Object? data}) checkoutResult = (type: -1, data: true);
  List<int> statuses = const [];
  GuestConfig guest = GuestConfig.fromJson(const {});
  List<AccountNotice> noticesResult = const [];
  List<GuideArticle> guidesResult = const [];
  List<BrandCoupon> couponsResult = const [];
  InviteInfo inviteResult = InviteInfo.fromJson(const {});
  ({bool success, String message}) checkinResult = (
    success: true,
    message: '1 GB',
  );

  void _maybeFail() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  @override
  AccountState build() => initial;

  @override
  Future<void> login({required String email, required String password}) async {
    calls.add('login $email $password');
    _maybeFail();
  }

  @override
  Future<GuestConfig> guestConfig() async => guest;

  @override
  Future<void> sendEmailCode(String email, {String? captchaToken}) async {
    calls.add('code $email ${captchaToken ?? '-'}');
    _maybeFail();
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String emailCode,
    String? inviteCode,
    String? captchaToken,
  }) async {
    calls.add('register $email $password $emailCode ${inviteCode ?? '-'}');
    _maybeFail();
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String emailCode,
    required String password,
  }) async {
    calls.add('reset $email $emailCode $password');
    _maybeFail();
  }

  @override
  Future<void> refresh({bool updateProfile = false}) async {
    calls.add('refresh $updateProfile');
  }

  @override
  Future<void> logout({String? message}) async {
    calls.add('logout');
    state = const AccountState(status: AccountStatus.loggedOut);
  }

  @override
  Future<List<AccountPlan>> plans() async {
    _maybeFail();
    return plansResult;
  }

  @override
  Future<List<PaymentMethod>> paymentMethods() async => methodsResult;

  @override
  Future<AccountCoupon> checkCoupon(
    String code,
    AccountPlan plan,
    PlanPeriod period,
  ) async {
    calls.add('coupon $code ${period.name}');
    _maybeFail();
    return couponResult ?? (throw const XboardException('优惠券无效'));
  }

  @override
  Future<List<AccountOrder>> unpaidOrders() async => unpaid;

  @override
  Future<void> cancelOrder(String tradeNo) async {
    calls.add('cancel $tradeNo');
  }

  @override
  Future<String> saveOrder(
    AccountPlan plan,
    PlanPeriod period,
    String? couponCode,
  ) async {
    calls.add('order ${plan.id} ${period.name} ${couponCode ?? '-'}');
    return 'T100';
  }

  @override
  Future<({int type, Object? data})> checkout(
    String tradeNo,
    int methodId,
  ) async {
    calls.add('checkout $tradeNo $methodId');
    return checkoutResult;
  }

  @override
  Future<int> orderStatus(String tradeNo) async {
    if (statuses.isEmpty) return 0;
    final status = statuses.first;
    statuses = statuses.sublist(1);
    return status;
  }

  @override
  Future<({bool success, String message})> checkin() async {
    calls.add('checkin');
    _maybeFail();
    return checkinResult;
  }

  @override
  Future<List<AccountNotice>> notices() async => noticesResult;

  @override
  Future<List<GuideArticle>> guides() async => guidesResult;

  @override
  Future<GuideArticle> guide(int id) async =>
      guidesResult.firstWhere((guide) => guide.id == id);

  @override
  Future<List<BrandCoupon>> coupons() async => couponsResult;

  @override
  Future<InviteInfo> invite() async => inviteResult;
}

AccountPlan proPlan() => AccountPlan.fromJson(const {
  'id': 5,
  'name': 'Pro',
  'tags': ['推荐'],
  'content': '<p>香港 · 日本</p><p>&nbsp;不限速</p>',
  'transfer_enable': 300,
  'month_price': 4900,
  'quarter_price': 13965,
  'reset_price': 1000,
});

/// Answers url_launcher, which has no host side in tests, and records the
/// URLs it was asked to open.
List<String> fakeUrlLauncher() {
  final opened = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'plugins.flutter.io/url_launcher',
    'plugins.flutter.io/url_launcher_linux',
  ]) {
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments;
      if (arguments is Map && arguments['url'] is String) {
        opened.add(arguments['url'] as String);
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  return opened;
}
