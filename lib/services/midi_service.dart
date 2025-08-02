import 'package:flutter/services.dart';
import '../models/midi_device.dart';

class MidiService {
  static const platform = MethodChannel('com.example.midi_controller/usb');
  
  // MIDI消息回调函数
  Function(String)? _onMidiMessageReceived;

  Future<List<MidiDevice>> getUsbDevices() async {
    try {
      final result = await platform.invokeMethod('getUsbDevices');
      // 更安全的类型转换
      return (result as List).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MidiDevice.fromMap(map);
      }).toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get USB devices: ${e.message}');
    }
  }

  Future<bool> requestUsbPermission(int deviceId) async {
    try {
      return await platform.invokeMethod('requestUsbPermission', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to request USB permission: ${e.message}');
    }
  }

  Future<bool> sendMidiMessage(int deviceId, String message) async {
    try {
      return await platform.invokeMethod('sendMidiMessage', {
        'deviceId': deviceId,
        'message': message,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to send MIDI message: ${e.message}');
    }
  }

  /// 开始监听MIDI回传信号
  Future<bool> startMidiListening(int deviceId) async {
    try {
      return await platform.invokeMethod('startMidiListening', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to start MIDI listening: ${e.message}');
    }
  }

  /// 停止监听MIDI回传信号
  Future<bool> stopMidiListening() async {
    try {
      return await platform.invokeMethod('stopMidiListening');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop MIDI listening: ${e.message}');
    }
  }

  /// 设置MIDI消息接收回调
  void setMidiMessageListener(Function(String) onMessageReceived) {
    _onMidiMessageReceived = onMessageReceived;
  }

  void setDeviceListListener(Function(List<MidiDevice>) onUpdate) {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceListUpdated') {
        final result = call.arguments as List;
        // 更安全的类型转换
        final devices = result.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return MidiDevice.fromMap(map);
        }).toList();
        onUpdate(devices);
      } else if (call.method == 'onMidiMessageReceived') {
        final message = call.arguments as String;
        _onMidiMessageReceived?.call(message);
      }
    });
  }
}
