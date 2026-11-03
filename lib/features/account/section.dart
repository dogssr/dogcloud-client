import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/more.dart';
import 'package:fl_clash/features/account/purchase.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/features/account/tickets.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> checkinAndNotify(BuildContext context, WidgetRef ref) async {
  final strings = AccountStrings.of(context);
  try {
    final result = await ref.read(accountProvider.notifier).checkin();
    dialogs.showNotifier(
      result.success ? strings.checkinReward(result.message) : result.message,
      level: result.success ? MessageLevel.success : MessageLevel.info,
    );
  } catch (e) {
    dialogs.showNotifier(
      e is XboardException ? e.message : compactError(e),
      level: MessageLevel.error,
    );
  }
}

Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final strings = AccountStrings.of(context);
  final confirmed = await dialogs.showMessage(
    title: strings.logout,
    message: TextSpan(text: strings.logoutMessage),
    confirmText: strings.logout,
    destructive: true,
  );
  if (confirmed == true) {
    await ref.read(accountProvider.notifier).logout();
  }
}

/// The account rows that head the 我的 tab.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AccountStrings.of(context);
    final account = ref.watch(accountProvider);
    if (!account.loggedIn) return const SizedBox.shrink();
    final subscription = account.subscription;
    return Column(
      children: [
        generateSection(
          title: strings.account,
          items: [
            ListItem(
              leading: const GlyphIcon(AppGlyphs.account),
              title: Text(account.email ?? subscription?.email ?? ''),
              subtitle: Text(subscription?.planName ?? strings.noPlan),
            ),
            ListItem.open(
              leading: const GlyphIcon(AppGlyphs.star),
              title: Text(
                subscription?.hasPlan ?? false
                    ? strings.renew
                    : strings.buyPlan,
              ),
              widget: const PlansView(),
            ),
            ListItem(
              leading: const GlyphIcon(AppGlyphs.verified),
              title: Text(strings.checkin),
              onTap: () => unawaited(checkinAndNotify(context, ref)),
            ),
            ListItem.open(
              leading: const GlyphIcon(AppGlyphs.sparkle),
              title: Text(strings.coupons),
              widget: const CouponsView(),
            ),
            ListItem.open(
              leading: const GlyphIcon(AppGlyphs.link),
              title: Text(strings.invite),
              widget: const InviteView(),
            ),
          ],
        ),
        generateSection(
          title: strings.help,
          items: [
            ListItem.open(
              leading: const GlyphIcon(AppGlyphs.info),
              title: Text(strings.notices),
              widget: const NoticesView(),
            ),
            ListItem.open(
              leading: const GlyphIcon(AppGlyphs.resources),
              title: Text(strings.guides),
              widget: const GuidesView(),
            ),
            ListItem.open(
              leading: const GlyphIcon(AppGlyphs.compose),
              title: Text(strings.tickets),
              widget: const TicketsView(),
            ),
          ],
        ),
        generateSection(
          items: [
            ListItem(
              leading: const GlyphIcon(AppGlyphs.close),
              title: Text(strings.logout),
              onTap: () => unawaited(confirmLogout(context, ref)),
            ),
          ],
        ),
      ],
    );
  }
}
