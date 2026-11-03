import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/account/more.dart';
import 'package:fl_clash/features/account/strings.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/account.dart';
import 'package:fl_clash/providers/account.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

final _listDate = DateFormat('yyyy-MM-dd HH:mm');
final _messageDate = DateFormat('MM-dd HH:mm');

void _notifyError(Object e) {
  dialogs.showNotifier(
    e is XboardException ? e.message : compactError(e),
    level: MessageLevel.error,
  );
}

class TicketsView extends ConsumerWidget {
  const TicketsView({super.key});

  Future<void> _create(BuildContext context, VoidCallback reload) async {
    final created = await showFormSheet<bool>(
      context: context,
      builder: (_) => const _NewTicketForm(),
    );
    if (created == true) reload();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AccountStrings.of(context);
    return AccountLoader<List<AccountTicket>>(
      title: strings.tickets,
      load: ref.read(accountProvider.notifier).tickets,
      actions: (_, reload) => [
        IconButtonData(
          glyph: AppGlyphs.compose,
          tooltip: strings.newTicket,
          onPressed: () => unawaited(_create(context, reload)),
        ),
      ],
      builder: (context, tickets, reload) => tickets.isEmpty
          ? AccountEmpty(
              action: FilledButton(
                onPressed: () => unawaited(_create(context, reload)),
                child: Text(strings.newTicket),
              ),
            )
          : ListView(
              padding: accountPagePadding(context),
              children: [
                generateSection(
                  items: [
                    for (final ticket in tickets)
                      ListItem.open(
                        title: Text(ticket.subject),
                        subtitle: Text(
                          '${strings.ticketStatus(ticket)} · '
                          '${_listDate.format(ticket.updatedAt)}',
                        ),
                        widget: _TicketView(
                          id: ticket.id,
                          subject: ticket.subject,
                        ),
                        onChanged: (_) => reload(),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _TicketView extends ConsumerStatefulWidget {
  const _TicketView({required this.id, required this.subject});

  final int id;
  final String subject;

  @override
  ConsumerState<_TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends ConsumerState<_TicketView> {
  final _reply = TextEditingController();
  var _sending = false;

  Account get _account => ref.read(accountProvider.notifier);

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send(VoidCallback reload) async {
    final message = _reply.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _account.replyTicket(widget.id, message);
      if (_reply.text.trim() == message) _reply.clear();
      reload();
    } catch (e) {
      _notifyError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _close(VoidCallback reload) async {
    final strings = AccountStrings.of(context);
    final confirmed = await dialogs.showMessage(
      title: strings.closeTicket,
      message: TextSpan(text: strings.closeTicketMessage),
      confirmText: strings.closeTicket,
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await _account.closeTicket(widget.id);
      reload();
    } catch (e) {
      _notifyError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    return AccountLoader<AccountTicket>(
      title: widget.subject,
      load: () => _account.ticket(widget.id),
      actions: (ticket, reload) => [
        if (!ticket.closed)
          IconButtonData(
            glyph: AppGlyphs.checkCircle,
            tooltip: strings.closeTicket,
            onPressed: () => unawaited(_close(reload)),
          ),
      ],
      builder: (context, ticket, reload) => Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              padding: EdgeInsets.fromLTRB(
                16,
                context.contentTopPadding,
                16,
                16,
              ),
              children: [
                for (final message in ticket.messages.reversed)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _MessageBubble(message: message),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ticket.closed
                ? Text(
                    strings.ticketStatus(ticket),
                    textAlign: TextAlign.center,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 8,
                    children: [
                      Expanded(
                        child: FilledInputTheme(
                          child: TextField(
                            controller: _reply,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: strings.replyHint,
                            ),
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: strings.send,
                        onPressed: _sending
                            ? null
                            : () => unawaited(_send(reload)),
                        icon: _sending
                            ? const CommonCircleLoading(size: 18)
                            : const GlyphIcon(AppGlyphs.send, fill: 1),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final colorScheme = context.colorScheme;
    final mine = message.mine;
    final time = _messageDate.format(message.createdAt);
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            spacing: 4,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: mine
                      ? colorScheme.primary
                      : context.raisedSurfaceLevel.colorOf(colorScheme),
                  shape: AppShape.md,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: SelectableText(
                    message.message,
                    style: AppTextStyle.body
                        .of(context)
                        .copyWith(color: mine ? colorScheme.onPrimary : null),
                  ),
                ),
              ),
              Text(
                mine ? time : '${strings.support} · $time',
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTicketForm extends ConsumerStatefulWidget {
  const _NewTicketForm();

  @override
  ConsumerState<_NewTicketForm> createState() => _NewTicketFormState();
}

class _NewTicketFormState extends ConsumerState<_NewTicketForm> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  var _attempted = false;
  var _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _subjectMissing => _subject.text.trim().isEmpty;

  bool get _messageMissing => _message.text.trim().isEmpty;

  void _changed(String _) {
    if (_attempted) setState(() {});
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_subjectMissing || _messageMissing) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(accountProvider.notifier)
          .createTicket(_subject.text.trim(), _message.text.trim());
      if (!mounted) return;
      dialogs.showNotifier(
        AccountStrings.of(context).ticketCreated,
        level: MessageLevel.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      _notifyError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AccountStrings.of(context);
    final error = !_attempted
        ? null
        : _subjectMissing
        ? strings.subjectRequired
        : _messageMissing
        ? strings.messageRequired
        : null;
    return FormPage(
      title: strings.newTicket,
      saveLabel: strings.send,
      saving: _saving,
      error: error,
      onSave: () => unawaited(_submit()),
      children: [
        generateSection(
          items: [
            FormRow(
              title: strings.subject,
              invalid: _attempted && _subjectMissing,
              trailing: FormRowTextField(
                controller: _subject,
                hintText: strings.required,
                textInputAction: TextInputAction.next,
                onChanged: _changed,
              ),
            ),
          ],
        ),
        generateSection(
          items: [
            DecorationListItem(
              title: TextField(
                controller: _message,
                minLines: 5,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onChanged: _changed,
                decoration: InputDecoration.collapsed(
                  border: const NoInputBorder(),
                  hintText: strings.message,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
