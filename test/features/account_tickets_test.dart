import 'package:fl_clash/features/account/tickets.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _FakeAccount extends Account {
  final replies = <String>[];

  @override
  AccountState build() =>
      const AccountState(status: AccountStatus.loggedIn, authData: 'token');

  AccountTicket _ticket() => AccountTicket.fromJson({
    'id': 3,
    'subject': '无法连接',
    'status': 0,
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
  Future<List<AccountTicket>> tickets() async => [_ticket()];

  @override
  Future<AccountTicket> ticket(int id) async => _ticket();

  @override
  Future<void> replyTicket(int id, String message) async {
    replies.add(message);
  }
}

void main() {
  testWidgets('a ticket opens as a conversation that takes a reply', (
    tester,
  ) async {
    final account = _FakeAccount();
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('zh'),
        overrides: [accountProvider.overrideWith(() => account)],
        child: const TicketsView(),
      ),
    );
    await tester.pump();

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
}
