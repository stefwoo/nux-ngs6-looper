import 'package:flutter/services.dart';
import '../models/midi_device.dart';

class MidiService {
  static const platform = MethodChannel('com.example.midi_controller/usb');

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
      }
    });
  }
}
