import 'package:flutter/material.dart';
import '../../../utils/colors.dart';

class ProfileCard extends StatelessWidget {
  final String name;
  final String plotArea;
  final int totalPlots;
  final int totalCrops;
  final String? email;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.name,
    required this.plotArea,
    required this.totalPlots,
    required this.totalCrops,
    this.email,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProfileAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: _ProfileInfo(
                  name: name,
                  plotArea: plotArea,
                  totalPlots: totalPlots,
                  totalCrops: totalCrops,
                  email: email,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primaryWhite,
      child: Icon(Icons.person, color: AppColors.iconPrimary, size: 50),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  final String name;
  final String plotArea;
  final int totalPlots;
  final int totalCrops;
  final String? email;

  const _ProfileInfo({
    required this.name,
    required this.plotArea,
    required this.totalPlots,
    required this.totalCrops,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnPrimary,
          ),
        ),
        if (email != null) ...[
          const SizedBox(height: 4),
          Text(
            email!,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textOnPrimary.withOpacity(0.8),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          plotArea,
          style: const TextStyle(fontSize: 16, color: AppColors.textOnPrimary),
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 1, color: AppColors.primaryWhite),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatItem(label: "Total Plots", value: totalPlots.toString()),
            _StatItem(label: "Total Crops", value: totalCrops.toString()),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label : $value",
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
