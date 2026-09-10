import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  const ApiConfig._();

  static const String _storageKey = 'doctry_api_base_url';
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String _runtimeBaseUrl = '';

  static String get defaultBaseUrl {
    if (_definedBaseUrl.trim().isNotEmpty) {
      return _normalize(_definedBaseUrl);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String get baseUrl =>
      _runtimeBaseUrl.isNotEmpty ? _runtimeBaseUrl : defaultBaseUrl;

  static Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stored = prefs.getString(_storageKey) ?? '';
    if (stored.trim().isNotEmpty) {
      _runtimeBaseUrl = _normalize(stored);
    }
  }

  static Future<void> override(String url) async {
    final String normalized = _normalize(url);
    _runtimeBaseUrl = normalized;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, normalized);
  }

  static Future<void> reset() async {
    _runtimeBaseUrl = '';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  static String _normalize(String url) {
    String value = url.trim();
    if (value.isEmpty) {
      return value;
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String resolve(String path) {
    if (path.isEmpty) {
      return path;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$baseUrl${path.startsWith('/') ? path : '/$path'}';
  }

  static Future<bool> isDoctryServer(String candidateUrl, {Duration timeout = const Duration(milliseconds: 1500)}) async {
    try {
      final Uri uri = Uri.parse('$candidateUrl/api/health');
      final http.Response res = await http.get(uri).timeout(timeout);
      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && (data['status'] == 'ok' || data.containsKey('ai_engine'))) {
          return true;
        }
      }
    } catch (_) {
      // Ignore network errors during probe
    }
    return false;
  }

  static List<String> getCandidateUrls() {
    final List<String> candidates = <String>[];
    final String current = baseUrl;
    candidates.add(current);

    if (current.contains(':8000')) {
      candidates.add(current.replaceAll(':8000', ':8001'));
    } else if (current.contains(':8001')) {
      candidates.add(current.replaceAll(':8001', ':8000'));
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (!candidates.contains('http://10.0.2.2:8000')) {
        candidates.add('http://10.0.2.2:8000');
      }
      if (!candidates.contains('http://10.0.2.2:8001')) {
        candidates.add('http://10.0.2.2:8001');
      }
    } else {
      if (!candidates.contains('http://127.0.0.1:8000')) {
        candidates.add('http://127.0.0.1:8000');
      }
      if (!candidates.contains('http://127.0.0.1:8001')) {
        candidates.add('http://127.0.0.1:8001');
      }
      if (!candidates.contains('http://localhost:8000')) {
        candidates.add('http://localhost:8000');
      }
      if (!candidates.contains('http://localhost:8001')) {
        candidates.add('http://localhost:8001');
      }
    }

    return candidates;
  }

  static Future<String?> probeAndAutoSelect() async {
    final List<String> candidates = getCandidateUrls();
    for (final String candidate in candidates) {
      if (await isDoctryServer(candidate)) {
        if (candidate != baseUrl) {
          await override(candidate);
        }
        return candidate;
      }
    }
    return null;
  }
}
