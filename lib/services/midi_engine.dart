import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

// Enum to represent predefined signals for clarity
enum MidiSignal {
  signal1,
  signal2,
  signal3,
  signal4,
  signal5,
  signal6,
  signal7,
  signal8,
  unknown,
}

class MidiEngine {
  final MidiCommand _midiCommand;
  StreamSubscription<MidiPacket>? _rxSubscription;

  MidiEngine(this._midiCommand);
  final StreamController<MidiSignal> _signalController = StreamController.broadcast();
  Uint8List? _lastReceivedPacket;

  Stream<MidiSignal> get signalStream => _signalController.stream;

  // Map of control index to MIDI message
  static const Map<int, List<int>> _controlSignals = {
    // All signals now use Controller 0x29 on Channel 1 (0xB0) with different values
    1: [0xB0, 0x29, 0x00],
    2: [0xB0, 0x29, 0x01],
    3: [0xB0, 0x29, 0x02],
    4: [0xB0, 0x29, 0x03],
    5: [0xB0, 0x29, 0x04],
    6: [0xB0, 0x29, 0x05],
    7: [0xB0, 0x29, 0x06],
    8: [0xB0, 0x29, 0x07],
  };

  // Map of raw MIDI data to our internal signal representation
  static const Map<String, MidiSignal> _signalMap = {
    'F030': MidiSignal.signal1,
    // Add other mappings as needed
  };

  void sendControlSignal(int controlIndex) {
    if (_controlSignals.containsKey(controlIndex)) {
      final signal = _controlSignals[controlIndex]!;
      if (signal.length == 3) {
        final status = signal[0];
        final channel = status & 0x0F;
        final controller = signal[1];
        final value = signal[2];

        print('Sending CC via Message: Ch: $channel, CC: $controller, Val: $value');
        CCMessage(
          channel: channel,
          controller: controller,
          value: value,
        ).send();
      }
    }
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
      // Simple parser example
      final signalId = _parseMidiData(packet.data);
      _signalController.add(signalId); // Always add the signal, even if unknown
    });
  }

  void stopListening() {
    _rxSubscription?.cancel();
    _rxSubscription = null;
  }

  MidiSignal _parseMidiData(Uint8List data) {
    // This is a placeholder for a more robust parser.
    // For now, we'll just convert the byte array to a hex string to use as a key.
    final key = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    print('Parsed MIDI key: $key');
    return _signalMap[key] ?? MidiSignal.unknown;
  }

  void dispose() {
    stopListening();
    _signalController.close();
  }
}
