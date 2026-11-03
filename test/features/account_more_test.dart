import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/features/account/more.dart';
import 'package:fl_clash/features/account/purchase.dart';
import 'package:fl_clash/features/account/section.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/account.dart';
import '../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeAccount account,
  Widget child, {
  Locale locale = const Locale('zh'),
}) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TestApp(
      locale: locale,
      withStatusManager: true,
      overrides: [accountProvider.overrideWith(() => account)],
      child: child,
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

final _subscribed = AccountState(
  status: AccountStatus.loggedIn,
  authData: 'token',
  email: 'dog@gmail.com',
  subscription: AccountSubscription.fromJson(const {
    'email': 'dog@gmail.com',
    'plan_id': 5,
    'plan': {'name': 'Pro'},
    'transfer_enable': 1000,
  }),
);

void main() {
  late FakeAccount account;

  setUp(() => account = FakeAccount());

  testWidgets('an announcement opens in full from the list', (tester) async {
    account.noticesResult = [
      AccountNotice.fromJson(const {
        'id': 1,
        'title': '维护通知',
        'content': '## 今晚维护\n- 节点重启',
        'updated_at': 1700000000,
      }),
    ];
    await _pump(tester, account, const NoticesView());

    await tester.tap(find.text('维护通知'));
    await _settle(tester);

    expect(find.text('维护通知'), findsNWidgets(2));
    expect(find.textContaining('今晚维护', findRichText: true), findsOneWidget);
  });

  testWidgets('an empty list says there is nothing yet', (tester) async {
    await _pump(tester, account, const NoticesView());

    expect(find.text('暂时没有内容'), findsOneWidget);
  });

  testWidgets('guides group by category and open as articles', (tester) async {
    account.guidesResult = const [
      GuideArticle(
        id: 2,
        category: 'iOS',
        title: '小火箭教程',
        body: '# 安装\n点击 [下载](https://example.com)',
      ),
      GuideArticle(id: 3, category: 'Windows', title: '电脑教程', body: ''),
    ];
    await _pump(tester, account, const GuidesView());

    expect(find.text('iOS'), findsOneWidget);
    expect(find.text('Windows'), findsOneWidget);

    await tester.tap(find.text('小火箭教程'));
    await tester.pumpAndSettle();

    expect(find.textContaining('安装'), findsOneWidget);
    expect(find.textContaining('点击 下载'), findsOneWidget);
  });

  testWidgets('a coupon goes to the plans with its code', (tester) async {
    account
      ..couponsResult = [
        BrandCoupon(
          code: 'DOG20',
          label: '8折',
          title: '',
          endsAt: DateTime.now().add(const Duration(days: 2, minutes: 5)),
        ),
      ]
      ..plansResult = [proPlan()];
    await _pump(tester, account, const CouponsView());

    expect(find.text('8折优惠券'), findsOneWidget);
    expect(find.text('专属优惠券 · 剩 2 天 0 小时'), findsOneWidget);
    expect(find.text('DOG20'), findsOneWidget);

    await tester.tap(find.text('去使用'));
    await tester.pumpAndSettle();

    final plans = tester.widget<PlansView>(find.byType(PlansView));
    expect(plans.couponCode, 'DOG20');
    expect(find.text('Pro'), findsOneWidget);
  });

  testWidgets('the invite page copies the link and shows the commission', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    account.inviteResult = InviteInfo.fromJson(const {
      'codes': [
        {'code': 'abc123'},
      ],
      'stat': [3, 1500, 0, 20, 800],
    });
    await _pump(tester, account, const InviteView());

    final link = '${account.state.brand.siteUrl}/#/register?code=abc123';
    expect(find.text(link), findsOneWidget);
    expect(find.text('已邀请 3 人'), findsOneWidget);
    expect(find.text('返利比例 20%'), findsOneWidget);
    expect(find.text('¥15.00'), findsOneWidget);
    expect(find.text('¥8.00'), findsOneWidget);

    await tester.tap(find.text('复制'));
    await _settle(tester);
    expect(copied, [link]);
    expect(find.text('已复制'), findsOneWidget);
  });

  testWidgets('the account rows check in and sign out', (tester) async {
    account = FakeAccount(initial: _subscribed);
    await _pump(
      tester,
      account,
      const Material(child: SingleChildScrollView(child: AccountSection())),
    );

    expect(find.text('dog@gmail.com'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('续费'), findsOneWidget);
    for (final row in ['我的优惠券', '邀请返利', '网站公告', '使用教程', '工单']) {
      expect(find.text(row), findsOneWidget);
    }

    await tester.tap(find.text('签到'));
    await _settle(tester);
    expect(find.text('签到成功，获得 1 GB 流量'), findsOneWidget);

    account.failNext = const XboardException('今天已经签到过了');
    await tester.tap(find.text('签到'));
    await _settle(tester);
    expect(find.text('今天已经签到过了'), findsOneWidget);

    await tester.tap(find.text('退出登录'));
    await _settle(tester);
    expect(find.textContaining('退出后会删除本机上这个账号的订阅'), findsOneWidget);
    await tester.tap(find.text('退出登录').last);
    await _settle(tester);

    expect(account.calls, contains('logout'));
    expect(find.text('dog@gmail.com'), findsNothing);
  });

  testWidgets('the account rows read in English too', (tester) async {
    account = FakeAccount(
      initial: const AccountState(
        status: AccountStatus.loggedIn,
        authData: 'token',
        email: 'dog@gmail.com',
      ),
    );
    await _pump(
      tester,
      account,
      const Material(child: SingleChildScrollView(child: AccountSection())),
      locale: const Locale('en'),
    );

    for (final row in [
      'No plan',
      'Get a plan',
      'Check in',
      'My coupons',
      'Invite friends',
      'Announcements',
      'Guides',
      'Support tickets',
      'Sign out',
    ]) {
      expect(find.text(row), findsOneWidget);
    }
  });
}
