import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/features/chat/data/chat_repository.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatRepository(dio);
});

final chatListProvider =
    FutureProvider.autoDispose<List<ChatConversation>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchAllChats();
});
