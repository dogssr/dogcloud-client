import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/common/brand.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'generated/account.g.dart';

const _authKey = 'account.auth';
const _emailKey = 'account.email';
const _profileKey = 'account.profileId';
const _subscriptionKey = 'account.subscription';
const _seenNoticesKey = 'account.seenNotices';

/// Short enough that a plan change or a node rotation on the panel reaches
/// the client the same day.
const _accountProfileUpdateDuration = Duration(hours: 6);

@Riverpod(keepAlive: true)
class Account extends _$Account {
  XboardClient? _client;

  XboardClient get _xboard =>
      _client ??= XboardClient(userAgent: globalState.packageInfo.ua);

  @override
  AccountState build() {
    unawaited(_restore());
    return const AccountState();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final authData = preferences.getString(_authKey);
    if (authData == null) {
      state = const AccountState(status: AccountStatus.loggedOut);
      unawaited(loadConfig());
      return;
    }
    AccountSubscription? subscription;
    final cached = preferences.getString(_subscriptionKey);
    if (cached != null) {
      try {
        subscription = AccountSubscription.fromJson(
          json.decode(cached) as Map<String, Object?>,
        );
      } catch (_) {}
    }
    state = AccountState(
      status: AccountStatus.loggedIn,
      authData: authData,
      email: preferences.getString(_emailKey),
      subscription: subscription,
      profileId: preferences.getInt(_profileKey),
    );
    unawaited(refresh());
  }

  Future<BrandConfig> loadConfig() async {
    final config = await _xboard.loadConfig();
    if (ref.mounted) {
      state = state.copyWith(config: config);
    }
    return config;
  }

  /// Throws [XboardException] with a message fit for the login form.
  Future<void> login({required String email, required String password}) async {
    final config = state.config ?? await loadConfig();
    final authData = await _xboard.login(
      config,
      email: email,
      password: password,
    );
    await _signIn(config, authData, email);
  }

  Future<GuestConfig> guestConfig() async =>
      _xboard.guestConfig(state.config ?? await loadConfig());

  Future<void> sendEmailCode(String email, {String? captchaToken}) async =>
      _xboard.sendEmailCode(
        state.config ?? await loadConfig(),
        email: email,
        captchaToken: captchaToken,
      );

  Future<void> register({
    required String email,
    required String password,
    required String emailCode,
    String? inviteCode,
    String? captchaToken,
  }) async {
    final config = state.config ?? await loadConfig();
    final authData = await _xboard.register(
      config,
      email: email,
      password: password,
      emailCode: emailCode,
      inviteCode: inviteCode,
      captchaToken: captchaToken,
    );
    await _signIn(config, authData, email);
  }

  /// Resets the password, then signs in with it.
  Future<void> resetPassword({
    required String email,
    required String emailCode,
    required String password,
  }) async {
    await _xboard.resetPassword(
      state.config ?? await loadConfig(),
      email: email,
      emailCode: emailCode,
      password: password,
    );
    await login(email: email, password: password);
  }

