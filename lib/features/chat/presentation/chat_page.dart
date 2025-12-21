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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Your Conversations'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: chatListAsync.when(
        data: (chats) {
          if (chats.isEmpty) {
            return const Center(
              child: Text(
                'No conversations yet.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListItem(
                chat: chat,
                onDelete: () async {
                  try {
                    await ref.read(chatRepositoryProvider).deleteChat(chat.articleId);
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
            style: const TextStyle(color: Colors.red),
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

    return Dismissible(
      key: ValueKey(chat.articleId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1F2937),
              title: const Text("Confirm", style: TextStyle(color: Colors.white)),
              content: const Text(
                "Are you sure you want to delete this conversation?",
                style: TextStyle(color: Colors.white70),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
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
            MaterialPageRoute(
              builder: (context) => ChatDetailPage(
                article: chat.article,
                existingConversation: chat,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  chat.article.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.article, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage?.content ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF1F2937),
                      title: const Text("Delete Chat", style: TextStyle(color: Colors.white)),
                      content: const Text(
                        "Are you sure you want to delete this conversation?",
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
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
