import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import 'smart_retranslator.dart';

class DisclaimerBanner extends StatelessWidget {
  final String message;

  const DisclaimerBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: AppColors.primaryGreen.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
