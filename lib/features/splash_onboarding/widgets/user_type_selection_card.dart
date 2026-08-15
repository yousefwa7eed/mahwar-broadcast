import 'package:flutter/material.dart';

class UserTypeSelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final String imageAsset;
  final IconData fallbackIcon;
  final Gradient gradient;
  final VoidCallback onTap;

  const UserTypeSelectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.fallbackIcon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 132,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _CardImage(
                    assetPath: imageAsset,
                    fallbackIcon: fallbackIcon,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;

  const _CardImage({
    required this.assetPath,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        assetPath,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              fallbackIcon,
              color: Colors.white,
              size: 42,
            ),
          );
        },
      ),
    );
  }
}
