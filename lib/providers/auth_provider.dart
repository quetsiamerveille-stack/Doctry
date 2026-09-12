import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/doctry_api.dart';
import '../core/config/api_config.dart';
import '../core/services/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/json_helpers.dart';
import '../models/user.dart';

enum AuthStatus { unknown, installRequired, unauthenticated, otpPending, authenticated }

class ServerInfo {
  ServerInfo({
    required this.online,
    required this.adminInstallRequired,
    required this.emailDelivery,
    required this.smsDelivery,
    required this.aiEngine,
    required this.minRewardAmount,
    required this.commissionRate,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        online: true,
        adminInstallRequired: asBool(json['admin_install_required']),
        emailDelivery: asString(json['email_delivery'], 'simulation'),
        smsDelivery: asString(json['sms_delivery'], 'simulation'),
        aiEngine: asString(json['ai_engine'], 'moteur-local'),
        minRewardAmount: asInt(json['min_reward_amount']),
        commissionRate: asDouble(json['commission_rate']),
      );

  factory ServerInfo.offline() => ServerInfo(
        online: false,
        adminInstallRequired: false,
        emailDelivery: '—',
        smsDelivery: '—',
        aiEngine: '—',
        minRewardAmount: 1500,
        commissionRate: 0.05,
      );

  final bool online;
  final bool adminInstallRequired;
  final String emailDelivery;
  final String smsDelivery;
  final String aiEngine;
  final int minRewardAmount;
  final double commissionRate;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({DoctryApi? api}) : _api = api ?? DoctryApi();

  static const String _tokenKey = 'doctry_token';
  static const String _userKey = 'doctry_user';

  final DoctryApi _api;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  ServerInfo _server = ServerInfo.offline();
  OtpChallenge? _challenge;
  bool _busy = false;
  String? _error;
  String? _info;
  bool _ratingDue = false;
  int _ratingIntervalDays = 3;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  ServerInfo get server => _server;
  OtpChallenge? get challenge => _challenge;
  bool get busy => _busy;
  String? get error => _error;

  /// Erreur de validation cote client (sans appel serveur).
  void setValidationError(String message) {
    _error = message;
    notifyListeners();
  }
  String? get info => _info;
  bool get ratingDue => _ratingDue;
  int get ratingIntervalDays => _ratingIntervalDays;

  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String get activeProfile => _user?.activeProfile ?? 'owner';
  bool get isOwnerProfile => activeProfile == 'owner';
  bool get isFinderProfile => activeProfile == 'finder';
  bool get isAdminProfile => activeProfile == 'admin';

  void _setError(Object exception) {
    _error = exception is ApiException ? exception.message : 'Erreur inattendue.';
  }

  void clearMessages() {
    if (_error == null && _info == null) {
      return;
    }
    _error = null;
    _info = null;
    notifyListeners();
  }

  Future<bool> _safe(Future<bool> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final bool result = await action();
      _busy = false;
      notifyListeners();
      return result;
    } catch (exception) {
      _setError(exception);
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> bootstrap() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storedToken = prefs.getString(_tokenKey);
    final String? storedUser = prefs.getString(_userKey);

    if (storedToken != null && storedToken.isNotEmpty) {
      ApiClient.instance.setToken(storedToken);
      if (storedUser != null && storedUser.isNotEmpty) {
        try {
          _user = AppUser.fromJson(
            Map<String, dynamic>.from(jsonDecode(storedUser) as Map),
          );
        } on FormatException {
          _user = null;
        }
      }
    }

    await refreshServerInfo();

    if (_user == null) {
      _status = _server.online && _server.adminInstallRequired
          ? AuthStatus.installRequired
          : AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final Map<String, dynamic> payload = await _api.me();
      _user = AppUser.fromJson(payload);
      await _persist();
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _clearSession(prefs);
      _status = _server.online && _server.adminInstallRequired
          ? AuthStatus.installRequired
          : AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> refreshServerInfo() async {
    try {
      _server = ServerInfo.fromJson(await _api.installStatus());
      return;
    } catch (_) {
      // Primary port unreachable or returned non-doctry response
    }

    final String? discovered = await ApiConfig.probeAndAutoSelect();
    if (discovered != null) {
      try {
        _server = ServerInfo.fromJson(await _api.installStatus());
        return;
      } catch (_) {}
    }

    _server = ServerInfo.offline();
  }

  Future<void> _persist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = ApiClient.instance.token ?? '';
    if (token.isEmpty || _user == null) {
      await _clearSession(prefs);
      return;
    }
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(_toUserJson(_user!)));
  }

  Map<String, dynamic> _toUserJson(AppUser value) => <String, dynamic>{
        'id': value.id,
        'email': value.email,
        'first_name': value.firstName,
        'last_name': value.lastName,
        'phone': value.phone,
        'role': value.role,
        'active_profile': value.activeProfile,
        'profile_photo': value.profilePhoto,
        'is_admin': value.isAdmin,
        'is_blocked': value.isBlocked,
        'wallet_balance': value.walletBalance,
        'average_rating': value.averageRating,
        'rating_count': value.ratingCount,
        'created_at': value.createdAt,
      };

  Future<void> _clearSession(SharedPreferences prefs) async {
    _user = null;
    _challenge = null;
    ApiClient.instance.setToken(null);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  void _applyTokenPayload(Map<String, dynamic> payload) {
    ApiClient.instance.setToken(asString(payload['token']));
    _user = AppUser.fromJson(asMap(payload['user']));
    _challenge = null;
    _status = AuthStatus.authenticated;
    _ratingDue = false;
  }

  Future<bool> login({
    required String profile,
    required String email,
    required String password,
  }) {
    return _safe(() async {
      _challenge = await _api.login(profile: profile, email: email, password: password);
      _status = AuthStatus.otpPending;
      _info = _challenge!.isSimulated
          ? 'Simulation email : le code OTP est ${_challenge!.devCode}.'
          : 'Un code OTP a été envoyé à ${_challenge!.email}.';
      return true;
    });
  }

  Future<bool> signup({
    required String profile,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String phone = '',
  }) {
    return _safe(() async {
      _challenge = await _api.signup(
        profile: profile,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone,
      );
      _status = AuthStatus.otpPending;
      _info = _challenge!.isSimulated
          ? 'Compte créé. Simulation email : le code OTP est ${_challenge!.devCode}.'
          : 'Compte créé. Un code OTP a été envoyé à ${_challenge!.email}.';
      return true;
    });
  }

  Future<bool> adminLogin({required String email, required String password}) {
    return _safe(() async {
      _challenge = await _api.adminLogin(email: email, password: password);
      _status = AuthStatus.otpPending;
      _info = _challenge!.isSimulated
          ? 'Simulation email : le code OTP administrateur est ${_challenge!.devCode}.'
          : 'Un code OTP administrateur a été envoyé à ${_challenge!.email}.';
      return true;
    });
  }

  Future<bool> installAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phone = '',
  }) {
    return _safe(() async {
      _challenge = await _api.installAdmin(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      _status = AuthStatus.otpPending;
      _server = ServerInfo(
        online: _server.online,
        adminInstallRequired: false,
        emailDelivery: _server.emailDelivery,
        smsDelivery: _server.smsDelivery,
        aiEngine: _server.aiEngine,
        minRewardAmount: _server.minRewardAmount,
        commissionRate: _server.commissionRate,
      );
      _info = _challenge!.isSimulated
          ? 'Administrateur installé. Code OTP de simulation : ${_challenge!.devCode}.'
          : 'Administrateur installé. Un code OTP a été envoyé.';
      return true;
    });
  }

  Future<bool> verifyOtp(String code) {
    return _safe(() async {
      final OtpChallenge? current = _challenge;
      if (current == null) {
        _error = 'Aucun challenge OTP en cours.';
        return false;
      }
      final Map<String, dynamic> payload =
          await _api.verifyOtp(ticket: current.ticket, code: code.trim());
      _applyTokenPayload(payload);
      await _persist();
      _info = 'Connexion réussie.';
      return true;
    });
  }

  Future<bool> resendOtp() {
    return _safe(() async {
      final OtpChallenge? current = _challenge;
      if (current == null) {
        _error = 'Aucun challenge OTP en cours.';
        return false;
      }
      final Map<String, dynamic> payload = await _api.resendOtp(current.email);
      _challenge = OtpChallenge.fromJson(payload);
      _info = _challenge!.isSimulated
          ? 'Nouveau code OTP (simulation) : ${_challenge!.devCode}.'
          : 'Un nouveau code OTP a été envoyé.';
      return true;
    });
  }

  void cancelOtp() {
    _challenge = null;
    _status = _user == null
        ? (_server.online && _server.adminInstallRequired
            ? AuthStatus.installRequired
            : AuthStatus.unauthenticated)
        : AuthStatus.authenticated;
    _error = null;
    _info = null;
    notifyListeners();
  }

  Future<bool> refreshMe() {
    return _safe(() async {
      _user = AppUser.fromJson(await _api.me());
      await _persist();
      return true;
    });
  }

  void adoptUser(AppUser value) {
    _user = value;
    _persist();
    notifyListeners();
  }

  /// URL chargeable de la photo de profil d'un utilisateur (avec token).
  String profilePhotoUrl(String userId) =>
      _api.client.mediaUrl('/api/media/profiles/$userId');

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? password,
    String? currentPassword,
    String? phone,
  }) {
    return _safe(() async {
      final Map<String, dynamic> payload = await _api.updateProfile(
        firstName: firstName,
        lastName: lastName,
        password: password,
        currentPassword: currentPassword,
        phone: phone,
      );
      _user = AppUser.fromJson(payload);
      await _persist();
      _info = 'Profil mis à jour.';
      return true;
    });
  }

  Future<bool> updateAdminProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? currentPassword,
  }) {
    return _safe(() async {
      final Map<String, dynamic> payload = await _api.updateAdminProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        currentPassword: currentPassword,
      );
      _user = AppUser.fromJson(payload);
      await _persist();
      _info = 'Profil administrateur mis à jour.';
      return true;
    });
  }

  Future<bool> uploadProfilePhoto({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) {
    return _safe(() async {
      final Map<String, dynamic> payload = await _api.uploadProfilePhoto(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
      _user = AppUser.fromJson(payload);
      await _persist();
      _info = 'Photo de profil mise à jour.';
      return true;
    });
  }

  Future<bool> switchProfile(String profile) {
    return _safe(() async {
      final Map<String, dynamic> payload = await _api.switchProfile(profile);
      _user = AppUser.fromJson(payload);
      await _persist();
      _info = 'Profil actif : ${Fmt.profileLabel(profile)}.';
      return true;
    });
  }

  Future<void> checkRatingDue() async {
    if (_user == null) {
      return;
    }
    try {
      final Map<String, dynamic> payload = await _api.ratingDue();
      _ratingDue = asBool(payload['due']);
      _ratingIntervalDays = asInt(payload['interval_days']) == 0
          ? _ratingIntervalDays
          : asInt(payload['interval_days']);
      notifyListeners();
    } catch (_) {
      _ratingDue = false;
    }
  }

  Future<bool> submitRating({required int stars, String comment = ''}) {
    return _safe(() async {
      await _api.submitRating(stars: stars, comment: comment);
      _ratingDue = false;
      if (_user != null) {
        _user = AppUser.fromJson(await _api.me());
        await _persist();
      }
      _info = 'Merci pour votre évaluation.';
      return true;
    });
  }

  void dismissRating() {
    _ratingDue = false;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // ignore: empty_catches
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    await refreshServerInfo();
    _status = _server.online && _server.adminInstallRequired
        ? AuthStatus.installRequired
        : AuthStatus.unauthenticated;
    _ratingDue = false;
    _error = null;
    _info = 'Vous avez été déconnecté.';
    notifyListeners();
  }
}
