/// Riverpod providers for the first-launch Terms acceptance gate.
library;

import 'package:blips_mobile/features/onboarding/data/terms_local_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final termsLocalServiceProvider = Provider<TermsLocalService>(
  (ref) => TermsLocalService(),
);

/// Async bool — true once the user has accepted the current Terms.
final termsAcceptedProvider = FutureProvider<bool>((ref) async {
  final local = ref.watch(termsLocalServiceProvider);
  return local.isAccepted();
});

/// Records acceptance and invalidates [termsAcceptedProvider] so the
/// router redirect re-evaluates.
///
/// Accepts a [WidgetRef] so it can be called from a stateful widget.
Future<void> acceptTerms(WidgetRef ref) async {
  final local = ref.read(termsLocalServiceProvider);
  await local.markAccepted();
  ref.invalidate(termsAcceptedProvider);
}
