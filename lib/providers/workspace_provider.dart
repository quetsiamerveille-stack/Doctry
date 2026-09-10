import 'package:flutter/foundation.dart';

import '../core/api/doctry_api.dart';
import '../core/services/api_client.dart';
import '../core/utils/media_picker.dart';
import '../models/chat.dart';
import '../models/declaration.dart';
import '../models/document.dart';
import '../models/json_helpers.dart';
import '../models/stats.dart';
import '../models/user.dart';

class WalletInfo {
  WalletInfo({
    required this.balance,
    required this.minRewardAmount,
    required this.commissionRate,
    required this.providers,
  });

  factory WalletInfo.empty() => WalletInfo(
        balance: 0,
        minRewardAmount: 1500,
        commissionRate: 0.05,
        providers: const <PaymentProvider>[],
      );

  final double balance;
  final int minRewardAmount;
  final double commissionRate;
  final List<PaymentProvider> providers;
}

class WorkspaceProvider extends ChangeNotifier {
  WorkspaceProvider({DoctryApi? api}) : _api = api ?? DoctryApi();

  final DoctryApi _api;

  List<DocRecord> _documents = <DocRecord>[];
  List<LossDeclaration> _losses = <LossDeclaration>[];
  List<FindDeclaration> _finds = <FindDeclaration>[];
  List<MatchResult> _matches = <MatchResult>[];
  List<Peer> _peers = <Peer>[];
  List<Conversation> _conversations = <Conversation>[];
  List<ChatMessage> _messages = <ChatMessage>[];
  Conversation? _activeConversation;
  List<AppNotification> _notifications = <AppNotification>[];
  List<PaymentRecord> _transactions = <PaymentRecord>[];
  OwnerStats _ownerStats = OwnerStats.empty();
  FinderStats _finderStats = FinderStats.empty();
  WalletInfo _wallet = WalletInfo.empty();
  DocRecord? _lastDocument;
  String _busyOn = '';
  String? _error;
  String? _info;
  int _unread = 0;

  List<DocRecord> get documents => _documents;
  List<LossDeclaration> get losses => _losses;
  List<FindDeclaration> get finds => _finds;
  List<MatchResult> get matches => _matches;
  List<Peer> get peers => _peers;
  List<Conversation> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  Conversation? get activeConversation => _activeConversation;
  List<AppNotification> get notifications => _notifications;
  List<PaymentRecord> get transactions => _transactions;
  OwnerStats get ownerStats => _ownerStats;
  FinderStats get finderStats => _finderStats;
  WalletInfo get wallet => _wallet;
  DocRecord? get lastDocument => _lastDocument;
  String get busyOn => _busyOn;
  String? get error => _error;
  String? get info => _info;
  int get unread => _unread;

  bool get isBusy => _busyOn.isNotEmpty;

  void clearMessages() {
    if (_error == null && _info == null) {
      return;
    }
    _error = null;
    _info = null;
    notifyListeners();
  }

  void clearLastDocument() {
    _lastDocument = null;
    notifyListeners();
  }

