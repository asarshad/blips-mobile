/// Fire-and-forget sync of selected categories to the backend.
///
/// Calls `PUT /preferences/categories`.
/// All errors are swallowed — the user experience must never block on this.
library;

import 'package:blips_mobile/core/error/error.dart';
import 'package:dio/dio.dart';

/// Syncs user category preferences to the remote backend.
class InterestsRemoteService {
  const InterestsRemoteService(this._dio);

  final Dio _dio;

  /// Fire-and-forget: sends [selectedCategories] for the current session.
  ///
  /// Does not throw. Any network or parse error is logged and silently
  /// ignored so the caller is never blocked.
  Future<void> syncCategories({
    required List<String> selectedCategories,
  }) async {
    try {
      await _dio.put<void>(
        '/preferences/categories',
        data: {'selected_categories': selectedCategories},
      );
    } on DioException catch (e) {
      logger.warning(
        'InterestsRemoteService: failed to sync categories',
        category: LogCategory.network,
        error: e,
      );
    } catch (e) {
      logger.warning(
        'InterestsRemoteService: unexpected error syncing categories',
        category: LogCategory.network,
        error: e,
      );
    }
  }
}
