import '../services/api_client.dart';

class OtpChallenge {
  OtpChallenge({
    required this.ticket,
    required this.email,
    required this.delivery,
    required this.devCode,
    required this.expiresIn,
    required this.profile,
    required this.isAdmin,
  });

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        ticket: json['ticket']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        delivery: json['delivery']?.toString() ?? 'simulation',
        devCode: json['dev_code']?.toString() ?? '',
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 600,
        profile: json['profile']?.toString() ?? 'owner',
        isAdmin: json['is_admin'] == true,
      );

  final String ticket;
  final String email;
  final String delivery;
  final String devCode;
  final int expiresIn;
  final String profile;
  final bool isAdmin;

  bool get isSimulated => delivery != 'sent';
}

class DoctryApi {
  DoctryApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  ApiClient get client => _client;

  Future<Map<String, dynamic>> installStatus() async =>
      Map<String, dynamic>.from(await _client.get('/api/auth/status') as Map);

  Future<Map<String, dynamic>> health() async =>
      Map<String, dynamic>.from(await _client.get('/api/health') as Map);

  Future<Map<String, dynamic>> publicConfig() async =>
      Map<String, dynamic>.from(await _client.get('/api/config/public') as Map);

  Future<OtpChallenge> installAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phone = '',
  }) async {
    final dynamic result = await _client.post('/api/auth/install', body: <String, dynamic>{
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
    });
    return OtpChallenge.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<OtpChallenge> signup({
    required String profile,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String phone = '',
  }) async {
    final dynamic result = await _client.post('/api/auth/signup', body: <String, dynamic>{
      'profile': profile,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'phone': phone,
    });
    return OtpChallenge.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<OtpChallenge> login({
    required String profile,
    required String email,
    required String password,
  }) async {
    final dynamic result = await _client.post('/api/auth/login', body: <String, dynamic>{
      'profile': profile,
      'email': email,
      'password': password,
    });
    return OtpChallenge.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<OtpChallenge> adminLogin({required String email, required String password}) async {
    final dynamic result = await _client.post('/api/auth/admin/login', body: <String, dynamic>{
      'email': email,
      'password': password,
    });
    return OtpChallenge.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<Map<String, dynamic>> verifyOtp({required String ticket, required String code}) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/auth/otp/verify', body: <String, dynamic>{
          'ticket': ticket,
          'code': code,
        }) as Map,
      );

  Future<Map<String, dynamic>> resendOtp(String email) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/auth/otp/resend', query: <String, dynamic>{'email': email})
            as Map,
      );

  Future<Map<String, dynamic>> logout() async =>
      Map<String, dynamic>.from(await _client.post('/api/auth/logout') as Map);

  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await _client.get('/api/auth/me') as Map);

  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? password,
    String? phone,
  }) async =>
      Map<String, dynamic>.from(
        await _client.patch('/api/auth/me', body: <String, dynamic>{
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (password != null && password.isNotEmpty) 'password': password,
          if (phone != null) 'phone': phone,
        }) as Map,
      );

  Future<Map<String, dynamic>> updateAdminProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async =>
      Map<String, dynamic>.from(
        await _client.patch('/api/auth/me/admin-profile', body: <String, dynamic>{
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (email != null) 'email': email,
        }) as Map,
      );

  Future<Map<String, dynamic>> switchProfile(String profile) async =>
      Map<String, dynamic>.from(
        await _client.patch('/api/auth/me/profile', body: <String, dynamic>{'profile': profile})
            as Map,
      );

  Future<Map<String, dynamic>> listDocuments() async =>
      Map<String, dynamic>.from(await _client.get('/api/documents') as Map);

  Future<Map<String, dynamic>> registerByQr({
    required String docType,
    required String lastName,
    required String firstName,
    required String phone,
    required String email,
  }) async =>
      Map<String, dynamic>.from(
        await _client.postForm('/api/documents/qr', fields: <String, String>{
          'doc_type': docType,
          'last_name': lastName,
          'first_name': firstName,
          'phone': phone,
          'email': email,
        }) as Map,
      );

  Future<Map<String, dynamic>> registerByPhoto({
    required List<int> bytes,
    required String filename,
    required String docType,
    String lastName = '',
    String firstName = '',
    String phone = '',
    String email = '',
    String source = 'gallery',
    String documentId = '',
  }) async =>
      Map<String, dynamic>.from(
        await _client.postForm(
          '/api/documents/photo',
          fields: <String, String>{
            'doc_type': docType,
            'last_name': lastName,
            'first_name': firstName,
            'phone': phone,
            'email': email,
            'source': source,
            if (documentId.isNotEmpty) 'document_id': documentId,
          },
          fileField: 'file',
          fileBytes: bytes,
          filename: filename,
        ) as Map,
      );

  Future<void> deleteDocument(String id) => _client.delete('/api/documents/$id');

  Future<Map<String, dynamic>> listLosses() async =>
      Map<String, dynamic>.from(await _client.get('/api/declarations/losses') as Map);

  Future<Map<String, dynamic>> createLoss({
    required String docType,
    String description = '',
    String location = '',
    String? documentId,
    String? lossDate,
    int number = 0,
  }) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/declarations/losses', body: <String, dynamic>{
          'doc_type': docType,
          'description': description,
          'location': location,
          if (number > 0) 'number': number,
          if (documentId != null && documentId.isNotEmpty) 'document_id': documentId,
          if (lossDate != null && lossDate.isNotEmpty) 'loss_date': lossDate,
        }) as Map,
      );

  Future<Map<String, dynamic>> activateLoss(String lossId) async =>
      Map<String, dynamic>.from(
        await _client.patch('/api/declarations/losses/$lossId/activate') as Map,
      );

  Future<Map<String, dynamic>> listFinds() async =>
      Map<String, dynamic>.from(await _client.get('/api/declarations/finds') as Map);

  Future<Map<String, dynamic>> createFind({
    required String docType,
    String description = '',
    String location = '',
    String holderName = '',
    String source = 'gallery',
    List<int>? bytes,
    String filename = '',
  }) async =>
      Map<String, dynamic>.from(
        await _client.postForm('/api/declarations/finds', fields: <String, String>{
          'doc_type': docType,
          'description': description,
          'location': location,
          'holder_name': holderName,
          'source': source,
        }, fileField: bytes == null ? null : 'file', fileBytes: bytes, filename: filename) as Map,
      );

  Future<Map<String, dynamic>> scanQr({
    required String payload,
    String location = '',
    List<int>? bytes,
    String filename = '',
  }) async =>
      Map<String, dynamic>.from(
        await _client.postForm('/api/declarations/scan', fields: <String, String>{
          'payload': payload,
          'location': location,
        }, fileField: bytes == null ? null : 'file', fileBytes: bytes, filename: filename) as Map,
      );

  Future<Map<String, dynamic>> listMatches() async =>
      Map<String, dynamic>.from(await _client.get('/api/declarations/matches') as Map);

  Future<Map<String, dynamic>> confirmReturn({required String lossId, required String findId}) async =>
      Map<String, dynamic>.from(
        await _client.post(
          '/api/declarations/confirm-return',
          query: <String, dynamic>{'loss_id': lossId, 'find_id': findId},
        ) as Map,
      );

  Future<Map<String, dynamic>> accounts() async =>
      Map<String, dynamic>.from(await _client.get('/api/payments/accounts') as Map);

  Future<Map<String, dynamic>> topUp({
    required double amount,
    required String provider,
    required String pin,
    String phone = '',
  }) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/payments/topup', body: <String, dynamic>{
          'amount': amount,
          'provider': provider,
          'phone': phone,
          'pin': pin,
        }) as Map,
      );

  Future<Map<String, dynamic>> initiateEscrow({
    required String lossId,
    required double amount,
    required String provider,
    String phone = '',
  }) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/payments/escrow/initiate', body: <String, dynamic>{
          'loss_id': lossId,
          'amount': amount,
          'provider': provider,
          'phone': phone,
        }) as Map,
      );

  Future<Map<String, dynamic>> confirmEscrow({required String reference, required String pin}) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/payments/escrow/confirm', body: <String, dynamic>{
          'reference': reference,
          'pin': pin,
        }) as Map,
      );

  Future<Map<String, dynamic>> requestRelease(String lossId) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/payments/release/request', body: <String, dynamic>{
          'loss_id': lossId,
        }) as Map,
      );

  Future<Map<String, dynamic>> confirmRelease({
    required String lossId,
    required String ticket,
    required String code,
  }) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/payments/release/confirm', body: <String, dynamic>{
          'loss_id': lossId,
          'ticket': ticket,
          'code': code,
        }) as Map,
      );

  Future<Map<String, dynamic>> refundEscrow(String lossId) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/payments/escrow/refund', query: <String, dynamic>{
          'loss_id': lossId,
        }) as Map,
      );

  Future<Map<String, dynamic>> paymentHistory() async =>
      Map<String, dynamic>.from(await _client.get('/api/payments/history') as Map);

  Future<Map<String, dynamic>> mailbox(String email) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/payments/dev/mailbox', query: <String, dynamic>{'email': email})
            as Map,
      );

  Future<Map<String, dynamic>> peers() async =>
      Map<String, dynamic>.from(await _client.get('/api/chat/peers') as Map);

  Future<Map<String, dynamic>> conversations() async =>
      Map<String, dynamic>.from(await _client.get('/api/chat/conversations') as Map);

  Future<Map<String, dynamic>> startConversation({
    required String peerId,
    String subject = '',
    String? lossId,
    String? findId,
  }) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/chat/conversations', body: <String, dynamic>{
          'peer_id': peerId,
          'subject': subject,
          if (lossId != null && lossId.isNotEmpty) 'loss_id': lossId,
          if (findId != null && findId.isNotEmpty) 'find_id': findId,
        }) as Map,
      );

  Future<Map<String, dynamic>> messages(String conversationId) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/chat/conversations/$conversationId/messages') as Map,
      );

  Future<Map<String, dynamic>> sendMessage(String conversationId, String body) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/chat/conversations/$conversationId/messages',
            body: <String, dynamic>{'body': body}) as Map,
      );

  Future<Map<String, dynamic>> notifications() async =>
      Map<String, dynamic>.from(await _client.get('/api/notifications') as Map);

  Future<Map<String, dynamic>> markNotificationsRead() async =>
      Map<String, dynamic>.from(await _client.post('/api/notifications/read-all') as Map);

  Future<Map<String, dynamic>> ratingDue() async =>
      Map<String, dynamic>.from(await _client.get('/api/ratings/due') as Map);

  Future<Map<String, dynamic>> submitRating({required int stars, String comment = ''}) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/ratings', body: <String, dynamic>{
          'stars': stars,
          'comment': comment,
        }) as Map,
      );

  Future<Map<String, dynamic>> ownerStats() async =>
      Map<String, dynamic>.from(await _client.get('/api/stats/owner') as Map);

  Future<Map<String, dynamic>> finderStats() async =>
      Map<String, dynamic>.from(await _client.get('/api/stats/finder') as Map);

  Future<Map<String, dynamic>> adminOverview() async =>
      Map<String, dynamic>.from(await _client.get('/api/admin/overview') as Map);

  Future<Map<String, dynamic>> adminUsers({String search = ''}) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/admin/users', query: <String, dynamic>{'search': search}) as Map,
      );

  Future<Map<String, dynamic>> adminCreateUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String phone = '',
  }) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/admin/users', body: <String, dynamic>{
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'role': role,
          'phone': phone,
        }) as Map,
      );

  Future<Map<String, dynamic>> blockUser(String userId) async =>
      Map<String, dynamic>.from(await _client.post('/api/admin/users/$userId/block') as Map);

  Future<Map<String, dynamic>> unblockUser(String userId) async =>
      Map<String, dynamic>.from(await _client.post('/api/admin/users/$userId/unblock') as Map);

  Future<Map<String, dynamic>> finance({String? date}) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/admin/finance', query: <String, dynamic>{
          if (date != null && date.isNotEmpty) 'date': date,
        }) as Map,
      );

  Future<Map<String, dynamic>> adminStats() async =>
      Map<String, dynamic>.from(await _client.get('/api/admin/stats') as Map);

  Future<Map<String, dynamic>> smsLogs() async =>
      Map<String, dynamic>.from(await _client.get('/api/admin/sms-logs') as Map);
}
