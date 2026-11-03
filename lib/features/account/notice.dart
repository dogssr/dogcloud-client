import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

final _heading = RegExp(r'^#{1,6}\s+(.*)$');
final _bullet = RegExp(r'^\s*[-*+]\s+(.*)$');
final _tag = RegExp(r'<[^>]+>');
final _inline = RegExp(
  r'\*\*(.+?)\*\*|`([^`]+)`|!\[[^\]]*\]\([^)]*\)|\[([^\]]+)\]\(([^)\s]+)\)',
);

Future<void> showAccountNotice(AccountNotice notice) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  final recognizers = <TapGestureRecognizer>[];
  try {
    await dialogs.showAlert(
      title: notice.title,
      message: noticeSpan(context, notice.content, recognizers),
    );
  } finally {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
  }
}

/// Panel notices are Markdown; this keeps the subset they use (headings,
/// lists, bold, code, links) and drops images and HTML tags.
InlineSpan noticeSpan(
  BuildContext context,
  String markdown,
  List<TapGestureRecognizer> recognizers,
) {
  final body = AppTextStyle.subheadline.of(context);
  final strong = AppTextStyle.subheadline.of(context, emphasized: true);
  final heading = AppTextStyle.headline.of(context, emphasized: true);
  final primary = context.colorScheme.primary;
  final link = body.copyWith(
    color: primary,
    decoration: TextDecoration.underline,
    decorationColor: primary,
  );
  final children = <InlineSpan>[];
  final lines = markdown.replaceAll('\r\n', '\n').trim().split('\n');
  for (final (index, raw) in lines.indexed) {
    final line = raw.replaceAll(_tag, '').trimRight();
    if (index > 0) children.add(const TextSpan(text: '\n'));
    if (_heading.firstMatch(line) case final match?) {
      children.add(TextSpan(text: match.group(1), style: heading));
      continue;
    }
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) children.add(const TextSpan(text: '• '));
    var start = 0;
    final text = bullet?.group(1) ?? line;
    for (final match in _inline.allMatches(text)) {
      if (match.start > start) {
        children.add(TextSpan(text: text.substring(start, match.start)));
      }
      if (match.group(1) ?? match.group(2) case final emphasis?) {
        children.add(TextSpan(text: emphasis, style: strong));
      } else if (match.group(3) case final label?) {
        final url = match.group(4)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => unawaited(
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          );
        recognizers.add(recognizer);
        children.add(
          TextSpan(text: label, style: link, recognizer: recognizer),
        );
      }
      start = match.end;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }
  }
  return TextSpan(style: body, children: children);
}
