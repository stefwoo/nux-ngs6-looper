part of 'app_cubit.dart';

enum RecButtonState {
  rec,
  recording,
  playing,
  waitRec,
  duoRec,
  // redo, // move to UndoButtonState
  // undo, // move to UndoButtonState
  play,
}

enum UndoButtonState { none, undo, redo }

class AppState {
  final bool drumOn;
  final int drumStyle;
  final RecButtonState recButtonState;
  final bool isRecButtonBlinking;
  final UndoButtonState undoButtonState;

  const AppState({
    this.drumOn = false,
    this.drumStyle = 0,
    this.recButtonState = RecButtonState.rec,
    this.isRecButtonBlinking = false,
    this.undoButtonState = UndoButtonState.none,
  });

  AppState copyWith({
    bool? drumOn,
    int? drumStyle,
    RecButtonState? recButtonState,
    bool? isRecButtonBlinking,
    UndoButtonState? undoButtonState,
  }) {
    return AppState(
      drumOn: drumOn ?? this.drumOn,
      drumStyle: drumStyle ?? this.drumStyle,
      recButtonState: recButtonState ?? this.recButtonState,
      isRecButtonBlinking: isRecButtonBlinking ?? this.isRecButtonBlinking,
      undoButtonState: undoButtonState ?? this.undoButtonState,
    );
  }
}
