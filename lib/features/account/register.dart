import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/captcha.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _resendDelay = 60;
const _minPasswordLength = 8;

/// The email, code and password fields both forms share, and sending the
/// code behind the panel's captcha.
mixin _EmailCodeForm<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  GuestConfig? guest;
  var busy = false;
  var _sending = false;
  var _resendIn = 0;
  Timer? _timer;

  Account get account => ref.read(accountProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(_loadGuest());
  }

  @override
  void dispose() {
    _timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _loadGuest() async {
    try {
      final config = await account.guestConfig();
      if (mounted) setState(() => guest = config);
    } catch (e) {
      notifyError(e);
    }
  }

  void notifyError(Object e) {
    dialogs.showNotifier(
      e is XboardException ? e.message : compactError(e),
      level: MessageLevel.error,
    );
  }

  /// Null when the user leaves the captcha or the device cannot show it.
  Future<String?> captchaToken() async {
    final config = guest ?? await account.guestConfig();
    if (!config.captchaRequired) return '';
    final siteKey = config.turnstileSiteKey;
    if (siteKey == null || !hasInAppWebView) {
      if (mounted) {
        dialogs.showNotifier(AccountStrings.of(context).captchaUnavailable);
      }
      return null;
    }
    if (!mounted) return null;
    return solveCaptcha(
      context,
      siteKey: siteKey,
      siteUrl: ref.read(accountProvider).brand.siteUrl,
    );
  }

  Future<void> sendCode() async {
    final address = email.text.trim();
    if (_sending || _resendIn > 0 || address.isEmpty) return;
    setState(() => _sending = true);
    try {
      final token = await captchaToken();
      if (token == null) return;
      await account.sendEmailCode(
        address,
        captchaToken: token.isEmpty ? null : token,
      );
      if (!mounted) return;
      dialogs.showNotifier(
        AccountStrings.of(context).codeSent,
        level: MessageLevel.success,
      );
      setState(() => _resendIn = _resendDelay);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _resendIn <= 1) timer.cancel();
        if (!mounted) return;
        setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      });
    } catch (e) {
      notifyError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? validatePassword(String? value) {
    final strings = AccountStrings.of(context);
    if (value == null || value.length < _minPasswordLength) {
      return strings.passwordTooShort;
    }
    return null;
  }

  List<Widget> emailFields(AccountStrings strings) {
    final suffixes = guest?.emailSuffixes ?? const [];
    return [
      FilledInputTheme(
        child: TextFormField(
          controller: email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            hintText: strings.email,
            helperText: suffixes.isEmpty
                ? null
                : strings.emailSuffixes(suffixes),
          ),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? strings.emailRequired : null,
        ),
      ),
      Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FilledInputTheme(
              child: TextFormField(
                controller: code,
                enabled: !busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: InputDecoration(hintText: strings.emailCode),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? strings.codeRequired
                    : null,
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: busy || _sending || _resendIn > 0 ? null : sendCode,
            child: _sending
                ? const CommonCircleLoading(size: 18)
                : Text(
                    _resendIn > 0
                        ? strings.resendIn(_resendIn)
                        : strings.sendCode,
                  ),
          ),
        ],
      ),
    ];
  }

  List<Widget> passwordFields(AccountStrings strings, {required String hint}) {
    return [
      FilledInputTheme(
        child: SecretTextFormField(
          controller: password,
          decoration: InputDecoration(hintText: hint),
          validator: validatePassword,
        ),
      ),
      FilledInputTheme(
        child: SecretTextFormField(
          controller: confirm,
          decoration: InputDecoration(hintText: strings.confirmPassword),
          validator: (value) =>
              value != password.text ? strings.passwordMismatch : null,
        ),
      ),
    ];
  }

  Future<void> submit(Future<void> Function() action, String done) async {
    if (busy || !(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      dialogs.showNotifier(done, level: MessageLevel.success);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      notifyError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget page({
    required String title,
    required List<Widget> fields,
    required String action,
    required VoidCallback onSubmit,
  }) {
    return CommonScaffold(
      title: title,
      body: Form(
        key: formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            context.contentTopPadding + 8,
            24,
            32 + context.bottomInset,
          ),
          children: [
            for (final field in fields)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: field),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: busy ? const CommonCircleLoading(size: 18) : Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView>
    with _EmailCodeForm {
  final _invite = TextEditingController();

  @override
  void dispose() {
    _invite.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final token = await captchaToken();
    if (token == null) return;
    await account.register(
      email: email.text.trim(),
      password: password.text,
      emailCode: code.text.trim(),
      inviteCode: _invite.text.trim(),
      captchaToken: token.isEmpty ? null : token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final inviteRequired = guest?.inviteRequired ?? false;
    return page(
      title: strings.register,
      action: strings.register,
      onSubmit: () => unawaited(submit(_register, strings.registered)),
      fields: [
        ...emailFields(strings),
        ...passwordFields(strings, hint: strings.password),
        FilledInputTheme(
          child: TextFormField(
            controller: _invite,
            enabled: !busy,
            decoration: InputDecoration(
              hintText: strings.inviteCode(required: inviteRequired),
            ),
            validator: (value) =>
                inviteRequired && (value?.trim().isEmpty ?? true)
                ? strings.inviteCode(required: true)
                : null,
          ),
        ),
      ],
    );
  }
}

class ResetPasswordView extends ConsumerStatefulWidget {
  const ResetPasswordView({super.key});

  @override
  ConsumerState<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends ConsumerState<ResetPasswordView>
    with _EmailCodeForm {
  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    return page(
      title: strings.forgotPassword,
      action: strings.forgotPassword,
      onSubmit: () => unawaited(
        submit(
          () => account.resetPassword(
            email: email.text.trim(),
            emailCode: code.text.trim(),
            password: password.text,
          ),
          strings.passwordReset,
        ),
      ),
      fields: [
        ...emailFields(strings),
        ...passwordFields(strings, hint: strings.newPassword),
      ],
    );
  }
}
