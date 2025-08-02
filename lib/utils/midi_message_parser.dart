/// MIDI消息解析工具类
/// 专门用于解析Looper相关的MIDI回传信号
class MidiMessageParser {
  // Looper相关的MIDI命令前缀
  static const String LOOPER_PREFIX = 'B0 2D';
  
  /// 解析MIDI消息，返回命令类型
  static LooperMidiCommand? parseLooperMessage(String midiMessage) {
    if (!isLooperMessage(midiMessage)) {
      return null;
    }
    
    final parts = midiMessage.trim().split(' ');
    if (parts.length < 3) {
      return null;
    }
    
    try {
      final commandByte = int.parse(parts[2], radix: 16);
      return LooperMidiCommand.fromValue(commandByte);
    } catch (e) {
      return null;
    }
  }
  
  /// 检查是否是Looper相关的MIDI消息
  static bool isLooperMessage(String midiMessage) {
    return midiMessage.trim().toUpperCase().startsWith(LOOPER_PREFIX);
  }
  
  /// 将MIDI消息转换为十六进制字符串
  static String formatMidiMessage(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
  }
}

/// Looper MIDI命令枚举
enum LooperMidiCommand {
  /// 清除完成 (B0 2D 00)
  clearComplete(0x00),
  
  /// 开始录音 (B0 2D 01)
  startRecording(0x01),
  
  /// 录音完成开始播放 (B0 2D 02)
  recordingCompletePlay(0x02),
  
  /// 开始叠加录音 (B0 2D 03)
  startDubRecording(0x03),
  
  /// 停止播放 (B0 2D 04)
  stopPlayback(0x04),
  
  /// 等待录音 (B0 2D 09)
  waitingForRecord(0x09),
  
  /// 叠加录音完成播放 (B0 2D 12)
  dubRecordingCompletePlay(0x12),
  
  /// 撤销叠加录音 (B0 2D 22)
  undoDubRecording(0x22);
  
  const LooperMidiCommand(this.value);
  
  final int value;
  
  /// 从数值创建命令
  static LooperMidiCommand? fromValue(int value) {
    for (final command in LooperMidiCommand.values) {
      if (command.value == value) {
        return command;
      }
    }
    return null;
  }
  
  /// 获取命令的中文描述
  String get description {
    switch (this) {
      case LooperMidiCommand.clearComplete:
        return '清除完成';
      case LooperMidiCommand.startRecording:
        return '开始录音';
      case LooperMidiCommand.recordingCompletePlay:
        return '录音完成播放';
      case LooperMidiCommand.startDubRecording:
        return '开始叠加录音';
      case LooperMidiCommand.stopPlayback:
        return '停止播放';
      case LooperMidiCommand.waitingForRecord:
        return '等待录音';
      case LooperMidiCommand.dubRecordingCompletePlay:
        return '叠加录音完成播放';
      case LooperMidiCommand.undoDubRecording:
        return '撤销叠加录音';
    }
  }
  
  /// 获取十六进制字符串表示
  String get hexString {
    return 'B0 2D ${value.toRadixString(16).toUpperCase().padLeft(2, '0')}';
  }
}

/// Looper发送命令常量
class LooperSendCommands {
  /// 录音/叠加录音命令
  static const String RECORD = 'B0 2D 01';
  
  /// 停止命令
  static const String STOP = 'B0 2D 02';
  
  /// 清除命令
  static const String CLEAR = 'B0 2D 04';
  
  /// Undo/Redo命令
  static const String UNDO_REDO = 'B0 2D 08';
}
