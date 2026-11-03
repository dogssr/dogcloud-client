import 'dart:async';

import 'package:fl_clash/features/account/more.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('a failed load offers a retry that shows the data', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        locale: const Locale('zh'),
        child: AccountLoader<String>(
          title: 'Page',
          load: () async {
            calls++;
            if (calls == 1) throw Exception('offline');
            return 'loaded';
          },
          actions: (data, _) => [
            IconButtonData(
              glyph: AppGlyphs.compose,
              tooltip: 'Action $data',
              onPressed: () {},
            ),
          ],
          builder: (context, data, _) => Text(data),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.byTooltip('Action loaded'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('loaded'), findsOneWidget);
    expect(find.byTooltip('Action loaded'), findsOneWidget);
  });

  testWidgets('a reload keeps the data on screen while it runs', (
    tester,
  ) async {
    final pending = Completer<String>();
    var calls = 0;
    late VoidCallback reload;
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        child: AccountLoader<String>(
          title: 'Page',
          load: () {
            calls++;
            return calls == 1 ? Future.value('first') : pending.future;
          },
          builder: (context, data, onReload) {
            reload = onReload;
            return Text(data);
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    reload();
    await tester.pump();
    expect(find.text('first'), findsOneWidget);
    expect(find.byType(CommonCircleLoading), findsNothing);

    pending.complete('second');
    await tester.idle();
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('an empty page can carry its one action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('zh'),
        child: AccountEmpty(
          action: FilledButton(
            onPressed: () => tapped = true,
            child: const Text('新建工单'),
          ),
        ),
      ),
    );

    expect(find.text('暂时没有内容'), findsOneWidget);
    await tester.tap(find.text('新建工单'));
    expect(tapped, isTrue);
  });
}
