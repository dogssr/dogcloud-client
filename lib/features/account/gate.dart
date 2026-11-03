import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/account/login.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Keeps the sign-in page over [child] while no account is signed in, and
/// offers a newer release once per launch.
class AccountGate extends ConsumerStatefulWidget {
  const AccountGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<AccountGate> {
  var _loginOpen = false;
  var _updateOffered = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(accountProvider, (_, next) {
      if (next.status == AccountStatus.loggedOut) {
        _openLogin();
      }
      if (next.config case final config? when !_updateOffered) {
        _updateOffered = true;
        unawaited(_offerUpdate(config));
      }
    }, fireImmediately: true);
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
      if (mounted &&
          ref.read(accountProvider).status == AccountStatus.loggedOut) {
        _openLogin();
      }
    });
  }

  Future<void> _offerUpdate(BrandConfig config) async {
    final latest = config.latestVersion;
    if (latest == null ||
        compareVersions(latest, globalState.packageInfo.version) <= 0) {
      return;
    }
    final url =
        config.downloadUrls[Platform.operatingSystem] ??
        config.downloadUrls['default'] ??
        config.siteUrl;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final strings = AccountStrings.of(context);
    final accepted = await dialogs.showMessage(
      title: strings.updateTitle(latest),
      message: TextSpan(text: config.releaseNotes ?? strings.updateMessage),
      confirmText: strings.download,
      cancelText: strings.later,
    );
    if (accepted == true) {
      unawaited(
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
