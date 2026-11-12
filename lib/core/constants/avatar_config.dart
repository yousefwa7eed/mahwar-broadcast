import 'package:flutter/material.dart';

class AvatarConfig {
  AvatarConfig._();

  static const List<AvatarOption> carOwnerAvatars = [
    AvatarOption(
      id: 'car_owner_1',
      gradient: LinearGradient(
        colors: [Color(0xFFFF6B00), Color(0xFFFF8E3C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🚗',
    ),
    AvatarOption(
      id: 'car_owner_2',
      gradient: LinearGradient(
        colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🚙',
    ),
    AvatarOption(
      id: 'car_owner_3',
      gradient: LinearGradient(
        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🏎️',
    ),
    AvatarOption(
      id: 'car_owner_4',
      gradient: LinearGradient(
        colors: [Color(0xFFFD79A8), Color(0xFFFDCB6E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🚕',
    ),
    AvatarOption(
      id: 'car_owner_5',
      gradient: LinearGradient(
        colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🛻',
    ),
    AvatarOption(
      id: 'car_owner_6',
      gradient: LinearGradient(
        colors: [Color(0xFFE17055), Color(0xFFFF7675)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🚛',
    ),
    AvatarOption(
      id: 'car_owner_7',
      gradient: LinearGradient(
        colors: [Color(0xFF74B9FF), Color(0xFF0984E3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🚐',
    ),
    AvatarOption(
      id: 'car_owner_8',
      gradient: LinearGradient(
        colors: [Color(0xFFFD79A8), Color(0xFFE84393)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🛵',
    ),
  ];

  static const List<AvatarOption> providerAvatars = [
    AvatarOption(
      id: 'provider_1',
      gradient: LinearGradient(
        colors: [Color(0xFF2D3436), Color(0xFF636E72)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🔧',
    ),
    AvatarOption(
      id: 'provider_2',
      gradient: LinearGradient(
        colors: [Color(0xFFE17055), Color(0xFFFF7675)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🛠️',
    ),
    AvatarOption(
      id: 'provider_3',
      gradient: LinearGradient(
        colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🔨',
    ),
    AvatarOption(
      id: 'provider_4',
      gradient: LinearGradient(
        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '⚙️',
    ),
    AvatarOption(
      id: 'provider_5',
      gradient: LinearGradient(
        colors: [Color(0xFFFD79A8), Color(0xFFFDCB6E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🪛',
    ),
    AvatarOption(
      id: 'provider_6',
      gradient: LinearGradient(
        colors: [Color(0xFF74B9FF), Color(0xFF0984E3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🛞',
    ),
    AvatarOption(
      id: 'provider_7',
      gradient: LinearGradient(
        colors: [Color(0xFFE17055), Color(0xFFD63031)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🔩',
    ),
    AvatarOption(
      id: 'provider_8',
      gradient: LinearGradient(
        colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🧰',
    ),
  ];

  static List<AvatarOption> getAvatarsForRole(String role) {
    if (role == 'provider') {
      return providerAvatars;
    }
    return carOwnerAvatars;
  }

  static AvatarOption? getAvatarById(String role, String avatarId) {
    final list = getAvatarsForRole(role);
    try {
      return list.firstWhere((a) => a.id == avatarId);
    } catch (_) {
      return null;
    }
  }

  static AvatarOption getDefaultAvatar(String role) {
    return getAvatarsForRole(role).first;
  }
}

class AvatarOption {
  final String id;
  final LinearGradient gradient;
  final String emoji;

  const AvatarOption({
    required this.id,
    required this.gradient,
    required this.emoji,
  });
}

class AvatarWidget extends StatelessWidget {
  final String? avatarId;
  final String role;
  final double size;
  final String? photoUrl;

  const AvatarWidget({
    super.key,
    this.avatarId,
    required this.role,
    this.size = 48,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = avatarId != null
        ? AvatarConfig.getAvatarById(role, avatarId!)
        : null;
    final displayAvatar = avatar ?? AvatarConfig.getDefaultAvatar(role);
    // مربّع ناعم الحواف بدل الدائرة — يوحّد شكل صورة العميل والمزوّد.
    final radius = BorderRadius.circular(size * 0.28);

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildGradientAvatar(displayAvatar, radius),
        ),
      );
    }

    return _buildGradientAvatar(displayAvatar, radius);
  }

  Widget _buildGradientAvatar(AvatarOption avatar, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: avatar.gradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: avatar.gradient.colors.first.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(avatar.emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}
