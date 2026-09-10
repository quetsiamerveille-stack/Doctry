import 'package:flutter/foundation.dart';

import '../core/api/doctry_api.dart';
import '../core/services/api_client.dart';
import '../models/json_helpers.dart';
import '../models/stats.dart';
import '../models/user.dart';

class SmsLogEntry {
  SmsLogEntry({
    required this.id,
    required this.phone,
    required this.body,
    required this.provider,
    required this.status,
    required this.createdAt,
  });

  factory SmsLogEntry.fromJson(Map<String, dynamic> json) => SmsLogEntry(
        id: asString(json['id']),
        phone: asString(json['phone']),
        body: asString(json['body']),
        provider: asString(json['provider']),
        status: asString(json['status']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String phone;
  final String body;
  final String provider;
  final String status;
  final String createdAt;
}

class AdminProvider extends ChangeNotifier {
  AdminProvider({DoctryApi? api}) : _api = api ?? DoctryApi();

  final DoctryApi _api;

  AdminOverview _overview = AdminOverview.empty();
  AdminStats _stats = AdminStats.empty();
  List<AdminUser> _users = <AdminUser>[];
  FinanceReport _finance = FinanceReport.empty();
  List<SmsLogEntry> _smsLogs = <SmsLogEntry>[];
  String _search = '';
  String _financeDate = '';
  String _busyOn = '';
  String? _error;
  String? _info;

  AdminOverview get overview => _overview;
  AdminStats get stats => _stats;
  List<AdminUser> get users => _users;
  FinanceReport get finance => _finance;
  List<SmsLogEntry> get smsLogs => _smsLogs;
  String get search => _search;
  String get financeDate => _financeDate;
  String get busyOn => _busyOn;
  String? get error => _error;
  String? get info => _info;
  bool get isBusy => _busyOn.isNotEmpty;

  void clearMessages() {
    if (_error == null && _info == null) {
      return;
    }
    _error = null;
    _info = null;
    notifyListeners();
  }

  void reset() {
    _overview = AdminOverview.empty();
    _stats = AdminStats.empty();
    _users = <AdminUser>[];
    _finance = FinanceReport.empty();
    _smsLogs = <SmsLogEntry>[];
    _search = '';
    _financeDate = '';
    _busyOn = '';
    _error = null;
    _info = null;
    notifyListeners();
  }

  Future<bool> _run(String key, Future<bool> Function() action) async {
    _busyOn = key;
    _error = null;
    notifyListeners();
    try {
      final bool result = await action();
      _busyOn = '';
      notifyListeners();
      return result;
    } catch (exception) {
      _error = exception is ApiException ? exception.message : 'Erreur inattendue.';
      _busyOn = '';
      notifyListeners();
      return false;
    }
  }

  void _setError(Object exception) {
    _error = exception is ApiException ? exception.message : 'Erreur inattendue.';
  }

  Future<void> loadAll() async {
    await Future.wait<void>(<Future<void>>[
      loadOverview(),
      loadUsers(),
      loadStats(),
      loadFinance(),
      loadSmsLogs(),
    ]);
  }

  Future<bool> loadOverview() async {
    try {
      _overview = AdminOverview.fromJson(await _api.adminOverview());
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadUsers({String search = ''}) async {
    try {
      final Map<String, dynamic> payload = await _api.adminUsers(search: search);
      _users = asMapList(payload['items']).map(AdminUser.fromJson).toList();
      _search = search;
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String phone = '',
  }) {
    return _run('create-user', () async {
      await _api.adminCreateUser(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        phone: phone,
      );
      await Future.wait<void>(<Future<void>>[loadUsers(), loadOverview()]);
      _info = 'Utilisateur créé.';
      return true;
    });
  }

  Future<bool> blockUser(String userId) {
    return _run('block-$userId', () async {
      final Map<String, dynamic> payload = await _api.blockUser(userId);
      await Future.wait<void>(<Future<void>>[loadUsers(search: _search), loadOverview()]);
      _info = asString(payload['message'], 'Utilisateur bloqué.');
      return true;
    });
  }

  Future<bool> unblockUser(String userId) {
    return _run('unblock-$userId', () async {
      final Map<String, dynamic> payload = await _api.unblockUser(userId);
      await Future.wait<void>(<Future<void>>[loadUsers(search: _search), loadOverview()]);
      _info = asString(payload['message'], 'Utilisateur débloqué.');
      return true;
    });
  }

  Future<bool> loadFinance({String? date}) async {
    try {
      _finance = FinanceReport.fromJson(await _api.finance(date: date));
      _financeDate = date ?? '';
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> searchFinance(String date) => _run('finance', () => loadFinance(date: date));

  Future<bool> loadStats() async {
    try {
      _stats = AdminStats.fromJson(await _api.adminStats());
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadSmsLogs() async {
    try {
      final Map<String, dynamic> payload = await _api.smsLogs();
      _smsLogs = asMapList(payload['items']).map(SmsLogEntry.fromJson).toList();
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }
}
