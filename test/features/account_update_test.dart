import 'dart:async';

import 'package:fl_clash/features/account/update.dart';
import 'package:fl_clash/models/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/account.dart';
import '../helpers/test_app.dart';

BrandConfig _config({int snoozeDays = 3, String version = '4.1.0'}) =>
    BrandConfig.fromJson({
      'latest': {
        'version': version,
        'min_version': version,
        'snooze_days': snoozeDays,
        'notes': '修复连接问题',
        'url': {'default': 'https://example.com/app'},
      },
    });

void main() {
  final start = DateTime(2026, 11, 4, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      const TestApp(
        locale: Locale('zh'),
        child: Scaffold(body: SizedBox.shrink()),
      ),
    );
  }

  Future<bool> prompt(
    WidgetTester tester,
    BrandConfig config,
    DateTime now, {
    String? tap,
  }) async {
    final shown = promptRequiredUpdate(config, '4.0.0', now: now);
    await tester.pumpAndSettle();
    if (tap != null) {
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
    }
    return shown;
  }

  testWidgets('a put-off update asks again once the days run out', (
    tester,
  ) async {
    await pumpHost(tester);

    final first = promptRequiredUpdate(_config(), '4.0.0', now: start);
    await tester.pumpAndSettle();
    expect(find.text('需要更新'), findsOneWidget);
    expect(find.textContaining('请更新到 v4.1.0'), findsOneWidget);
    expect(find.textContaining('修复连接问题'), findsOneWidget);
    await tester.tap(find.text('3 天后提醒'));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(find.text('需要更新'), findsNothing);

    final early = start.add(const Duration(days: 2));
    expect(await prompt(tester, _config(), early), isFalse);
    expect(find.text('需要更新'), findsNothing);

    final newer = _config(version: '4.2.0');
    expect(await prompt(tester, newer, early, tap: '3 天后提醒'), isTrue);

    final late = start.add(const Duration(days: 3, minutes: 1));
    expect(await prompt(tester, _config(), late, tap: '3 天后提醒'), isTrue);
  });

  testWidgets('with no days to put it off only updating is offered', (
    tester,
  ) async {
    final opened = fakeUrlLauncher();
    await pumpHost(tester);

    unawaited(
      promptRequiredUpdate(_config(snoozeDays: 0), '4.0.0', now: start),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsOneWidget);
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(opened, ['https://example.com/app']);
    expect(find.text('需要更新'), findsOneWidget);
  });

  testWidgets('a current build is not asked', (tester) async {
    await pumpHost(tester);

    expect(await promptRequiredUpdate(_config(), '4.1.0', now: start), isFalse);
  });
}
