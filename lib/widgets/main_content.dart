import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/looper_state.dart';
import 'drum_controls.dart';
import 'looper_status.dart';
import 'looper_controls.dart';

class MainContent extends StatelessWidget {
  final bool drumOn;
  final int drumStyle;
  final String looperStatus;
  final double looperProgress;
  final LooperButtonStates buttonStates;
  final ValueChanged<bool> onDrumToggle;
  final ValueChanged<int> onDrumStyleChange;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onRec;
  final VoidCallback onStop;

  const MainContent({
    super.key,
    required this.drumOn,
    required this.drumStyle,
    required this.looperStatus,
    required this.looperProgress,
    required this.buttonStates,
    required this.onDrumToggle,
    required this.onDrumStyleChange,
    required this.onClear,
    required this.onUndo,
    required this.onRec,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 15), // 顶部留白
                  DrumControls(
                    isOn: drumOn,
                    styleValue: drumStyle,
                    onToggle: onDrumToggle,
                    onStyleChange: onDrumStyleChange,
                  ),
                  const SizedBox(height: 15),
                  LooperStatus(status: looperStatus, progress: looperProgress),
                  const SizedBox(height: 10),
                  LooperControls(
                    onClear: onClear,
                    onUndo: onUndo,
                    onRec: onRec,
                    onStop: onStop,
                    buttonStates: buttonStates,
                  ),
                  const Spacer(), // 填充剩余空间
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 5),
                    child: Container(
                      height: 1,
                      color: AppColors.footerBorder,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      '通过USB MIDI控制连接至吉他效果器',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
