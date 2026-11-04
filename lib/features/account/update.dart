import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _snoozeKey = 'brand_update_snooze';

/// Asks for the required release unless the user put that release off and
/// the days have not run out; false when nothing was asked.
Future<bool> promptRequiredUpdate(
  BrandConfig config,
  String version, {
  DateTime? now,
}) async {
  final latest = config.requiredUpdateFor(version);
  if (latest == null || rootNavigatorKey.currentContext == null) return false;
  final time = now ?? DateTime.now();
  final preferences = await SharedPreferences.getInstance();
  final until = _snoozedUntil(preferences.getString(_snoozeKey), latest);
  if (until != null && until.isAfter(time)) return false;
  final snoozed = await dialogs.showCommonDialog<bool>(
    dismissible: false,
    child: _RequiredUpdateDialog(config: config, latest: latest),
  );
  if (snoozed == true) {
    final end = time.add(Duration(days: config.snoozeDays));
    await preferences.setString(
      _snoozeKey,
      '$latest@${end.millisecondsSinceEpoch}',
    );
  }
  return true;
}

DateTime? _snoozedUntil(String? value, String latest) {
  final at = value?.lastIndexOf('@') ?? -1;
  if (value == null || at < 0 || value.substring(0, at) != latest) return null;
  final millis = int.tryParse(value.substring(at + 1));
  return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
}

class _RequiredUpdateDialog extends StatelessWidget {
  const _RequiredUpdateDialog({required this.config, required this.latest});

  final BrandConfig config;
  final String latest;

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final notes = config.releaseNotes?.trim() ?? '';
    final days = config.snoozeDays;
    return CommonDialog(
      title: strings.updateRequired,
      actions: [
        if (days > 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.remindIn(days)),
          ),
        TextButton(
          onPressed: () {
            unawaited(
              launchUrl(
                Uri.parse(config.downloadUrl),
                mode: LaunchMode.externalApplication,
              ),
            );
            // With no days to put it off, the prompt stays until the update.
            if (days > 0) Navigator.of(context).pop(false);
          },
          child: Text(strings.updateNow),
        ),
      ],
      child: Text(
        [
          strings.updateMessage(latest),
          if (notes.isNotEmpty) notes,
        ].join('\n\n'),
        style: AppTextStyle.subheadline.of(context),
      ),
    );
  }
}
