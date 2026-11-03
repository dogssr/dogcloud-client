import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/login.dart';
import 'package:fl_clash/features/account/notice.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the sign-in page over [child] while no account is signed in, and
/// shows the panel's popup notices once the app is up and signed in.
class AccountGate extends ConsumerStatefulWidget {
  const AccountGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<AccountGate> {
  var _loginOpen = false;
  var _noticesShown = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(accountProvider, (_, next) {
      if (next.status == AccountStatus.loggedOut) {
        _openLogin();
      }
      _showNoticesWhenReady();
    }, fireImmediately: true);
    ref.listenManual(
      initProvider,
      (_, _) => _showNoticesWhenReady(),
      fireImmediately: true,
    );
  }

  void _openLogin() {
    if (_loginOpen) return;
    _loginOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) {
        _loginOpen = false;
        return;
      }
      await navigator.push<void>(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const AccountLoginView(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      _loginOpen = false;
      if (!mounted) return;
      if (ref.read(accountProvider).status == AccountStatus.loggedOut) {
        _openLogin();
      } else {
        _showNoticesWhenReady();
      }
    });
  }

  void _showNoticesWhenReady() {
    if (_noticesShown ||
        _loginOpen ||
        !ref.read(accountProvider).loggedIn ||
        !ref.read(initProvider)) {
      return;
    }
    _noticesShown = true;
    unawaited(_showNotices());
  }

  Future<void> _showNotices() async {
    final account = ref.read(accountProvider.notifier);
    final List<AccountNotice> notices;
    try {
      notices = await account.unseenPopupNotices();
    } catch (e) {
      commonPrint.log(
        'popup notices: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      return;
    }
    for (final notice in notices) {
      if (!mounted) return;
      await showAccountNotice(notice);
      await account.markNoticeSeen(notice);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
