import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:midi_controller/services/midi_engine.dart';

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  final MidiEngine _midiEngine;
  StreamSubscription? _midiSubscription;

  AppCubit(this._midiEngine) : super(const AppState()) {
    _midiSubscription = _midiEngine.rawHexStream.listen(_onMidiHexReceived);
  }

  void connectToDevice(MidiDevice device) {
    _midiEngine.startListening(device);
  }

  // --- Public methods for UI interaction ---

  void toggleDrum() {
    final newState = !state.drumOn;
    // B0 29 01 for ON, B0 29 00 for OFF
    _midiEngine.sendCcMessage(0x29, newState ? 0x01 : 0x00);
    emit(state.copyWith(drumOn: newState));
  }

  void changeDrumStyle(int style) {
    // B0 2A xx
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
          undoButtonState: UndoButtonState.none,
        ),
      );
    }
    // B0 2D 01 rec控件label变为recording，闪烁
    else if (hexKey == 'B02D01') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.recording,
          isRecButtonBlinking: true,
          undoButtonState: UndoButtonState.none,
        ),
      );
    }
    // B0 2D 02 rec控件label变为playing，闪烁
    else if (hexKey == 'B02D02') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.playing,
          isRecButtonBlinking: true,
          undoButtonState: UndoButtonState.none,
        ),
      );
    }
    // B0 2D 03 rec控件label变为duo rec，闪烁
    else if (hexKey == 'B02D03') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.duoRec,
          isRecButtonBlinking: true,
          undoButtonState: UndoButtonState.none,
        ),
      );
    }
    // B0 2D 12 undo控件label变为undo
    else if (hexKey == 'B02D12') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.playing,
          isRecButtonBlinking: true,
        ),
      );
    }
    // B0 2D 22 undo控件label变为redo
    else if (hexKey == 'B02D22') {
      emit(
        state.copyWith(
          undoButtonState: UndoButtonState.redo,
        ),
      );
    }
    // B0 2D 04 rec控件label变为play，无闪烁
    else if (hexKey == 'B02D04') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.play,
          isRecButtonBlinking: false,
          undoButtonState: UndoButtonState.none,
        ),
      );
    }
    // B0 2D 00 rec控件label变为rec，无闪烁
    else if (hexKey == 'B02D00') {
      emit(
        state.copyWith(
          recButtonState: RecButtonState.rec,
          isRecButtonBlinking: false,
          undoButtonState: UndoButtonState.none,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _midiSubscription?.cancel();
    return super.close();
  }
}
