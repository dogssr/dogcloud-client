import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/features/account/purchase.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/account.dart';
import '../helpers/test_app.dart';

Future<void> _pumpPlans(
  WidgetTester tester,
  FakeAccount account, {
  String? couponCode,
}) async {
  await tester.pumpWidget(
    TestApp(
      locale: const Locale('zh'),
      withStatusManager: true,
      overrides: [accountProvider.overrideWith(() => account)],
      child: PlansView(couponCode: couponCode),
    ),
  );
  await tester.pump();
}

Future<void> _openCheckout(WidgetTester tester) async {
  await tester.tap(find.text('Pro'));
  await tester.pumpAndSettle();
}

Finder _payButton(String amount) =>
    find.widgetWithText(FilledButton, '立即支付 $amount');

/// The pay button spins while an order is under way, so nothing settles.
Future<void> _pumpDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late FakeAccount account;

  setUp(() {
    account = FakeAccount()
      ..plansResult = [proPlan()]
      ..methodsResult = [
        PaymentMethod.fromJson(const {'id': 6, 'name': 'EPay'}),
        PaymentMethod.fromJson(const {
          'id': 7,
          'name': 'Alipay',
          'handling_fee_percent': '1',
        }),
      ];
  });

  testWidgets('a plan shows its data, description and monthly price', (
    tester,
  ) async {
    await _pumpPlans(tester, account);

    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('300 GB 流量 · 不限设备数'), findsOneWidget);
    expect(find.text('香港 · 日本\n 不限速'), findsOneWidget);
    expect(find.text('¥46.55/月 起'), findsOneWidget);
  });

  testWidgets('plans that fail to load offer a retry', (tester) async {
    account.failNext = const XboardException('网络不可用');
    await _pumpPlans(tester, account);

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('网络不可用'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('Pro'), findsOneWidget);
  });

  testWidgets('checkout prices a period with a coupon and a payment fee', (
    tester,
  ) async {
    account.couponResult = const AccountCoupon(
      code: 'DOG5',
      name: '立减',
      type: 1,
      value: 500,
    );
    await _pumpPlans(tester, account);
    await _openCheckout(tester);

    expect(find.text('月付'), findsOneWidget);
    expect(find.text('流量重置包'), findsNothing);
    expect(_payButton('¥49.00'), findsOneWidget);

    await tester.tap(find.text('季付'));
    await tester.pump();
    expect(find.text('约 ¥46.55/月'), findsOneWidget);
    expect(_payButton('¥139.65'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'DOG5');
    await tester.tap(find.text('使用'));
    await tester.pump();
    expect(account.calls, contains('coupon DOG5 quarter'));
    expect(find.text('-¥5.00'), findsOneWidget);
    expect(_payButton('¥134.65'), findsOneWidget);

    await tester.tap(find.text('Alipay'));
    await tester.pump();
    expect(find.text('¥1.35'), findsOneWidget);
    expect(_payButton('¥136.00'), findsOneWidget);

    await tester.tap(find.text('月付'));
    await tester.pump();
    expect(account.calls.where((call) => call.startsWith('coupon')), [
      'coupon DOG5 quarter',
      'coupon DOG5 month',
    ]);
  });

  testWidgets('a coupon the panel refuses says why and takes nothing off', (
    tester,
  ) async {
    await _pumpPlans(tester, account);
    await _openCheckout(tester);

    await tester.enterText(find.byType(TextField), 'NOPE');
    await tester.tap(find.text('使用'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('优惠券无效'), findsOneWidget);
    expect(_payButton('¥49.00'), findsOneWidget);
  });

  testWidgets('a coupon from the coupon list is applied at checkout', (
    tester,
  ) async {
    account.couponResult = const AccountCoupon(
      code: 'VIP20',
      name: '八折',
      type: 2,
      value: 20,
    );
    await _pumpPlans(tester, account, couponCode: 'VIP20');
    await _openCheckout(tester);

    expect(account.calls, contains('coupon VIP20 month'));
    expect(find.text('VIP20'), findsOneWidget);
    expect(_payButton('¥39.20'), findsOneWidget);
  });

  testWidgets('a paid order activates the plan and refreshes the account', (
    tester,
  ) async {
    await _pumpPlans(tester, account);
    await _openCheckout(tester);

    await tester.tap(_payButton('¥49.00'));
    await _pumpDialog(tester);

    expect(
      account.calls,
      containsAllInOrder(['order 5 month -', 'checkout T100 6']),
    );
    expect(account.calls, contains('refresh true'));
    expect(find.text('支付成功，套餐已开通'), findsOneWidget);
  });

  testWidgets('a gateway page waits for the panel to confirm the payment', (
    tester,
  ) async {
    final opened = fakeUrlLauncher();
    account
      ..checkoutResult = (type: 1, data: 'https://pay.example/T100')
      ..statuses = [0, 3];
    await _pumpPlans(tester, account);
    await _openCheckout(tester);

    await tester.tap(_payButton('¥49.00'));
    await _pumpDialog(tester);
    expect(opened, ['https://pay.example/T100']);
    expect(find.text('请在打开的页面完成支付，支付成功后会自动开通。'), findsOneWidget);

    await tester.tap(find.text('我已支付'));
    await _pumpDialog(tester);
    expect(find.text('还没有收到支付结果。如果已经付款，请稍等片刻后在账户里刷新。'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await _pumpDialog(tester);
    expect(find.text('支付成功，套餐已开通'), findsOneWidget);
    expect(account.calls, contains('refresh true'));
  });

  testWidgets('leaving the payment wait says the order is not paid yet', (
    tester,
  ) async {
    fakeUrlLauncher();
    account.checkoutResult = (type: 1, data: 'https://pay.example/T100');
    await _pumpPlans(tester, account);
    await _openCheckout(tester);

    await tester.tap(_payButton('¥49.00'));
    await _pumpDialog(tester);
    await tester.tap(find.text('取消'));
    await _pumpDialog(tester);

    expect(find.text('请在打开的页面完成支付，支付成功后会自动开通。'), findsNothing);
    expect(account.calls, isNot(contains('refresh true')));
    expect(_payButton('¥49.00'), findsOneWidget);
  });

  testWidgets('an unpaid order is paid instead of placing another', (
    tester,
  ) async {
    account.unpaid = [
      AccountOrder.fromJson(const {
        'trade_no': 'T9',
        'status': 0,
        'total_amount': 2100,
      }),
    ];
    await _pumpPlans(tester, account);
    await _openCheckout(tester);

    await tester.tap(_payButton('¥49.00'));
    await _pumpDialog(tester);
    expect(find.text('有未完成的订单'), findsOneWidget);
    expect(find.textContaining('¥21.00'), findsOneWidget);

    await tester.tap(find.text('继续支付'));
    await _pumpDialog(tester);

    expect(account.calls, contains('checkout T9 6'));
    expect(account.calls.where((call) => call.startsWith('order')), isEmpty);
  });

  testWidgets('an unpaid order can be cancelled for a new one', (tester) async {
    account.unpaid = [
      AccountOrder.fromJson(const {
        'trade_no': 'T9',
        'status': 0,
        'total_amount': 2100,
      }),
    ];
    await _pumpPlans(tester, account);
    await _openCheckout(tester);

    await tester.tap(_payButton('¥49.00'));
    await _pumpDialog(tester);
    await tester.tap(find.text('取消并重新下单'));
    await _pumpDialog(tester);

    expect(
      account.calls,
      containsAllInOrder(['cancel T9', 'order 5 month -', 'checkout T100 6']),
    );
  });
}
