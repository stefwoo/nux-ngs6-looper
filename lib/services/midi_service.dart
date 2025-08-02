import 'package:flutter/services.dart';
import '../models/midi_device.dart';

class MidiService {
  static const platform = MethodChannel('com.example.midi_controller/usb');

  Future<List<MidiDevice>> getUsbDevices() async {
    try {
      final result = await platform.invokeMethod('getUsbDevices');
      return (result as List).map((item) => MidiDevice.fromMap(item)).toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get USB devices: ${e.message}');
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
        final devices = result.map((item) => MidiDevice.fromMap(item)).toList();
        onUpdate(devices);
      }
    });
  }
}
