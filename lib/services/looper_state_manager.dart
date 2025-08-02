import 'dart:async';
import '../models/looper_state.dart';
import '../utils/midi_message_parser.dart';

/// Looper状态管理器
/// 负责管理Looper的状态转换和按钮配置
class LooperStateManager {
  // 当前状态
  LooperState _currentState = LooperState.idle;
  
  // 是否为Undo模式（true表示可以Redo，false表示可以Undo）
  bool _isUndoMode = false;
  
  // 状态变化流控制器
  final StreamController<LooperState> _stateController = StreamController.broadcast();
  final StreamController<LooperButtonStates> _buttonStatesController = StreamController.broadcast();
  final StreamController<String> _statusController = StreamController.broadcast();
  
  /// 获取当前状态
  LooperState get currentState => _currentState;
  
  /// 获取当前按钮状态配置
  LooperButtonStates get currentButtonStates => 
      LooperButtonStates.fromLooperState(_currentState, _isUndoMode);
  
  /// 状态变化流
  Stream<LooperState> get stateStream => _stateController.stream;
  
  /// 按钮状态变化流
  Stream<LooperButtonStates> get buttonStatesStream => _buttonStatesController.stream;
  
  /// 状态描述变化流
  Stream<String> get statusStream => _statusController.stream;
  
  /// 处理MIDI回传消息
  void handleMidiMessage(String midiMessage) {
    final command = MidiMessageParser.parseLooperMessage(midiMessage);
    if (command == null) return;
    
    final previousState = _currentState;
    
    switch (command) {
      case LooperMidiCommand.clearComplete:
        _updateState(LooperState.idle);
        _isUndoMode = false;
        break;
        
      case LooperMidiCommand.waitingForRecord:
        _updateState(LooperState.waitingForRecord);
        break;
        
      case LooperMidiCommand.startRecording:
        _updateState(LooperState.recording);
        break;
        
      case LooperMidiCommand.recordingCompletePlay:
        _updateState(LooperState.playing);
        break;
        
      case LooperMidiCommand.startDubRecording:
        _updateState(LooperState.dubRecording);
        break;
        
      case LooperMidiCommand.dubRecordingCompletePlay:
        _updateState(LooperState.dubPlaying);
        break;
        
      case LooperMidiCommand.stopPlayback:
        _updateState(LooperState.stopped);
        break;
        
      case LooperMidiCommand.undoDubRecording:
        // 撤销叠加录音后，切换Undo/Redo模式
        _isUndoMode = !_isUndoMode;
        _updateState(LooperState.playing); // 保持播放状态
        break;
    }
    
    // 如果状态发生变化，通知监听者
    if (previousState != _currentState || command == LooperMidiCommand.undoDubRecording) {
      _notifyStateChange();
    }
  }
  
  /// 更新状态
  void _updateState(LooperState newState) {
    _currentState = newState;
  }
  
  /// 通知状态变化
  void _notifyStateChange() {
    _stateController.add(_currentState);
    _buttonStatesController.add(currentButtonStates);
    _statusController.add(_currentState.description);
  }
  
  /// 获取录音按钮应该发送的MIDI命令
  String getRecordCommand() {
    return LooperSendCommands.RECORD;
  }
  
  /// 获取停止按钮应该发送的MIDI命令
  String getStopCommand() {
    return LooperSendCommands.STOP;
  }
  
  /// 获取清除按钮应该发送的MIDI命令
  String getClearCommand() {
    return LooperSendCommands.CLEAR;
  }
  
  /// 获取Undo/Redo按钮应该发送的MIDI命令
  String getUndoRedoCommand() {
    return LooperSendCommands.UNDO_REDO;
  }
  
  /// 检查按钮是否可用
  bool isRecordEnabled() => currentButtonStates.record.enabled;
  bool isStopEnabled() => currentButtonStates.stop.enabled;
  bool isClearEnabled() => currentButtonStates.clear.enabled;
  bool isUndoRedoEnabled() => currentButtonStates.undoRedo.enabled;
  
  /// 检查按钮是否应该闪烁
  bool isRecordBlinking() => currentButtonStates.record.blinking;
  
  /// 重置状态到初始状态
  void reset() {
    _currentState = LooperState.idle;
    _isUndoMode = false;
    _notifyStateChange();
  }
  
  /// 获取详细的状态信息用于调试
  Map<String, dynamic> getStateInfo() {
    return {
      'currentState': _currentState.name,
      'stateDescription': _currentState.description,
      'isUndoMode': _isUndoMode,
      'buttonStates': {
        'record': {
          'text': currentButtonStates.record.text,
          'enabled': currentButtonStates.record.enabled,
          'blinking': currentButtonStates.record.blinking,
        },
        'stop': {
          'text': currentButtonStates.stop.text,
          'enabled': currentButtonStates.stop.enabled,
        },
        'clear': {
          'text': currentButtonStates.clear.text,
          'enabled': currentButtonStates.clear.enabled,
        },
        'undoRedo': {
          'text': currentButtonStates.undoRedo.text,
          'enabled': currentButtonStates.undoRedo.enabled,
        },
      }
    };
  }
  
  /// 释放资源
  void dispose() {
    _stateController.close();
    _buttonStatesController.close();
    _statusController.close();
  }
}
