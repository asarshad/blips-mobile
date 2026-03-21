import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

/// Displays a list of past conversations.
class ChatPage extends ConsumerWidget {
  /// Creates the chat list page.
  const ChatPage({super.key});

  /// Router path for the chat experience.
  static const path = '/chat';

  /// Router name for the chat experience.
  static const name = 'chat';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatListAsync = ref.watch(chatListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Your Conversations'),
      ),
      body: chatListAsync.when(
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Text(
                'No conversations yet.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          return ListView.separated(
            padding: AppSpacing.allLg,
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListItem(
                chat: chat,
                onDelete: () async {
                  try {
                    await ref
                        .read(chatRepositoryProvider)
                        .deleteChat(chat.articleId);
                    // Optimistically update or refresh
                    ref.invalidate(chatListProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete chat: $e')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error loading chats: $error',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  const _ChatListItem({
    required this.chat,
    required this.onDelete,
  });

  final ChatConversation chat;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lastMessage = chat.lastMessage;
    final timeLabel = lastMessage != null
        ? DateFormat('MMM d, h:mm a').format(lastMessage.timestamp.toLocal())
        : '';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final imageUrl = chat.article.imageUrl?.trim();

    return Dismissible(
      key: ValueKey(chat.articleId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        return showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm"),
              content: const Text(
                "Are you sure you want to delete this conversation?",
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text("Delete",
                      style: TextStyle(color: colorScheme.error)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) => onDelete(),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => ChatDetailPage(
                article: chat.article,
                existingConversation: chat,
              ),
            ),
          );
        },
        child: Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: AppRadius.borderLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: AppSizes.thumbnailSm,
                        height: AppSizes.thumbnailSm,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: AppSizes.thumbnailSm,
                          height: AppSizes.thumbnailSm,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.article,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        width: AppSizes.thumbnailSm,
                        height: AppSizes.thumbnailSm,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.article,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.article.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      lastMessage?.content ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      timeLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: colorScheme.onSurfaceVariant),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Delete Chat"),
                        content: const Text(
                          "Are you sure you want to delete this conversation?",
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text("Delete",
                                style: TextStyle(color: colorScheme.error)),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
