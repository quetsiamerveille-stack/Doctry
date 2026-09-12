import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();
  String? _token;

  String? get token => _token;

  void setToken(String? value) {
    _token = (value == null || value.isEmpty) ? null : value;
  }

  Map<String, String> get _headers => <String, String>{
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  String mediaUrl(String path) {
    if (path.isEmpty) {
      return path;
    }
    final String absolute = ApiConfig.resolve(path);
    if (_token == null) {
      return absolute;
    }
    final String separator = absolute.contains('?') ? '&' : '?';
    return '$absolute${separator}token=$_token';
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final Map<String, String> parameters = <String, String>{};
    query?.forEach((String key, dynamic value) {
      if (value != null && '$value'.isNotEmpty) {
        parameters[key] = '$value';
      }
    });
    return Uri.parse(ApiConfig.resolve(path)).replace(
      queryParameters: parameters.isEmpty ? null : parameters,
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(
        () => _client.post(
          _uri(path, query),
          headers: <String, String>{
            ..._headers,
            'Content-Type': 'application/json',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<dynamic> patch(String path, {Object? body}) => _send(
        () => _client.patch(
          _uri(path),
          headers: <String, String>{
            ..._headers,
            'Content-Type': 'application/json',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<dynamic> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  Future<dynamic> postForm(
    String path, {
    Map<String, String> fields = const <String, String>{},
    String? fileField,
    List<int>? fileBytes,
    String? filename,
    String? fileMimeType,
  }) {
    return _send(() async {
      final http.MultipartRequest request =
          http.MultipartRequest('POST', _uri(path))..headers.addAll(_headers);
      request.fields.addAll(fields);
      if (fileField != null && fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            fileBytes,
            filename: filename ?? 'upload.jpg',
            contentType: fileMimeType == null
                ? null
                : MediaType.parse(fileMimeType),
          ),
        );
      }
      final http.StreamedResponse streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
  }

  Future<List<int>?> getBytes(String path) async {
    try {
      final http.Response response = await _client
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } on Exception {
      return null;
    }
  }

  Future<dynamic> _send(Future<http.Response> Function() action) async {
    final http.Response response;
    try {
      response = await action().timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas. Vérifiez votre connexion.');
    } catch (_) {
      throw ApiException(
        'Impossible de joindre le serveur DOCTRY (${ApiConfig.baseUrl}). '
        'Assurez-vous que le backend FastAPI est démarré.',
      );
    }

    final dynamic decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(_extractError(decoded, response.statusCode),
        statusCode: response.statusCode);
  }

  dynamic _decode(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  String _extractError(dynamic decoded, int statusCode) {
    if (decoded is Map) {
      final dynamic detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (detail is Map && detail['msg'] is String) {
        return detail['msg'] as String;
      }
      if (detail is List && detail.isNotEmpty && detail.first is Map) {
        final dynamic message = (detail.first as Map)['msg'];
        if (message is String) {
          return message;
        }
      }
      if (decoded['message'] is String) {
        return decoded['message'] as String;
      }
    }
    if (decoded is String && decoded.isNotEmpty) {
      return decoded;
    }
    switch (statusCode) {
      case 401:
        return 'Session expirée. Veuillez vous reconnecter.';
      case 403:
        return 'Accès refusé.';
      case 404:
        return 'Ressource introuvable.';
      default:
        return 'Erreur serveur (code $statusCode).';
    }
  }
}
