import 'package:blips_mobile/core/network/backend_api_client.dart';

/// Deterministic fake for [BackendApiClient] used in unit/widget tests.
///
/// Responses are keyed by request path.
final class FakeBackendApiClient implements BackendApiClient {
  FakeBackendApiClient({Map<String, Map<String, dynamic>> responses = const {}})
      : _responses = Map<String, Map<String, dynamic>>.from(responses);

  final Map<String, Map<String, dynamic>> _responses;

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
    return _responses[path] ?? const <String, dynamic>{};
  }
}
