import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerService {
  final MidiCommand _midiCommand;

  PermissionHandlerService(this._midiCommand);

  Future<void> requestPermissions() async {
    // On Android, Bluetooth permission is required for MIDI.
    // On iOS, this is not needed.
    if (await Permission.bluetooth.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
    }
    if (await Permission.bluetoothScan.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
    }
    if (await Permission.bluetoothConnect.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
    }
  }

  Future<List<MidiDevice>> listMidiDevices() async {
    return await _midiCommand.devices ?? [];
  }

  Future<MidiDevice?> findDevice(String vendorId, String productId) async {
    final devices = await listMidiDevices();
    for (var device in devices) {
      // Note: VID/PID filtering might require more specific platform logic
      // as it's not directly exposed in a cross-platform way by flutter_midi_command.
      // This is a conceptual implementation.
      if (device.id.contains(vendorId) && device.id.contains(productId)) {
        return device;
      }
    }
    return null;
  }

  Future<void> connectToDevice(MidiDevice device) async {
    await _midiCommand.connectToDevice(device);
  }
}
