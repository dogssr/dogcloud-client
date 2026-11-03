import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/features/account/captcha.dart';
import 'package:fl_clash/features/account/register.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountLoginView extends ConsumerStatefulWidget {
  const AccountLoginView({super.key});

  @override
  ConsumerState<AccountLoginView> createState() => _AccountLoginViewState();
}

class _AccountLoginViewState extends ConsumerState<AccountLoginView> {
  static const _maxWidth = 400.0;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      // A dialog opened over this page meanwhile must stay open: pop() would
      // close that dialog instead.
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
    } on XboardException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = compactError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openForm(Widget form, String url) {
    if (hasInAppWebView) {
      unawaited(BaseNavigator.push<void>(context, form));
    } else {
      unawaited(
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final colorScheme = context.colorScheme;
    final brand = ref.watch(accountProvider.select((state) => state.brand));
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/icon.png',
                            width: 72,
                            height: 72,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          appDisplayName,
                          textAlign: TextAlign.center,
                          style: AppTextStyle.title2.of(
                            context,
                            emphasized: true,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.loginSubtitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyle.subheadline
                              .of(context)
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        FilledInputTheme(
                          child: TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.email,
                              AutofillHints.username,
                            ],
                            decoration: InputDecoration(
                              hintText: strings.email,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? strings.emailRequired
                                : null,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledInputTheme(
                          child: SecretTextFormField(
                            controller: _password,
                            focusNode: _passwordFocus,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: strings.password,
                            ),
                            validator: (value) => (value?.isEmpty ?? true)
                                ? strings.passwordRequired
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ),
                        if (_error case final error?) ...[
                          const SizedBox(height: 12),
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: AppTextStyle.footnote
                                .of(context)
                                .copyWith(color: colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const CommonCircleLoading(size: 18)
                              : Text(strings.login),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => _openForm(
                                const RegisterView(),
                                brand.registerUrl,
                              ),
                              child: Text(strings.register),
                            ),
                            TextButton(
                              onPressed: () => _openForm(
                                const ResetPasswordView(),
                                brand.forgotPasswordUrl,
                              ),
                              child: Text(strings.forgotPassword),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
