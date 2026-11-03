import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/features/account/login.dart';
import 'package:fl_clash/features/account/register.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/account.dart';
import '../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeAccount account,
  Widget child,
) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TestApp(
      locale: const Locale('zh'),
      withStatusManager: true,
      overrides: [accountProvider.overrideWith(() => account)],
      child: child,
    ),
  );
  await tester.pump();
}

Future<void> _settleNotice(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _field(int index) => find.byType(TextField).at(index);

class _Opener extends StatelessWidget {
  const _Opener();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AccountLoginView()),
        ),
        child: const Text('open'),
      ),
    );
  }
}

void main() {
  late FakeAccount account;

  setUp(() {
    account =
        FakeAccount(
            initial: const AccountState(status: AccountStatus.loggedOut),
          )
          ..guest = GuestConfig.fromJson(const {
            'email_whitelist_suffix': ['gmail.com', 'qq.com'],
            'is_invite_force': 1,
            'is_captcha': 0,
          });
  });

  testWidgets('sign-up checks every field before it sends', (tester) async {
    await _pump(tester, account, const RegisterView());

    expect(find.text('支持 gmail.com、qq.com 邮箱'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '注册账号'));
    await tester.pump();

    expect(find.text('请输入邮箱'), findsOneWidget);
    expect(find.text('请输入验证码'), findsOneWidget);
    expect(find.text('密码至少 8 位'), findsOneWidget);
    expect(find.text('邀请码'), findsWidgets);
    expect(account.calls, isEmpty);

    await tester.enterText(_field(2), 'password1');
    await tester.enterText(_field(3), 'password2');
    await tester.tap(find.widgetWithText(FilledButton, '注册账号'));
    await tester.pump();
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
  });

  testWidgets('sign-up sends a code, counts down and signs in', (tester) async {
    await _pump(tester, account, const RegisterView());

    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    expect(account.calls, isEmpty);

    await tester.enterText(_field(0), ' dog@gmail.com ');
    await tester.tap(find.text('获取验证码'));
    await _settleNotice(tester);
    expect(account.calls, ['code dog@gmail.com -']);
    expect(find.text('验证码已发送，请查收邮箱'), findsOneWidget);
    expect(find.text('60 秒后重发'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59 秒后重发'), findsOneWidget);

    await tester.enterText(_field(1), '123456');
    await tester.enterText(_field(2), 'password1');
    await tester.enterText(_field(3), 'password1');
    await tester.enterText(_field(4), 'INV1');
    await tester.tap(find.widgetWithText(FilledButton, '注册账号'));
    await _settleNotice(tester);

    expect(account.calls.last, 'register dog@gmail.com password1 123456 INV1');
    expect(find.text('注册成功，欢迎使用'), findsOneWidget);
  });

  testWidgets('a refused sign-up says why and keeps the form', (tester) async {
    await _pump(tester, account, const RegisterView());
    account.failNext = const XboardException('邮箱验证码有误');

    await tester.enterText(_field(0), 'dog@gmail.com');
    await tester.enterText(_field(1), '000000');
    await tester.enterText(_field(2), 'password1');
    await tester.enterText(_field(3), 'password1');
    await tester.enterText(_field(4), 'INV1');
    await tester.tap(find.widgetWithText(FilledButton, '注册账号'));
    await _settleNotice(tester);

    expect(find.text('邮箱验证码有误'), findsOneWidget);
    expect(find.text('注册成功，欢迎使用'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '注册账号'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a captcha this device cannot show sends no code', (
    tester,
  ) async {
    account.guest = GuestConfig.fromJson(const {
      'is_captcha': 1,
      'captcha_type': 'turnstile',
      'turnstile_site_key': '0xKEY',
    });
    await _pump(tester, account, const RegisterView());

    await tester.enterText(_field(0), 'dog@gmail.com');
    await tester.tap(find.text('获取验证码'));
    await _settleNotice(tester);

    expect(account.calls, isEmpty);
    expect(find.text('当前设备无法完成安全验证，请在官网操作'), findsOneWidget);
  });

  testWidgets('a password reset sets the new password', (tester) async {
    await _pump(tester, account, const ResetPasswordView());

    expect(find.text('新密码'), findsOneWidget);
    await tester.enterText(_field(0), 'dog@gmail.com');
    await tester.enterText(_field(1), '654321');
    await tester.enterText(_field(2), 'newpassword');
    await tester.enterText(_field(3), 'newpassword');
    await tester.tap(find.widgetWithText(FilledButton, '忘记密码'));
    await _settleNotice(tester);

    expect(account.calls, ['reset dog@gmail.com 654321 newpassword']);
    expect(find.text('密码已重置'), findsOneWidget);
  });

  testWidgets('sign-in asks for both fields and shows the panel error', (
    tester,
  ) async {
    await _pump(tester, account, const AccountLoginView());

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    expect(find.text('请输入邮箱'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);

    account.failNext = const XboardException('邮箱或密码错误');
    await tester.enterText(_field(0), 'dog@gmail.com');
    await tester.enterText(_field(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(account.calls, ['login dog@gmail.com wrong']);
    expect(find.text('邮箱或密码错误'), findsOneWidget);
  });

  testWidgets('signing in closes the sign-in page', (tester) async {
    await _pump(tester, account, const _Opener());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountLoginView), findsOneWidget);

    await tester.enterText(_field(0), 'dog@gmail.com');
    await tester.enterText(_field(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(account.calls, ['login dog@gmail.com secret']);
    expect(find.byType(AccountLoginView), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('sign-up and reset open the website where no web view runs', (
    tester,
  ) async {
    final opened = fakeUrlLauncher();
    await _pump(tester, account, const AccountLoginView());

    await tester.tap(find.widgetWithText(TextButton, '注册账号'));
    await tester.tap(find.widgetWithText(TextButton, '忘记密码'));
    await tester.pump();

    final site = account.state.brand.siteUrl;
    expect(opened, ['$site/#/register', '$site/#/forgot-password']);
    expect(find.byType(CommonScaffold), findsNothing);
  });
}
