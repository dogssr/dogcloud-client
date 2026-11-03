import 'package:fl_clash/features/account/notice.dart';
import 'package:fl_clash/models/account.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

AccountNotice _notice(Map<String, Object?> json) => AccountNotice.fromJson({
  'id': 7,
  'title': 'title',
  'content': '',
  'updated_at': 5,
  ...json,
});

void main() {
  test('only a shown notice tagged 弹窗 pops up', () {
    expect(
      _notice({
        'tags': ['弹窗'],
      }).popup,
      isTrue,
    );
    expect(
      _notice({
        'tags': ['弹窗'],
        'show': false,
      }).popup,
      isFalse,
    );
    expect(_notice({'tags': <String>[]}).popup, isFalse);
    expect(_notice({'tags': null}).popup, isFalse);
  });

  test('an edited notice gets a new seen key', () {
    expect(_notice({'updated_at': 5}).seenKey, '7:5');
    expect(_notice({'updated_at': 9}).seenKey, '7:9');
  });

  testWidgets(
    'notice Markdown keeps text and links but drops images and tags',
    (tester) async {
      late InlineSpan span;
      final recognizers = <TapGestureRecognizer>[];
      addTearDown(() {
        for (final recognizer in recognizers) {
          recognizer.dispose();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = noticeSpan(
                context,
                '## 标题\r\n\r\n- **加粗** 和 `代码`\n'
                '[点击获取](https://id.dogssr.com)<br>![图](https://x.y/z.png)',
                recognizers,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(span.toPlainText(), '标题\n\n• 加粗 和 代码\n点击获取');
      expect(recognizers, hasLength(1));
    },
  );
}
