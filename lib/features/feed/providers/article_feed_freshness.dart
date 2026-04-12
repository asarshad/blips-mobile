import 'package:hooks_riverpod/hooks_riverpod.dart';

/// True until the first shell frame completes in the current app process.
final articleColdLaunchPendingProvider = StateProvider<bool>((_) => true);

/// Timestamp of the latest article freshness hint, usually from push.
final articleFeedDirtyAtProvider = StateProvider<DateTime?>((_) => null);
