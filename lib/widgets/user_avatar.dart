import 'package:flutter/material.dart';

import '../core/services/api_client.dart';
import '../core/theme/app_colors.dart';
import '../models/user.dart';

/// Avatar utilisateur : affiche la photo de profil si presente,
/// sinon les initiales sur fond degrade DOCTRY.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 46,
    this.onTap,
    this.editBadge = false,
  });

  final AppUser user;
  final double size;
  final VoidCallback? onTap;
  final bool editBadge;

  String get _initials {
    final String first =
        user.firstName.trim().isEmpty ? '' : user.firstName.trim().substring(0, 1).toUpperCase();
    final String last =
        user.lastName.trim().isEmpty ? '' : user.lastName.trim().substring(0, 1).toUpperCase();
    final String combined = '$first$last'.trim();
    return combined.isEmpty ? '?' : combined;
  }

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = user.profilePhoto.isEmpty
        ? null
        : ApiClient.instance.mediaUrl('/api/media/profiles/${user.id}');

    final Widget fallback = Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
      ),
    );

    final Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.siam, AppColors.darkBlue],
        ),
        borderRadius: BorderRadius.circular(size * 0.5),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.5 - 2),
        child: photoUrl == null
            ? fallback
            : Image.network(
                photoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );

    if (onTap == null) {
      return avatar;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          avatar,
          if (editBadge)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Color(0x33000000), blurRadius: 4),
                  ],
                ),
                child: Icon(Icons.photo_camera, size: size * 0.22, color: AppColors.darkBlue),
              ),
            ),
        ],
      ),
    );
  }
}
