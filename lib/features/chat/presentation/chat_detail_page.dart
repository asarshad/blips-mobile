import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/article_image.dart';
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
    this.initialPromptIsStarter = false,
  });

  final ArticleFeedEntry article;
  final ChatConversation? existingConversation;
  final String? initialPrompt;
  final bool initialPromptIsStarter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = useState<List<ChatMessage>>(
      existingConversation?.messages ?? [],
    );
    final isLoading = useState(false);
    final remainingQuota = useState<int?>(null);
    final remainingArticleQuota = useState<int?>(null);
    final articleQuotaReached = useState(false);
    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final isHistoryLoaded = useState(existingConversation != null);
    final hasSentInitialPrompt = useRef(false);
    final previousMessageCount = useRef(messages.value.length);

    void dismissKeyboard() {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    void scrollToLatest({required bool animated}) {
      if (!scrollController.hasClients) return;

      final targetOffset = scrollController.position.maxScrollExtent;
      if (animated) {
        scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }

      scrollController.jumpTo(targetOffset);
    }

    // Fetch initial quota
    useEffect(() {
      Future(() async {
        try {
          final repo = ref.read(chatRepositoryProvider);
          final quota = await repo.getQuotaStatus(article.id);
          if (context.mounted) {
            remainingQuota.value = quota.remainingDaily;
            remainingArticleQuota.value = quota.remainingArticle;
            articleQuotaReached.value =
                quota.remainingArticle != null && quota.remainingArticle! <= 0;
          }
        } catch (e, stack) {
          logger.warning(
            'Failed to fetch quota',
            category: LogCategory.network,
            error: e,
            stackTrace: stack,
          );
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
            logger.debug(
              'Failed to fetch chat history (may not exist)',
              category: LogCategory.network,
            );
          } finally {
            if (context.mounted) {
              isHistoryLoaded.value = true;
            }
          }
        });
      }
      return null;
    }, []);

    Future<void> sendMessage([
      String? customText,
      bool isStarterPrompt = false,
    ]) async {
      final text = customText ?? textController.text.trim();
      final quotaBlocked = !isStarterPrompt &&
          (remainingQuota.value == 0 || articleQuotaReached.value);
      if (text.isEmpty || isLoading.value || quotaBlocked) return;
      final hadAssistantReply =
          messages.value.any((message) => message.role == 'assistant');

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
        final response = await repository.sendMessage(
          article.id,
          text,
          starterPrompt: isStarterPrompt,
        );

        final aiMsg = ChatMessage(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: response.content,
          timestamp: DateTime.now(),
        );

        messages.value = [...messages.value, aiMsg];
        remainingQuota.value = response.remainingDaily;
        remainingArticleQuota.value = response.remainingArticle;
        articleQuotaReached.value = response.remainingArticle != null &&
            response.remainingArticle! <= 0;

        // Refresh the chat list so the new conversation appears/updates
        ref.invalidate(chatListProvider);
      } catch (e) {
        // Restore text if it was cleared
        if (customText == null) {
          textController.text = text;
        }

        String errorMessage = hadAssistantReply
            ? 'Unable to continue this chat right now. Please try your follow-up again.'
            : 'Unable to start this chat right now. Please try again.';
        bool isQuotaLimit = false;

        if (e is DioException) {
          if (e.response?.statusCode == 429) {
            isQuotaLimit = true;
            final responseData = e.response?.data;
            final detail = responseData is Map ? responseData['detail'] : null;
            final quotaType = responseData is Map
                ? responseData['quota_type']?.toString() ??
                    (detail is Map ? detail['quota_type']?.toString() : null)
                : null;
            final serverMessage = responseData is Map
                ? responseData['message']?.toString() ??
                    (detail is Map ? detail['message']?.toString() : null) ??
                    (detail is String ? detail : null)
                : (detail is String ? detail : null);

            if (quotaType == 'article') {
              errorMessage = serverMessage ??
                  'You have reached today\'s limit for this item. Try another story or come back tomorrow.';
              remainingArticleQuota.value = 0;
              articleQuotaReached.value = true;
            } else {
              errorMessage = serverMessage ??
                  'Daily message limit reached. Please try again tomorrow.';
              remainingQuota.value = 0;
            }

            // Remove the optimistic message since it failed due to quota
            messages.value =
                messages.value.where((m) => m.id != userMsg.id).toList();
          } else if (e.response?.data is Map &&
              (e.response?.data as Map).containsKey('detail')) {
            final detail = (e.response?.data as Map)['detail'];
            if (detail is Map && detail['message'] != null) {
              errorMessage = detail['message'].toString();
            } else {
              errorMessage = detail.toString();
            }
          } else if ((e.response?.statusCode ?? 0) >= 500) {
            errorMessage = hadAssistantReply
                ? 'The AI could not continue this conversation just now. Please try again in a moment.'
                : 'The AI could not answer right now. Please try again in a moment.';
          }
        }

        if (context.mounted &&
            (!isQuotaLimit ||
                (remainingQuota.value != 0 && !articleQuotaReached.value))) {
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
        Future.microtask(
          () => sendMessage(initialPrompt, initialPromptIsStarter),
        );
      }
      return null;
    }, [isHistoryLoaded.value, remainingQuota.value]);

    useEffect(() {
      final messageCount = messages.value.length;
      final shouldAnimate = previousMessageCount.value > 0 &&
          messageCount > previousMessageCount.value;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !scrollController.hasClients) return;
        scrollToLatest(animated: shouldAnimate);
      });

      previousMessageCount.value = messageCount;
      return null;
    }, [messages.value.length]);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDailyLimit = remainingQuota.value == 0;
    final hasArticleLimit = articleQuotaReached.value;
    final showQuotaBanner = hasDailyLimit || hasArticleLimit;
    final quotaBannerText = hasDailyLimit
        ? 'Daily chat limit reached'
        : 'Chat limit reached for this item today';
    final quotaHintText =
        hasDailyLimit ? 'Daily limit reached' : 'Item limit reached for today';
    final isComposerEnabled = !hasDailyLimit && !hasArticleLimit;

    return PrimaryScrollController(
      controller: scrollController,
      child: Scaffold(
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
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: ArticleImage.thumbnail(
                    imageUrl: article.imageUrl,
                    category: article.category,
                    source: article.source,
                    width: AppSizes.iconLg + 4,
                    height: AppSizes.iconLg + 4,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        article.source,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
              icon: Icon(Icons.open_in_new, size: AppSizes.iconSm),
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
                primary: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(AppSpacing.lg),
                itemCount: messages.value.length + (showQuotaBanner ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showQuotaBanner && index == 0) {
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.yellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: Colors.yellow.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.yellow,
                            size: AppSizes.iconXs,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            quotaBannerText,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.yellow,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final listIndex = showQuotaBanner ? index - 1 : index;
                  final msg = messages.value[listIndex];
                  final isUser = msg.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(bottom: AppSpacing.md),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppRadius.xl).copyWith(
                          bottomRight: isUser ? Radius.zero : null,
                          bottomLeft: !isUser ? Radius.zero : null,
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUser
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
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
            TextFieldTapRegion(
              child: Container(
                padding: EdgeInsets.all(AppSpacing.lg).copyWith(
                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
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
                        enabled: isComposerEnabled,
                        textInputAction: TextInputAction.send,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: isComposerEnabled
                              ? 'Type a message...'
                              : quotaHintText,
                          hintStyle:
                              TextStyle(color: colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: !isComposerEnabled
                              ? colorScheme.surface.withValues(alpha: 0.5)
                              : colorScheme.surfaceContainerHighest,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.sm + 2,
                          ),
                        ),
                        onTapOutside: (_) => dismissKeyboard(),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    IconButton(
                      onPressed: isComposerEnabled ? () => sendMessage() : null,
                      icon: const Icon(Icons.send),
                      iconSize: AppSizes.iconMd,
                      color: !isComposerEnabled
                          ? colorScheme.onSurface.withValues(alpha: 0.3)
                          : colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
