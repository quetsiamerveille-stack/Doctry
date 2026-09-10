import 'json_helpers.dart';

class DocRecord {
  DocRecord({
    required this.id,
    required this.docType,
    required this.holderFirstName,
    required this.holderLastName,
    required this.holderPhone,
    required this.holderEmail,
    required this.qrId,
    required this.qrUrl,
    required this.qrPayload,
    required this.imageUrl,
    required this.blurredUrl,
    required this.status,
    required this.createdAt,
  });

  factory DocRecord.fromJson(Map<String, dynamic> json) => DocRecord(
        id: asString(json['id']),
        docType: asString(json['doc_type']),
        holderFirstName: asString(json['holder_first_name']),
        holderLastName: asString(json['holder_last_name']),
        holderPhone: asString(json['holder_phone']),
        holderEmail: asString(json['holder_email']),
        qrId: asString(json['qr_id']),
        qrUrl: asString(json['qr_url']),
        qrPayload: asString(json['qr_payload']),
        imageUrl: asString(json['image_url']),
        blurredUrl: asString(json['blurred_url']),
        status: asString(json['status']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String docType;
  final String holderFirstName;
  final String holderLastName;
  final String holderPhone;
  final String holderEmail;
  final String qrId;
  final String qrUrl;
  final String qrPayload;
  final String imageUrl;
  final String blurredUrl;
  final String status;
  final String createdAt;

  String get holderName =>
      '$holderFirstName $holderLastName'.trim().isEmpty ? '—' : '$holderFirstName $holderLastName'.trim();

  bool get hasQr => qrUrl.isNotEmpty;
  bool get hasImage => imageUrl.isNotEmpty;
}
