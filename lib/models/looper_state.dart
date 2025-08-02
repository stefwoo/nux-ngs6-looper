/// Looper状态枚举
enum LooperState {
  /// 空闲状态 - 未录制任何内容
  idle,
  
  /// 等待录音 - 按下录音按钮，等待声音进入
  waitingForRecord,
  
  /// 录音中 - 正在录制第一轨
  recording,
  
  /// 播放中 - 录音完成后播放
  playing,
  
  /// 叠加录音中 - 正在录制叠加轨道
  dubRecording,
  
  /// 叠加播放中 - 叠加录音完成后播放
  dubPlaying,
  
  /// 停止状态 - 有录音内容但已停止播放
  stopped;
  
  /// 获取状态的中文描述
  String get description {
    switch (this) {
      case LooperState.idle:
        return '空闲';
      case LooperState.waitingForRecord:
        return '等待录音';
      case LooperState.recording:
        return '录音中';
      case LooperState.playing:
        return '播放中';
      case LooperState.dubRecording:
        return '叠加录音中';
      case LooperState.dubPlaying:
        return '叠加播放中';
      case LooperState.stopped:
        return '已停止';
    }
  }
  
  /// 判断是否处于录音状态
  bool get isRecording {
    return this == LooperState.recording || this == LooperState.dubRecording;
  }
  
  /// 判断是否处于播放状态
  bool get isPlaying {
    return this == LooperState.playing || this == LooperState.dubPlaying;
  }
  
  /// 判断是否有录音内容
  bool get hasRecording {
    return this != LooperState.idle && this != LooperState.waitingForRecord;
  }
  
  /// 判断是否可以停止
  bool get canStop {
    return isPlaying;
  }
  
  /// 判断是否可以清除
  bool get canClear {
    return hasRecording;
  }
  
  /// 判断是否可以Undo
  bool get canUndo {
    return this == LooperState.dubPlaying || this == LooperState.stopped;
  }
}

/// 按钮状态配置类
class ButtonConfig {
  final String text;
  final bool enabled;
  final bool blinking;
  
  const ButtonConfig({
    required this.text,
    required this.enabled,
    this.blinking = false,
  });
}

/// Looper按钮状态管理类
class LooperButtonStates {
  final ButtonConfig record;
  final ButtonConfig stop;
  final ButtonConfig clear;
  final ButtonConfig undoRedo;
  
  const LooperButtonStates({
    required this.record,
    required this.stop,
    required this.clear,
    required this.undoRedo,
  });
  
  /// 根据Looper状态创建按钮状态配置
  static LooperButtonStates fromLooperState(LooperState state, bool isUndoMode) {
    switch (state) {
      case LooperState.idle:
        return const LooperButtonStates(
          record: ButtonConfig(text: 'REC', enabled: true),
          stop: ButtonConfig(text: 'STOP', enabled: false),
          clear: ButtonConfig(text: 'CLEAR', enabled: false),
          undoRedo: ButtonConfig(text: 'UNDO', enabled: false),
        );
        
      case LooperState.waitingForRecord:
        return const LooperButtonStates(
          record: ButtonConfig(text: 'WAIT REC', enabled: true),
          stop: ButtonConfig(text: 'STOP', enabled: false),
          clear: ButtonConfig(text: 'CLEAR', enabled: false),
          undoRedo: ButtonConfig(text: 'UNDO', enabled: false),
        );
        
      case LooperState.recording:
        return const LooperButtonStates(
          record: ButtonConfig(text: 'REC', enabled: true, blinking: true),
          stop: ButtonConfig(text: 'STOP', enabled: true),
          clear: ButtonConfig(text: 'CLEAR', enabled: true),
          undoRedo: ButtonConfig(text: 'UNDO', enabled: false),
        );
        
      case LooperState.playing:
        return const LooperButtonStates(
          record: ButtonConfig(text: 'PLAY', enabled: true, blinking: true),
          stop: ButtonConfig(text: 'STOP', enabled: true),
          clear: ButtonConfig(text: 'CLEAR', enabled: true),
          undoRedo: ButtonConfig(text: 'UNDO', enabled: false),
        );
        
      case LooperState.dubRecording:
        return LooperButtonStates(
          record: const ButtonConfig(text: 'DUB REC', enabled: true, blinking: true),
          stop: const ButtonConfig(text: 'STOP', enabled: true),
          clear: const ButtonConfig(text: 'CLEAR', enabled: true),
          undoRedo: ButtonConfig(text: isUndoMode ? 'REDO' : 'UNDO', enabled: true),
        );
        
      case LooperState.dubPlaying:
        return LooperButtonStates(
          record: const ButtonConfig(text: 'PLAY', enabled: true, blinking: true),
          stop: const ButtonConfig(text: 'STOP', enabled: true),
          clear: const ButtonConfig(text: 'CLEAR', enabled: true),
          undoRedo: ButtonConfig(text: isUndoMode ? 'REDO' : 'UNDO', enabled: true),
        );
        
      case LooperState.stopped:
        return LooperButtonStates(
          record: const ButtonConfig(text: 'PLAY', enabled: true, blinking: false),
          stop: const ButtonConfig(text: 'STOP', enabled: false),
          clear: const ButtonConfig(text: 'CLEAR', enabled: true),
          undoRedo: ButtonConfig(text: isUndoMode ? 'REDO' : 'UNDO', enabled: true),
        );
    }
  }
}
