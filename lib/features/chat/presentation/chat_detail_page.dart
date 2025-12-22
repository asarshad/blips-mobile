import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatDetailPage extends HookConsumerWidget {
  const ChatDetailPage({
    super.key,
    required this.article,
    this.existingConversation,
    this.initialPrompt,
  });

  final ArticleFeedEntry article;
  final ChatConversation? existingConversation;
  final String? initialPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = useState<List<ChatMessage>>(existingConversation?.messages ?? []);
    final isLoading = useState(false);
    final remainingQuota = useState<int?>(null);
    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final isHistoryLoaded = useState(existingConversation != null);
    final hasSentInitialPrompt = useRef(false);

    // Fetch initial quota
    useEffect(() {
      Future(() async {
        try {
          final repo = ref.read(chatRepositoryProvider);
          final quota = await repo.getRemainingDailyMessages();
          if (context.mounted) {
            remainingQuota.value = quota;
          }
        } catch (e) {
          debugPrint('Failed to fetch quota: $e');
        }
      });
      return null;
    }, []);

    // Fetch history if needed
    useEffect(() {
      if (existingConversation == null) {
        Future(() async {
          try {
            final repo = ref.read(chatRepositoryProvider);
            final chat = await repo.getChat(article);
            if (context.mounted) {
              // Prepend history to current messages
              messages.value = [...chat.messages, ...messages.value];
            }
          } catch (e) {
            // Ignore error (e.g. 404 if no history)
            debugPrint('Failed to fetch chat history: $e');
          } finally {
            if (context.mounted) {
              isHistoryLoaded.value = true;
            }
          }
        });
      }
      return null;
    }, []);

    Future<void> sendMessage([String? customText]) async {
      final text = customText ?? textController.text.trim();
      if (text.isEmpty || isLoading.value || remainingQuota.value == 0) return;

      if (customText == null) {
        textController.clear();
      }
      isLoading.value = true;

      // Optimistic update
      final userMsg = ChatMessage(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      );
      
      messages.value = [...messages.value, userMsg];

      try {
        final repository = ref.read(chatRepositoryProvider);
        final response = await repository.sendMessage(article.id, text);
        
        final aiMsg = ChatMessage(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: response.content,
          timestamp: DateTime.now(),
        );
        
        messages.value = [...messages.value, aiMsg];
        remainingQuota.value = response.remainingDaily;
        
        // Refresh the chat list so the new conversation appears/updates
        ref.invalidate(chatListProvider);
      } catch (e) {
        // Restore text if it was cleared
        if (customText == null) {
          textController.text = text;
        }
        
        String errorMessage = 'Failed to send message';
        bool isQuotaLimit = false;

        if (e is DioException) {
          if (e.response?.statusCode == 429) {
            errorMessage = 'Daily message limit reached. Please try again tomorrow.';
            remainingQuota.value = 0;
            isQuotaLimit = true;
            
            // Remove the optimistic message since it failed due to quota
            messages.value = messages.value.where((m) => m.id != userMsg.id).toList();
          } else if (e.response?.data is Map && (e.response?.data as Map).containsKey('detail')) {
             errorMessage = (e.response?.data as Map)['detail'].toString();
          }
        }

        if (context.mounted && !isQuotaLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    // Handle initial prompt
    useEffect(() {
      if (isHistoryLoaded.value && 
          remainingQuota.value != null && 
          initialPrompt != null && 
          !hasSentInitialPrompt.value) {
        
        hasSentInitialPrompt.value = true;
        
        if (remainingQuota.value! > 0) {
          Future.microtask(() => sendMessage(initialPrompt));
        }
      }
      return null;
    }, [isHistoryLoaded.value, remainingQuota.value]);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () async {
            final uri = Uri.parse(article.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  article.imageUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 32,
                    height: 32,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.article,
                        size: 16, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      article.source,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () async {
              final uri = Uri.parse(article.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: messages.value.length + (remainingQuota.value == 0 ? 1 : 0),
              itemBuilder: (context, index) {
                if (remainingQuota.value == 0 && index == 0) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: Colors.yellow, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Daily chat limit reached',
                          style: TextStyle(color: Colors.yellow, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                
                final listIndex = remainingQuota.value == 0 ? index - 1 : index;
                final msg = messages.value[messages.value.length - 1 - listIndex];
                final isUser = msg.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? Radius.zero : null,
                        bottomLeft: !isUser ? Radius.zero : null,
                      ),
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLoading.value)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: colorScheme.primary,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16).copyWith(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    enabled: remainingQuota.value != 0,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: remainingQuota.value == 0 
                          ? 'Daily limit reached' 
                          : 'Type a message...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: remainingQuota.value == 0 
                          ? colorScheme.surface.withValues(alpha: 0.5) 
                          : colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: remainingQuota.value == 0 ? null : () => sendMessage(),
                  icon: const Icon(Icons.send),
                  color: remainingQuota.value == 0 
                      ? colorScheme.onSurface.withValues(alpha: 0.3) 
                      : colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
