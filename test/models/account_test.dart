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
}
