import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/payment.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

final _tag = RegExp(r'<[^>]+>');
final _blankLines = RegExp(r'\n{3,}');

/// Plan descriptions are HTML from the panel editor; paragraphs become lines.
String _planText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false), '\n')
    .replaceAll(_tag, '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(_blankLines, '\n\n')
    .trim();

class PlansView extends ConsumerStatefulWidget {
  const PlansView({super.key});

  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  List<AccountPlan>? _plans;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final plans = await ref.read(accountProvider.notifier).plans();
      if (mounted) setState(() => _plans = plans);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is XboardException ? e.message : compactError(e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final currentPlanId = ref.watch(
      accountProvider.select((state) => state.subscription?.planId),
    );
    final plans = _plans;
    return CommonScaffold(
      title: strings.buyPlan,
      body: plans == null
          ? Center(
              child: _error == null
                  ? const CommonCircleLoading.page()
                  : _LoadError(message: _error!, onRetry: _load),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                context.contentTopPadding,
                16,
                24 + context.bottomInset,
              ),
              children: [
                for (final plan in plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCard(
                      plan: plan,
                      current: plan.id == currentPlanId,
                      onPressed: () => BaseNavigator.push<void>(
                        context,
                        PlanCheckoutView(
                          plan: plan,
                          current: plan.id == currentPlanId,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Text(strings.loadFailed, style: AppTextStyle.headline.of(context)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
        FilledButton(onPressed: onRetry, child: Text(strings.retry)),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.onPressed,
  });

  final AccountPlan plan;
  final bool current;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final colorScheme = context.colorScheme;
    final monthly = plan.monthlyFrom;
    final description = _planText(plan.content);
    return CommonCard(
      onPressed: onPressed,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  plan.name,
                  style: AppTextStyle.title3.of(context, emphasized: true),
                ),
              ),
              for (final tag in [
                if (current) strings.currentPlan,
                ...plan.tags,
              ])
                CommonChip(label: tag),
            ],
          ),
          Text(
            '${strings.traffic(plan.transferGb)} · ${strings.devices(plan.deviceLimit)}',
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (description.isNotEmpty)
            Text(
              description,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          if (monthly != null)
            Text(
              strings.fromPerMonth(yuan(monthly)),
              style: AppTextStyle.headline
                  .of(context, emphasized: true)
                  .copyWith(color: colorScheme.primary),
            ),
        ],
      ),
    );
  }
}

class PlanCheckoutView extends ConsumerStatefulWidget {
  const PlanCheckoutView({
    super.key,
    required this.plan,
    required this.current,
  });

  final AccountPlan plan;

  /// Only the account's own plan sells a data reset.
  final bool current;

  @override
  ConsumerState<PlanCheckoutView> createState() => _PlanCheckoutViewState();
}

class _PlanCheckoutViewState extends ConsumerState<PlanCheckoutView> {
  final _couponController = TextEditingController();
  late final List<PlanPeriod> _periods;
  late PlanPeriod _period;
  List<PaymentMethod> _methods = const [];
  PaymentMethod? _method;
  AccountCoupon? _coupon;
  var _checkingCoupon = false;
  var _paying = false;

  @override
  void initState() {
    super.initState();
    _periods = [
      for (final period in widget.plan.prices.keys)
        if (period != PlanPeriod.reset || widget.current) period,
    ];
    _period = _periods.first;
    unawaited(_loadMethods());
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Account get _account => ref.read(accountProvider.notifier);

  Future<void> _loadMethods() async {
    try {
      final methods = await _account.paymentMethods();
      if (mounted) {
        setState(() {
          _methods = methods;
          _method = methods.firstOrNull;
        });
      }
    } catch (e) {
      _notifyError(e);
    }
  }

  void _notifyError(Object e) {
    dialogs.showNotifier(
      e is XboardException ? e.message : compactError(e),
      level: MessageLevel.error,
    );
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty || _checkingCoupon) return;
    setState(() => _checkingCoupon = true);
    try {
      final coupon = await _account.checkCoupon(code, widget.plan, _period);
      if (mounted) setState(() => _coupon = coupon);
    } catch (e) {
      if (mounted) setState(() => _coupon = null);
      _notifyError(e);
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  Future<void> _pay() async {
    final method = _method;
    if (_paying || method == null) return;
    setState(() => _paying = true);
    try {
      final tradeNo = await _orderToPay();
      if (tradeNo == null || !mounted) return;
      final paid = await payOrder(context, _account, tradeNo, method);
      if (!mounted) return;
      final strings = AccountStrings.of(context);
      if (!paid) {
        dialogs.showNotifier(strings.notPaidYet);
        return;
      }
      dialogs.showNotifier(strings.paid, level: MessageLevel.success);
      unawaited(_account.refresh(updateProfile: true));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _notifyError(e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// The panel allows one unpaid order at a time, so an older one is either
  /// paid instead or cancelled first.
  Future<String?> _orderToPay() async {
    final unpaid = await _account.unpaidOrders();
    if (unpaid.firstOrNull case final order?) {
      if (!mounted) return null;
      final strings = AccountStrings.of(context);
      final cancel = await dialogs.showMessage(
        title: strings.unpaidTitle,
        message: TextSpan(text: strings.unpaidMessage(yuan(order.totalAmount))),
        confirmText: strings.cancelAndNew,
        cancelText: strings.continuePay,
      );
      if (cancel == null) return null;
      if (!cancel) return order.tradeNo;
      await _account.cancelOrder(order.tradeNo);
    }
    return _account.saveOrder(widget.plan, _period, _coupon?.code);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final colorScheme = context.colorScheme;
    final price = widget.plan.prices[_period] ?? 0;
    final discount = _coupon?.discountFor(price) ?? 0;
    final fee = _method?.feeFor(price - discount) ?? 0;
    final total = price - discount + fee;
    final label = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    Widget line(String name, String value, {bool strong = false}) => Row(
      children: [
        Expanded(child: Text(name, style: label)),
        Text(
          value,
          style: strong
              ? AppTextStyle.headline.of(context, emphasized: true)
              : AppTextStyle.subheadline.of(context),
        ),
      ],
    );
    return CommonScaffold(
      title: widget.plan.name,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                context.contentTopPadding,
                16,
                16,
              ),
              children: [
                Text(strings.period, style: label),
                const SizedBox(height: 8),
                for (final period in _periods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CommonCard(
                      isSelected: period == _period,
                      onPressed: () => setState(() {
                        _period = period;
                        _coupon = null;
                      }),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              strings.periodName(period),
                              style: AppTextStyle.body.of(context),
                            ),
                          ),
                          if (period.months > 1)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                strings.perMonth(
                                  yuan(
                                    widget.plan.prices[period]! ~/
                                        period.months,
                                  ),
                                ),
                                style: label,
                              ),
                            ),
                          Text(
                            yuan(widget.plan.prices[period]!),
                            style: AppTextStyle.headline.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(strings.coupon, style: label),
                const SizedBox(height: 8),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: FilledInputTheme(
                        child: TextField(
                          controller: _couponController,
                          enabled: !_paying,
                          decoration: InputDecoration(hintText: strings.coupon),
                          onSubmitted: (_) => _applyCoupon(),
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _checkingCoupon ? null : _applyCoupon,
                      child: _checkingCoupon
                          ? const CommonCircleLoading(size: 18)
                          : Text(strings.apply),
                    ),
                  ],
                ),
                if (_methods.length > 1) ...[
                  const SizedBox(height: 16),
                  Text(strings.paymentMethod, style: label),
                  const SizedBox(height: 8),
                  for (final method in _methods)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CommonCard(
                        isSelected: method.id == _method?.id,
                        onPressed: () => setState(() => _method = method),
                        padding: const EdgeInsets.all(14),
                        child: Text(method.name),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                CommonCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    spacing: 8,
                    children: [
                      line(strings.price, yuan(price)),
                      if (discount > 0)
                        line(strings.discount, '-${yuan(discount)}'),
                      if (fee > 0) line(strings.fee, yuan(fee)),
                      if (_method case final method?)
                        line(strings.paymentMethod, method.name),
                      line(strings.total, yuan(total), strong: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _paying || _method == null ? null : _pay,
                child: _paying
                    ? const CommonCircleLoading(size: 18)
                    : Text(strings.payNow(yuan(total))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
