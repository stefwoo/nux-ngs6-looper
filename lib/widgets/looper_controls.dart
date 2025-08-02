import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LooperControls extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onRec;
  final VoidCallback onStop;

  const LooperControls({
    super.key,
    required this.onClear,
    required this.onUndo,
    required this.onRec,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildControlButton(
                icon: '✖',
                text: 'CLEAR',
                bgColor: AppColors.clearButtonBg,
                iconColor: AppColors.accentPurple,
                onTap: onClear,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildControlButton(
                icon: '↺',
                text: 'UNDO',
                bgColor: AppColors.undoButtonBg,
                iconColor: AppColors.accentBlue,
                onTap: onUndo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildControlButton(
                icon: '●',
                text: 'REC',
                bgColor: AppColors.recButtonBg,
                iconColor: AppColors.accentPink,
                onTap: onRec,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildControlButton(
                icon: '■',
                text: 'STOP',
                bgColor: AppColors.stopButtonBg,
                iconColor: AppColors.accentRed,
                onTap: onStop,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required String icon,
    required String text,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 65),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
