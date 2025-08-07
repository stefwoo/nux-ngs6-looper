part of 'app_cubit.dart';

enum RecButtonState {
  rec,
  recording,
  playing,
  waitRec,
  duoRec,
  duoRecComplete, // 新增：用于表示叠加录音完成的状态
  play,
}

enum UndoButtonState { none, undo, redo }

class AppState {
  final bool drumOn;
  final int drumStyle;
  final RecButtonState recButtonState;
  final bool isRecButtonBlinking;
  final UndoButtonState undoButtonState;
  final int layerCount; // 新增：追踪录音层数
  final Duration recordingTime;
  final double playbackProgress;
  final Duration? loopDuration;

  const AppState({
    this.drumOn = false,
    this.drumStyle = 0,
    this.recButtonState = RecButtonState.rec,
    this.isRecButtonBlinking = false,
    this.undoButtonState = UndoButtonState.none,
    this.layerCount = 1, // 初始为第1层
    this.recordingTime = Duration.zero,
    this.playbackProgress = 0.0,
    this.loopDuration,
  });

  AppState copyWith({
    bool? drumOn,
    int? drumStyle,
    RecButtonState? recButtonState,
    bool? isRecButtonBlinking,
    UndoButtonState? undoButtonState,
    int? layerCount, // 新增
    Duration? recordingTime,
    double? playbackProgress,
    Duration? loopDuration,
  }) {
    return AppState(
      drumOn: drumOn ?? this.drumOn,
      drumStyle: drumStyle ?? this.drumStyle,
      recButtonState: recButtonState ?? this.recButtonState,
      isRecButtonBlinking: isRecButtonBlinking ?? this.isRecButtonBlinking,
      undoButtonState: undoButtonState ?? this.undoButtonState,
      layerCount: layerCount ?? this.layerCount, // 新增
      recordingTime: recordingTime ?? this.recordingTime,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      loopDuration: loopDuration ?? this.loopDuration,
    );
  }
}
