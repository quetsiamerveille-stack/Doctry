import 'json_helpers.dart';

class LossDeclaration {
  LossDeclaration({
    required this.id,
    required this.number,
    required this.docType,
    required this.preregistrationDate,
    required this.lossDate,
    required this.ownerName,
    required this.ownerId,
    required this.description,
    required this.location,
    required this.status,
    required this.rewardAmount,
    required this.rewardStatus,
    required this.documentId,
    required this.qrUrl,
    required this.matchedFindId,
    required this.returnedAt,
    required this.createdAt,
  });

  factory LossDeclaration.fromJson(Map<String, dynamic> json) => LossDeclaration(
        id: asString(json['id']),
        number: asInt(json['number']),
        docType: asString(json['doc_type']),
        preregistrationDate: asString(json['preregistration_date']),
        lossDate: asString(json['loss_date']),
        ownerName: asString(json['owner_name']),
        ownerId: asString(json['owner_id']),
        description: asString(json['description']),
        location: asString(json['location']),
        status: asString(json['status'], 'inactive'),
        rewardAmount: asDouble(json['reward_amount']),
        rewardStatus: asString(json['reward_status'], 'none'),
        documentId: asString(json['document_id']),
        qrUrl: asString(json['qr_url']),
        matchedFindId: asString(json['matched_find_id']),
        returnedAt: asString(json['returned_at']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final int number;
  final String docType;
  final String preregistrationDate;
  final String lossDate;
  final String ownerName;
  final String ownerId;
  final String description;
  final String location;
  final String status;
  final double rewardAmount;
  final String rewardStatus;
  final String documentId;
  final String qrUrl;
  final String matchedFindId;
  final String returnedAt;
  final String createdAt;

  bool get isActive => status == 'declared' || status == 'matched' || status == 'returned';
  bool get isReturned => status == 'returned';
  bool get hasEscrow => rewardStatus == 'escrow';
  bool get canReleaseReward => rewardStatus == 'escrow' && status == 'returned';
}

class FindDeclaration {
  FindDeclaration({
    required this.id,
    required this.number,
    required this.docType,
    required this.foundDate,
    required this.holderName,
    required this.finderId,
    required this.description,
    required this.location,
    required this.source,
    required this.status,
    required this.documentId,
    required this.matchedOwnerId,
    required this.imageUrl,
    required this.blurredUrl,
    required this.returnedAt,
    required this.createdAt,
  });

  factory FindDeclaration.fromJson(Map<String, dynamic> json) => FindDeclaration(
        id: asString(json['id']),
        number: asInt(json['number']),
        docType: asString(json['doc_type']),
        foundDate: asString(json['found_date']),
        holderName: asString(json['holder_name']),
        finderId: asString(json['finder_id']),
        description: asString(json['description']),
        location: asString(json['location']),
        source: asString(json['source']),
        status: asString(json['status'], 'found'),
        documentId: asString(json['document_id']),
        matchedOwnerId: asString(json['matched_owner_id']),
        imageUrl: asString(json['image_url']),
        blurredUrl: asString(json['blurred_url']),
        returnedAt: asString(json['returned_at']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final int number;
  final String docType;
  final String foundDate;
  final String holderName;
  final String finderId;
  final String description;
  final String location;
  final String source;
  final String status;
  final String documentId;
  final String matchedOwnerId;
  final String imageUrl;
  final String blurredUrl;
  final String returnedAt;
  final String createdAt;

  bool get isReturned => status == 'returned';
  bool get fromQr => source == 'qr';
}

class MatchResult {
  MatchResult({
    required this.id,
    required this.lossId,
    required this.findId,
    required this.score,
    required this.engine,
    required this.reason,
    required this.status,
    required this.docType,
    required this.counterpartId,
    required this.counterpartName,
    required this.rewardAmount,
    required this.rewardStatus,
    required this.lossStatus,
    required this.findStatus,
    required this.createdAt,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
        id: asString(json['id']),
        lossId: asString(json['loss_id']),
        findId: asString(json['find_id']),
        score: asDouble(json['score']),
        engine: asString(json['engine']),
        reason: asString(json['reason']),
        status: asString(json['status']),
        docType: asString(json['doc_type']),
        counterpartId: asString(json['counterpart_id']),
        counterpartName: asString(json['counterpart_name']),
        rewardAmount: asDouble(json['reward_amount']),
        rewardStatus: asString(json['reward_status']),
        lossStatus: asString(json['loss_status']),
        findStatus: asString(json['find_status']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String lossId;
  final String findId;
  final double score;
  final String engine;
  final String reason;
  final String status;
  final String docType;
  final String counterpartId;
  final String counterpartName;
  final double rewardAmount;
  final String rewardStatus;
  final String lossStatus;
  final String findStatus;
  final String createdAt;

  int get percent => (score * 100).round();
  String get engineLabel => engine == 'deepseek'
      ? 'IA DeepSeek'
      : engine == 'qr'
          ? 'QR Code'
          : 'Moteur local';
}
