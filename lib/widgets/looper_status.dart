import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LooperStatus extends StatelessWidget {
  final String status;
  final double progress;

  const LooperStatus({
    super.key,
    required this.status,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOOPER',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accentPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '当前状态',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.accentGreen,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accentPink, AppColors.accentRed],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
