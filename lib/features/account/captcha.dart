import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// webview_flutter has no Windows or Linux implementation.
bool get hasInAppWebView => system.isAndroid || system.isMacOS;

Future<String?> solveCaptcha(
  BuildContext context, {
  required String siteKey,
  required String siteUrl,
}) {
  return BaseNavigator.push<String>(
    context,
    _CaptchaView(siteKey: siteKey, siteUrl: siteUrl),
  );
}

class _CaptchaView extends StatefulWidget {
  const _CaptchaView({required this.siteKey, required this.siteUrl});

  final String siteKey;
  final String siteUrl;

  @override
  State<_CaptchaView> createState() => _CaptchaViewState();
}

class _CaptchaViewState extends State<_CaptchaView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final siteKey = widget.siteKey.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Captcha',
        onMessageReceived: (message) {
          if (mounted) Navigator.of(context).pop(message.message);
        },
      )
      // Turnstile renders only on hosts its key allows: borrow the site's.
      ..loadHtmlString(_page(siteKey), baseUrl: widget.siteUrl);
  }

  String _page(String siteKey) =>
      '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<style>html,body{margin:0;height:100%}body{display:flex;align-items:center;justify-content:center}</style>
</head><body>
<div class="cf-turnstile" data-sitekey="$siteKey" data-theme="auto" data-language="auto" data-callback="done"></div>
<script>function done(token){Captcha.postMessage(token)}</script>
</body></html>''';

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: AccountStrings.of(context).captchaTitle,
      body: WebViewWidget(controller: _controller),
    );
  }
}
