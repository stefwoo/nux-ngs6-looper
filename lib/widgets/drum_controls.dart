import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class DrumControls extends StatelessWidget {
  final bool isOn;
  final int styleValue;
  final Function(bool) onToggle;
  final Function(int) onStyleChange;

  const DrumControls({
    super.key,
    required this.isOn,
    required this.styleValue,
    required this.onToggle,
    required this.onStyleChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 5),
          child: Text(
            '鼓机',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryText,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(!isOn),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.drumButtonActiveBg : AppColors.drumButtonBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      isOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isOn ? AppColors.accentGreen : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.statusContainerBg,
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '风格选择 (00-42)',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      styleValue.toRadixString(16).toUpperCase().padLeft(2, '0'),
                      style: const TextStyle(color: AppColors.accentCyan, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: styleValue.toDouble(),
                  min: 0,
                  max: 66,
                  activeColor: AppColors.accentCyan,
                  inactiveColor: AppColors.sliderBg,
                  onChanged: (value) => onStyleChange(value.round()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onStyleChange(styleValue > 0 ? styleValue - 1 : 66),
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppColors.styleButtonBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Center(
                    child: Text(
                      '-',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: () => onStyleChange(styleValue < 66 ? styleValue + 1 : 0),
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppColors.styleButtonBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Center(
                    child: Text(
                      '+',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
