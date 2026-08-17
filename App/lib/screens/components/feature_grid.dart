import 'package:flutter/material.dart';
import '../../../../utils/colors.dart';
import '../shared/smart_retranslator.dart';

class FeatureGrid extends StatelessWidget {
  final List<FeatureItem> features;
  final double childAspectRatio;
  final double spacing;

  const FeatureGrid({
    super.key,
    required this.features,
    this.childAspectRatio = 1.02,
    this.spacing = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final int crossAxisCount;

        if (width < 500) {
          crossAxisCount = 3;
        } else if (width < 800) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 5;
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final feature = features[index];

            return FeatureCard(
              title: feature.title,
              icon: feature.icon,
              onTap: feature.onTap,
              backgroundColor: feature.backgroundColor,
              iconColor: feature.iconColor,
            );
          },
        );
      },
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const FeatureCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color tileColor = backgroundColor ?? Colors.white;
    final Color tileIconColor = iconColor ?? AppColors.primaryGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD7DEC9), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.045),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: tileIconColor),
              const SizedBox(height: 10),
              SmartReTranslator(
                text: title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E2C1C),
                  height: 1.2,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const FeatureItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });
}
