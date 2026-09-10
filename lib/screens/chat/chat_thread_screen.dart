import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat.dart';
import '../../models/declaration.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workspace_provider.dart';

Future<void> openMatchThread(BuildContext context, MatchResult match) async {
  final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
  final bool ok = await workspace.startConversation(
    peerId: match.counterpartId,
    subject: 'Document ${match.docType} — mise en relation DOCTRY',
    lossId: match.lossId,
    findId: match.findId,
  );
  if (!context.mounted) {
    return;
  }
  final Conversation? conversation = workspace.activeConversation;
  if (!ok || conversation == null) {
    return;
  }
  await openChatThread(context, conversation);
}

Future<void> openChatThread(BuildContext context, Conversation conversation) async {
  final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
  workspace.selectConversation(conversation);
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ChatThreadScreen(conversation: conversation),
    ),
  );
  if (context.mounted) {
    workspace.selectConversation(null);
    await workspace.loadConversations();
  }
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceProvider>().loadMessages(widget.conversation.id);
      _jumpToEnd();
    });
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      context.read<WorkspaceProvider>().loadMessages(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    if (!_scroll.hasClients) {
      return;
    }
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  Future<void> _send() async {
    final String body = _input.text.trim();
    if (body.isEmpty) {
      return;
    }
    _input.clear();
    await context.read<WorkspaceProvider>().sendMessage(body);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final String me = context.watch<AuthProvider>().user?.id ?? '';
    final Conversation conversation = workspace.activeConversation ?? widget.conversation;
    final List<ChatMessage> messages = workspace.messages;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        foregroundColor: AppColors.white,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.gold,
              child: Text(
                Fmt.initials(conversation.peerName),
                style: const TextStyle(
                  color: AppColors.darkBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    conversation.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    conversation.subject.isEmpty
                        ? Fmt.profileLabel(conversation.peerRole)
                        : conversation.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.gold.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun message pour le moment. '
                          'Envoyez le premier message à votre interlocuteur DOCTRY.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
                      itemCount: messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ChatMessage message = messages[index];
                        return _Bubble(message: message, mine: message.isMine(me));
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Écrivez votre message…',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    width: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.siam,
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      onPressed: workspace.busyOn == 'message' ? null : _send,
                      child: workspace.busyOn == 'message'
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 19, color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final Color background = mine ? AppColors.siam : AppColors.white;
    final Color foreground = mine ? AppColors.white : AppColors.textPrimary;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message.body, style: TextStyle(color: foreground, fontSize: 13.5)),
            const SizedBox(height: 4),
            Text(
              Fmt.dateTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: mine
                    ? AppColors.white.withValues(alpha: 0.8)
                    : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
