import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/login.dart';
import 'package:fl_clash/features/account/notice.dart';
import 'package:fl_clash/features/account/update.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the sign-in page over [child] while signed out, then shows popup
/// notices; a required update is asked for at launch and on every return.
class AccountGate extends ConsumerStatefulWidget {
  const AccountGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<AccountGate> {
  static const _updateRecheck = Duration(hours: 1);

  late final AppLifecycleListener _lifecycle;
  var _loginOpen = false;
  var _noticesShown = false;
  var _updateChecking = false;
  DateTime? _updateCheckedAt;

  @override
  void initState() {
    super.initState();
    ref.listenManual(accountProvider, (_, next) {
      if (next.status == AccountStatus.loggedOut) {
        _openLogin();
      }
      _showNoticesWhenReady();
    }, fireImmediately: true);
    ref.listenManual(initProvider, (_, _) {
      _showNoticesWhenReady();
      unawaited(_checkUpdate());
    }, fireImmediately: true);
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(_checkUpdate()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final last = _updateCheckedAt;
    final now = DateTime.now();
    if (_updateChecking ||
        !ref.read(initProvider) ||
        (last != null && now.difference(last) < _updateRecheck)) {
      return;
    }
    _updateChecking = true;
    _updateCheckedAt = now;
    try {
      final config = await ref.read(accountProvider.notifier).loadConfig();
      await promptRequiredUpdate(config, globalState.packageInfo.version);
    } catch (e) {
      commonPrint.log(
        'required update: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
    } finally {
      _updateChecking = false;
    }
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