  void reset() {
    _documents = <DocRecord>[];
    _losses = <LossDeclaration>[];
    _finds = <FindDeclaration>[];
    _matches = <MatchResult>[];
    _peers = <Peer>[];
    _conversations = <Conversation>[];
    _messages = <ChatMessage>[];
    _activeConversation = null;
    _notifications = <AppNotification>[];
    _transactions = <PaymentRecord>[];
    _ownerStats = OwnerStats.empty();
    _finderStats = FinderStats.empty();
    _wallet = WalletInfo.empty();
    _lastDocument = null;
    _unread = 0;
    _error = null;
    _info = null;
    _busyOn = '';
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

  Future<void> loadOwnerWorkspace() async {
    await Future.wait<void>(<Future<void>>[
      loadDocuments(),
      loadLosses(),
      loadMatches(),
      loadNotifications(),
      loadWallet(),
      loadTransactions(),
      loadOwnerStats(),
    ]);
  }

  Future<void> loadFinderWorkspace() async {
    await Future.wait<void>(<Future<void>>[
      loadFinds(),
      loadMatches(),
      loadNotifications(),
      loadFinderStats(),
    ]);
  }

  Future<void> loadDocuments() async {
    try {
      final Map<String, dynamic> payload = await _api.listDocuments();
      _documents = asMapList(payload['items']).map(DocRecord.fromJson).toList();
      notifyListeners();
    } catch (exception) {
      _setError(exception);
      notifyListeners();
    }
  }

  Future<bool> registerByQr({
    required String docType,
    required String lastName,
    required String firstName,
    required String phone,
    required String email,
  }) {
    return _run('qr', () async {
      final Map<String, dynamic> payload = await _api.registerByQr(
        docType: docType,
        lastName: lastName,
        firstName: firstName,
        phone: phone,
        email: email,
      );
      _lastDocument = DocRecord.fromJson(asMap(payload['document']));
      await loadDocuments();
      _info = 'QR Code généré avec succès.';
      return true;
    });
  }

  Future<bool> registerByPhoto({
    required PickedMedia media,
    required String docType,
    String source = 'gallery',
  }) {
    return _run('photo', () async {
      final Map<String, dynamic> payload = await _api.registerByPhoto(
        bytes: media.bytes,
        filename: media.filename,
        docType: docType,
        source: source,
      );
      _lastDocument = DocRecord.fromJson(asMap(payload['document']));
      await loadDocuments();
      _info = 'Document enregistré. Les zones sensibles ont été floutées automatiquement.';
      return true;
    });
  }

  Future<bool> deleteDocument(String id) {
    return _run('document-$id', () async {
      await _api.deleteDocument(id);
      await loadDocuments();
      _info = 'Document supprimé.';
      return true;
    });
  }

  Future<bool> loadLosses() async {
    try {
      final Map<String, dynamic> payload = await _api.listLosses();
      _losses = asMapList(payload['items']).map(LossDeclaration.fromJson).toList();
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createLoss({
    required String docType,
    String description = '',
    String location = '',
    String? documentId,
    String? lossDate,
    int number = 0,
  }) {
    return _run('loss', () async {
      final Map<String, dynamic> payload = await _api.createLoss(
        docType: docType,
        description: description,
        location: location,
        documentId: documentId,
        lossDate: lossDate,
        number: number,
      );
      _absorbMatches(payload['matches']);
      await loadLosses();
      await loadOwnerStats();
      _info = _matchSummary(payload['matches']);
      return true;
    });
  }

  Future<bool> activateLoss(String lossId) {
    return _run('activate-$lossId', () async {
      final Map<String, dynamic> payload = await _api.activateLoss(lossId);
      _absorbMatches(payload['matches']);
      await loadLosses();
      await loadOwnerStats();
      _info = _matchSummary(payload['matches']);
      return true;
    });
  }

  Future<bool> loadFinds() async {
    try {
      final Map<String, dynamic> payload = await _api.listFinds();
      _finds = asMapList(payload['items']).map(FindDeclaration.fromJson).toList();
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createFind({
    required String docType,
    String description = '',
    String location = '',
    String holderName = '',
    String source = 'manual',
    PickedMedia? media,
  }) {
    return _run('find', () async {
      final Map<String, dynamic> payload = await _api.createFind(
        docType: docType,
        description: description,
        location: location,
        holderName: holderName,
        source: source,
        bytes: media?.bytes,
        filename: media?.filename ?? '',
      );
      _absorbMatches(payload['matches']);
      await loadFinds();
      await loadFinderStats();
      _info = _matchSummary(payload['matches']);
      return true;
    });
  }

  Future<bool> scanQr({required String payload, String location = ''}) {
    return _run('scan', () async {
      final Map<String, dynamic> result = await _api.scanQr(payload: payload, location: location);
      _absorbMatches(result['matches']);
      await loadFinds();
      await loadFinderStats();
      if (asBool(result['already_declared'])) {
        _info = 'Ce document avait déjà été déclaré comme retrouvé.';
      } else {
        final String holder = asString(asMap(result['document'])['holder']);
        _info = holder.isEmpty
            ? _matchSummary(result['matches'])
            : 'Retrouvaille déclarée pour $holder. ${_matchSummary(result['matches'])}';
      }
      return true;
    });
  }

  Future<bool> loadMatches() async {
    try {
      final Map<String, dynamic> payload = await _api.listMatches();
      _matches = asMapList(payload['items']).map(MatchResult.fromJson).toList();
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmReturn({required String lossId, required String findId}) {
    return _run('return-$lossId', () async {
      final Map<String, dynamic> payload = await _api.confirmReturn(lossId: lossId, findId: findId);
      await Future.wait<void>(<Future<void>>[loadLosses(), loadFinds(), loadMatches()]);
      _info = asString(payload['message'], 'Restitution confirmée.');
      return true;
    });
  }

  void _absorbMatches(dynamic raw) {
    final List<Map<String, dynamic>> items = asMapList(raw);
    if (items.isEmpty) {
      return;
    }
    final List<MatchResult> incoming = items.map(MatchResult.fromJson).toList();
    final Map<String, MatchResult> merged = <String, MatchResult>{
      for (final MatchResult item in _matches) item.id: item,
    };
    for (final MatchResult item in incoming) {
      merged[item.id] = item;
    }
    _matches = merged.values.toList()
      ..sort((MatchResult a, MatchResult b) => b.createdAt.compareTo(a.createdAt));
  }

  String _matchSummary(dynamic raw) {
    final int count = asMapList(raw).length;
    return count == 0
        ? 'Aucune correspondance trouvée. Déclaration mise en attente.'
        : count == 1
            ? 'Document similaire trouvé !'
            : '$count documents similaires trouvés !';
  }

  Future<bool> loadWallet() async {
    try {
      final Map<String, dynamic> payload = await _api.accounts();
      _wallet = WalletInfo(
        balance: asDouble(payload['wallet_balance']),
        minRewardAmount: asInt(payload['min_reward_amount']),
        commissionRate: asDouble(payload['commission_rate']),
        providers: asMapList(payload['providers']).map(PaymentProvider.fromJson).toList(),
      );
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> topUp({
    required double amount,
    required String provider,
    required String pin,
    String phone = '',
  }) {
    return _run('topup', () async {
      final Map<String, dynamic> payload =
          await _api.topUp(amount: amount, provider: provider, pin: pin, phone: phone);
      await loadWallet();
      await loadTransactions();
      _info = asString(payload['message'], 'Compte rechargé.');
      return true;
    });
  }

  Future<Map<String, dynamic>?> initiateEscrow({
    required String lossId,
    required double amount,
    required String provider,
    String phone = '',
  }) async {
    _busyOn = 'escrow';
    _error = null;
    notifyListeners();
    try {
      final Map<String, dynamic> payload = await _api.initiateEscrow(
        lossId: lossId,
        amount: amount,
        provider: provider,
        phone: phone,
      );
      _busyOn = '';
      notifyListeners();
      return payload;
    } catch (exception) {
      _setError(exception);
      _busyOn = '';
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmEscrow({required String reference, required String pin}) {
    return _run('escrow-pin', () async {
      final Map<String, dynamic> payload =
          await _api.confirmEscrow(reference: reference, pin: pin);
      await Future.wait<void>(<Future<void>>[loadWallet(), loadLosses(), loadTransactions()]);
      _info = asString(payload['message'], 'Récompense séquestrée.');
      return true;
    });
  }

  Future<Map<String, dynamic>?> requestRelease(String lossId) async {
    try {
      return await _api.requestRelease(lossId);
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmRelease({
    required String lossId,
    required String ticket,
    required String code,
  }) {
    return _run('release', () async {
      final Map<String, dynamic> payload =
          await _api.confirmRelease(lossId: lossId, ticket: ticket, code: code);
      await Future.wait<void>(<Future<void>>[loadWallet(), loadLosses(), loadTransactions()]);
      _info = asString(payload['message'], 'Récompense libérée.');
      return true;
    });
  }

  Future<bool> refundEscrow(String lossId) {
    return _run('refund-$lossId', () async {
      final Map<String, dynamic> payload = await _api.refundEscrow(lossId);
      await Future.wait<void>(<Future<void>>[loadWallet(), loadLosses(), loadTransactions()]);
      _info = asString(payload['message'], 'Remboursement effectué.');
      return true;
    });
  }

  Future<bool> loadTransactions() async {
    try {
      final Map<String, dynamic> payload = await _api.paymentHistory();
      _transactions = asMapList(payload['items']).map(PaymentRecord.fromJson).toList();
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadChat() async {
    await Future.wait<void>(<Future<void>>[loadPeers(), loadConversations()]);
    return true;
  }

  Future<bool> loadPeers() async {
    return _run('peers', () async {
      final Map<String, dynamic> payload = await _api.peers();
      _peers = asMapList(payload['items']).map(Peer.fromJson).toList();
      return true;
    });
  }

  Future<bool> loadConversations() async {
    try {
      final Map<String, dynamic> payload = await _api.conversations();
      _conversations = asMapList(payload['items']).map(Conversation.fromJson).toList();
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> startConversation({
    required String peerId,
    String subject = '',
    String lossId = '',
    String findId = '',
  }) {
    return _run('conversation', () async {
      final Map<String, dynamic> payload = await _api.startConversation(
        peerId: peerId,
        subject: subject,
        lossId: lossId,
        findId: findId,
      );
      _activeConversation = Conversation.fromJson(payload);
      await loadConversations();
      await loadMessages(_activeConversation!.id);
      return true;
    });
  }

  void selectConversation(Conversation? value) {
    _activeConversation = value;
    _messages = <ChatMessage>[];
    notifyListeners();
  }

  Future<bool> loadMessages(String conversationId) async {
    try {
      final Map<String, dynamic> payload = await _api.messages(conversationId);
      _messages = asMapList(payload['items']).map(ChatMessage.fromJson).toList();
      if (payload['conversation'] is Map) {
        _activeConversation = Conversation.fromJson(asMap(payload['conversation']));
      }
      await loadConversations();
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMessage(String body) {
    final Conversation? conversation = _activeConversation;
    if (conversation == null || body.trim().isEmpty) {
      return Future<bool>.value(false);
    }
    return _run('message', () async {
      final Map<String, dynamic> payload =
          await _api.sendMessage(conversation.id, body.trim());
      _messages = <ChatMessage>[..._messages, ChatMessage.fromJson(payload)];
      await loadConversations();
      return true;
    });
  }

  Future<bool> loadNotifications() async {
    try {
      final Map<String, dynamic> payload = await _api.notifications();
      _notifications = asMapList(payload['items']).map(AppNotification.fromJson).toList();
      _unread = asInt(payload['unread']);
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> markNotificationsRead() {
    return _run('notifications', () async {
      await _api.markNotificationsRead();
      await loadNotifications();
      return true;
    });
  }

  Future<bool> loadOwnerStats() async {
    try {
      _ownerStats = OwnerStats.fromJson(await _api.ownerStats());
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadFinderStats() async {
    try {
      _finderStats = FinderStats.fromJson(await _api.finderStats());
      notifyListeners();
      return true;
    } catch (exception) {
      _setError(exception);
      notifyListeners();
      return false;
    }
  }

  Future<List<int>?> qrBytes(String qrUrl) => _api.client.getBytes(qrUrl);

  String publicUrl(String path) => ApiClient.instance.mediaUrl(path);
}
