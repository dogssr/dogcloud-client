import 'package:fl_clash/models/account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountPlan', () {
    final plan = AccountPlan.fromJson({
      'id': 5,
      'name': 'Pro',
      'tags': ['推荐'],
      'transfer_enable': 300,
      'device_limit': null,
      'month_price': 4900,
      'quarter_price': 13965,
      'half_year_price': 26460.000000000004,
      'year_price': 49980,
      'onetime_price': null,
      'reset_price': 4900,
    });

    test('keeps only the periods it sells, rounded to cents', () {
      expect(plan.prices, {
        PlanPeriod.month: 4900,
        PlanPeriod.quarter: 13965,
        PlanPeriod.halfYear: 26460,
        PlanPeriod.year: 49980,
        PlanPeriod.reset: 4900,
      });
      expect(plan.tags, ['推荐']);
      expect(plan.deviceLimit, isNull);
    });

    test('quotes the cheapest month among renewing periods', () {
      expect(plan.monthlyFrom, 4165);
      expect(AccountPlan.fromJson({'reset_price': 100}).monthlyFrom, isNull);
    });
  });

  test('a coupon never takes off more than the price', () {
    const fixed = AccountCoupon(code: 'A', name: 'a', type: 1, value: 500);
    const percent = AccountCoupon(code: 'B', name: 'b', type: 2, value: 20);
    expect(fixed.discountFor(4900), 500);
    expect(fixed.discountFor(300), 300);
    expect(percent.discountFor(4900), 980);
  });

  test('a payment fee applies to the amount still due', () {
    final method = PaymentMethod.fromJson({
      'id': 6,
      'name': 'EPay',
      'handling_fee_percent': '4.00',
      'handling_fee_fixed': 10,
    });
    expect(method.feeFor(10000), 410);
    expect(method.feeFor(0), 0);
  });

  test('orders and check-in read the panel fields', () {
    final order = AccountOrder.fromJson({
      'trade_no': 'T1',
      'plan_id': 1,
      'period': 'month_price',
      'status': 0,
      'total_amount': 2100,
      'created_at': 1793311575,
    });
    expect(order.unpaid, isTrue);
    expect(order.totalAmount, 2100);

    final status = CheckinStatus.fromJson({
      'enabled': true,
      'checked_today': false,
      'reason': null,
    });
    expect(status.enabled, isTrue);
    expect(status.checkedToday, isFalse);
  });

  test('sign-up settings name the captcha the app can show', () {
    final turnstile = GuestConfig.fromJson({
      'email_whitelist_suffix': ['gmail.com', 'qq.com'],
      'is_invite_force': 0,
      'is_captcha': 1,
      'captcha_type': 'turnstile',
      'turnstile_site_key': '0xKEY',
    });
    expect(turnstile.emailSuffixes, ['gmail.com', 'qq.com']);
    expect(turnstile.inviteRequired, isFalse);
    expect(turnstile.captchaRequired, isTrue);
    expect(turnstile.turnstileSiteKey, '0xKEY');

    final recaptcha = GuestConfig.fromJson({
      'is_invite_force': 1,
      'is_captcha': 1,
      'captcha_type': 'recaptcha',
      'turnstile_site_key': '0xKEY',
    });
    expect(recaptcha.inviteRequired, isTrue);
    expect(recaptcha.captchaRequired, isTrue);
    expect(recaptcha.turnstileSiteKey, isNull);

    final open = GuestConfig.fromJson({'is_captcha': 0});
    expect(open.captchaRequired, isFalse);
    expect(open.emailSuffixes, isEmpty);
  });

  test('tickets, invites and coupons read the panel fields', () {
    final ticket = AccountTicket.fromJson({
      'id': 7,
      'subject': '无法连接',
      'status': 0,
      'reply_status': 1,
      'updated_at': 1700000000,
      'message': [
        {'is_me': true, 'message': '连不上', 'created_at': 1699990000},
        {'is_me': false, 'message': '已处理', 'created_at': 1700000000},
      ],
    });
    expect(ticket.closed, isFalse);
    expect(ticket.replied, isTrue);
    expect(ticket.messages.map((message) => message.mine), [true, false]);
    expect(
      ticket.messages.last.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    );

    final invite = InviteInfo.fromJson({
      'codes': [
        {'code': 'abc123'},
      ],
      'stat': [3, 1500, 200, 20, 800],
    });
    expect(invite.codes, ['abc123']);
    expect(invite.invited, 3);
    expect(invite.earned, 1500);
    expect(invite.rate, 20);
    expect(invite.balance, 800);
    expect(
      InviteInfo.fromJson({
        'stat': [1],
      }).balance,
      0,
    );

    final coupon = BrandCoupon.fromJson({
      'code': 'DOG20',
      'label': '8 折',
      'title': '新用户',
      'ended_at': 1700000000,
    });
    expect(coupon.code, 'DOG20');
    expect(
      coupon.endsAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    );
  });
}
