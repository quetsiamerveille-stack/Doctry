import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat.dart';
import '../../models/user.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/doctry_shell.dart';
import 'chat_thread_screen.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key, required this.newConversationLabel});

  final String newConversationLabel;

  Future<void> _newConversation(BuildContext context) async {
    final WorkspaceProvider workspace = context.read<WorkspaceProvider>();
    await workspace.loadPeers();
    if (!context.mounted) {
      return;
    }
    final Peer? peer = await showModalBottomSheet<Peer>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _PeerSheet(peers: workspace.peers),
    );
    if (peer == null || !context.mounted) {
      return;
    }
    final bool ok = await workspace.startConversation(peerId: peer.id);
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      showDoctrySnackBar(
        context,
        workspace.error ?? 'Impossible de démarrer la conversation.',
        isError: true,
      );
      return;
    }
    final Conversation? conversation = workspace.activeConversation;
    if (conversation != null) {
      await openChatThread(context, conversation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceProvider workspace = context.watch<WorkspaceProvider>();
    final List<Conversation> conversations = workspace.conversations;

    return PageScaffold(
      title: 'Chat',
      onRefresh: workspace.loadConversations,
      children: <Widget>[
        SectionCard(
          title: 'Messagerie directe',
          icon: Icons.forum_outlined,
          subtitle: 'Échangez en toute sécurité avec les autres membres DOCTRY.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DoctryButton(
                label: newConversationLabel,
                icon: Icons.add_comment_outlined,
                onPressed: () => _newConversation(context),
                loading: workspace.busyOn == 'peers',
              ),
              const SizedBox(height: 18),
              if (conversations.isEmpty)
                const EmptyState(
                  message: 'Aucune conversation. Démarrez-en une nouvelle.',
                  icon: Icons.chat_bubble_outline,
                )
              else
                Column(
                  children: <Widget>[
                    for (final Conversation conversation in conversations)
                      _ConversationTile(
                        conversation: conversation,
                        onTap: () => openChatThread(context, conversation),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: conversation.unreadCount > 0 ? AppColors.gold : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 21,
                  backgroundColor: AppColors.siamSoft,
                  child: Text(
                    Fmt.initials(conversation.peerName),
                    style: const TextStyle(
                      color: AppColors.siam,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        conversation.peerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conversation.lastMessage.isEmpty
                            ? (conversation.subject.isEmpty
                                ? Fmt.profileLabel(conversation.peerRole)
                                : conversation.subject)
                            : conversation.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      Fmt.relative(conversation.lastMessageAt),
                      style: const TextStyle(fontSize: 10.5, color: AppColors.grey),
                    ),
                    if (conversation.unreadCount > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      Badge(
                        backgroundColor: AppColors.gold,
                        textColor: AppColors.darkBlue,
                        label: Text('${conversation.unreadCount}'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeerSheet extends StatelessWidget {
  const _PeerSheet({required this.peers});

  final List<Peer> peers;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.35,
      builder: (BuildContext context, ScrollController controller) {
        return Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.group_outlined, color: AppColors.siam),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Membres DOCTRY disponibles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: peers.isEmpty
                  ? const EmptyState(
                      message: 'Aucun membre inscrit pour le moment.',
                      icon: Icons.person_off_outlined,
                    )
                  : ListView.separated(
                      controller: controller,
                      itemCount: peers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final Peer peer = peers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.siamSoft,
                            child: Text(
                              Fmt.initials(peer.fullName),
                              style: const TextStyle(
                                color: AppColors.siam,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            peer.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColors.darkBlue,
                            ),
                          ),
                          subtitle: Text(
                            '${Fmt.profileLabel(peer.role)} · ${peer.email}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          trailing: peer.averageRating > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.star, size: 16, color: AppColors.gold),
                                    const SizedBox(width: 3),
                                    Text(
                                      peer.averageRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              : const Icon(Icons.chevron_right, color: AppColors.grey),
                          onTap: () => Navigator.pop(context, peer),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
