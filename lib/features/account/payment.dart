import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _pollInterval = Duration(seconds: 3);

/// webview_flutter has no Windows or Linux implementation.
bool get _inAppWebView => system.isAndroid || system.isMacOS;

/// Pays [tradeNo] and reports whether the order is paid; a page the user
/// leaves before the panel hears from the gateway reports false.
Future<bool> payOrder(
  BuildContext context,
  Account account,
  String tradeNo,
  PaymentMethod method,
) async {
  final result = await account.checkout(tradeNo, method.id);
  if (result.type == -1) return true;
  final data = result.data;
  if (data is! String || data.isEmpty) {
    throw const XboardException('支付发起失败，请换一种支付方式');
  }
  if (!context.mounted) return false;
  if (result.type == 1 && _inAppWebView) {
    return await BaseNavigator.push<bool>(
          context,
          _PaymentView(url: data, tradeNo: tradeNo),
        ) ??
        false;
  }
  unawaited(launchUrl(Uri.parse(data), mode: LaunchMode.externalApplication));
  return await dialogs.showCommonDialog<bool>(
        dismissible: false,
        child: _PaymentWaitDialog(tradeNo: tradeNo),
      ) ??
      false;
}

/// Polls the order and pops with true once the gateway has confirmed it.
mixin _OrderPolling<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _timer;
  var _done = false;

  String get tradeNo;

  void startPolling() {
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(checkPaid()));
  }

  Future<bool> checkPaid() async {
    if (_done) return true;
    try {
      final status = await ref
          .read(accountProvider.notifier)
          .orderStatus(tradeNo);
      if (status == 1 || status == 3) {
        _done = true;
        if (mounted) Navigator.of(context).pop(true);
        return true;
      }
    } catch (e) {
      commonPrint.log(
        'order $tradeNo: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _PaymentView extends ConsumerStatefulWidget {
  const _PaymentView({required this.url, required this.tradeNo});

  final String url;
  final String tradeNo;

  @override
  ConsumerState<_PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends ConsumerState<_PaymentView> with _OrderPolling {
  late final WebViewController _controller;

  @override
  String get tradeNo => widget.tradeNo;

  @override
  void initState() {
    super.initState();
    final siteHost = Uri.tryParse(
      ref.read(accountProvider).brand.siteUrl,
    )?.host;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              // The gateway sends the browser back to the panel's site once
              // it is done; the order status, not that page, is the answer.
              if (uri.host == siteHost) {
                unawaited(checkPaid());
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            }
            if (_appUri(request.url) case final app?) {
              unawaited(launchUrl(app, mode: LaunchMode.externalApplication));
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    return CommonScaffold(
      title: strings.payment,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.check,
          tooltip: strings.iPaid,
          onPressed: () async {
            if (!await checkPaid() && context.mounted) {
              dialogs.showNotifier(strings.notPaidYet);
            }
          },
        ),
      ],
      body: WebViewWidget(controller: _controller),
    );
  }
}

class _PaymentWaitDialog extends ConsumerStatefulWidget {
  const _PaymentWaitDialog({required this.tradeNo});

  final String tradeNo;

  @override
  ConsumerState<_PaymentWaitDialog> createState() => _PaymentWaitDialogState();
}

class _PaymentWaitDialogState extends ConsumerState<_PaymentWaitDialog>
    with _OrderPolling {
  @override
  String get tradeNo => widget.tradeNo;

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    return CommonDialog(
      title: strings.payment,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () async {
            if (!await checkPaid() && context.mounted) {
              dialogs.showNotifier(strings.notPaidYet);
            }
          },
          child: Text(strings.iPaid),
        ),
      ],
      child: Row(
        spacing: 16,
        children: [
          const CommonCircleLoading(size: 24),
          Expanded(child: Text(strings.waitingPayment)),
        ],
      ),
    );
  }
}

/// Alipay and WeChat hand off to their apps through custom schemes; Android
/// pages wrap them as intent:// URLs that name the scheme in the fragment.
Uri? _appUri(String url) {
  if (!url.startsWith('intent:')) return Uri.tryParse(url);
  final scheme = RegExp(r'[#;]scheme=([^;]+)').firstMatch(url)?.group(1);
  final end = url.indexOf('#Intent');
  if (scheme == null || end < 0) return null;
  return Uri.tryParse('$scheme:${url.substring('intent:'.length, end)}');
}
