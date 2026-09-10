import 'json_helpers.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.activeProfile,
    required this.profilePhoto,
    required this.isAdmin,
    required this.isBlocked,
    required this.walletBalance,
    required this.averageRating,
    required this.ratingCount,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: asString(json['id']),
        email: asString(json['email']),
        firstName: asString(json['first_name']),
        lastName: asString(json['last_name']),
        phone: asString(json['phone']),
        role: asString(json['role'], 'owner'),
        activeProfile: asString(json['active_profile'], 'owner'),
        profilePhoto: asString(json['profile_photo']),
        isAdmin: asBool(json['is_admin']),
        isBlocked: asBool(json['is_blocked']),
        walletBalance: asDouble(json['wallet_balance']),
        averageRating: asDouble(json['average_rating']),
        ratingCount: asInt(json['rating_count']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final String activeProfile;
  final String profilePhoto;
  final bool isAdmin;
  final bool isBlocked;
  final double walletBalance;
  final double averageRating;
  final int ratingCount;
  final String createdAt;

  String get fullName =>
      '$firstName $lastName'.trim().isEmpty ? email : '$firstName $lastName'.trim();

  bool get isOwner => activeProfile == 'owner';
  bool get isFinder => activeProfile == 'finder';
  bool get isAdminProfile => isAdmin || activeProfile == 'admin';

  AppUser copyWith({String? activeProfile, double? walletBalance, String? firstName, String? lastName, String? phone, String? email}) =>
      AppUser(
        id: id,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        role: role,
        activeProfile: activeProfile ?? this.activeProfile,
        profilePhoto: profilePhoto,
        isAdmin: isAdmin,
        isBlocked: isBlocked,
        walletBalance: walletBalance ?? this.walletBalance,
        averageRating: averageRating,
        ratingCount: ratingCount,
        createdAt: createdAt,
      );
}

class Peer {
  Peer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.profilePhoto,
    required this.averageRating,
  });

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
        id: asString(json['id']),
        firstName: asString(json['first_name']),
        lastName: asString(json['last_name']),
        email: asString(json['email']),
        phone: asString(json['phone']),
        role: asString(json['role']),
        profilePhoto: asString(json['profile_photo']),
        averageRating: asDouble(json['average_rating']),
      );

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String profilePhoto;
  final double averageRating;

  String get fullName => '$firstName $lastName'.trim().isEmpty ? email : '$firstName $lastName'.trim();
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isBlocked,
    required this.walletBalance,
    required this.averageRating,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: asString(json['id']),
        fullName: asString(json['full_name']),
        email: asString(json['email']),
        phone: asString(json['phone']),
        role: asString(json['role']),
        isBlocked: asBool(json['is_blocked']),
        walletBalance: asDouble(json['wallet_balance']),
        averageRating: asDouble(json['average_rating']),
        createdAt: asString(json['created_at']),
      );

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final bool isBlocked;
  final double walletBalance;
  final double averageRating;
  final String createdAt;
}
