import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class ProfileCard extends StatelessWidget {
  final String name;
  final String? email;
  final String? category;
  final bool emailVerified;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.name,
    this.email,
    this.category,
    this.emailVerified = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryGreen.withOpacity(0.8),
              AppColors.primaryGreen,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              // Avatar with verification badge
              _buildAvatar(),
              const SizedBox(width: 16),

              // Name, Email & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name with verification
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryWhite,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (emailVerified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.successColor.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Email
                    if (email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        email!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primaryWhite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Category Badge
                    if (category != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryWhite.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryWhite,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Arrow Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryWhite.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.primaryWhite,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            color: AppColors.mediumGreenAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
        // Verification badge on avatar
        if (emailVerified)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.successColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.mediumGreenAccent,
                  width: 2,
                ),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 12),
            ),
          ),
      ],
    );
  }
}
