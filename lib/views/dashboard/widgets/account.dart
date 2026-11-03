import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/purchase.dart';
import 'package:fl_clash/features/account/section.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  String _expiry(AccountStrings strings, AccountSubscription? subscription) {
    final expiredAt = subscription?.expiredAt;
    if (subscription == null || !subscription.hasPlan) return '';
    if (expiredAt == null) return strings.neverExpires;
    final date = DateFormat('yyyy-MM-dd').format(expiredAt);
    if (subscription.expired) return strings.expiredOn(date);
    return strings.expiresOn(
      date,
      (expiredAt.difference(DateTime.now()).inHours / 24).ceil(),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final strings = AccountStrings.of(context);
    try {
      await ref.read(accountProvider.notifier).refresh(updateProfile: true);
      dialogs.showNotifier(strings.refreshed, level: MessageLevel.success);
    } on XboardException catch (e) {
      dialogs.showNotifier(e.message, level: MessageLevel.error);
    } catch (e) {
      dialogs.showNotifier(compactError(e), level: MessageLevel.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AccountStrings.of(context);
    final colorScheme = context.colorScheme;
    final mobile = !DashboardDensityScope.of(context).isDesktop;
    final account = ref.watch(accountProvider);
    final subscription = account.subscription;
    final hasPlan = subscription?.hasPlan ?? false;
    final expiry = _expiry(strings, subscription);
    return DashboardCard(
      semanticLabel: strings.account,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.account,
            title: strings.account,
            trailing: [
              DashboardIconButton(
                glyph: AppGlyphs.refresh,
                tooltip: strings.refresh,
                onPressed: account.syncing
                    ? null
                    : () => unawaited(_refresh(context, ref)),
              ),
              DashboardIconButton(
                glyph: AppGlyphs.more,
                tooltip: strings.logout,
                onPressed: () => unawaited(confirmLogout(context, ref)),
              ),
            ],
          ),
          SizedBox(height: mobile ? 12 : 10),
          DashboardFitText(
            subscription?.planName ?? strings.noPlan,
            style: DashboardText.figure(
              context,
              mobile ? AppTextStyle.title2 : AppTextStyle.title3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            account.email ?? subscription?.email ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
          if (expiry.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              expiry,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DashboardText.label(
                context,
                color: subscription?.expired ?? false
                    ? colorScheme.error
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => unawaited(
                    BaseNavigator.push<void>(context, const PlansView()),
                  ),
                  child: Text(hasPlan ? strings.renew : strings.buyPlan),
                ),
              ),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => unawaited(checkinAndNotify(context, ref)),
                  child: Text(strings.checkin),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
