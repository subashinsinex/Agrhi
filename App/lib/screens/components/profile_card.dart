import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class ProfileCard extends StatelessWidget {
  final String name;
  final String? email;
  final String? phone;
  final String? category;
  final String? address;

  const ProfileCard({
    super.key,
    required this.name,
    this.email,
    this.phone,
    this.category,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      color: AppColors.primaryGreen, // Very light green background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryWhite, // Dark green text
                        ),
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryGreen, // Medium green background
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(
              height: 1,
              color: AppColors.mediumGreenAccent, // Soft green divider
              thickness: 1,
            ),
            const SizedBox(height: 18),
            if (email != null) _buildInfoRow(Icons.email_outlined, email!),
            if (phone != null) ...[
              const SizedBox(height: 14),
              _buildInfoRow(Icons.phone_outlined, phone!),
            ],
            if (address != null) ...[
              const SizedBox(height: 14),
              _buildInfoRow(Icons.location_on_outlined, address!, maxLines: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.mediumGreenAccent, // Soft green background
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.secondaryGreen, // Medium green border
          width: 2.5,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen, // Dark green letter
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // White containers for better readability
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.mediumGreenAccent, // Soft green border
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.mediumGreenAccent, // Soft green icon background
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGreen, // Dark green icon
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary, // Dark text
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
