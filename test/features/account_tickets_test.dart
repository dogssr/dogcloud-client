import 'package:fl_clash/features/account/tickets.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _FakeAccount extends Account {
  _FakeAccount({this.hasTicket = true});

  bool hasTicket;
  var closed = false;
  final replies = <String>[];
  final created = <String>[];

  @override
  AccountState build() =>
      const AccountState(status: AccountStatus.loggedIn, authData: 'token');

  AccountTicket _ticket() => AccountTicket.fromJson({
    'id': 3,
    'subject': '无法连接',
    'status': closed ? 1 : 0,
    'reply_status': 1,
    'updated_at': 1700000000,
    'message': [
      {'is_me': true, 'message': '香港节点连不上', 'created_at': 1699990000},
      {'is_me': false, 'message': '请更新订阅后再试', 'created_at': 1700000000},
      for (final reply in replies)
        {'is_me': true, 'message': reply, 'created_at': 1700000100},
    ],
  });

  @override
  Future<List<AccountTicket>> tickets() async => [if (hasTicket) _ticket()];

  @override
  Future<AccountTicket> ticket(int id) async => _ticket();

  @override
  Future<void> replyTicket(int id, String message) async {
    replies.add(message);
  }

  @override
  Future<void> createTicket(String subject, String message) async {
    created.add('$subject: $message');
    hasTicket = true;
  }

  @override
  Future<void> closeTicket(int id) async {
    closed = true;
  }
}

Future<void> _pumpTickets(WidgetTester tester, _FakeAccount account) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TestApp(
      locale: const Locale('zh'),
      withStatusManager: true,
      overrides: [accountProvider.overrideWith(() => account)],
      child: const TicketsView(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a ticket opens as a conversation that takes a reply', (
    tester,
  ) async {
    final account = _FakeAccount();
    await _pumpTickets(tester, account);

    expect(find.text('无法连接'), findsOneWidget);
    expect(find.textContaining('客服已回复'), findsOneWidget);

    await tester.tap(find.text('无法连接'));
    await tester.pumpAndSettle();

    expect(find.text('香港节点连不上'), findsOneWidget);
    expect(find.text('请更新订阅后再试'), findsOneWidget);
    expect(find.textContaining('客服 · '), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  已经可以了，谢谢  ');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(account.replies, ['已经可以了，谢谢']);
    expect(find.text('已经可以了，谢谢'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a new ticket needs a subject and a message', (tester) async {
    final account = _FakeAccount(hasTicket: false);
    await _pumpTickets(tester, account);

    expect(find.text('暂时没有内容'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '新建工单'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('请填写标题'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '无法连接');
    await tester.pump();
    expect(find.text('请描述你遇到的问题'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '所有节点都超时');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(account.created, ['无法连接: 所有节点都超时']);
    expect(find.text('工单已提交，我们会尽快回复'), findsOneWidget);
    expect(find.text('无法连接'), findsOneWidget);
  });

  testWidgets('a closed ticket takes no more replies', (tester) async {
    final account = _FakeAccount();
    await _pumpTickets(tester, account);
    await tester.tap(find.text('无法连接'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('关闭工单'));
    await tester.pumpAndSettle();
    expect(find.text('关闭后不能再回复，确定要关闭这个工单吗？'), findsOneWidget);
    await tester.tap(find.text('关闭工单').last);
    await tester.pumpAndSettle();

    expect(account.closed, isTrue);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('关闭工单'), findsNothing);
    expect(find.text('已关闭'), findsOneWidget);
  });
}
