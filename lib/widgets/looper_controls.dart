import 'package:flutter/material.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../models/looper_state.dart';

class LooperControls extends StatefulWidget {
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onRec;
  final VoidCallback onStop;
  final LooperButtonStates buttonStates;

  const LooperControls({
    super.key,
    required this.onClear,
    required this.onUndo,
    required this.onRec,
    required this.onStop,
    required this.buttonStates,
  });

  @override
  State<LooperControls> createState() => _LooperControlsState();
}

class _LooperControlsState extends State<LooperControls>
    with TickerProviderStateMixin {
  Timer? _blinkTimer;
  bool _isBlinkVisible = true;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _updateBlinking();
  }

  @override
  void didUpdateWidget(LooperControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buttonStates.record.blinking != widget.buttonStates.record.blinking) {
      _updateBlinking();
    }
  }

  void _updateBlinking() {
    if (widget.buttonStates.record.blinking) {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      _blinkController.reset();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildControlButton(
                icon: '✖',
                text: widget.buttonStates.clear.text,
                bgColor: AppColors.clearButtonBg,
                iconColor: AppColors.accentPurple,
                enabled: true,  // 强制启用Clear按钮
                onTap: widget.onClear,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildControlButton(
                icon: '↺',
                text: widget.buttonStates.undoRedo.text,
                bgColor: AppColors.undoButtonBg,
                iconColor: AppColors.accentBlue,
                enabled: true,  // 强制启用Undo按钮
                onTap: widget.onUndo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _blinkAnimation,
                builder: (context, child) {
                  final opacity = widget.buttonStates.record.blinking 
                      ? _blinkAnimation.value 
                      : 1.0;
                  return Opacity(
                    opacity: opacity,
                    child: _buildControlButton(
                      icon: '●',
                      text: widget.buttonStates.record.text,
                      bgColor: AppColors.recButtonBg,
                      iconColor: AppColors.accentPink,
                      enabled: widget.buttonStates.record.enabled,
                      onTap: widget.onRec,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildControlButton(
                icon: '■',
                text: widget.buttonStates.stop.text,
                bgColor: AppColors.stopButtonBg,
                iconColor: AppColors.accentRed,
                enabled: true,  // 强制启用Stop按钮
                onTap: widget.onStop,
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
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 65),
        decoration: BoxDecoration(
          color: enabled ? bgColor : bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 18,
                color: enabled ? iconColor : iconColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: enabled ? iconColor : iconColor.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