  Future<void> _signIn(
    BrandConfig config,
    String authData,
    String email,
  ) async {
    final subscription = await _xboard.subscription(config, authData);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_authKey, authData);
    await preferences.setString(_emailKey, email);
    await _saveSubscription(subscription);
    state = AccountState(
      status: AccountStatus.loggedIn,
      authData: authData,
      email: email,
      subscription: subscription,
      profileId: state.profileId ?? preferences.getInt(_profileKey),
      config: config,
    );
    await _syncProfile(subscription, select: true);
  }

  /// Reloads the plan and, when the panel hands out a new link, the profile.
  Future<void> refresh({bool updateProfile = false}) async {
    final authData = state.authData;
    if (authData == null || state.syncing) return;
    state = state.copyWith(syncing: true);
    try {
      final config = await loadConfig();
      final subscription = await _xboard.subscription(config, authData);
      final previous = state.subscription;
      await _saveSubscription(subscription);
      state = state.copyWith(subscription: subscription);
      final profile = _accountProfile();
      if (updateProfile ||
          profile == null ||
          profile.url != subscription.profileUrl ||
          previous?.subscribeUrl != subscription.subscribeUrl) {
        await _syncProfile(subscription, select: profile == null);
      }
    } on XboardException catch (e) {
      if (e.unauthorized) {
        await logout(message: '登录已过期，请重新登录');
        return;
      }
      rethrow;
    } finally {
      if (ref.mounted && state.syncing) {
        state = state.copyWith(syncing: false);
      }
    }
  }

  /// Removes the account's profile too: its proxies carry this user's keys.
  Future<void> logout({String? message}) async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in [_authKey, _emailKey, _profileKey, _subscriptionKey]) {
      await preferences.remove(key);
    }
    final profileId = state.profileId;
    state = AccountState(status: AccountStatus.loggedOut, config: state.config);
    if (profileId != null &&
        ref.read(profilesProvider).getProfile(profileId) != null) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(profileId);
    }
    if (message != null) {
      dialogs.showNotifier(message, level: MessageLevel.warning);
    }
  }

  /// Runs a panel call with the saved login; an expired login signs out.
  Future<T> _signedIn<T>(
    Future<T> Function(BrandConfig config, String authData) call,
  ) async {
    final authData = state.authData;
    if (authData == null) {
      throw const XboardException('请先登录', unauthorized: true);
    }
    try {
      return await call(state.brand, authData);
    } on XboardException catch (e) {
      if (e.unauthorized) {
        await logout(message: '登录已过期，请重新登录');
      }
      rethrow;
    }
  }

  Future<List<AccountPlan>> plans() => _signedIn(_xboard.plans);

  Future<List<PaymentMethod>> paymentMethods() =>
      _signedIn(_xboard.paymentMethods);

  Future<AccountCoupon> checkCoupon(
    String code,
    AccountPlan plan,
    PlanPeriod period,
  ) => _signedIn(
    (config, authData) => _xboard.checkCoupon(
      config,
      authData,
      code: code,
      planId: plan.id,
      period: period,
    ),
  );

  Future<String> saveOrder(
    AccountPlan plan,
    PlanPeriod period,
    String? couponCode,
  ) => _signedIn(
    (config, authData) => _xboard.saveOrder(
      config,
      authData,
      planId: plan.id,
      period: period,
      couponCode: couponCode,
    ),
  );

  Future<({int type, Object? data})> checkout(String tradeNo, int methodId) =>
      _signedIn(
        (config, authData) => _xboard.checkout(
          config,
          authData,
          tradeNo: tradeNo,
          methodId: methodId,
        ),
      );

  Future<int> orderStatus(String tradeNo) => _signedIn(
    (config, authData) => _xboard.orderStatus(config, authData, tradeNo),
  );

  Future<List<AccountOrder>> unpaidOrders() async {
    final orders = await _signedIn(_xboard.orders);
    return [
      for (final order in orders)
        if (order.unpaid) order,
    ];
  }

  Future<void> cancelOrder(String tradeNo) => _signedIn(
    (config, authData) => _xboard.cancelOrder(config, authData, tradeNo),
  );

  Future<CheckinStatus> checkinStatus() => _signedIn(_xboard.checkinStatus);

  Future<({bool success, String message})> checkin() async {
    final result = await _signedIn(_xboard.checkin);
    if (result.success) {
      unawaited(refresh());
    }
    return result;
  }

  Future<List<AccountNotice>> unseenPopupNotices() async {
    final authData = state.authData;
    if (authData == null) return const [];
    final notices = await _xboard.notices(state.brand, authData);
    final preferences = await SharedPreferences.getInstance();
    final seen = preferences.getStringList(_seenNoticesKey) ?? const [];
    return [
      for (final notice in notices)
        if (notice.popup && !seen.contains(notice.seenKey)) notice,
    ];
  }

  Future<void> markNoticeSeen(AccountNotice notice) async {
    final preferences = await SharedPreferences.getInstance();
    final seen = preferences.getStringList(_seenNoticesKey) ?? const [];
    await preferences.setStringList(_seenNoticesKey, [
      for (final key in seen)
        if (!key.startsWith('${notice.id}:')) key,
      notice.seenKey,
    ]);
  }

  Profile? _accountProfile() {
    final profileId = state.profileId;
    return profileId == null
        ? null
        : ref.read(profilesProvider).getProfile(profileId);
  }

  Future<void> _saveSubscription(AccountSubscription subscription) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _subscriptionKey,
      json.encode(subscription.toJson()),
    );
  }

  Future<void> _syncProfile(
    AccountSubscription subscription, {
    required bool select,
  }) async {
    if (subscription.subscribeUrl.isEmpty) return;
    final existing = _accountProfile();
    final profile =
        (existing ??
                Profile.normal(
                  label: brandProfileLabel,
                  url: subscription.profileUrl,
                ))
            .copyWith(
              url: subscription.profileUrl,
              autoUpdate: true,
              autoUpdateDuration: _accountProfileUpdateDuration,
            );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_profileKey, profile.id);
    state = state.copyWith(profileId: profile.id);
    await ref
        .read(profilesActionProvider.notifier)
        .updateProfile(profile, showLoading: true);
    if (select && ref.read(currentProfileIdProvider) != profile.id) {
      ref.read(currentProfileIdProvider.notifier).value = profile.id;
    }
  }
}
