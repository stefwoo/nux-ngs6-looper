import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

class MidiEngine {
  final MidiCommand _midiCommand;
  StreamSubscription<MidiPacket>? _rxSubscription;
  final StreamController<String> _rawHexController = StreamController.broadcast();
  Uint8List? _lastReceivedPacket;

  MidiEngine(this._midiCommand);

  Stream<String> get rawHexStream => _rawHexController.stream;

  // This map is now deprecated in favor of direct CC messages, but kept for reference.
  static const Map<int, List<int>> _controlSignals = {
    1: [0xB0, 0x29, 0x00],
    2: [0xB0, 0x29, 0x01],
    3: [0xB0, 0x29, 0x02],
    4: [0xB0, 0x29, 0x03],
    5: [0xB0, 0x29, 0x04],
    6: [0xB0, 0x29, 0x05],
    7: [0xB0, 0x29, 0x06],
    8: [0xB0, 0x29, 0x07],
  };

  void sendControlSignal(int controlIndex) {
    if (_controlSignals.containsKey(controlIndex)) {
      final signal = _controlSignals[controlIndex]!;
      if (signal.length == 3) {
        final status = signal[0];
        final channel = status & 0x0F;
        final controller = signal[1];
        final value = signal[2];
        sendCcMessage(controller, value, channel: channel);
      }
    }
  }

  void sendCcMessage(int controller, int value, {int channel = 0}) {
    print('Sending CC: Ch: $channel, CC: $controller, Val: $value');
    CCMessage(
      channel: channel,
      controller: controller,
      value: value,
    ).send();
  }

  void sendLastReceivedPacket() {
    if (_lastReceivedPacket != null) {
      print('Sending last received packet: $_lastReceivedPacket');
      _midiCommand.sendData(_lastReceivedPacket!);
    } else {
      print('No packet received yet to send back.');
    }
  }

  void startListening(MidiDevice device) {
    stopListening(); // Ensure no previous listener is active
    print('Starting to listen on ${device.name}');
    _rxSubscription = _midiCommand.onMidiDataReceived?.listen((packet) {
      print('Received MIDI: ${packet.data}');
      _lastReceivedPacket = packet.data;
      final key = _parseMidiDataToHex(packet.data);
      _rawHexController.add(key);
    });
  }

  void stopListening() {
    _rxSubscription?.cancel();
    _rxSubscription = null;
  }

  String _parseMidiDataToHex(Uint8List data) {
    final key = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    print('Parsed MIDI key: $key');
    return key;
  }

  void dispose() {
    stopListening();
    _rawHexController.close();
  }
}
