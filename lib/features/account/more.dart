import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/notice.dart';
import 'package:fl_clash/features/account/purchase.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Loads [load] as it mounts, with a retry on failure.
class AccountLoader<T> extends StatefulWidget {
  const AccountLoader({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
    this.actions,
  });

  final String title;
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
  builder;

  /// App bar buttons for the loaded data.
  final List<IconButtonData> Function(T data, VoidCallback reload)? actions;

  @override
  State<AccountLoader<T>> createState() => _AccountLoaderState<T>();
}

class _AccountLoaderState<T> extends State<AccountLoader<T>> {
  T? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.load();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      final message = e is XboardException ? e.message : compactError(e);
      if (_data == null) {
        setState(() => _error = message);
      } else {
        dialogs.showNotifier(message, level: MessageLevel.error);
      }
    }
  }

  void _reload() => unawaited(_load());

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final data = _data;
    return CommonScaffold(
      title: widget.title,
      iconActions: data == null
          ? const []
          : widget.actions?.call(data, _reload) ?? const [],
      body: data != null
          ? widget.builder(context, data, _reload)
          : Center(
              child: _error == null
                  ? const CommonCircleLoading.page()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12,
                      children: [
                        Text(
                          strings.loadFailed,
                          style: AppTextStyle.headline.of(context),
                        ),
                        Text(_error!, textAlign: TextAlign.center),
                        FilledButton(
                          onPressed: _reload,
                          child: Text(strings.retry),
                        ),
                      ],
                    ),
            ),
    );
  }
}

EdgeInsets accountPagePadding(BuildContext context) => EdgeInsets.fromLTRB(
  16,
  context.contentTopPadding,
  16,
  24 + context.bottomInset,
);

class AccountEmpty extends StatelessWidget {
  const AccountEmpty({super.key, this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text(
            AccountStrings.of(context).nothingHere,
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
          ?action,
        ],
      ),
    );
  }
}

class NoticesView extends ConsumerWidget {
  const NoticesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AccountStrings.of(context);
    return AccountLoader<List<AccountNotice>>(
      title: strings.notices,
      load: ref.read(accountProvider.notifier).notices,
      builder: (context, notices, _) => notices.isEmpty
          ? const AccountEmpty()
          : ListView(
              padding: accountPagePadding(context),
              children: [
                generateSection(
                  items: [
                    for (final notice in notices)
                      ListItem(
                        title: Text(notice.title),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              notice.updatedAt * 1000,
                            ),
                          ),
                        ),
                        onTap: () => unawaited(showAccountNotice(notice)),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class GuidesView extends ConsumerWidget {
  const GuidesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AccountStrings.of(context);
    return AccountLoader<List<GuideArticle>>(
      title: strings.guides,
      load: ref.read(accountProvider.notifier).guides,
      builder: (context, guides, _) {
        if (guides.isEmpty) return const AccountEmpty();
        final categories = <String, List<GuideArticle>>{};
        for (final guide in guides) {
          categories.putIfAbsent(guide.category, () => []).add(guide);
        }
        return ListView(
          padding: accountPagePadding(context),
          children: [
            for (final MapEntry(key: category, value: items)
                in categories.entries)
              generateSection(
                title: category,
                items: [
                  for (final guide in items)
                    ListItem.open(
                      title: Text(guide.title),
                      widget: _GuideView(id: guide.id, title: guide.title),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _GuideView extends ConsumerStatefulWidget {
  const _GuideView({required this.id, required this.title});

  final int id;
  final String title;

  @override
  ConsumerState<_GuideView> createState() => _GuideViewState();
}

class _GuideViewState extends ConsumerState<_GuideView> {
  final _recognizers = <TapGestureRecognizer>[];

  void _releaseRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _releaseRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccountLoader<GuideArticle>(
      title: widget.title,
      load: () => ref.read(accountProvider.notifier).guide(widget.id),
      builder: (context, guide, _) {
        _releaseRecognizers();
        return SingleChildScrollView(
          padding: accountPagePadding(context),
          child: SelectableText.rich(
            noticeSpan(context, guide.body, _recognizers) as TextSpan,
          ),
        );
      },
    );
  }
}

class CouponsView extends ConsumerWidget {
  const CouponsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AccountStrings.of(context);
    return AccountLoader<List<BrandCoupon>>(
      title: strings.coupons,
      load: ref.read(accountProvider.notifier).coupons,
      builder: (context, coupons, _) => coupons.isEmpty
          ? const AccountEmpty()
          : ListView(
              padding: accountPagePadding(context),
              children: [
                for (final coupon in coupons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CommonCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        spacing: 12,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                Text(
                                  strings.couponName(coupon.label),
                                  style: AppTextStyle.headline.of(
                                    context,
                                    emphasized: true,
                                  ),
                                ),
                                Text(
                                  '${coupon.title.isEmpty ? strings.exclusiveCoupon : coupon.title}'
                                  ' · ${strings.timeLeft(coupon.endsAt.difference(DateTime.now()))}',
                                  style: AppTextStyle.footnote
                                      .of(context)
                                      .copyWith(
                                        color: context
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                SelectableText(
                                  coupon.code,
                                  style: AppTextStyle.subheadline.of(
                                    context,
                                    emphasized: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => unawaited(
                              BaseNavigator.push<void>(
                                context,
                                PlansView(couponCode: coupon.code),
                              ),
                            ),
                            child: Text(strings.useCoupon),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class InviteView extends ConsumerWidget {
  const InviteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AccountStrings.of(context);
    final site = ref.watch(
      accountProvider.select((state) => state.brand.siteUrl),
    );
    return AccountLoader<InviteInfo>(
      title: strings.invite,
      load: ref.read(accountProvider.notifier).invite,
      builder: (context, info, _) {
        final link = info.codes.isEmpty
            ? null
            : '$site/#/register?code=${info.codes.first}';
        return ListView(
          padding: accountPagePadding(context),
          children: [
            generateSection(
              items: [
                if (link != null)
                  ListItem(
                    title: Text(strings.inviteLink),
                    subtitle: Text(link),
                    trailing: TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        dialogs.showNotifier(
                          strings.copied,
                          level: MessageLevel.success,
                        );
                      },
                      child: Text(strings.copy),
                    ),
                  ),
                ListItem(
                  title: Text(strings.invited(info.invited)),
                  subtitle: Text(strings.commissionRate(info.rate)),
                ),
                ListItem(
                  title: Text(strings.earned),
                  trailing: Text(yuan(info.earned)),
                ),
                ListItem(
                  title: Text(strings.balance),
                  trailing: Text(yuan(info.balance)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
