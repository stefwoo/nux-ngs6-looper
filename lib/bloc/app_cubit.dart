import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:midi_controller/services/midi_engine.dart';

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  final MidiEngine _midiEngine;
  StreamSubscription? _midiSubscription;
  Timer? _recordingTimer;
  Timer? _playbackTimer;
 
   AppCubit(this._midiEngine) : super(const AppState()) {
     _midiSubscription = _midiEngine.rawHexStream.listen(_onMidiHexReceived);
   }

  void connectToDevice(MidiDevice device) {
    _midiEngine.startListening(device);
  }

  // --- Public methods for UI interaction ---

  void toggleDrum() {
    final newState = !state.drumOn;
    _midiEngine.sendCcMessage(0x29, newState ? 0x01 : 0x00);
    emit(state.copyWith(drumOn: newState));
  }

  void changeDrumStyle(int style) {
    _midiEngine.sendCcMessage(0x2A, style);
    emit(state.copyWith(drumStyle: style));
  }

  void pressRec() {
    _midiEngine.sendCcMessage(0x2D, 0x01);
  }

  void pressClear() {
    _midiEngine.sendCcMessage(0x2D, 0x04);
  }

  void pressStop() {
    _midiEngine.sendCcMessage(0x2D, 0x02);
  }

  void pressUndo() {
    // Undo 和 Redo 发送相同的指令
    _midiEngine.sendCcMessage(0x2D, 0x08);
  }

  // --- MIDI Signal Handling ---

  void _onMidiHexReceived(String hexKey) {
    // B0 2D 09 rec控件label变为wait rec
    if (hexKey == 'B02D09') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.waitRec,
          isRecButtonBlinking: false,
        ),
      );
    }
    // B0 2D 01 rec控件label变为recording，闪烁
    else if (hexKey == 'B02D01') {
      _startRecordingTimer();
      emit(
        state.copyWith(
          recButtonState: RecButtonState.recording,
          isRecButtonBlinking: true,
          layerCount: 1, // 开始第一层录音
          undoButtonState: UndoButtonState.none,
          recordingTime: Duration.zero,
          loopDuration: null,
          playbackProgress: 0.0,
        ),
      );
    }
    // B0 2D 02 rec控件label变为playing，闪烁
    else if (hexKey == 'B02D02') {
      _stopRecordingTimer(saveLoopDuration: true);
      _startPlaybackTimer();
      emit(
        state.copyWith(
          recButtonState: RecButtonState.playing,
          isRecButtonBlinking: true,
          // 当录音层数大于1时，可以进行Undo
          undoButtonState: state.layerCount > 1 ? UndoButtonState.undo : UndoButtonState.none,
        ),
      );
    }
    // B0 2D 03 rec控件label变为duo rec，闪烁
    else if (hexKey == 'B02D03') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.duoRec,
          isRecButtonBlinking: true,
          layerCount: state.layerCount + 1, // 叠加层数增加
          undoButtonState: UndoButtonState.none,
        ),
      );
    }
    // B0 2D 12 可能是 "Duo Rec 完成" 或 "Redo 完成"
    else if (hexKey == 'B02D12') {
      // 关键逻辑：通过判断之前的状态来区分
      if (state.undoButtonState == UndoButtonState.redo) {
        // 这是 Redo 操作
        emit(
          state.copyWith(
            undoButtonState: UndoButtonState.undo, // 恢复为 Undo
            recButtonState: RecButtonState.playing, // 状态变为 playing
            layerCount: state.layerCount + 1, // 层数恢复
          ),
        );
      } else {
        // 这是 Duo Rec 完成
        emit(
          state.copyWith(
            recButtonState: RecButtonState.duoRecComplete, // 使用新状态
            isRecButtonBlinking: true,
            undoButtonState: UndoButtonState.undo, // 完成后可以进行Undo
          ),
        );
        _startPlaybackTimer();
      }
    }
    // B0 2D 22 undo控件label变为redo
    else if (hexKey == 'B02D22') {
      emit(
        state.copyWith(
          undoButtonState: UndoButtonState.redo,
          layerCount: state.layerCount - 1, // 层数减少
        ),
      );
    }
    // B0 2D 04 rec控件label变为play，无闪烁
    else if (hexKey == 'B02D04' || hexKey == 'B02D00') {
      emit(
        state.copyWith(
          recButtonState: hexKey == 'B02D04' ? RecButtonState.play : RecButtonState.rec,
          isRecButtonBlinking: false,
          undoButtonState: UndoButtonState.none,
          layerCount: 1, // 清除或停止后重置层数
          recordingTime: Duration.zero,
          playbackProgress: 0.0,
          loopDuration: hexKey == 'B02D04' ? state.loopDuration : null,
        ),
      );
      _stopRecordingTimer();
      _stopPlaybackTimer();
    }
  }

  // --- Timer Methods ---

  void _startRecordingTimer() {
    _stopRecordingTimer();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final newTime = state.recordingTime + const Duration(milliseconds: 100);
      emit(state.copyWith(recordingTime: newTime));
    });
  }

  void _stopRecordingTimer({bool saveLoopDuration = false}) {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (saveLoopDuration) {
      emit(state.copyWith(loopDuration: state.recordingTime, recordingTime: Duration.zero));
    }
  }

  void _startPlaybackTimer() {
    _stopPlaybackTimer();
    if (state.loopDuration == null || state.loopDuration == Duration.zero) return;

    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final newProgress = (state.playbackProgress + 50 / state.loopDuration!.inMilliseconds) % 1.0;
      emit(state.copyWith(playbackProgress: newProgress));
    });
  }

  void _stopPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  @override
  Future<void> close() {
    _midiSubscription?.cancel();
    _stopRecordingTimer();
    _stopPlaybackTimer();
    return super.close();
  }
}
