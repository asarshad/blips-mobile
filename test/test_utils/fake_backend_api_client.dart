import 'package:blips_mobile/core/network/backend_api_client.dart';

/// Deterministic fake for [BackendApiClient] used in unit/widget tests.
///
/// Responses are keyed by request path.
typedef FakeResponseResolver = Map<String, dynamic> Function(
  String path,
  Map<String, dynamic>? queryParameters,
);

final class FakeBackendApiClient implements BackendApiClient {
  FakeBackendApiClient({
    Map<String, Map<String, dynamic>> responses = const {},
    Map<String, List<Map<String, dynamic>>> queuedResponses = const {},
    this.responseResolver,
  })  : _responses = Map<String, Map<String, dynamic>>.from(responses),
        _queuedResponses = queuedResponses.map(
          (key, value) => MapEntry(
            key,
            List<Map<String, dynamic>>.from(value),
          ),
        );

  final Map<String, Map<String, dynamic>> _responses;
  final Map<String, List<Map<String, dynamic>>> _queuedResponses;
  final FakeResponseResolver? responseResolver;

  final List<({String path, Map<String, dynamic>? queryParameters})> requests =
      [];

  void setResponse(String path, Map<String, dynamic> response) {
    _responses[path] = response;
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add((path: path, queryParameters: queryParameters));
    if (responseResolver != null) {
      return responseResolver!(path, queryParameters);
    }
    final queue = _queuedResponses[path];
    if (queue != null && queue.isNotEmpty) {
      return queue.removeAt(0);
    }
    return _responses[path] ?? const <String, dynamic>{};
  }
}
