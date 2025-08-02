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
                color: AppColors.accentPurple,
                onTap: onClear,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildControlButton(
                icon: '↺',
                text: 'UNDO',
                color: AppColors.accentBlue,
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
                color: AppColors.accentPink,
                onTap: onRec,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildControlButton(
                icon: '■',
                text: 'STOP',
                color: AppColors.accentRed,
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 65,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 18,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
