import 'json_helpers.dart';

class Conversation {
  Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerRole,
    required this.peerPhoto,
    required this.subject,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.lossId,
    required this.findId,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: asString(json['id']),
        peerId: asString(json['peer_id']),
        peerName: asString(json['peer_name']),
        peerRole: asString(json['peer_role']),
        peerPhoto: asString(json['peer_photo']),
        subject: asString(json['subject']),
        lastMessage: asString(json['last_message']),
        lastMessageAt: asString(json['last_message_at']),
        unreadCount: asInt(json['unread_count']),
        lossId: asString(json['loss_id']),
        findId: asString(json['find_id']),
      );

  final String id;
  final String peerId;
  final String peerName;
  final String peerRole;
  final String peerPhoto;
  final String subject;
  final String lastMessage;
  final String lastMessageAt;
  final int unreadCount;
  final String lossId;
  final String findId;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: asString(json['id']),
        conversationId: asString(json['conversation_id']),
        senderId: asString(json['sender_id']),
        body: asString(json['body']),
        read: asBool(json['read']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final bool read;
  final String createdAt;

  bool isMine(String currentUserId) => senderId == currentUserId;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: asString(json['id']),
        title: asString(json['title']),
        body: asString(json['body']),
        kind: asString(json['kind'], 'info'),
        read: asBool(json['read']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String title;
  final String body;
  final String kind;
  final bool read;
  final String createdAt;
}

class PaymentRecord {
  PaymentRecord({
    required this.id,
    required this.reference,
    required this.kind,
    required this.provider,
    required this.providerLabel,
    required this.amount,
    required this.commission,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: asString(json['id']),
        reference: asString(json['reference']),
        kind: asString(json['kind']),
        provider: asString(json['provider']),
        providerLabel: asString(json['provider_label']),
        amount: asDouble(json['amount']),
        commission: asDouble(json['commission']),
        status: asString(json['status']),
        message: asString(json['message']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String reference;
  final String kind;
  final String provider;
  final String providerLabel;
  final double amount;
  final double commission;
  final String status;
  final String message;
  final String createdAt;

  String get kindLabel {
    switch (kind) {
      case 'topup':
        return 'Recharge';
      case 'escrow_deposit':
        return 'Séquestre';
      case 'escrow_release':
        return 'Libération';
      case 'escrow_refund':
        return 'Remboursement';
      default:
        return kind;
    }
  }
}

class PaymentProvider {
  PaymentProvider({required this.code, required this.label, required this.ussd});

  factory PaymentProvider.fromJson(Map<String, dynamic> json) => PaymentProvider(
        code: asString(json['code']),
        label: asString(json['label']),
        ussd: asString(json['ussd']),
      );

  final String code;
  final String label;
  final String ussd;
}
